from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Optional
from xml.etree import ElementTree as ET
from zipfile import ZipFile


XLSX_NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}

HEADER_ALIASES = {
    "window": ("처리창구", "창구", "담당창구"),
    "service_name": ("신고및질문내용", "업무명", "민원명", "질문내용"),
    "fee_raw": ("수수료여부", "수수료"),
    "reception_fee_raw": ("접수수수료", "수수료금액", "금액"),
    "license_tax_raw": ("등록면허세여부", "등록면허세", "면허세여부"),
    "department": ("처리부서", "처리 부서", "담당 부서", "담당부서"),
    "special_note": ("특이사항", "비고", "안내사항"),
}


@dataclass(frozen=True)
class RawServiceRow:
    source_row: int
    window: str
    service_name: str
    fee_raw: str
    reception_fee_raw: str = ""
    license_tax_raw: str = ""
    department: str = ""
    special_note: str = ""


@dataclass(frozen=True)
class DepartmentLocation:
    floor: str
    department: str
    normalized_department: str
    source_row: int


def normalize_space(value: object) -> str:
    return re.sub(r"\s+", " ", "" if value is None else str(value)).strip()


def normalize_key(value: str) -> str:
    value = normalize_space(value).lower()
    return re.sub(r"[^0-9a-z가-힣]+", "", value)


def make_service_id(service_name: str) -> str:
    normalized = normalize_key(service_name)
    digest = hashlib.sha1(normalized.encode("utf-8")).hexdigest()[:8]
    return f"svc_{digest}"


def excel_col_to_idx(cell_ref: str) -> int:
    letters = "".join(ch for ch in cell_ref if ch.isalpha())
    idx = 0
    for ch in letters:
        idx = idx * 26 + ord(ch.upper()) - ord("A") + 1
    return idx - 1


def read_cell_text(cell: ET.Element, shared_strings: list[str]) -> str:
    value = cell.find("a:v", XLSX_NS)
    if value is None:
        return normalize_space("".join(text.text or "" for text in cell.findall(".//a:t", XLSX_NS)))
    text = value.text or ""
    if cell.get("t") == "s":
        return normalize_space(shared_strings[int(text)])
    return normalize_space(text)


def read_shared_strings(zip_file: ZipFile) -> list[str]:
    if "xl/sharedStrings.xml" not in zip_file.namelist():
        return []
    root = ET.fromstring(zip_file.read("xl/sharedStrings.xml"))
    values = []
    for item in root.findall("a:si", XLSX_NS):
        values.append("".join(text.text or "" for text in item.findall(".//a:t", XLSX_NS)))
    return values


def read_workbook_sheet_path(zip_file: ZipFile, sheet_name: Optional[str] = None) -> str:
    workbook = ET.fromstring(zip_file.read("xl/workbook.xml"))
    rels = ET.fromstring(zip_file.read("xl/_rels/workbook.xml.rels"))
    relmap = {rel.get("Id"): rel.get("Target") for rel in rels}
    sheets = workbook.findall("a:sheets/a:sheet", XLSX_NS)
    selected = None
    if sheet_name:
        selected = next((sheet for sheet in sheets if sheet.get("name") == sheet_name), None)
    selected = selected or sheets[0]
    rel_id = selected.get(f"{{{XLSX_NS['r']}}}id")
    target = relmap[rel_id]
    return "xl/" + target.lstrip("/")


def read_sheet_rows(path: Path, sheet_name: Optional[str] = None) -> list[tuple[int, list[str]]]:
    rows: list[tuple[int, list[str]]] = []
    with ZipFile(path) as zip_file:
        shared_strings = read_shared_strings(zip_file)
        sheet_path = read_workbook_sheet_path(zip_file, sheet_name)
        sheet = ET.fromstring(zip_file.read(sheet_path))
        for row in sheet.findall("a:sheetData/a:row", XLSX_NS):
            row_no = int(row.get("r", "0"))
            values: list[str] = []
            for cell in row.findall("a:c", XLSX_NS):
                col_idx = excel_col_to_idx(cell.get("r", "A1"))
                while len(values) <= col_idx:
                    values.append("")
                values[col_idx] = read_cell_text(cell, shared_strings)
            rows.append((row_no, values))
    return rows


def find_header_map(rows: list[tuple[int, list[str]]]) -> tuple[int, dict[str, int]]:
    for row_index, (_row_no, values) in enumerate(rows):
        normalized_headers = {normalize_key(value): idx for idx, value in enumerate(values) if normalize_key(value)}
        header_map: dict[str, int] = {}
        for field, aliases in HEADER_ALIASES.items():
            for alias in aliases:
                if alias in normalized_headers:
                    header_map[field] = normalized_headers[alias]
                    break
        if {"window", "service_name"} <= set(header_map):
            return row_index, header_map
    return 0, {"window": 0, "service_name": 1, "fee_raw": 2}


def get_value(values: list[str], header_map: dict[str, int], field: str) -> str:
    idx = header_map.get(field)
    if idx is None or idx >= len(values):
        return ""
    return normalize_space(values[idx])


def read_service_rows_from_xlsx(path: Path, sheet_name: Optional[str] = None) -> list[RawServiceRow]:
    rows: list[RawServiceRow] = []
    current_window = ""
    sheet_rows = read_sheet_rows(path, sheet_name)
    header_index, header_map = find_header_map(sheet_rows)
    for row_no, values in sheet_rows[header_index + 1 :]:
        window = get_value(values, header_map, "window")
        if window:
            current_window = window
        service_name = get_value(values, header_map, "service_name")
        if not service_name:
            continue
        rows.append(
            RawServiceRow(
                source_row=row_no,
                window=current_window,
                service_name=service_name,
                fee_raw=get_value(values, header_map, "fee_raw"),
                reception_fee_raw=get_value(values, header_map, "reception_fee_raw"),
                license_tax_raw=get_value(values, header_map, "license_tax_raw"),
                department=get_value(values, header_map, "department"),
                special_note=get_value(values, header_map, "special_note"),
            )
        )
    return rows


def read_department_locations_from_xlsx(path: Path | None) -> list[DepartmentLocation]:
    if not path or not path.is_file():
        return []

    rows: list[DepartmentLocation] = []
    current_floor = ""
    for row_no, values in read_sheet_rows(path):
        floor = normalize_space(values[0]) if len(values) > 0 else ""
        department = normalize_space(values[1]) if len(values) > 1 else ""
        if floor:
            current_floor = floor
        if not current_floor or not department:
            continue
        rows.append(
            DepartmentLocation(
                floor=current_floor,
                department=department,
                normalized_department=normalize_key(department),
                source_row=row_no,
            )
        )
    return rows


def is_empty_amount(raw: str) -> bool:
    return normalize_space(raw) in {"", "-", "?", "없음", "해당없음"}


def parse_required_status(raw_status: str, unknown_note: str, required_note: str, not_required_note: str) -> tuple[str, str]:
    raw = normalize_space(raw_status)
    upper = raw.upper()
    if upper == "T":
        return "required", required_note
    if upper == "F":
        return "not_required", not_required_note
    if raw in {"?", ""}:
        return "unknown", unknown_note
    if "확인" in raw or "상동" in raw or "달라" in raw or "상이" in raw:
        return "conditional", raw
    return "unknown", raw


def amount_sentence(amount: str) -> str:
    amount = normalize_space(amount)
    if not amount:
        return ""
    if amount.endswith("상이함"):
        return f"접수 수수료는 {amount[:-3]}상이합니다."
    if amount.endswith(("원", "시", "임", "함", "됨")):
        return f"접수 수수료는 {amount}입니다."
    return f"접수 수수료는 {amount}입니다."


def parse_fee_status(fee_raw: str, reception_fee_raw: str = "") -> tuple[str, str]:
    raw = normalize_space(fee_raw)
    amount = normalize_space(reception_fee_raw)
    if raw.upper() == "T" and not is_empty_amount(amount):
        return "required", amount_sentence(amount)
    if raw.upper() == "T":
        return "required", "수수료 납부가 필요한 민원으로 표시되어 있습니다."
    if raw.upper() == "F":
        return "not_required", "접수 수수료가 필요하지 않은 민원으로 표시되어 있습니다."
    if raw in {"?", ""} and not is_empty_amount(amount):
        return "conditional", f"{amount_sentence(amount)} 다만 수수료 여부 확인이 필요합니다."
    return parse_required_status(
        raw,
        "자료에서 접수 수수료 여부가 명확히 확인되지 않습니다.",
        "수수료 납부가 필요한 민원으로 표시되어 있습니다.",
        "접수 수수료가 필요하지 않은 민원으로 표시되어 있습니다.",
    )


def parse_license_tax_status(license_tax_raw: str) -> tuple[str, str]:
    return parse_required_status(
        license_tax_raw,
        "자료에서 등록면허세 납부 여부가 명확히 확인되지 않습니다.",
        "등록면허세 납부가 필요한 민원으로 표시되어 있습니다.",
        "등록면허세 납부가 필요하지 않은 민원으로 표시되어 있습니다.",
    )


def parse_special_note(note: str, department: str = "") -> dict[str, object]:
    raw = normalize_space(note)
    explicit_department = normalize_space(department)
    referral_department = explicit_department
    unattended_available = "무인민원발급기" in raw
    identity_required = "본인확인" in raw

    if not referral_department and re.fullmatch(r"[가-힣A-Za-z0-9·\s]+과", raw):
        referral_department = raw

    special_types: list[str] = []
    if referral_department:
        special_types.append("department_referral")
    if unattended_available:
        special_types.append("unattended_issuer")
    if identity_required:
        special_types.append("identity_verification")

    return {
        "department": referral_department,
        "special_type": ",".join(special_types),
        "unattended_available": int(unattended_available),
        "identity_required": int(identity_required),
    }


def load_alias_map(path: Path) -> dict[str, list[str]]:
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        return {}
    aliases: dict[str, list[str]] = {}
    for service_name, values in data.items():
        if isinstance(values, str):
            values = [values]
        if not isinstance(values, list):
            continue
        cleaned = [normalize_space(value) for value in values if normalize_space(value)]
        aliases[normalize_space(service_name)] = cleaned
    return aliases


def create_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        PRAGMA foreign_keys = ON;

        DROP TABLE IF EXISTS aliases;
        DROP TABLE IF EXISTS department_locations;
        DROP TABLE IF EXISTS services;

        CREATE TABLE services (
            service_id TEXT PRIMARY KEY,
            service_name TEXT NOT NULL UNIQUE,
            category TEXT,
            window TEXT NOT NULL,
            department TEXT,
            department_floor TEXT,
            window_floor TEXT,
            fee_status TEXT NOT NULL CHECK (fee_status IN ('required', 'not_required', 'conditional', 'unknown')),
            reception_fee TEXT,
            fee_note TEXT,
            license_tax_status TEXT NOT NULL CHECK (license_tax_status IN ('required', 'not_required', 'conditional', 'unknown')),
            license_tax_note TEXT,
            document_note TEXT,
            status_note TEXT,
            special_note TEXT,
            special_type TEXT,
            unattended_available INTEGER NOT NULL DEFAULT 0,
            identity_required INTEGER NOT NULL DEFAULT 0,
            source_file TEXT NOT NULL,
            source_row INTEGER NOT NULL,
            created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE aliases (
            alias_id INTEGER PRIMARY KEY AUTOINCREMENT,
            service_id TEXT NOT NULL,
            alias TEXT NOT NULL,
            normalized_alias TEXT NOT NULL,
            source TEXT NOT NULL,
            FOREIGN KEY(service_id) REFERENCES services(service_id) ON DELETE CASCADE,
            UNIQUE(service_id, normalized_alias)
        );

        CREATE TABLE department_locations (
            department_id INTEGER PRIMARY KEY AUTOINCREMENT,
            floor TEXT NOT NULL,
            department TEXT NOT NULL,
            normalized_department TEXT NOT NULL UNIQUE,
            source_file TEXT NOT NULL,
            source_row INTEGER NOT NULL
        );

        CREATE INDEX idx_services_name ON services(service_name);
        CREATE INDEX idx_services_window ON services(window);
        CREATE INDEX idx_services_department ON services(department);
        CREATE INDEX idx_department_locations_normalized ON department_locations(normalized_department);
        CREATE INDEX idx_aliases_normalized ON aliases(normalized_alias);
        """
    )


def insert_service(conn: sqlite3.Connection, row: RawServiceRow, source_file: str) -> str:
    service_name = row.service_name
    service_id = make_service_id(service_name)
    if conn.execute("SELECT 1 FROM services WHERE service_id = ?", (service_id,)).fetchone():
        service_id = make_service_id(f"{service_name} {row.source_row}")
    if conn.execute("SELECT 1 FROM services WHERE service_name = ?", (service_name,)).fetchone():
        service_name = f"{service_name} ({row.source_row}행)"
    fee_status, fee_note = parse_fee_status(row.fee_raw, row.reception_fee_raw)
    license_tax_status, license_tax_note = parse_license_tax_status(row.license_tax_raw)
    reception_fee = "" if is_empty_amount(row.reception_fee_raw) else normalize_space(row.reception_fee_raw)
    special = parse_special_note(row.special_note, row.department)
    conn.execute(
        """
        INSERT INTO services (
            service_id, service_name, category, window, department,
            department_floor, window_floor,
            fee_status, reception_fee, fee_note, license_tax_status, license_tax_note,
            document_note, status_note, special_note, special_type,
            unattended_available, identity_required, source_file, source_row
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            service_id,
            service_name,
            None,
            row.window,
            special["department"] or None,
            None,
            None,
            fee_status,
            reception_fee,
            fee_note,
            license_tax_status,
            license_tax_note,
            "구비서류와 보완 필요 여부는 담당부서 확인이 필요합니다.",
            "처리 가능 여부와 세부 기준은 민원 내용에 따라 달라질 수 있습니다.",
            normalize_space(row.special_note),
            special["special_type"],
            special["unattended_available"],
            special["identity_required"],
            source_file,
            row.source_row,
        ),
    )
    return service_id


def insert_department_locations(conn: sqlite3.Connection, locations: list[DepartmentLocation], source_file: str) -> None:
    for location in locations:
        conn.execute(
            """
            INSERT OR IGNORE INTO department_locations (
                floor, department, normalized_department, source_file, source_row
            ) VALUES (?, ?, ?, ?, ?)
            """,
            (
                location.floor,
                location.department,
                location.normalized_department,
                source_file,
                location.source_row,
            ),
        )


def department_key_from_window(window: str) -> str:
    normalized = normalize_space(window)
    match = re.match(r"([가-힣A-Za-z0-9·\s]+?과)", normalized)
    if match:
        return normalize_key(match.group(1))
    return normalize_key(normalized)


def apply_service_floors(conn: sqlite3.Connection) -> None:
    location_rows = conn.execute("SELECT normalized_department, floor FROM department_locations").fetchall()
    floors_by_department = {row["normalized_department"]: row["floor"] for row in location_rows}
    if not floors_by_department:
        return

    rows = conn.execute("SELECT service_id, window, department FROM services").fetchall()
    for row in rows:
        department_key = normalize_key(row["department"] or "")
        window_key = department_key_from_window(row["window"] or "")
        conn.execute(
            """
            UPDATE services
            SET department_floor = ?,
                window_floor = ?
            WHERE service_id = ?
            """,
            (
                floors_by_department.get(department_key),
                floors_by_department.get(window_key),
                row["service_id"],
            ),
        )


def merge_related_special_notes(conn: sqlite3.Connection) -> None:
    rows = conn.execute(
        """
        SELECT service_id, service_name, department, special_note, special_type,
               unattended_available, identity_required
        FROM services
        """
    ).fetchall()
    groups: dict[str, list[sqlite3.Row]] = {}
    for row in rows:
        groups.setdefault(normalize_key(row["service_name"]), []).append(row)

    for group in groups.values():
        if len(group) < 2:
            continue
        departments = [normalize_space(row["department"]) for row in group if normalize_space(row["department"])]
        notes = [normalize_space(row["special_note"]) for row in group if normalize_space(row["special_note"])]
        special_types = []
        for row in group:
            for value in normalize_space(row["special_type"]).split(","):
                if value and value not in special_types:
                    special_types.append(value)
        unattended_available = int(any(row["unattended_available"] for row in group))
        identity_required = int(any(row["identity_required"] for row in group))
        department = departments[0] if departments else None
        special_note = " / ".join(dict.fromkeys(notes))
        special_type = ",".join(special_types)
        for row in group:
            conn.execute(
                """
                UPDATE services
                SET department = COALESCE(department, ?),
                    special_note = ?,
                    special_type = ?,
                    unattended_available = ?,
                    identity_required = ?
                WHERE service_id = ?
                """,
                (department, special_note, special_type, unattended_available, identity_required, row["service_id"]),
            )


def insert_alias(conn: sqlite3.Connection, service_id: str, alias: str, source: str) -> None:
    alias = normalize_space(alias)
    if not alias:
        return
    conn.execute(
        """
        INSERT OR IGNORE INTO aliases (service_id, alias, normalized_alias, source)
        VALUES (?, ?, ?, ?)
        """,
        (service_id, alias, normalize_key(alias), source),
    )


OPTION_SPLIT_PATTERN = re.compile(r"\s*(?:/|,|·|및|또는|와|과)\s*")


def split_option_text(text: str) -> list[str]:
    options = [normalize_space(part) for part in OPTION_SPLIT_PATTERN.split(text) if normalize_space(part)]
    return [option for option in options if len(normalize_key(option)) >= 2]


def alias_variants(alias: str) -> list[str]:
    base = normalize_space(alias)
    if not base:
        return []

    variants: list[str] = []

    def add(value: str) -> None:
        value = normalize_space(value)
        if value and value not in variants:
            variants.append(value)

    add(base)
    replacements = {
        "재교부": "재발급",
        "갱신": "재발급",
        "개시": "개업",
        "신규": "개업",
        "축조": "설치",
        "영업의 ": "영업 ",
        "신고사항": "신고 사항",
    }
    for source, target in replacements.items():
        if source in base:
            add(base.replace(source, target))
        if target in base:
            add(base.replace(target, source))
    if "(" in base and ")" in base:
        without_parentheses = normalize_space(re.sub(r"\([^)]*\)", " ", base))
        add(without_parentheses)
        for inner in re.findall(r"\(([^)]*)\)", base):
            inner = normalize_space(re.sub(r"^(일명|약칭)\s*", "", inner))
            if inner:
                add(inner)
                add(f"{inner} {without_parentheses}")
                add(f"{without_parentheses} {inner}")
                for option in split_option_text(inner):
                    add(f"{option} {without_parentheses}")
                    add(f"{without_parentheses} {option}")
                    add(base.replace(f"({inner})", option))
    for match in re.finditer(r"[0-9A-Za-z가-힣]+(?:/[0-9A-Za-z가-힣]+)+", base):
        grouped = match.group(0)
        for option in split_option_text(grouped):
            add(base.replace(grouped, option))
    compact = normalize_space(base.replace(" ", ""))
    if compact != base:
        add(compact)
    return variants


def derived_service_aliases(service_name: str) -> list[str]:
    aliases = []
    base = normalize_space(service_name)
    suffixes = ("관련 문의", "관련 민원", "문의", "민원", "관련")
    aliases.extend(alias_variants(base))
    for suffix in suffixes:
        if base.endswith(suffix):
            stripped = normalize_space(base[: -len(suffix)])
            if stripped:
                aliases.extend(alias_variants(stripped))

    stop_suffixes = (" 신청", " 신고", " 발급", " 등록", " 허가", " 관련")
    generic_short_aliases = {"사업개업", "사업개시", "영업개업", "영업개시", "변경", "등록"}
    for alias in list(aliases):
        for suffix in stop_suffixes:
            if alias.endswith(suffix):
                short = normalize_space(alias[: -len(suffix)])
                if len(normalize_key(short)) >= 4 and normalize_key(short) not in generic_short_aliases:
                    aliases.extend(alias_variants(short))

    return list(dict.fromkeys(alias for alias in aliases if alias != base and normalize_key(alias) not in generic_short_aliases))


def alias_match_score(text: str, service_name: str) -> float:
    left = normalize_key(text)
    right = normalize_key(service_name)
    if not left or not right:
        return 0.0
    if left in right or right in left:
        return 1.0
    left_grams = {left[idx : idx + 2] for idx in range(max(1, len(left) - 1))}
    right_grams = {right[idx : idx + 2] for idx in range(max(1, len(right) - 1))}
    if not left_grams or not right_grams:
        return 0.0
    return len(left_grams & right_grams) / max(1, len(left_grams | right_grams))


def resolve_alias_service_id(alias: str, service_ids: dict[str, str], min_score: float = 0.55) -> str | None:
    normalized_alias = normalize_key(alias)
    if len(normalized_alias) < 4:
        return None
    for service_name, service_id in service_ids.items():
        normalized_service = normalize_key(service_name)
        if normalized_service == normalized_alias:
            return service_id
        if normalized_alias in normalized_service or normalized_service in normalized_alias:
            return service_id
    ranked = sorted(
        ((alias_match_score(alias, service_name), service_id) for service_name, service_id in service_ids.items()),
        key=lambda item: item[0],
        reverse=True,
    )
    if ranked and ranked[0][0] >= min_score:
        return ranked[0][1]
    return None


def build_database(xlsx_path: Path, alias_path: Path, db_path: Path) -> None:
    build_database_with_locations(xlsx_path, alias_path, db_path, Path("data/층별_과분포도.xlsx"))


def build_database_with_locations(xlsx_path: Path, alias_path: Path, db_path: Path, floors_path: Path | None = None) -> None:
    rows = read_service_rows_from_xlsx(xlsx_path)
    alias_map = load_alias_map(alias_path)
    department_locations = read_department_locations_from_xlsx(floors_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    with sqlite3.connect(db_path) as conn:
        conn.row_factory = sqlite3.Row
        create_schema(conn)
        insert_department_locations(conn, department_locations, floors_path.name if floors_path else "")
        service_ids: dict[str, str] = {}
        for row in rows:
            service_id = insert_service(conn, row, xlsx_path.name)
            service_ids[row.service_name] = service_id
            insert_alias(conn, service_id, row.service_name, "service_name")
            compact = normalize_space(row.service_name.replace(" ", ""))
            if compact != row.service_name:
                insert_alias(conn, service_id, compact, "service_name_compact")
            for alias in derived_service_aliases(row.service_name):
                insert_alias(conn, service_id, alias, "service_name_derived")

        merge_related_special_notes(conn)
        apply_service_floors(conn)

        for service_name, aliases in alias_map.items():
            service_id = service_ids.get(service_name) or resolve_alias_service_id(service_name, service_ids, min_score=0.45)
            inserted = 0
            for alias in aliases:
                alias_service_id = service_id or resolve_alias_service_id(alias, service_ids)
                if not alias_service_id:
                    continue
                for variant in alias_variants(alias):
                    insert_alias(conn, alias_service_id, variant, alias_path.name)
                inserted += 1
            if not service_id and not inserted:
                print(f"[warn] alias service not found in xlsx: {service_name}")

        service_count = conn.execute("SELECT COUNT(*) FROM services").fetchone()[0]
        alias_count = conn.execute("SELECT COUNT(*) FROM aliases").fetchone()[0]
        floor_count = conn.execute("SELECT COUNT(*) FROM department_locations").fetchone()[0]
        print(f"[db] created={db_path} services={service_count} aliases={alias_count} department_locations={floor_count}")


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build local SQLite DB from department task xlsx.")
    parser.add_argument("--xlsx", default="data/각부서별_업무담당.xlsx")
    parser.add_argument("--floors", default="data/층별_과분포도.xlsx")
    parser.add_argument("--aliases", default="data/route_aliases.json")
    parser.add_argument("--output", default="data/services.db")
    return parser


def main() -> None:
    args = build_arg_parser().parse_args()
    build_database_with_locations(Path(args.xlsx), Path(args.aliases), Path(args.output), Path(args.floors))


if __name__ == "__main__":
    main()
