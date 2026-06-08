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
}


@dataclass(frozen=True)
class RawServiceRow:
    source_row: int
    window: str
    service_name: str
    fee_raw: str
    reception_fee_raw: str = ""
    license_tax_raw: str = ""


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
        DROP TABLE IF EXISTS services;

        CREATE TABLE services (
            service_id TEXT PRIMARY KEY,
            service_name TEXT NOT NULL UNIQUE,
            category TEXT,
            window TEXT NOT NULL,
            department TEXT,
            fee_status TEXT NOT NULL CHECK (fee_status IN ('required', 'not_required', 'conditional', 'unknown')),
            reception_fee TEXT,
            fee_note TEXT,
            license_tax_status TEXT NOT NULL CHECK (license_tax_status IN ('required', 'not_required', 'conditional', 'unknown')),
            license_tax_note TEXT,
            document_note TEXT,
            status_note TEXT,
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

        CREATE INDEX idx_services_name ON services(service_name);
        CREATE INDEX idx_services_window ON services(window);
        CREATE INDEX idx_aliases_normalized ON aliases(normalized_alias);
        """
    )


def insert_service(conn: sqlite3.Connection, row: RawServiceRow, source_file: str) -> str:
    service_id = make_service_id(row.service_name)
    fee_status, fee_note = parse_fee_status(row.fee_raw, row.reception_fee_raw)
    license_tax_status, license_tax_note = parse_license_tax_status(row.license_tax_raw)
    reception_fee = "" if is_empty_amount(row.reception_fee_raw) else normalize_space(row.reception_fee_raw)
    conn.execute(
        """
        INSERT INTO services (
            service_id, service_name, category, window, department,
            fee_status, reception_fee, fee_note, license_tax_status, license_tax_note,
            document_note, status_note, source_file, source_row
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        (
            service_id,
            row.service_name,
            None,
            row.window,
            None,
            fee_status,
            reception_fee,
            fee_note,
            license_tax_status,
            license_tax_note,
            "구비서류와 보완 필요 여부는 담당부서 확인이 필요합니다.",
            "처리 가능 여부와 세부 기준은 민원 내용에 따라 달라질 수 있습니다.",
            source_file,
            row.source_row,
        ),
    )
    return service_id


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


def derived_service_aliases(service_name: str) -> list[str]:
    aliases = []
    base = normalize_space(service_name)
    suffixes = ("관련 문의", "관련 민원", "문의", "민원", "관련")
    for suffix in suffixes:
        if base.endswith(suffix):
            stripped = normalize_space(base[: -len(suffix)])
            if stripped:
                aliases.append(stripped)

    for alias in list(aliases):
        compact = normalize_space(alias.replace(" ", ""))
        if compact and compact != alias:
            aliases.append(compact)

    return list(dict.fromkeys(aliases))


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
    rows = read_service_rows_from_xlsx(xlsx_path)
    alias_map = load_alias_map(alias_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    if db_path.exists():
        db_path.unlink()

    with sqlite3.connect(db_path) as conn:
        create_schema(conn)
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

        for service_name, aliases in alias_map.items():
            service_id = service_ids.get(service_name)
            inserted = 0
            for alias in aliases:
                alias_service_id = service_id or resolve_alias_service_id(alias, service_ids)
                if not alias_service_id:
                    continue
                insert_alias(conn, alias_service_id, alias, alias_path.name)
                inserted += 1
            if not service_id and not inserted:
                print(f"[warn] alias service not found in xlsx: {service_name}")

        service_count = conn.execute("SELECT COUNT(*) FROM services").fetchone()[0]
        alias_count = conn.execute("SELECT COUNT(*) FROM aliases").fetchone()[0]
        print(f"[db] created={db_path} services={service_count} aliases={alias_count}")


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build local SQLite DB from department task xlsx.")
    parser.add_argument("--xlsx", default="data/각부서별_업무담당.xlsx")
    parser.add_argument("--aliases", default="data/route_aliases.json")
    parser.add_argument("--output", default="data/services.db")
    return parser


def main() -> None:
    args = build_arg_parser().parse_args()
    build_database(Path(args.xlsx), Path(args.aliases), Path(args.output))


if __name__ == "__main__":
    main()
