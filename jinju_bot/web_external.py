from __future__ import annotations

try:
    from .gov24_search import Gov24Lookup, lookup_gov24_service, summarize_gov24_result
    from .public_data_search import PublicDataLookup, lookup_public_service, summarize_public_result
except ImportError:
    from gov24_search import Gov24Lookup, lookup_gov24_service, summarize_gov24_result
    from public_data_search import PublicDataLookup, lookup_public_service, summarize_public_result


INTERNAL_CANDIDATE_MIN_SCORE = 0.10


def wants_external_lookup(question: str) -> bool:
    return any(word in question for word in ("공공데이터", "정부24", "인터넷", "온라인", "최신", "공식자료", "API"))


def has_usable_internal_candidates(evidence, min_score: float = INTERNAL_CANDIDATE_MIN_SCORE) -> bool:
    return bool(getattr(evidence, "matches", None) and evidence.confidence >= min_score)


def is_public_data_lookup_needed(question, evidence) -> bool:
    service = evidence.selected_service

    if wants_external_lookup(question):
        return True
    if evidence.ambiguous and has_usable_internal_candidates(evidence):
        return False
    if not service or evidence.ambiguous:
        return True
    requested = set(evidence.requested_fields)

    if "fee" in requested and service.fee_status == "unknown":
        return True
    if "documents" in requested and not service.document_note:
        return True
    if "status" in requested and not service.status_note:
        return True
    return False


def public_data_query(question: str, evidence) -> str:
    service = evidence.selected_service
    if evidence.ambiguous or not service:
        return question
    return service.service_name


def maybe_lookup_public_data(
    question: str,
    evidence,
    *,
    enabled: bool,
    service_key: str,
    timeout: float,
) -> PublicDataLookup | None:
    if not enabled or not is_public_data_lookup_needed(question, evidence):
        return None
    return lookup_public_service(
        public_data_query(question, evidence),
        service_key=service_key,
        timeout=timeout,
    )


def is_gov24_lookup_needed(question: str, evidence) -> bool:
    service = evidence.selected_service
    if wants_external_lookup(question):
        return True
    if evidence.ambiguous and has_usable_internal_candidates(evidence):
        return False
    if not service or evidence.ambiguous:
        return True
    if evidence.confidence < 0.18:
        return True
    return bool({"documents", "status"} & set(evidence.requested_fields))


def maybe_lookup_gov24(
    question: str,
    evidence,
    *,
    enabled: bool,
    timeout: float,
) -> Gov24Lookup | None:
    if not enabled or not is_gov24_lookup_needed(question, evidence):
        return None
    return lookup_gov24_service(
        public_data_query(question, evidence),
        timeout=timeout,
    )


def is_estimated_template_answer(answer: str) -> bool:
    return answer.startswith("가장 가까운 후보인 ")


def apply_gov24_answer(answer: str, evidence, gov24_data: Gov24Lookup | None) -> str:
    if not gov24_data:
        return answer
    if evidence.ambiguous and has_usable_internal_candidates(evidence):
        return answer
    if not gov24_data.ok or not gov24_data.results:
        if evidence.ambiguous and gov24_data.enabled:
            return f"{answer} 정부24에서도 바로 일치하는 결과를 찾지 못했습니다."
        return answer

    gov24_summary = summarize_gov24_result(gov24_data)
    if evidence.ambiguous or not evidence.selected_service:
        if is_estimated_template_answer(answer):
            return f"{answer} 추가로 {gov24_summary}"
        return f"내부 자료에서는 정확한 업무를 특정하기 어렵습니다. 대신 {gov24_summary}"
    return f"{answer} 추가로 {gov24_summary}"


def apply_public_data_answer(answer: str, evidence, public_data: PublicDataLookup | None) -> str:
    if not public_data:
        return answer
    if evidence.ambiguous and has_usable_internal_candidates(evidence):
        return answer
    if not public_data.ok or not public_data.result:
        if evidence.ambiguous and public_data.enabled:
            return f"{answer} 공공데이터에서도 바로 일치하는 결과를 찾지 못했습니다."
        return answer

    public_summary = summarize_public_result(public_data, evidence.requested_fields)
    if evidence.ambiguous or not evidence.selected_service:
        if is_estimated_template_answer(answer):
            return f"{answer} 추가로 {public_summary}"
        return f"Local DB에서는 정확한 업무를 특정하기 어렵습니다. 대신 {public_summary}"
    return f"{answer} 추가로 {public_summary}"
