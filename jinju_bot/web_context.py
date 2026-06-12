from __future__ import annotations

import time
import uuid
from collections import deque
from dataclasses import dataclass, field
from threading import Lock

try:
    from .topic_extractor import get_topic_extractor
    from .tools import build_evidence, build_evidence_for_service, get_service, normalize_key
except ImportError:
    from topic_extractor import get_topic_extractor
    from tools import build_evidence, build_evidence_for_service, get_service, normalize_key


SESSION_TTL_SECONDS = 60 * 60 * 6
MAX_SESSION_TURNS = 12
MAX_PENDING_CANDIDATES = 3
CONTEXT_FOLLOWUP_MAX_CHARS = 8
CONTEXT_OVERRIDE_MIN_CONFIDENCE = 0.30
CONTEXT_NEW_TOPIC_MIN_SCORE = 0.18
FOLLOWUP_HINT_WORDS = (
    "수수료", "비용", "금액", "얼마", "무료", "면제",
    "서류", "준비", "구비", "처리", "기간", "가능",
    "어디", "창구", "부서", "담당", "몇번", "몇층",
    "그럼", "그러면", "이건", "그건", "그거", "이거",
)
ORDINAL_WORDS = {
    "1": 0, "1번": 0, "첫번째": 0, "첫째": 0, "하나": 0,
    "2": 1, "2번": 1, "두번째": 1, "둘째": 1,
    "3": 2, "3번": 2, "세번째": 2, "셋째": 2,
    "4": 3, "4번": 3, "네번째": 3, "넷째": 3,
    "5": 4, "5번": 4, "다섯번째": 4,
}
CONFIRM_WORDS = {"맞아", "맞아요", "네", "예", "응", "ㅇㅇ", "그거", "그거야", "맞습니다", "1번"}
REJECT_WORDS = {"아니", "아니야", "아니요", "틀려", "틀렸어", "다른거", "다른거야"}


@dataclass
class ConversationState:
    turns: deque = field(default_factory=lambda: deque(maxlen=MAX_SESSION_TURNS))
    active_service_id: str | None = None
    pending_service_ids: list[str] = field(default_factory=list)
    responses: dict[str, dict] = field(default_factory=dict)
    updated_at: float = field(default_factory=time.time)


def make_session_id() -> str:
    return uuid.uuid4().hex


def make_response_id() -> str:
    return uuid.uuid4().hex


def cleanup_sessions(sessions: dict[str, ConversationState]) -> None:
    now = time.time()
    expired = [session_id for session_id, state in sessions.items() if now - state.updated_at > SESSION_TTL_SECONDS]
    for session_id in expired:
        sessions.pop(session_id, None)


def get_conversation_state(
    sessions: dict[str, ConversationState],
    sessions_lock: Lock,
    session_id: str | None,
) -> tuple[str, ConversationState]:
    with sessions_lock:
        cleanup_sessions(sessions)
        if not session_id:
            session_id = make_session_id()
        state = sessions.get(session_id)
        if state is None:
            state = ConversationState()
            sessions[session_id] = state
        state.updated_at = time.time()
        return session_id, state


def compact_question(question: str) -> str:
    return normalize_key(question)


def has_followup_hint(question: str) -> bool:
    compact = compact_question(question)
    return bool(compact and any(word in compact for word in FOLLOWUP_HINT_WORDS))


def is_followup_question(question: str, db_path: str) -> bool:
    compact = compact_question(question)
    if not compact:
        return False
    if len(compact) <= CONTEXT_FOLLOWUP_MAX_CHARS:
        return True
    if not has_followup_hint(question):
        return False
    return not get_topic_extractor(db_path).question_matches(question)


def evidence_has_new_topic(question: str, evidence, state: ConversationState, db_path: str) -> bool:
    return get_topic_extractor(db_path).evidence_has_new_topic(
        question,
        evidence,
        state.active_service_id,
        min_score=CONTEXT_NEW_TOPIC_MIN_SCORE,
    )


def resolve_pending_candidate(question: str, state: ConversationState, db_path: str):
    if not state.pending_service_ids:
        return None

    compact = compact_question(question)
    if compact in CONFIRM_WORDS:
        return get_service(state.pending_service_ids[0], db_path)
    if compact in REJECT_WORDS:
        return None

    ordinal = ORDINAL_WORDS.get(compact)
    if ordinal is not None and ordinal < len(state.pending_service_ids):
        return get_service(state.pending_service_ids[ordinal], db_path)

    for service_id in state.pending_service_ids:
        service = get_service(service_id, db_path)
        if service and normalize_key(service.service_name) in compact:
            return service
    return None


def should_use_conversation_context(question: str, evidence, state: ConversationState, db_path: str) -> bool:
    if not state.active_service_id or not has_followup_hint(question):
        return False
    if evidence_has_new_topic(question, evidence, state, db_path):
        return False
    if not is_followup_question(question, db_path):
        return False
    if evidence.selected_service and not evidence.ambiguous and evidence.confidence >= CONTEXT_OVERRIDE_MIN_CONFIDENCE:
        return False
    return True


def resolve_evidence_with_context(question: str, state: ConversationState, db_path: str, alias_db_path: str | None = None):
    selected_from_pending = resolve_pending_candidate(question, state, db_path)
    if selected_from_pending:
        return build_evidence_for_service(question, selected_from_pending, db_path=db_path), "candidate_selection"

    evidence = build_evidence(question, db_path=db_path, alias_db_path=alias_db_path)
    if should_use_conversation_context(question, evidence, state, db_path):
        service = get_service(state.active_service_id, db_path)
        if service:
            return build_evidence_for_service(question, service, db_path=db_path), "followup"
    return evidence, None


def update_conversation_state(
    state: ConversationState,
    response_id: str,
    question: str,
    answer: str,
    evidence,
    evidence_data: dict,
    mode: str,
    context_used: str | None,
) -> None:
    service = evidence.selected_service
    if service and not evidence.ambiguous:
        state.active_service_id = service.service_id
        state.pending_service_ids = []
    elif evidence.matches:
        state.pending_service_ids = [match.service.service_id for match in evidence.matches[:MAX_PENDING_CANDIDATES]]

    response = {
        "response_id": response_id,
        "question": question,
        "answer": answer,
        "service_id": service.service_id if service else None,
        "ambiguous": evidence.ambiguous,
        "evidence": evidence_data,
        "mode": mode,
        "context_used": context_used,
    }
    state.responses[response_id] = response
    while len(state.responses) > MAX_SESSION_TURNS:
        oldest_response_id = next(iter(state.responses))
        state.responses.pop(oldest_response_id, None)
    state.turns.append(response)
    state.updated_at = time.time()
