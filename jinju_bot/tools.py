from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Optional


DEFAULT_DB_PATH = Path("data/services.db")
DEFAULT_ALIAS_DB_PATH = Path("data/alias_learning.db")
MIN_CONFIDENT_SERVICE_SCORE = 0.35
ANSWER_STRATEGY_SUFFICIENT_SCORE = 0.35
ANSWER_STRATEGY_LARGE_MARGIN = 0.08
ANSWER_STRATEGY_CANDIDATE_LIMIT = 3
MIN_EXACT_ALIAS_LENGTH = 4
GENERIC_EXACT_ALIASES = {
    "등록증", "신고증", "허가증", "면허증", "자격증", "증명서", "확인서",
    "발급", "재발급", "재교부", "신청", "신고", "등록", "허가",
    "국내", "국외", "해외", "국문", "영문",
}
SERVICE_CORE_STOPWORDS = GENERIC_EXACT_ALIASES | {"관련", "문의", "민원", "업무", "및", "외", "내"}
COMMON_QUERY_WORDS = (
    "신청", "신고", "허가", "등록", "민원", "관련", "문의", "제출", "접수",
    "어디", "어디서", "하니", "하나요", "해요", "해야", "하러", "가요",
    "받으려면", "하려면", "할때", "할때는", "좀", "주세요", "알려줘",
)
MISMATCH_TERMS = ("폐업", "변경", "재발급", "재교부", "정정", "취소", "말소", "신규", "개업", "휴업", "허가")
DOMAIN_TERMS = ("화물", "여객", "전기", "식품", "공중위생", "건축", "차고지", "건강기능식품", "수상레저")
DOMAIN_TERM_MIN_COUNT = 2
DOMAIN_TERM_MIN_LENGTH = 2
DOMAIN_TERM_MAX_LENGTH = 20
DOMAIN_TOKEN_PATTERN = re.compile(r"[0-9A-Za-z가-힣]+")
DOMAIN_ALIAS_ACTION_TERMS = (
    "신청", "신고", "등록", "변경등록", "허가", "발급", "재발급", "재교부",
    "확인서", "증명서", "신고증", "등록증", "면허증", "폐업", "변경", "정정",
)
DOMAIN_ALIAS_STOPWORDS = SERVICE_CORE_STOPWORDS | set(DOMAIN_ALIAS_ACTION_TERMS) | {
    "처리", "가능", "여부", "구비", "준비", "서류", "수수료", "비용", "금액",
    "접수", "제출", "창구", "담당", "부서", "확인", "상담", "안내", "관련문의",
    "변경", "증명", "갱신", "폐업", "면허", "개업", "개시", "신규", "휴업",
    "영업", "영업의", "사업", "사항", "납부", "고용", "개명", "국문", "영문",
    "국문영문", "또는", "등본", "초본", "원부", "발전", "설치", "축조",
}
DOMAIN_SUFFIXES = (
    "관련문의", "관련민원", "관련", "문의", "민원", "신청", "신고", "등록",
    "변경등록", "허가", "발급", "재발급", "재교부", "증명서", "확인서",
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
    department_floor: Optional[str] = None
    window_floor: Optional[str] = None
    special_note: str = ""
    special_type: str = ""
    unattended_available: bool = False
    identity_required: bool = False
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


@dataclass(frozen=True)
class DomainTerm:
    term: str
    count: int
    service_ids: tuple[str, ...]


@dataclass(frozen=True)
class AliasCandidate:
    service_id: str
    service_name: str
    alias: str
    source: str


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


OPTION_SPLIT_PATTERN = re.compile(r"\s*(?:/|,|·|및|또는|와|과)\s*")


def add_unique(values: list[str], value: str) -> None:
    value = normalize_space(value)
    if value and value not in values:
        values.append(value)


def split_option_text(text: str) -> list[str]:
    options = [normalize_space(part) for part in OPTION_SPLIT_PATTERN.split(text) if normalize_space(part)]
    return [option for option in options if len(normalize_key(option)) >= 2]


def expand_parenthetical_aliases(alias: str) -> list[str]:
    base = normalize_space(alias)
    variants: list[str] = []
    add_unique(variants, base)

    if "(" in base and ")" in base:
        without_parentheses = normalize_space(re.sub(r"\([^)]*\)", " ", base))
        add_unique(variants, without_parentheses)
        for inner in re.findall(r"\(([^)]*)\)", base):
            inner = normalize_space(re.sub(r"^(일명|약칭)\s*", "", inner))
            if not inner:
                continue
            add_unique(variants, inner)
            add_unique(variants, f"{inner} {without_parentheses}")
            add_unique(variants, f"{without_parentheses} {inner}")
            for option in split_option_text(inner):
                add_unique(variants, f"{option} {without_parentheses}")
                add_unique(variants, f"{without_parentheses} {option}")
                add_unique(variants, base.replace(f"({inner})", option))

    for match in re.finditer(r"[0-9A-Za-z가-힣]+(?:/[0-9A-Za-z가-힣]+)+", base):
        grouped = match.group(0)
        for option in split_option_text(grouped):
            add_unique(variants, base.replace(grouped, option))

    compact = normalize_space(base.replace(" ", ""))
    if compact != base:
        add_unique(variants, compact)
    return variants


def strip_domain_suffixes(token: str) -> str:
    token = normalize_key(token)
    changed = True
    while changed:
        changed = False
        for suffix in DOMAIN_SUFFIXES:
            normalized_suffix = normalize_key(suffix)
            if token.endswith(normalized_suffix) and len(token) > len(normalized_suffix) + 1:
                token = token[: -len(normalized_suffix)]
                changed = True
                break
    return token


def is_domain_term_candidate(token: str) -> bool:
    token = normalize_key(token)
    if not (DOMAIN_TERM_MIN_LENGTH <= len(token) <= DOMAIN_TERM_MAX_LENGTH):
        return False
    return token not in DOMAIN_ALIAS_STOPWORDS


def domain_tokens_from_text(text: str) -> set[str]:
    tokens: set[str] = set()
    for variant in expand_parenthetical_aliases(text):
        for raw_token in DOMAIN_TOKEN_PATTERN.findall(variant):
            token = strip_domain_suffixes(raw_token)
            if is_domain_term_candidate(token):
                tokens.add(token)
        compact = strip_domain_suffixes(variant)
        if is_domain_term_candidate(compact):
            tokens.add(compact)
    return tokens


def collect_domain_terms_from_records(records: list[tuple[str, str, list[str]]], min_count: int = DOMAIN_TERM_MIN_COUNT) -> list[DomainTerm]:
    counts: Counter[str] = Counter()
    services_by_term: dict[str, set[str]] = defaultdict(set)
    for service_id, service_name, aliases in records:
        texts = [service_name, *aliases]
        service_terms: set[str] = set()
        for text in texts:
            service_terms.update(domain_tokens_from_text(text))
        for term in service_terms:
            counts[term] += 1
            services_by_term[term].add(service_id)

    terms = [
        DomainTerm(term=term, count=count, service_ids=tuple(sorted(services_by_term[term])))
        for term, count in counts.items()
        if count >= min_count
    ]
    terms.sort(key=lambda item: (item.count, len(item.term), item.term), reverse=True)
    return terms


def load_domain_terms(db_path: Path | str = DEFAULT_DB_PATH, min_count: int = DOMAIN_TERM_MIN_COUNT) -> list[DomainTerm]:
    with connect(db_path) as conn:
        service_rows = conn.execute("SELECT service_id, service_name FROM services").fetchall()
        alias_rows = conn.execute("SELECT service_id, alias FROM aliases").fetchall()

    aliases_by_service: dict[str, list[str]] = defaultdict(list)
    for row in alias_rows:
        aliases_by_service[row["service_id"]].append(row["alias"])

    records = [
        (row["service_id"], row["service_name"], aliases_by_service.get(row["service_id"], []))
        for row in service_rows
    ]
    return collect_domain_terms_from_records(records, min_count=min_count)


def action_terms_from_text(text: str) -> list[str]:
    normalized = normalize_key(text)
    actions = [term for term in DOMAIN_ALIAS_ACTION_TERMS if normalize_key(term) in normalized]
    return list(dict.fromkeys(actions))


def is_safe_generated_alias(alias: str, service_name: str) -> bool:
    normalized = normalize_key(alias)
    if not normalized or normalized == normalize_key(service_name):
        return False
    if normalized in DOMAIN_ALIAS_STOPWORDS or normalized in GENERIC_EXACT_ALIASES:
        return False

    tokens = [normalize_key(token) for token in DOMAIN_TOKEN_PATTERN.findall(alias)]
    meaningful_tokens = [token for token in tokens if token and token not in DOMAIN_ALIAS_STOPWORDS]
    if not meaningful_tokens:
        return False
    return any(len(token) >= DOMAIN_TERM_MIN_LENGTH for token in meaningful_tokens)


def generate_adaptive_aliases(service: ServiceRecord, aliases: list[str], domain_terms: list[DomainTerm]) -> list[str]:
    known_terms = {term.term for term in domain_terms}
    service_texts = [service.service_name, *aliases]
    service_tokens: set[str] = set()
    for text in service_texts:
        service_tokens.update(domain_tokens_from_text(text))

    variants: list[str] = []
    for text in service_texts:
        for variant in expand_parenthetical_aliases(text):
            add_unique(variants, variant)

    actions = action_terms_from_text(" ".join(service_texts))
    for token in sorted(service_tokens & known_terms, key=len, reverse=True):
        token_services = next((term.service_ids for term in domain_terms if term.term == token), ())
        if len(token_services) == 1:
            add_unique(variants, token)
        for action in actions:
            if normalize_key(action) not in token:
                add_unique(variants, f"{token} {action}")

    return [alias for alias in variants if is_safe_generated_alias(alias, service.service_name)]


def generate_alias_candidates(db_path: Path | str = DEFAULT_DB_PATH, min_domain_count: int = DOMAIN_TERM_MIN_COUNT) -> list[AliasCandidate]:
    domain_terms = load_domain_terms(db_path, min_count=min_domain_count)
    candidates: list[AliasCandidate] = []
    with connect(db_path) as conn:
        services = conn.execute("SELECT * FROM services").fetchall()
        alias_rows = conn.execute("SELECT service_id, alias, normalized_alias FROM aliases").fetchall()

    aliases_by_service: dict[str, list[str]] = defaultdict(list)
    existing: set[tuple[str, str]] = set()
    for row in alias_rows:
        aliases_by_service[row["service_id"]].append(row["alias"])
        existing.add((row["service_id"], row["normalized_alias"]))

    for row in services:
        service = row_to_service(row)
        for alias in generate_adaptive_aliases(service, aliases_by_service.get(service.service_id, []), domain_terms):
            key = (service.service_id, normalize_key(alias))
            if key in existing:
                continue
            existing.add(key)
            candidates.append(
                AliasCandidate(
                    service_id=service.service_id,
                    service_name=service.service_name,
                    alias=alias,
                    source="adaptive_domain",
                )
            )
    return candidates


def classify_query_domains(question: str, domain_terms: list[DomainTerm]) -> list[DomainTerm]:
    normalized_question = normalize_key(question)
    matches = [term for term in domain_terms if term.term and term.term in normalized_question]
    matches.sort(key=lambda item: (len(item.term), item.count), reverse=True)
    return matches


def mismatch_penalty(query: str, alias: str) -> float:
    normalized_query = normalize_key(query)
    normalized_alias = normalize_key(alias)
    equivalent_terms = {
        "신규": ("개업", "새로"),
        "개업": ("신규", "개시", "새로"),
        "재발급": ("재교부", "갱신"),
        "재교부": ("재발급", "갱신"),
        "개시": ("개업", "신규"),
    }
    for term in MISMATCH_TERMS:
        if term not in normalized_alias or term in normalized_query:
            continue
        if any(equiv in normalized_query for equiv in equivalent_terms.get(term, ())) :
            continue
        return 0.25
    return 1.0


def has_domain_conflict(query: str, service_name: str, alias: str) -> bool:
    normalized_query = normalize_key(query)
    normalized_route = normalize_key(f"{service_name} {alias}")
    route_terms = {term for term in DOMAIN_TERMS if term in normalized_route}
    query_terms = {term for term in DOMAIN_TERMS if term in normalized_query}
    return bool(route_terms and query_terms - route_terms)


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
    if not fields and any(word in normalized for word in ("신청", "신고", "허가", "등록", "발급", "재발급", "수령", "증명", "확인서", "등본", "초본", "원부", "뽑", "떼", "출력")):
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
        department_floor=row_value(row, "department_floor", None) or None,
        window_floor=row_value(row, "window_floor", None) or None,
        special_note=row_value(row, "special_note", "") or "",
        special_type=row_value(row, "special_type", "") or "",
        unattended_available=bool(row_value(row, "unattended_available", 0)),
        identity_required=bool(row_value(row, "identity_required", 0)),
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


def alias_db_exists(alias_db_path: Path | str | None = DEFAULT_ALIAS_DB_PATH) -> bool:
    return bool(alias_db_path and Path(alias_db_path).is_file())


def fetch_search_alias_rows(db_path: Path | str, alias_db_path: Path | str | None = DEFAULT_ALIAS_DB_PATH) -> list[sqlite3.Row]:
    with connect(db_path) as conn:
        rows = conn.execute(
            """
            SELECT
                s.*, a.alias, a.normalized_alias, a.source AS alias_source
            FROM aliases a
            JOIN services s ON s.service_id = a.service_id
            """
        ).fetchall()

        if alias_db_exists(alias_db_path):
            conn.execute("ATTACH DATABASE ? AS alias_learning", (str(alias_db_path),))
            try:
                promoted_rows = conn.execute(
                    """
                    SELECT
                        s.*, pa.alias, pa.normalized_alias, pa.source AS alias_source
                    FROM alias_learning.promoted_aliases pa
                    JOIN services s ON s.service_id = pa.service_id
                    """
                ).fetchall()
            except sqlite3.OperationalError as exc:
                print(f"[alias-db:warn] promoted alias lookup skipped: {exc}", file=sys.stderr)
                promoted_rows = []
            finally:
                conn.execute("DETACH DATABASE alias_learning")
            rows.extend(promoted_rows)
    return rows


def is_generic_exact_alias(alias: str) -> bool:
    normalized = normalize_key(alias)
    return normalized in GENERIC_EXACT_ALIASES or len(normalized) < MIN_EXACT_ALIAS_LENGTH


def service_core_matches_query(query: str, service_name: str) -> bool:
    normalized_query = normalize_key(query)
    service_tokens = []
    for token in re.split(r"[^0-9a-z가-힣]+", service_name.lower()):
        normalized_token = normalize_key(token)
        if len(normalized_token) < 3 or normalized_token in SERVICE_CORE_STOPWORDS:
            continue
        service_tokens.append(normalized_token)
    return any(token in normalized_query for token in service_tokens)


def search_services(
    query: str,
    db_path: Path | str = DEFAULT_DB_PATH,
    limit: int = 5,
    min_score: float = 0.05,
    alias_db_path: Path | str | None = DEFAULT_ALIAS_DB_PATH,
) -> list[ServiceMatch]:
    normalized_query = normalize_key(query)
    matches_by_service: dict[str, ServiceMatch] = {}

    rows = fetch_search_alias_rows(db_path, alias_db_path)

    searchable_query = normalize_for_search(query)

    for row in rows:
        alias = row["alias"]
        if has_domain_conflict(query, row["service_name"], alias):
            continue

        best_score = 0.0
        best_alias = alias
        for alias_variant in expand_parenthetical_aliases(alias):
            normalized_alias = normalize_key(alias_variant)
            searchable_alias = normalize_for_search(alias_variant)
            generic_exact = is_generic_exact_alias(alias_variant)
            if normalized_alias and normalized_alias in normalized_query:
                if generic_exact and not service_core_matches_query(query, row["service_name"]):
                    score = similarity(query, row["service_name"])
                else:
                    score = 0.90 + min(0.10, len(normalized_alias) / 100)
            elif searchable_alias and searchable_alias in searchable_query:
                if generic_exact and not service_core_matches_query(query, row["service_name"]):
                    score = similarity(query, row["service_name"])
                else:
                    score = 0.85 + min(0.10, len(searchable_alias) / 100)
            else:
                score = similarity(query, alias_variant)
            score *= mismatch_penalty(query, alias_variant)
            if score > best_score:
                best_score = score
                best_alias = alias_variant

        if best_score < min_score:
            continue

        service = row_to_service(row)
        match = ServiceMatch(
            service=service,
            score=best_score,
            matched_alias=best_alias,
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
    alias_db_path: Path | str | None = DEFAULT_ALIAS_DB_PATH,
) -> EvidencePackage:
    requested_fields = detect_requested_fields(question)
    intent = requested_fields[0]
    matches = search_services(question, db_path=db_path, limit=limit, min_score=min_score, alias_db_path=alias_db_path)
    selected = matches[0].service if matches else None
    confidence = matches[0].score if matches else 0.0
    second_score = matches[1].score if len(matches) > 1 else 0.0
    ambiguous = bool(matches and (confidence < MIN_CONFIDENT_SERVICE_SCORE or (second_score and confidence < 0.90 and confidence - second_score < ambiguity_margin)))
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


def build_evidence_for_service(question: str, service: ServiceRecord, db_path: Path | str = DEFAULT_DB_PATH) -> EvidencePackage:
    requested_fields = detect_requested_fields(question)
    intent = requested_fields[0]
    match = ServiceMatch(service=service, score=1.0, matched_alias=service.service_name, match_source="conversation_context")
    fee_info = lookup_fee(service.service_id, db_path) if {"fee", "license_tax"} & set(requested_fields) else None
    return EvidencePackage(
        question=question,
        intent=intent,
        requested_fields=requested_fields,
        matches=[match],
        selected_service=service,
        fee_info=fee_info,
        confidence=1.0,
        ambiguous=False,
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


def department_floor_text(service: ServiceRecord) -> str:
    if service.department and service.department_floor:
        return f"{service.department}는 {service.department_floor}에 있습니다."
    if service.department:
        return f"세부 처리는 {service.department} 담당부서 안내가 필요합니다."
    if service.window_floor:
        return f"해당 창구 부서는 {service.window_floor}에 있습니다."
    return ""


def special_notice_text(service: ServiceRecord, fields: list[str] | None = None) -> str:
    fields = fields or []
    notices: list[str] = []
    if service.unattended_available:
        notices.append("무인민원발급기에서도 처리 가능한 민원입니다.")
    if service.identity_required:
        notices.append("본인확인이 필요한 업무입니다.")
    if not fields or any(field in fields for field in ("route", "documents", "status", "general")):
        floor_notice = department_floor_text(service)
        if floor_notice:
            notices.append(floor_notice)
    return " ".join(dict.fromkeys(notice for notice in notices if notice))


def render_field_answer(service: ServiceRecord, field: str) -> str:
    if field == "route":
        if service.department and service.department_floor:
            return f"{service.window}에서 안내받으시면 됩니다. 실제 처리는 {service.department}에서 담당하며, {service.department_floor}에 있습니다."
        if service.department:
            return f"{service.window}에서 안내받으시면 됩니다. 세부 처리는 {service.department} 담당부서 안내가 필요합니다."
        if service.window_floor:
            return f"{service.window}에서 안내받으시면 됩니다. 해당 창구 부서는 {service.window_floor}에 있습니다."
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


def score_margin(evidence: EvidencePackage) -> float:
    second_score = evidence.matches[1].score if len(evidence.matches) > 1 else 0.0
    return evidence.confidence - second_score


def answer_strategy(evidence: EvidencePackage) -> str:
    score_high = evidence.confidence >= ANSWER_STRATEGY_SUFFICIENT_SCORE
    margin_large = score_margin(evidence) >= ANSWER_STRATEGY_LARGE_MARGIN
    if score_high and margin_large:
        return "detail_top1"
    if score_high and not margin_large:
        return "brief_top2_confirm"
    if not score_high and not margin_large:
        return "brief_top2_uncertain"
    return "brief_top1_uncertain"


def render_brief_candidate(match: ServiceMatch, fields: list[str]) -> str:
    service = match.service
    details = [f"{service.service_name}: {service.window}"]
    if "fee" in fields:
        details.append(fee_detail_text(service))
    if "license_tax" in fields:
        details.append(license_tax_detail_text(service))
    if "documents" in fields and service.document_note:
        details.append(service.document_note)
    if "status" in fields and service.status_note:
        details.append(service.status_note)
    notice = special_notice_text(service, fields)
    if notice and "route" in fields:
        details.append(notice)
    return " / ".join(dict.fromkeys(part for part in details if part))


def render_brief_candidates(evidence: EvidencePackage, fields: list[str], limit: int = ANSWER_STRATEGY_CANDIDATE_LIMIT) -> str:
    lines = []
    for idx, match in enumerate(evidence.matches[:limit], start=1):
        lines.append(f"{idx}. {render_brief_candidate(match, fields)}")
    return " ".join(lines)


def render_service_answer(service: ServiceRecord, fields: list[str]) -> str:
    topic = f"{service.service_name}{topic_particle(service.service_name)}"
    parts = [render_field_answer(service, field) for field in fields]
    deduped_parts = []
    for part in parts:
        if part and part not in deduped_parts:
            deduped_parts.append(part)
    answer = f"{topic} " + " ".join(deduped_parts)
    if "route" not in fields and any(field in fields for field in ("fee", "license_tax")) and "정확한 내용은" not in answer:
        answer += f" 정확한 내용은 {service.window}에서 확인하시면 됩니다."
    notice = special_notice_text(service, fields)
    if notice:
        for sentence in notice.split(". "):
            sentence = sentence.strip()
            already_has_floor = bool(
                service.department
                and service.department_floor
                and service.department in answer
                and service.department_floor in answer
                and service.department in sentence
                and service.department_floor in sentence
            )
            if sentence and not already_has_floor and sentence not in answer:
                answer += f" {sentence if sentence.endswith('.') else sentence + '.'}"
    return answer


def render_strategy_answer(evidence: EvidencePackage, fields: list[str]) -> str:
    strategy = answer_strategy(evidence)
    if strategy == "detail_top1":
        return render_service_answer(evidence.selected_service, fields)
    if strategy == "brief_top2_confirm":
        return f"가능성이 높은 민원이 두 가지 있습니다. {render_brief_candidates(evidence, fields)} 어느 민원인지 선택해 주세요."
    if strategy == "brief_top2_uncertain":
        return f"정확하지 않을 수 있지만 관련 후보는 다음과 같습니다. {render_brief_candidates(evidence, fields)} 어떤 민원인지 알려 주시면 더 정확히 안내하겠습니다."
    return f"정확하지 않을 수 있지만 가장 가까운 후보는 다음 민원입니다. {render_brief_candidate(evidence.matches[0], fields)} 이 민원이 맞으면 '맞아'라고 답해 주세요. 아니면 정확한 민원명을 알려 주세요."


def render_basic_answer(evidence: EvidencePackage) -> str:
    service = evidence.selected_service
    if not service:
        return fallback_answer(evidence)

    fields = [field for field in evidence.requested_fields if field != "general"] or ["route"]
    return render_strategy_answer(evidence, fields)


def evidence_to_dict(evidence: EvidencePackage) -> dict:
    return asdict(evidence)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Query local services SQLite DB.")
    parser.add_argument("query", nargs="?", default=None)
    parser.add_argument("--db", default=str(DEFAULT_DB_PATH))
    parser.add_argument("--alias-db", default=str(DEFAULT_ALIAS_DB_PATH))
    parser.add_argument("--limit", type=int, default=5)
    parser.add_argument("--show-answer", action="store_true")
    parser.add_argument("--show-domain-terms", action="store_true")
    parser.add_argument("--suggest-aliases", action="store_true")
    parser.add_argument("--domain-min-count", type=int, default=DOMAIN_TERM_MIN_COUNT)
    return parser


def main() -> None:
    args = build_arg_parser().parse_args()
    if args.show_domain_terms:
        for term in load_domain_terms(args.db, min_count=args.domain_min_count):
            print(f"{term.term}	count={term.count}	services={len(term.service_ids)}")
        return

    if args.suggest_aliases:
        for candidate in generate_alias_candidates(args.db, min_domain_count=args.domain_min_count):
            print(f"{candidate.service_id}	{candidate.service_name}	{candidate.alias}	{candidate.source}")
        return

    if not args.query:
        raise SystemExit("query를 입력해 주세요.")
    evidence = build_evidence(args.query, db_path=args.db, limit=args.limit, alias_db_path=args.alias_db)
    print(f"intent={evidence.intent} requested_fields={','.join(evidence.requested_fields)} confidence={evidence.confidence:.3f} ambiguous={evidence.ambiguous}")
    domain_matches = classify_query_domains(args.query, load_domain_terms(args.db, min_count=args.domain_min_count))
    if domain_matches:
        print("domains=" + ", ".join(f"{term.term}:{term.count}" for term in domain_matches[:8]))
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
