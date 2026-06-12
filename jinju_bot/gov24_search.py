from __future__ import annotations

import argparse
import html
import json
import re
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode, urljoin
from urllib.request import Request, urlopen


GOV24_HOME_URL = "https://plus.gov.kr"
DEFAULT_TIMEOUT_SECONDS = 5.0
DEFAULT_LIMIT = 5
POPULAR_RESULT_MIN_SCORE = 0.25
SEARCH_URLS = (
    "https://plus.gov.kr/search/searchList",
    "https://plus.gov.kr/search",
    "https://plus.gov.kr/minwon",
)
QUERY_PARAM_CANDIDATES = ("srhQuery", "searchKeyword", "keyword", "query")
SERVICE_PATH_HINTS = ("/search/searchdtl", "/minwon", "/mw/", "/portal/service")
POPULAR_SERVICE_PATTERN = re.compile(
    r"(?:\d+\s+){1,2}(토지\(임야\)대장|주민등록등본\(초본\)|자동차등록원부|건축물대장|가족관계증명서|여권 재발급|지방세 납세증명|납세증명|인감증명서|지적도\(임야도\))"
)
COMMON_QUERY_WORDS = (
    "정부24", "민원", "수수료", "비용", "구비서류", "서류",
    "어디서", "어디", "방법", "찾아줘", "알려줘", "확인해줘",
)


@dataclass(frozen=True)
class Gov24Result:
    query: str
    title: str
    url: str
    summary: str
    score: float


@dataclass(frozen=True)
class Gov24Lookup:
    enabled: bool
    ok: bool
    query: str
    message: str
    results: list[Gov24Result]
    fetched_at: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def normalize_space(value: object) -> str:
    return re.sub(r"\s+", " ", "" if value is None else str(value)).strip()


def normalize_key(value: str) -> str:
    value = normalize_space(value).lower()
    return re.sub(r"[^0-9a-z가-힣]+", "", value)


def clean_query(query: str) -> str:
    cleaned = normalize_space(query)
    for word in COMMON_QUERY_WORDS:
        cleaned = re.sub(re.escape(word), " ", cleaned, flags=re.IGNORECASE)
    return normalize_space(cleaned) or normalize_space(query)


def fetch_text(url: str, timeout: float = DEFAULT_TIMEOUT_SECONDS) -> str:
    request = Request(
        url,
        headers={
            "Accept": "text/html,application/xhtml+xml",
            "User-Agent": "jinju-bot/0.1 gov24-search",
        },
    )
    with urlopen(request, timeout=timeout) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        return response.read().decode(charset, errors="replace")


def strip_tags(value: str) -> str:
    value = re.sub(r"(?is)<(script|style).*?</\1>", " ", value)
    value = re.sub(r"(?s)<[^>]+>", " ", value)
    return normalize_space(html.unescape(value))


def title_from_html(page: str) -> str:
    match = re.search(r"(?is)<title[^>]*>(.*?)</title>", page)
    return strip_tags(match.group(1)) if match else ""


def page_summary(page: str, max_chars: int = 180) -> str:
    text = strip_tags(page)
    noise = (
        "본문 바로가기", "이 누리집은 대한민국 공식 전자정부 누리집입니다.",
        "정부24 앱에서", "위로 이동 Top",
    )
    for item in noise:
        text = text.replace(item, " ")
    text = normalize_space(text)
    return text[:max_chars].rstrip()


def similarity(left: str, right: str) -> float:
    left_key = normalize_key(left)
    right_key = normalize_key(right)
    if not left_key or not right_key:
        return 0.0
    if left_key in right_key or right_key in left_key:
        return 1.0
    left_grams = {left_key[idx : idx + 2] for idx in range(max(1, len(left_key) - 1))}
    right_grams = {right_key[idx : idx + 2] for idx in range(max(1, len(right_key) - 1))}
    if not left_grams or not right_grams:
        return 0.0
    return len(left_grams & right_grams) / max(1, len(left_grams | right_grams))


def extract_links(page: str, base_url: str) -> list[tuple[str, str]]:
    links: list[tuple[str, str]] = []
    for match in re.finditer(r'(?is)<a\b[^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)</a>', page):
        href, label_html = match.groups()
        if href.startswith(("#", "javascript:", "mailto:", "tel:")):
            continue
        url = urljoin(base_url, html.unescape(href))
        label = strip_tags(label_html)
        if not label or "plus.gov.kr" not in url:
            continue
        links.append((label, url))
    return list(dict.fromkeys(links))


def search_urls(query: str) -> list[str]:
    encoded = quote(query)
    urls = [f"https://plus.gov.kr/search/searchdtl/?keyword={encoded}"]
    for base in SEARCH_URLS:
        for param in QUERY_PARAM_CANDIDATES:
            urls.append(f"{base}?{urlencode({param: query})}")
    return list(dict.fromkeys(urls))


def extract_popular_services(page: str) -> list[str]:
    text = strip_tags(page)
    return list(dict.fromkeys(match.group(1) for match in POPULAR_SERVICE_PATTERN.finditer(text)))


def rank_popular_results(query: str, page: str, limit: int) -> list[Gov24Result]:
    results = []
    for title in extract_popular_services(page):
        score = similarity(query, title)
        if score < POPULAR_RESULT_MIN_SCORE:
            continue
        results.append(
            Gov24Result(
                query=query,
                title=title,
                url=GOV24_HOME_URL,
                summary="정부24 메인 화면의 자주 찾는 서비스에서 확인된 항목입니다.",
                score=score,
            )
        )
    results.sort(key=lambda item: item.score, reverse=True)
    return results[:limit]


def rank_link_results(query: str, links: list[tuple[str, str]], limit: int) -> list[Gov24Result]:
    ranked: list[Gov24Result] = []
    for label, url in links:
        if not any(hint in url for hint in SERVICE_PATH_HINTS):
            continue
        score = max(similarity(query, label), 0.2 if normalize_key(query) in normalize_key(url) else 0.0)
        if score <= 0:
            continue
        ranked.append(Gov24Result(query=query, title=label, url=url, summary="", score=score))
    ranked.sort(key=lambda item: item.score, reverse=True)
    return ranked[:limit]


def lookup_gov24_service(
    query: str,
    limit: int = DEFAULT_LIMIT,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
) -> Gov24Lookup:
    cleaned_query = clean_query(query)
    fetched_at = now_iso()
    errors: list[str] = []

    for url in search_urls(cleaned_query):
        try:
            page = fetch_text(url, timeout=timeout)
        except HTTPError as exc:
            errors.append(f"HTTP {exc.code}")
            continue
        except (URLError, TimeoutError) as exc:
            errors.append(str(exc))
            continue

        links = extract_links(page, url)
        results = rank_link_results(cleaned_query, links, limit)
        if results:
            return Gov24Lookup(True, True, cleaned_query, "정부24 검색 결과를 찾았습니다.", results, fetched_at)

        title = title_from_html(page)
        summary = page_summary(page)
        score = similarity(cleaned_query, f"{title} {summary}")
        if score > 0.2 and summary:
            result = Gov24Result(cleaned_query, title or "정부24 검색 결과", url, summary, score)
            return Gov24Lookup(True, True, cleaned_query, "정부24 페이지 내용을 확인했습니다.", [result], fetched_at)

    try:
        page = fetch_text(GOV24_HOME_URL, timeout=timeout)
        results = rank_popular_results(cleaned_query, page, limit)
        if results:
            return Gov24Lookup(True, True, cleaned_query, "정부24 메인 서비스에서 관련 항목을 찾았습니다.", results, fetched_at)
    except (HTTPError, URLError, TimeoutError) as exc:
        errors.append(str(exc))

    message = "정부24에서 바로 일치하는 결과를 찾지 못했습니다."
    if errors:
        message = f"정부24 연결 또는 응답 처리 실패: {errors[-1]}"
    return Gov24Lookup(True, False, cleaned_query, message, [], fetched_at)


def summarize_gov24_result(lookup: Gov24Lookup) -> str:
    if not lookup.ok or not lookup.results:
        return lookup.message
    top = lookup.results[0]
    parts = [f"정부24 기준으로 '{top.title}' 항목이 가장 가깝습니다."]
    if top.summary:
        parts.append(top.summary)
    parts.append(f"출처: {top.url}")
    return " ".join(parts)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Search and lightly crawl Gov24 service pages.")
    parser.add_argument("query", help="검색할 민원 또는 공공서비스 이름")
    parser.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT_SECONDS)
    parser.add_argument("--json", action="store_true")
    return parser


def main() -> None:
    args = build_arg_parser().parse_args()
    lookup = lookup_gov24_service(args.query, limit=args.limit, timeout=args.timeout)
    if args.json:
        print(json.dumps(lookup.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(summarize_gov24_result(lookup))


if __name__ == "__main__":
    main()
