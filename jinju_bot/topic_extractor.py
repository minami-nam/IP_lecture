from __future__ import annotations

import os
import re
import sqlite3
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


DEFAULT_DB_PATH = Path("data/services.db")
TOPIC_TOKEN_MIN_LENGTH = 2
TOPIC_TOKEN_MAX_LENGTH = 20
TOPIC_MATCH_MIN_SCORE = 0.18
KOREAN_SUFFIXES = (
    "으로", "에서", "에게", "부터", "까지", "하고", "이랑", "랑", "은", "는", "이", "가",
    "을", "를", "과", "와", "로", "에", "의", "도", "만", "요",
)
TOPIC_STOPWORDS = {
    "관련", "민원", "업무", "신청", "신고", "등록", "허가", "발급", "재발급", "재교부",
    "확인서", "증명서", "증명", "확인", "서류", "수수료", "비용", "금액", "처리", "접수",
    "어디", "어디서", "받지", "받아", "받나요", "하나요", "해요", "되나요", "필요",
    "필요해", "필요한", "필요하니", "필요하나요", "뭐", "무엇", "그럼", "그러면",
    "이건", "그건", "그거", "이거", "좀", "알려줘", "문의", "창구", "담당", "부서",
}
TOKEN_PATTERN = re.compile(r"[0-9a-zA-Z가-힣]+")
NON_TOPIC_CHARS = re.compile(r"[^0-9a-zA-Z가-힣]+")


@dataclass(frozen=True)
class TopicEntry:
    token: str
    service_id: str
    service_name: str
    source_text: str


@dataclass(frozen=True)
class TopicMatch:
    token: str
    service_id: str
    service_name: str
    source_text: str


@dataclass(frozen=True)
class TopicExtractorConfig:
    min_token_length: int = TOPIC_TOKEN_MIN_LENGTH
    max_token_length: int = TOPIC_TOKEN_MAX_LENGTH
    stopwords: frozenset[str] = frozenset(TOPIC_STOPWORDS)


_EXTRACTOR_CACHE: dict[tuple[str, float], "DbTopicExtractor"] = {}


def normalize_topic_text(value: object) -> str:
    text = "" if value is None else str(value)
    text = re.sub(r"\s+", " ", text).strip().lower()
    return NON_TOPIC_CHARS.sub("", text)


def strip_korean_suffix(token: str) -> str:
    for suffix in KOREAN_SUFFIXES:
        if token.endswith(suffix) and len(token) > len(suffix) + 1:
            return token[: -len(suffix)]
    return token


def clean_token(token: str, config: TopicExtractorConfig) -> str:
    token = normalize_topic_text(strip_korean_suffix(token))
    if not (config.min_token_length <= len(token) <= config.max_token_length):
        return ""
    if token in config.stopwords:
        return ""
    return token


def phrase_tokens(text: str, config: TopicExtractorConfig) -> set[str]:
    tokens: set[str] = set()
    for raw_token in TOKEN_PATTERN.findall(text):
        token = clean_token(raw_token, config)
        if token:
            tokens.add(token)
    return tokens


def compact_contains_token(text: str, token: str) -> bool:
    return bool(token and token in normalize_topic_text(text))


class DbTopicExtractor:
    def __init__(self, db_path: str | Path = DEFAULT_DB_PATH, config: TopicExtractorConfig | None = None):
        self.db_path = str(db_path)
        self.config = config or TopicExtractorConfig()
        self.entries_by_token: dict[str, list[TopicEntry]] = {}
        self.tokens_by_service: dict[str, set[str]] = {}
        self._load()

    def _load(self) -> None:
        if not os.path.isfile(self.db_path):
            return

        with sqlite3.connect(self.db_path) as conn:
            conn.row_factory = sqlite3.Row
            rows = conn.execute(
                """
                SELECT s.service_id, s.service_name, a.alias
                FROM services s
                LEFT JOIN aliases a ON a.service_id = s.service_id
                """
            ).fetchall()

        for row in rows:
            service_id = str(row["service_id"])
            service_name = str(row["service_name"] or "")
            for source_text in dict.fromkeys((service_name, str(row["alias"] or ""))):
                if not source_text:
                    continue
                for token in phrase_tokens(source_text, self.config):
                    entry = TopicEntry(
                        token=token,
                        service_id=service_id,
                        service_name=service_name,
                        source_text=source_text,
                    )
                    self.entries_by_token.setdefault(token, []).append(entry)
                    self.tokens_by_service.setdefault(service_id, set()).add(token)

    def question_matches(self, question: str) -> list[TopicMatch]:
        compact = normalize_topic_text(question)
        seen: set[tuple[str, str, str]] = set()
        matches: list[TopicMatch] = []
        for token, entries in self.entries_by_token.items():
            if token not in compact:
                continue
            for entry in entries:
                key = (entry.token, entry.service_id, entry.source_text)
                if key in seen:
                    continue
                seen.add(key)
                matches.append(
                    TopicMatch(
                        token=entry.token,
                        service_id=entry.service_id,
                        service_name=entry.service_name,
                        source_text=entry.source_text,
                    )
                )
        matches.sort(key=lambda item: (len(item.token), len(item.source_text)), reverse=True)
        return matches

    def service_has_question_topic(self, service_id: str | None, question: str) -> bool:
        if not service_id:
            return False
        service_tokens = self.tokens_by_service.get(service_id, set())
        question_tokens = {match.token for match in self.question_matches(question)}
        return bool(service_tokens & question_tokens)

    def evidence_has_new_topic(self, question: str, evidence, active_service_id: str | None, min_score: float = TOPIC_MATCH_MIN_SCORE) -> bool:
        matches = self.question_matches(question)
        if not matches or not getattr(evidence, "matches", None):
            return False
        if self.service_has_question_topic(active_service_id, question):
            return False

        topic_tokens = {match.token for match in matches}
        for match in evidence.matches:
            if match.score < min_score:
                continue
            service_id = match.service.service_id
            service_tokens = self.tokens_by_service.get(service_id, set())
            if service_tokens & topic_tokens:
                return True
            service_text = " ".join((match.service.service_name, match.matched_alias))
            if any(compact_contains_token(service_text, token) for token in topic_tokens):
                return True
        return False


def get_topic_extractor(db_path: str | Path = DEFAULT_DB_PATH) -> DbTopicExtractor:
    path = str(db_path)
    mtime = os.path.getmtime(path) if os.path.isfile(path) else 0.0
    key = (path, mtime)
    extractor = _EXTRACTOR_CACHE.get(key)
    if extractor is None:
        stale_keys = [cache_key for cache_key in _EXTRACTOR_CACHE if cache_key[0] == path]
        for cache_key in stale_keys:
            _EXTRACTOR_CACHE.pop(cache_key, None)
        extractor = DbTopicExtractor(path)
        _EXTRACTOR_CACHE[key] = extractor
    return extractor


def main(argv: Iterable[str] | None = None) -> None:
    import argparse

    parser = argparse.ArgumentParser(description="Extract DB-backed topic tokens from a question.")
    parser.add_argument("question")
    parser.add_argument("--db", default=str(DEFAULT_DB_PATH))
    args = parser.parse_args(list(argv) if argv is not None else None)

    extractor = get_topic_extractor(args.db)
    for match in extractor.question_matches(args.question):
        print(f"{match.token}\t{match.service_id}\t{match.service_name}\t{match.source_text}")


if __name__ == "__main__":
    main()
