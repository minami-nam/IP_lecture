from __future__ import annotations

import argparse
import json
import os
import re
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any, Optional
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


SERVICE_LIST_URL = "https://api.odcloud.kr/api/gov24/v3/serviceList"
SERVICE_DETAIL_URL = "https://api.odcloud.kr/api/gov24/v3/serviceDetail"
DATA_GO_KR_DATASET_URL = "https://www.data.go.kr/data/15113968/openapi.do"
DEFAULT_TIMEOUT_SECONDS = 5.0
DEFAULT_PER_PAGE = 5
API_KEY_ENV_NAMES = ("DATA_GO_KR_SERVICE_KEY", "PUBLIC_DATA_API_KEY")


@dataclass(frozen=True)
class PublicDataResult:
    query: str
    service_id: str
    service_name: str
    agency: str
    department: str
    application_method: str
    application_deadline: str
    reception_agency: str
    phone: str
    documents: str
    support_target: str
    support_content: str
    online_url: str
    detail_url: str
    modified_at: str
    source_url: str
    fetched_at: str
    score: float


@dataclass(frozen=True)
class PublicDataLookup:
    enabled: bool
    ok: bool
    query: str
    message: str
    result: Optional[PublicDataResult] = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def configured_api_key(explicit_key: str = "") -> str:
    if explicit_key and explicit_key.lower() != "none":
        return explicit_key
    for env_name in API_KEY_ENV_NAMES:
        value = os.environ.get(env_name, "").strip()
        if value:
            return value
    return ""


def normalize_text(value: object) -> str:
    text = "" if value is None else str(value)
    return re.sub(r"\s+", " ", text).strip()


def normalize_key(value: str) -> str:
    value = normalize_text(value).lower()
    return re.sub(r"[^0-9a-z가-힣]+", "", value)


def clean_service_query(query: str) -> str:
    cleaned = normalize_text(query)
    cleaned = re.sub(
        r"(공공데이터로?|정부24|인터넷|온라인|최신|공식자료|API|기준으로?|관련|민원|신청방법|신청|방법|발급|재발급|수수료|비용|구비서류|서류|어디서|어디|창구|접수|문의|찾아줘|알려줘|확인해줘)",
        " ",
        cleaned,
        flags=re.IGNORECASE,
    )
    cleaned = normalize_text(cleaned)
    return cleaned or normalize_text(query)


def similarity(left: str, right: str) -> float:
    left_key = normalize_key(left)
    right_key = normalize_key(right)
    if not left_key or not right_key:
        return 0.0
    if left_key in right_key or right_key in left_key:
        return 1.0
    left_chars = set(left_key)
    right_chars = set(right_key)
    return len(left_chars & right_chars) / max(1, len(left_chars | right_chars))


def request_json(url: str, params: dict[str, object], service_key: str, timeout: float = DEFAULT_TIMEOUT_SECONDS) -> dict[str, Any]:
    query = urlencode({key: value for key, value in params.items() if value not in ("", None)})
    full_url = f"{url}?{query}"
    headers = {
        "Accept": "application/json",
        "User-Agent": "jinju-bot/0.1 public-data-lookup",
    }
    if service_key:
        headers["Authorization"] = service_key
    request = Request(full_url, headers=headers)
    with urlopen(request, timeout=timeout) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        body = response.read().decode(charset, errors="replace")
    return json.loads(body)


def data_items(payload: dict[str, Any]) -> list[dict[str, Any]]:
    data = payload.get("data", [])
    return [item for item in data if isinstance(item, dict)]


def pick_best_item(query: str, items: list[dict[str, Any]]) -> Optional[dict[str, Any]]:
    best_item = None
    best_score = 0.0
    for item in items:
        name = normalize_text(item.get("서비스명"))
        score = similarity(query, name)
        if score > best_score:
            best_item = item
            best_score = score
    return best_item


def fetch_service_detail(service_id: str, service_key: str, timeout: float) -> dict[str, Any]:
    if not service_id:
        return {}
    payload = request_json(
        SERVICE_DETAIL_URL,
        {
            "page": 1,
            "perPage": 1,
            "returnType": "JSON",
            "serviceKey": service_key,
            "cond[서비스ID::EQ]": service_id,
        },
        service_key=service_key,
        timeout=timeout,
    )
    items = data_items(payload)
    return items[0] if items else {}


def build_result(query: str, list_item: dict[str, Any], detail_item: dict[str, Any]) -> PublicDataResult:
    merged = {**list_item, **detail_item}
    service_id = normalize_text(merged.get("서비스ID"))
    detail_url = normalize_text(merged.get("상세조회URL"))
    online_url = normalize_text(merged.get("온라인신청사이트URL"))
    source_url = detail_url or online_url or DATA_GO_KR_DATASET_URL
    return PublicDataResult(
        query=query,
        service_id=service_id,
        service_name=normalize_text(merged.get("서비스명")),
        agency=normalize_text(merged.get("소관기관명")),
        department=normalize_text(merged.get("부서명")),
        application_method=normalize_text(merged.get("신청방법")),
        application_deadline=normalize_text(merged.get("신청기한")),
        reception_agency=normalize_text(merged.get("접수기관명") or merged.get("접수기관")),
        phone=normalize_text(merged.get("문의처") or merged.get("전화문의")),
        documents=normalize_text(merged.get("구비서류")),
        support_target=normalize_text(merged.get("지원대상")),
        support_content=normalize_text(merged.get("지원내용") or merged.get("서비스목적요약") or merged.get("서비스목적")),
        online_url=online_url,
        detail_url=detail_url,
        modified_at=normalize_text(merged.get("수정일시")),
        source_url=source_url,
        fetched_at=now_iso(),
        score=similarity(query, normalize_text(merged.get("서비스명"))),
    )


def lookup_public_service(
    query: str,
    service_key: str = "",
    per_page: int = DEFAULT_PER_PAGE,
    timeout: float = DEFAULT_TIMEOUT_SECONDS,
) -> PublicDataLookup:
    api_key = configured_api_key(service_key)
    cleaned_query = clean_service_query(query)
    if not api_key:
        return PublicDataLookup(
            enabled=False,
            ok=False,
            query=cleaned_query,
            message="공공데이터 API 키가 없어 Local DB 내부 데이터로만 안내합니다.",
        )

    try:
        payload = request_json(
            SERVICE_LIST_URL,
            {
                "page": 1,
                "perPage": per_page,
                "returnType": "JSON",
                "serviceKey": api_key,
                "cond[서비스명::LIKE]": cleaned_query,
            },
            service_key=api_key,
            timeout=timeout,
        )
        items = data_items(payload)
        best_item = pick_best_item(cleaned_query, items)
        if not best_item:
            return PublicDataLookup(
                enabled=True,
                ok=False,
                query=cleaned_query,
                message="공공데이터 조회 결과가 없습니다.",
            )
        detail_item = fetch_service_detail(normalize_text(best_item.get("서비스ID")), api_key, timeout)
        result = build_result(cleaned_query, best_item, detail_item)
        return PublicDataLookup(
            enabled=True,
            ok=True,
            query=cleaned_query,
            message="공공데이터 조회 결과를 찾았습니다.",
            result=result,
        )
    except HTTPError as exc:
        return PublicDataLookup(
            enabled=True,
            ok=False,
            query=cleaned_query,
            message=f"공공데이터 API HTTP 오류: {exc.code}",
        )
    except (URLError, TimeoutError) as exc:
        return PublicDataLookup(
            enabled=True,
            ok=False,
            query=cleaned_query,
            message=f"공공데이터 API 연결 실패: {exc}",
        )
    except (json.JSONDecodeError, ValueError) as exc:
        return PublicDataLookup(
            enabled=True,
            ok=False,
            query=cleaned_query,
            message=f"공공데이터 API 응답 해석 실패: {exc}",
        )


def source_sentence(result: PublicDataResult) -> str:
    if result.source_url:
        return f"자세한 내용은 정부24에서 확인해 주세요. 출처: {result.source_url}"
    return "자세한 내용은 정부24에서 확인해 주세요."


def agency_sentence(result: PublicDataResult) -> str:
    return f"소관기관은 {result.agency}입니다." if result.agency else ""


def summarize_public_general(result: PublicDataResult) -> str:
    parts = [f"공공데이터 기준으로 '{result.service_name}' 항목이 확인됩니다."]
    if agency := agency_sentence(result):
        parts.append(agency)
    parts.append(source_sentence(result))
    return " ".join(parts)


def summarize_public_fee(result: PublicDataResult) -> str:
    parts = [f"공공데이터 기준으로 '{result.service_name}' 항목이 확인됩니다."]
    if result.support_content:
        parts.append(f"수수료와 관련해서는 {result.support_content} 내용을 확인해 주세요.")
    elif result.application_method:
        parts.append(f"수수료 여부는 신청방법과 함께 확인이 필요하며, 신청방법은 {result.application_method}입니다.")
    else:
        parts.append("수수료 금액은 공공데이터 응답만으로 명확히 확인되지 않습니다.")
    parts.append(source_sentence(result))
    return " ".join(parts)


def summarize_public_documents(result: PublicDataResult) -> str:
    parts = [f"공공데이터 기준으로 '{result.service_name}' 항목이 확인됩니다."]
    if result.documents:
        parts.append(f"구비서류는 {result.documents}입니다.")
    else:
        parts.append("구비서류는 공공데이터 응답만으로 명확히 확인되지 않습니다.")
    parts.append(source_sentence(result))
    return " ".join(parts)


def summarize_public_apply(result: PublicDataResult) -> str:
    parts = [f"공공데이터 기준으로 '{result.service_name}' 항목이 확인됩니다."]
    if result.application_method:
        parts.append(f"신청방법은 {result.application_method}입니다.")
    elif result.reception_agency:
        parts.append(f"접수기관은 {result.reception_agency}입니다.")
    else:
        parts.append("신청방법은 공공데이터 응답만으로 명확히 확인되지 않습니다.")
    parts.append(source_sentence(result))
    return " ".join(parts)


def public_summary_kind(requested_fields: object) -> str:
    if isinstance(requested_fields, str):
        fields = {requested_fields}
    else:
        fields = set(requested_fields or [])
    if "fee" in fields:
        return "fee"
    if "documents" in fields:
        return "documents"
    if "route" in fields or "status" in fields:
        return "apply"
    return "general"


def summarize_public_result(lookup: PublicDataLookup, requested_fields: object = "general") -> str:
    result = lookup.result
    if not lookup.ok or result is None:
        return lookup.message

    summarizers = {
        "general": summarize_public_general,
        "fee": summarize_public_fee,
        "documents": summarize_public_documents,
        "apply": summarize_public_apply,
    }
    kind = public_summary_kind(requested_fields)
    return summarizers[kind](result)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Search Gov24 public service data through data.go.kr.")
    parser.add_argument("query", help="검색할 민원 또는 공공서비스 이름")
    parser.add_argument("--api-key", default="", help="공공데이터포털 서비스 키. 없으면 DATA_GO_KR_SERVICE_KEY 환경변수를 사용합니다.")
    parser.add_argument("--per-page", type=int, default=DEFAULT_PER_PAGE)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT_SECONDS)
    parser.add_argument("--json", action="store_true", help="구조화된 JSON으로 출력합니다.")
    return parser


def main() -> None:
    args = build_arg_parser().parse_args()
    lookup = lookup_public_service(args.query, service_key=args.api_key, per_page=args.per_page, timeout=args.timeout)
    if args.json:
        print(json.dumps(lookup.to_dict(), ensure_ascii=False, indent=2))
    else:
        print(summarize_public_result(lookup))


if __name__ == "__main__":
    main()
