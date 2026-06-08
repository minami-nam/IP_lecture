from __future__ import annotations

import argparse
import re
import sqlite3
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional


DEFAULT_DB_PATH = Path("data/services.db")
COMMON_QUERY_WORDS = (
    "신청", "신고", "허가", "등록", "민원", "관련", "문의", "제출", "접수", "어디", "어디서", "하니", "하나요"
)


@dataclass(frozen=True)
class ServiceRecord:
    service_id: str
    service_name: str
    window: str
    fee_status: str
    fee_note: str
    document_note: str
    status_note: str
    reception_fee: str = ""
    license_tax_status: str = "unknown"
    license_tax_note: str = ""
    category: Optional[str] = None
    department: Optional[str] = None
    source_file: Optional[str] = None
    source_row: Optional[int] = None


@dataclass(frozen=True)
class ServiceMatch:
    service: ServiceRecord
    score: float
    matched_alias: str
    match_source: str


@dataclass(frozen=True)
class FeeInfo:
    service_id: str
    service_name: str
    fee_status: str
    fee_note: str
    reception_fee: str
    license_tax_status: str
    license_tax_note: str


@dataclass(frozen=True)
class EvidencePackage:
    question: str
    intent: str
    requested_fields: list[str]
    matches: list[ServiceMatch]
    selected_service: Optional[ServiceRecord]
    fee_info: Optional[FeeInfo]
    confidence: float
    ambiguous: bool


def normalize_space(value: object) -> str:
    return re.sub(r"\s+", " ", "" if value is None else str(value)).strip()


def normalize_key(value: str) -> str:
    value = normalize_space(value).lower()
    return re.sub(r"[^0-9a-z가-힣]+", "", value)


def normalize_for_search(value: str) -> str:
    normalized = normalize_key(value)
    for word in COMMON_QUERY_WORDS:
        normalized = normalized.replace(word, "")
    return normalized


def row_value(row: sqlite3.Row, key: str, default: object = "") -> object:
    return row[key] if key in row.keys() else default


def char_ngrams(value: str, n: int = 2) -> set[str]:
    normalized = normalize_for_search(value)
    if not normalized:
        return set()
    if len(normalized) <= n:
        return {normalized}
    return {normalized[idx : idx + n] for idx in range(len(normalized) - n + 1)}


def similarity(left: str, right: str) -> float:
    left_grams = char_ngrams(left)
    right_grams = char_ngrams(right)
    if not left_grams or not right_grams:
        return 0.0
    overlap = len(left_grams & right_grams)
    union = len(left_grams | right_grams)
    return overlap / max(1, union)


FIELD_ORDER = ("route", "fee", "license_tax", "documents", "status")
FIELD_LABELS = {
    "route": "담당 창구",
    "fee": "수수료",
    "license_tax": "등록면허세",
    "documents": "구비서류",
    "status": "처리 가능 여부",
    "general": "민원 정보",
}


def detect_requested_fields(question: str) -> list[str]:
    normalized = normalize_key(question)
    fields: list[str] = []
    if any(word in normalized for word in ("어디", "창구", "접수처", "제출처", "담당", "부서")):
        fields.append("route")
    if any(word in normalized for word in ("수수료", "비용", "금액", "접수비", "납부", "면제", "돈", "무료")):
        fields.append("fee")
    if any(word in normalized for word in ("등록면허세", "면허세")):
        fields.append("license_tax")
    if any(word in normalized for word in ("서류", "구비서류", "준비", "보완")):
        fields.append("documents")
    if any(word in normalized for word in ("처리기간", "가능", "결과", "상태", "처리")):
        fields.append("status")
    if not fields and any(word in normalized for word in ("신청", "신고", "허가", "등록", "발급", "재발급", "수령")):
        fields.append("route")
    return [field for field in FIELD_ORDER if field in fields] or ["general"]


def detect_intent(question: str) -> str:
    return detect_requested_fields(question)[0]


def connect(db_path: Path | str = DEFAULT_DB_PATH) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    return conn


def row_to_service(row: sqlite3.Row) -> ServiceRecord:
    return ServiceRecord(
        service_id=row["service_id"],
        service_name=row["service_name"],
        window=row["window"],
        fee_status=row["fee_status"],
        fee_note=row["fee_note"] or "",
        document_note=row["document_note"] or "",
        status_note=row["status_note"] or "",
        reception_fee=row_value(row, "reception_fee", "") or "",
        license_tax_status=row_value(row, "license_tax_status", "unknown") or "unknown",
        license_tax_note=row_value(row, "license_tax_note", "") or "",
        category=row["category"],
        department=row["department"],
        source_file=row["source_file"],
        source_row=row["source_row"],
    )


def get_service(service_id: str, db_path: Path | str = DEFAULT_DB_PATH) -> Optional[ServiceRecord]:
    with connect(db_path) as conn:
        row = conn.execute("SELECT * FROM services WHERE service_id = ?", (service_id,)).fetchone()
    return row_to_service(row) if row else None


def get_service_by_name(service_name: str, db_path: Path | str = DEFAULT_DB_PATH) -> Optional[ServiceRecord]:
    with connect(db_path) as conn:
        row = conn.execute("SELECT * FROM services WHERE service_name = ?", (service_name,)).fetchone()
    return row_to_service(row) if row else None


def list_aliases(service_id: str, db_path: Path | str = DEFAULT_DB_PATH) -> list[str]:
    with connect(db_path) as conn:
        rows = conn.execute(
            "SELECT alias FROM aliases WHERE service_id = ? ORDER BY alias_id",
            (service_id,),
        ).fetchall()
    return [row["alias"] for row in rows]


def search_services(
    query: str,
    db_path: Path | str = DEFAULT_DB_PATH,
    limit: int = 5,
    min_score: float = 0.05,
) -> list[ServiceMatch]:
    normalized_query = normalize_key(query)
    matches_by_service: dict[str, ServiceMatch] = {}

    with connect(db_path) as conn:
        rows = conn.execute(
            """
            SELECT
                s.*, a.alias, a.normalized_alias, a.source AS alias_source
            FROM aliases a
            JOIN services s ON s.service_id = a.service_id
            """
        ).fetchall()

    for row in rows:
        alias = row["alias"]
        normalized_alias = row["normalized_alias"]
        if normalized_alias and normalized_alias in normalized_query:
            score = 1.0
        else:
            score = similarity(query, alias)
        if score < min_score:
            continue

        service = row_to_service(row)
        match = ServiceMatch(
            service=service,
            score=score,
            matched_alias=alias,
            match_source=row["alias_source"],
        )
        existing = matches_by_service.get(service.service_id)
        if existing is None or match.score > existing.score:
            matches_by_service[service.service_id] = match

    matches = sorted(matches_by_service.values(), key=lambda item: item.score, reverse=True)
    return matches[:limit]


def lookup_fee(service_id: str, db_path: Path | str = DEFAULT_DB_PATH) -> Optional[FeeInfo]:
    service = get_service(service_id, db_path)
    if not service:
        return None
    return FeeInfo(
        service_id=service.service_id,
        service_name=service.service_name,
        fee_status=service.fee_status,
        fee_note=service.fee_note,
        reception_fee=service.reception_fee,
        license_tax_status=service.license_tax_status,
        license_tax_note=service.license_tax_note,
    )


def build_evidence(
    question: str,
    db_path: Path | str = DEFAULT_DB_PATH,
    limit: int = 5,
    min_score: float = 0.05,
    ambiguity_margin: float = 0.08,
) -> EvidencePackage:
    requested_fields = detect_requested_fields(question)
    intent = requested_fields[0]
    matches = search_services(question, db_path=db_path, limit=limit, min_score=min_score)
    selected = matches[0].service if matches else None
    confidence = matches[0].score if matches else 0.0
    second_score = matches[1].score if len(matches) > 1 else 0.0
    ambiguous = bool(matches and second_score and confidence - second_score < ambiguity_margin)
    fee_info = lookup_fee(selected.service_id, db_path) if selected and {"fee", "license_tax"} & set(requested_fields) else None
    return EvidencePackage(
        question=question,
        intent=intent,
        requested_fields=requested_fields,
        matches=matches,
        selected_service=selected,
        fee_info=fee_info,
        confidence=confidence,
        ambiguous=ambiguous,
    )


def topic_particle(text: str) -> str:
    stripped = text.strip()
    if not stripped:
        return "은"
    code = ord(stripped[-1])
    if 0xAC00 <= code <= 0xD7A3:
        return "은" if (code - 0xAC00) % 28 else "는"
    return "은"


def required_status_text(status: str, label: str) -> str:
    return {
        "required": f"{label} 납부가 필요한 민원입니다.",
        "not_required": f"{label} 납부가 필요하지 않은 민원입니다.",
        "conditional": f"{label} 납부 여부가 조건에 따라 달라질 수 있습니다.",
        "unknown": f"{label} 납부 여부가 명확히 확인되지 않습니다.",
    }.get(status, f"{label} 납부 여부가 명확히 확인되지 않습니다.")


def fee_status_text(status: str) -> str:
    return required_status_text(status, "수수료")


def is_redundant_unknown_fee_note(status: str, note: str) -> bool:
    if status != "unknown":
        return False
    compact_note = normalize_key(note)
    return "수수료" in compact_note and "명확" in compact_note and any(
        word in compact_note for word in ("확인되지", "확인안", "확인불가")
    )


def license_tax_status_text(status: str) -> str:
    return required_status_text(status, "등록면허세")


def reception_fee_text(amount: str) -> str:
    amount = amount.strip()
    if not amount:
        return ""
    if amount.endswith("상이함"):
        return f"접수 수수료는 {amount[:-3]}상이합니다."
    return f"접수 수수료는 {amount}입니다."


def fee_detail_text(service: ServiceRecord) -> str:
    if service.fee_status == "required" and service.reception_fee:
        return f"수수료 납부가 필요한 민원입니다. {reception_fee_text(service.reception_fee)}"
    if service.fee_status == "not_required":
        return fee_status_text(service.fee_status)
    if service.fee_status == "conditional" and service.reception_fee:
        return f"{reception_fee_text(service.reception_fee)} 다만 정확한 납부 여부는 확인이 필요합니다."
    if service.fee_note and not is_redundant_unknown_fee_note(service.fee_status, service.fee_note):
        return f"{fee_status_text(service.fee_status)} {service.fee_note}"
    return fee_status_text(service.fee_status)


def license_tax_detail_text(service: ServiceRecord) -> str:
    note = service.license_tax_note
    if service.license_tax_status in {"required", "not_required"}:
        return license_tax_status_text(service.license_tax_status)
    if note:
        return f"{license_tax_status_text(service.license_tax_status)} {note}"
    return license_tax_status_text(service.license_tax_status)


def candidate_names(evidence: EvidencePackage, limit: int = 3) -> str:
    names = []
    for match in evidence.matches[:limit]:
        name = match.service.service_name
        if name not in names:
            names.append(name)
    return ", ".join(names)


def fallback_answer(evidence: EvidencePackage) -> str:
    candidates = candidate_names(evidence)
    labels = [FIELD_LABELS.get(field, field) for field in evidence.requested_fields if field != "general"]
    label_text = ", ".join(labels) if labels else "민원 정보"
    if candidates:
        return f"{label_text}는 민원별로 달라서 정확한 업무 확인이 필요합니다. 혹시 {candidates} 중 어떤 민원인지 알려 주세요."
    return f"{label_text}는 민원별로 달라서 업무명 확인이 필요합니다. 신청하려는 민원명을 알려 주시면 확인해 드릴 수 있습니다."


def render_field_answer(service: ServiceRecord, field: str) -> str:
    if field == "route":
        return f"{service.window}에서 안내받으시면 됩니다."
    if field == "fee":
        return fee_detail_text(service)
    if field == "license_tax":
        return license_tax_detail_text(service)
    if field == "documents":
        return service.document_note
    if field == "status":
        return service.status_note
    return f"{service.window}에서 안내받으시면 됩니다."


def render_basic_answer(evidence: EvidencePackage) -> str:
    service = evidence.selected_service
    if not service or evidence.ambiguous:
        return fallback_answer(evidence)

    topic = f"{service.service_name}{topic_particle(service.service_name)}"
    fields = [field for field in evidence.requested_fields if field != "general"] or ["route"]
    parts = [render_field_answer(service, field) for field in fields]
    deduped_parts = []
    for part in parts:
        if part and part not in deduped_parts:
            deduped_parts.append(part)
    answer = f"{topic} " + " ".join(deduped_parts)
    if "route" not in fields and any(field in fields for field in ("fee", "license_tax")) and "정확한 내용은" not in answer:
        answer += f" 정확한 내용은 {service.window}에서 확인하시면 됩니다."
    return answer

def evidence_to_dict(evidence: EvidencePackage) -> dict:
    return asdict(evidence)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Query local services SQLite DB.")
    parser.add_argument("query", nargs="?", default=None)
    parser.add_argument("--db", default=str(DEFAULT_DB_PATH))
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--show-answer", action="store_true")
    return parser


def main() -> None:
    args = build_arg_parser().parse_args()
    if not args.query:
        raise SystemExit("query를 입력해 주세요.")
    evidence = build_evidence(args.query, db_path=args.db, limit=args.limit)
    print(f"intent={evidence.intent} requested_fields={','.join(evidence.requested_fields)} confidence={evidence.confidence:.3f} ambiguous={evidence.ambiguous}")
    for idx, match in enumerate(evidence.matches, start=1):
        service = match.service
        print(
            f"[{idx}] score={match.score:.3f} service={service.service_name} window={service.window} "
            f"fee={service.fee_status} reception_fee={service.reception_fee or '-'} "
            f"license_tax={service.license_tax_status} alias={match.matched_alias}"
        )
    if args.show_answer:
        print(render_basic_answer(evidence))


if __name__ == "__main__":
    main()
