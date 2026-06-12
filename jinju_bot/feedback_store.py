from __future__ import annotations

import json
import sqlite3
import time
import uuid
from pathlib import Path

try:
    from .tools import normalize_key
    from .web_context import MAX_PENDING_CANDIDATES
except ImportError:
    from tools import normalize_key
    from web_context import MAX_PENDING_CANDIDATES


FEEDBACK_PROMOTION_MIN_POSITIVE = 2
FEEDBACK_PROMOTION_MIN_CONFIDENCE = 0.35
FEEDBACK_AMBIGUOUS_MIN_COUNT = 3
MAX_PROMOTED_ALIAS_CHARS = 60
DEFAULT_ALIAS_DB_PATH = Path("data/alias_learning.db")


def connect_feedback_db(db_path: str | Path = DEFAULT_ALIAS_DB_PATH) -> sqlite3.Connection:
    db_path = Path(db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    return conn


def ensure_feedback_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS user_feedback (
            feedback_id TEXT PRIMARY KEY,
            created_at REAL NOT NULL,
            session_id TEXT NOT NULL,
            response_id TEXT NOT NULL,
            question TEXT NOT NULL,
            normalized_question TEXT NOT NULL,
            answer TEXT NOT NULL,
            rating TEXT NOT NULL,
            mode TEXT,
            context_used TEXT,
            selected_service_id TEXT,
            selected_service_name TEXT,
            selected_score REAL,
            ambiguous INTEGER NOT NULL DEFAULT 0,
            evidence_json TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS alias_feedback_candidates (
            normalized_question TEXT NOT NULL,
            service_id TEXT NOT NULL,
            alias TEXT NOT NULL,
            positive_count INTEGER NOT NULL DEFAULT 0,
            negative_count INTEGER NOT NULL DEFAULT 0,
            promoted INTEGER NOT NULL DEFAULT 0,
            promoted_at REAL,
            updated_at REAL NOT NULL,
            PRIMARY KEY(normalized_question, service_id)
        );

        CREATE TABLE IF NOT EXISTS promoted_aliases (
            promoted_alias_id TEXT PRIMARY KEY,
            service_id TEXT NOT NULL,
            alias TEXT NOT NULL,
            normalized_alias TEXT NOT NULL,
            source TEXT NOT NULL,
            positive_count INTEGER NOT NULL DEFAULT 0,
            negative_count INTEGER NOT NULL DEFAULT 0,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            UNIQUE(service_id, normalized_alias)
        );

        CREATE TABLE IF NOT EXISTS ambiguous_expression_stats (
            normalized_question TEXT PRIMARY KEY,
            question_sample TEXT NOT NULL,
            count INTEGER NOT NULL DEFAULT 0,
            last_service_ids TEXT NOT NULL,
            promoted INTEGER NOT NULL DEFAULT 0,
            updated_at REAL NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_user_feedback_response ON user_feedback(response_id);
        CREATE INDEX IF NOT EXISTS idx_user_feedback_service ON user_feedback(selected_service_id);
        CREATE INDEX IF NOT EXISTS idx_alias_feedback_counts ON alias_feedback_candidates(positive_count, negative_count);
        CREATE INDEX IF NOT EXISTS idx_promoted_aliases_normalized ON promoted_aliases(normalized_alias);
        CREATE INDEX IF NOT EXISTS idx_promoted_aliases_service ON promoted_aliases(service_id);
        """
    )
    migrate_feedback_schema(conn)


def table_columns(conn: sqlite3.Connection, table_name: str) -> set[str]:
    return {row["name"] for row in conn.execute(f"PRAGMA table_info({table_name})").fetchall()}


def table_indexes(conn: sqlite3.Connection, table_name: str) -> set[str]:
    return {row["name"] for row in conn.execute(f"PRAGMA index_list({table_name})").fetchall()}


def migrate_feedback_schema(conn: sqlite3.Connection) -> None:
    alias_columns = table_columns(conn, "alias_feedback_candidates")
    if "promoted_at" not in alias_columns:
        conn.execute("ALTER TABLE alias_feedback_candidates ADD COLUMN promoted_at REAL")

    user_feedback_indexes = table_indexes(conn, "user_feedback")
    if "idx_user_feedback_unique_response" not in user_feedback_indexes:
        conn.execute(
            """
            DELETE FROM user_feedback
            WHERE rowid NOT IN (
                SELECT MIN(rowid)
                FROM user_feedback
                GROUP BY session_id, response_id
            )
            """
        )
        conn.execute(
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_user_feedback_unique_response "
            "ON user_feedback(session_id, response_id)"
        )


def feedback_alias_text(question: str) -> str | None:
    alias = " ".join(question.split())
    if not alias or len(alias) > MAX_PROMOTED_ALIAS_CHARS:
        return None
    return alias


def selected_feedback_service(response: dict) -> tuple[str | None, str | None, float]:
    evidence = response.get("evidence") or {}
    selected = evidence.get("selected_service") or {}
    service_id = selected.get("service_id")
    service_name = selected.get("service_name")
    score = float(evidence.get("confidence") or 0.0)
    return service_id, service_name, score


def is_alias_promotion_eligible(response: dict, rating: str) -> bool:
    if rating != "good":
        return False
    evidence = response.get("evidence") or {}
    if evidence.get("ambiguous"):
        return False
    if response.get("context_used") == "candidate_selection":
        return True
    return float(evidence.get("confidence") or 0.0) >= FEEDBACK_PROMOTION_MIN_CONFIDENCE


def upsert_alias_feedback(conn: sqlite3.Connection, question: str, service_id: str, rating: str) -> bool:
    alias = feedback_alias_text(question)
    if not alias:
        return False
    normalized_question = normalize_key(question)
    now = time.time()
    positive_delta = 1 if rating == "good" else 0
    negative_delta = 1 if rating == "bad" else 0
    conn.execute(
        """
        INSERT INTO alias_feedback_candidates (
            normalized_question, service_id, alias, positive_count, negative_count, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(normalized_question, service_id) DO UPDATE SET
            alias = excluded.alias,
            positive_count = positive_count + excluded.positive_count,
            negative_count = negative_count + excluded.negative_count,
            updated_at = excluded.updated_at
        """,
        (normalized_question, service_id, alias, positive_delta, negative_delta, now),
    )
    return maybe_promote_alias(conn, normalized_question, service_id)


def maybe_promote_alias(conn: sqlite3.Connection, normalized_question: str, service_id: str) -> bool:
    row = conn.execute(
        """
        SELECT alias, positive_count, negative_count, promoted
        FROM alias_feedback_candidates
        WHERE normalized_question = ? AND service_id = ?
        """,
        (normalized_question, service_id),
    ).fetchone()
    if not row or row["promoted"]:
        return False
    if row["positive_count"] < FEEDBACK_PROMOTION_MIN_POSITIVE or row["negative_count"] > 0:
        return False

    now = time.time()
    conn.execute(
        """
        INSERT INTO promoted_aliases (
            promoted_alias_id, service_id, alias, normalized_alias, source,
            positive_count, negative_count, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(service_id, normalized_alias) DO UPDATE SET
            alias = excluded.alias,
            positive_count = excluded.positive_count,
            negative_count = excluded.negative_count,
            updated_at = excluded.updated_at
        """,
        (
            uuid.uuid4().hex,
            service_id,
            row["alias"],
            normalized_question,
            "user_feedback",
            row["positive_count"],
            row["negative_count"],
            now,
            now,
        ),
    )
    conn.execute(
        """
        UPDATE alias_feedback_candidates
        SET promoted = 1, promoted_at = ?, updated_at = ?
        WHERE normalized_question = ? AND service_id = ?
        """,
        (now, now, normalized_question, service_id),
    )
    return True


def upsert_ambiguous_expression(conn: sqlite3.Connection, response: dict) -> bool:
    evidence = response.get("evidence") or {}
    matches = evidence.get("matches") or []
    if not evidence.get("ambiguous") and len(matches) < 2:
        return False
    question = response.get("question", "")
    normalized_question = normalize_key(question)
    if not normalized_question:
        return False
    service_ids = [match.get("service", {}).get("service_id") for match in matches[:MAX_PENDING_CANDIDATES]]
    service_ids = [service_id for service_id in service_ids if service_id]
    conn.execute(
        """
        INSERT INTO ambiguous_expression_stats (
            normalized_question, question_sample, count, last_service_ids, promoted, updated_at
        ) VALUES (?, ?, 1, ?, 0, ?)
        ON CONFLICT(normalized_question) DO UPDATE SET
            question_sample = excluded.question_sample,
            count = count + 1,
            last_service_ids = excluded.last_service_ids,
            promoted = CASE
                WHEN count + 1 >= ? THEN 1
                ELSE promoted
            END,
            updated_at = excluded.updated_at
        """,
        (normalized_question, question, json.dumps(service_ids, ensure_ascii=False), time.time(), FEEDBACK_AMBIGUOUS_MIN_COUNT),
    )
    row = conn.execute(
        "SELECT promoted FROM ambiguous_expression_stats WHERE normalized_question = ?",
        (normalized_question,),
    ).fetchone()
    return bool(row and row["promoted"])


def init_alias_learning_db(db_path: str | Path = DEFAULT_ALIAS_DB_PATH) -> Path:
    db_path = Path(db_path)
    with connect_feedback_db(db_path) as conn:
        ensure_feedback_schema(conn)
        conn.commit()
    return db_path


def record_feedback(db_path: str | Path, session_id: str, response_id: str, rating: str, response: dict) -> dict:
    question = response.get("question", "")
    answer = response.get("answer", "")
    evidence = response.get("evidence") or {}
    service_id, service_name, score = selected_feedback_service(response)
    normalized_question = normalize_key(question)
    promoted = False
    ambiguous_review = False

    with connect_feedback_db(db_path) as conn:
        ensure_feedback_schema(conn)
        cursor = conn.execute(
            """
            INSERT OR IGNORE INTO user_feedback (
                feedback_id, created_at, session_id, response_id, question, normalized_question,
                answer, rating, mode, context_used, selected_service_id, selected_service_name,
                selected_score, ambiguous, evidence_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                uuid.uuid4().hex,
                time.time(),
                session_id,
                response_id,
                question,
                normalized_question,
                answer,
                rating,
                response.get("mode"),
                response.get("context_used") or "",
                service_id,
                service_name,
                score,
                1 if evidence.get("ambiguous") else 0,
                json.dumps(evidence, ensure_ascii=False),
            ),
        )
        if cursor.rowcount == 0:
            return {
                "ok": True,
                "rating": rating,
                "duplicate": True,
                "alias_promoted": False,
                "ambiguous_review": False,
                "message": "이미 기록된 피드백입니다.",
            }
        if service_id and is_alias_promotion_eligible(response, rating):
            promoted = upsert_alias_feedback(conn, question, service_id, rating)
        if rating == "bad" or evidence.get("ambiguous"):
            ambiguous_review = upsert_ambiguous_expression(conn, response)
        conn.commit()

    return {
        "ok": True,
        "rating": rating,
        "duplicate": False,
        "alias_promoted": promoted,
        "ambiguous_review": ambiguous_review,
        "message": "피드백을 기록했습니다." if not promoted else "피드백을 기록하고 alias learning DB에 승격했습니다.",
    }
