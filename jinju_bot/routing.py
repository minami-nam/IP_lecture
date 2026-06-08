from __future__ import annotations

import json
import os
import re
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional, Tuple


WINDOW_PATTERN = re.compile(
    r"민원여권과\s*[0-9,\s]+번(?:,\s*[0-9]+번)?\s*창구.*"
    r"|무인민원발급기"
    r"|행정복지센터"
    r"|[0-9]+층\s*[^,\s]+과"
)
NON_ROUTE_TAGS = {"where", "fee", "document", "T", "F", "운영원칙"}
FEE_QUERY_PATTERN = re.compile(r"수수료|비용|금액|납부|면제")

COMMON_ROUTE_WORDS = (
    "신청", "신고", "허가", "등록", "민원", "관련", "문의", "제출", "접수"
)
MISMATCH_ROUTE_TERMS = ("폐업", "변경", "재발급", "정정", "취소", "말소", "보완")
DOMAIN_ROUTE_TERMS = ("화물", "여객", "전기", "식품", "공중위생", "개발행위")


@dataclass(frozen=True)
class RouteEntry:
    service: str
    window: str
    aliases: Tuple[str, ...] = ()
    fee_required: Optional[bool] = None


def normalize_query(text: str) -> str:
    text = re.sub(r"\s+", "", text)
    text = re.sub(r"[^\w가-힣0-9]", "", text)
    return text.lower()


def strip_route_common_words(text: str) -> str:
    normalized = normalize_query(text)
    for word in COMMON_ROUTE_WORDS:
        normalized = normalized.replace(word, "")
    return normalized


def service_aliases(service: str, extra_aliases: Iterable[str] = ()) -> List[str]:
    aliases = {service}
    stripped = service
    for suffix in ("관련 문의", "문의", "관련 민원", "민원"):
        if stripped.endswith(suffix):
            stripped = stripped[: -len(suffix)].strip()
            aliases.add(stripped)

    aliases.add(service.replace(" / ", " "))
    aliases.add(service.replace("/", " "))

    for part in re.split(r"[,/·]+", stripped):
        part = part.strip()
        if part and len(normalize_query(part)) >= 3:
            aliases.add(part)

    for alias in list(aliases):
        core = strip_route_common_words(alias)
        if len(core) >= 3:
            aliases.add(core)

    aliases.update(str(alias).strip() for alias in extra_aliases if str(alias).strip())
    return [alias for alias in aliases if alias]


def normalize_for_similarity(text: str) -> str:
    return strip_route_common_words(text)


def extract_route_from_tags(tags: Iterable[Any]) -> Optional[RouteEntry]:
    window = None
    service = None
    tag_values = {str(tag).strip() for tag in tags}
    for tag in tags:
        tag_text = str(tag).strip()
        if not window and WINDOW_PATTERN.search(tag_text):
            window = tag_text
            continue
        if not tag_text or tag_text in NON_ROUTE_TAGS or tag_text.endswith("_policy"):
            continue
        service = service or tag_text

    if not window or not service:
        return None

    fee_required = None
    if "fee" in tag_values:
        if "T" in tag_values:
            fee_required = True
        elif "F" in tag_values:
            fee_required = False

    return RouteEntry(service=service, window=window, fee_required=fee_required)


def load_route_aliases(alias_file: Optional[str]) -> Dict[str, Tuple[str, ...]]:
    if not alias_file or not os.path.isfile(alias_file):
        return {}

    with open(alias_file, "r", encoding="utf-8") as f:
        data = json.load(f)

    aliases: Dict[str, Tuple[str, ...]] = {}
    if isinstance(data, dict):
        for service, values in data.items():
            if isinstance(values, str):
                values = [values]
            if not isinstance(values, list):
                continue
            cleaned = tuple(str(value).strip() for value in values if str(value).strip())
            if cleaned:
                aliases[normalize_query(str(service))] = cleaned
    elif isinstance(data, list):
        for item in data:
            if not isinstance(item, dict):
                continue
            service = str(item.get("service", "")).strip()
            values = item.get("aliases", [])
            if isinstance(values, str):
                values = [values]
            if not service or not isinstance(values, list):
                continue
            cleaned = tuple(str(value).strip() for value in values if str(value).strip())
            if cleaned:
                aliases[normalize_query(service)] = cleaned

    return aliases


def with_route_aliases(route: RouteEntry, alias_map: Dict[str, Tuple[str, ...]]) -> RouteEntry:
    aliases = alias_map.get(normalize_query(route.service), ())
    return RouteEntry(service=route.service, window=route.window, aliases=aliases, fee_required=route.fee_required)


def merge_route_entry(existing: RouteEntry, incoming: RouteEntry) -> RouteEntry:
    fee_required = existing.fee_required
    if incoming.fee_required is not None:
        fee_required = incoming.fee_required
    aliases = tuple(dict.fromkeys((*existing.aliases, *incoming.aliases)))
    return RouteEntry(
        service=existing.service,
        window=existing.window,
        aliases=aliases,
        fee_required=fee_required,
    )


def load_route_entries(train_file: str, alias_file: Optional[str] = None) -> List[RouteEntry]:
    if not os.path.isfile(train_file):
        return []

    with open(train_file, "r", encoding="utf-8") as f:
        rows = json.load(f)

    alias_map = load_route_aliases(alias_file)
    routes: Dict[str, RouteEntry] = {}
    for row in rows:
        route = extract_route_from_tags(row.get("tags", []))
        if not route:
            continue
        key = normalize_query(route.service)
        route = with_route_aliases(route, alias_map)
        routes[key] = merge_route_entry(routes[key], route) if key in routes else route

    return sorted(routes.values(), key=lambda item: len(normalize_query(item.service)), reverse=True)


def has_domain_conflict(question: str, route: RouteEntry, alias: str = "") -> bool:
    normalized_question = normalize_query(question)
    normalized_route_text = normalize_query(" ".join((route.service, alias, *route.aliases)))
    route_terms = {term for term in DOMAIN_ROUTE_TERMS if term in normalized_route_text}
    question_terms = {term for term in DOMAIN_ROUTE_TERMS if term in normalized_question}
    return bool(route_terms and question_terms - route_terms)


def find_route(question: str, routes: Iterable[RouteEntry]) -> Optional[RouteEntry]:
    normalized_question = normalize_query(question)
    for route in routes:
        for alias in service_aliases(route.service, route.aliases):
            normalized_alias = normalize_query(alias)
            if normalized_alias and normalized_alias in normalized_question and not has_domain_conflict(question, route, alias):
                return route
    return None


def char_ngrams(text: str, n: int = 2) -> set[str]:
    normalized = normalize_for_similarity(text)
    if len(normalized) <= n:
        return {normalized} if normalized else set()
    return {normalized[idx : idx + n] for idx in range(len(normalized) - n + 1)}


def mismatch_penalty(question: str, alias: str) -> float:
    normalized_question = normalize_query(question)
    normalized_alias = normalize_query(alias)
    for term in MISMATCH_ROUTE_TERMS:
        if term in normalized_alias and term not in normalized_question:
            return 0.25
    return 1.0


def route_similarity(question: str, route: RouteEntry) -> float:
    question_grams = char_ngrams(question)
    if not question_grams:
        return 0.0

    best = 0.0
    for alias in service_aliases(route.service, route.aliases):
        alias_grams = char_ngrams(alias)
        if not alias_grams:
            continue
        overlap = len(question_grams & alias_grams)
        union = len(question_grams | alias_grams)
        score = overlap / max(1, union)
        score *= mismatch_penalty(question, alias)
        best = max(best, score)
    return best


def rank_routes(question: str, routes: Iterable[RouteEntry], limit: int = 20) -> List[Tuple[int, float, RouteEntry]]:
    scored = [
        (idx, route_similarity(question, route), route)
        for idx, route in enumerate(routes)
    ]
    scored.sort(key=lambda item: item[1], reverse=True)
    return [(idx, score, route) for idx, score, route in scored[:limit] if score > 0.0]


def display_service_name(service: str) -> str:
    for suffix in ("관련 문의", "문의", "관련 민원", "민원"):
        if service.endswith(suffix):
            return service[: -len(suffix)].strip()
    return service


def is_fee_question(question: str) -> bool:
    return bool(FEE_QUERY_PATTERN.search(question))


def topic_particle(text: str) -> str:
    stripped = text.strip()
    if not stripped:
        return "은"
    code = ord(stripped[-1])
    if 0xAC00 <= code <= 0xD7A3:
        return "은" if (code - 0xAC00) % 28 else "는"
    return "은"


def render_route_candidate_label(route: RouteEntry, alias_limit: int = 6) -> str:
    aliases = [alias for alias in route.aliases if normalize_query(alias) != normalize_query(route.service)]
    if not aliases:
        return route.service
    alias_text = ", ".join(aliases[:alias_limit])
    return f"{route.service} (유사 표현: {alias_text})"


def render_route_answer(route: RouteEntry, question: Optional[str] = None) -> str:
    service = display_service_name(route.service)
    base = f"{service}{topic_particle(service)} {route.window}에서 안내받으시면 됩니다."
    if question and is_fee_question(question):
        if route.fee_required is True:
            return f"{base} 수수료 납부가 필요한 민원이며, 정확한 금액은 담당 창구 또는 담당부서에 확인하시면 됩니다."
        if route.fee_required is False:
            return f"{base} 수수료 납부가 필요하지 않은 민원이며, 세부 사항은 담당 창구 또는 담당부서에 확인하시면 됩니다."
        return f"{base} 수수료 납부 필요 여부는 민원 세부 내용에 따라 달라질 수 있어 담당 창구 또는 담당부서에 확인하시면 됩니다."
    return base
