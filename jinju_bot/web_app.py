from __future__ import annotations

import argparse
import json
import mimetypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock
from urllib.parse import unquote

try:
    from .feedback_store import DEFAULT_ALIAS_DB_PATH, init_alias_learning_db, record_feedback
    from .infer import build_arg_parser as build_infer_arg_parser
    from .infer import generate_answer, load_model_and_tokenizer
    from .tools import evidence_to_dict, render_basic_answer
    from .web_context import (
        ConversationState,
        get_conversation_state,
        make_response_id,
        resolve_evidence_with_context,
        update_conversation_state,
    )
    from .web_external import apply_gov24_answer, apply_public_data_answer, maybe_lookup_gov24, maybe_lookup_public_data
except ImportError:
    from feedback_store import DEFAULT_ALIAS_DB_PATH, init_alias_learning_db, record_feedback
    from infer import build_arg_parser as build_infer_arg_parser
    from infer import generate_answer, load_model_and_tokenizer
    from tools import evidence_to_dict, render_basic_answer
    from web_context import (
        ConversationState,
        get_conversation_state,
        make_response_id,
        resolve_evidence_with_context,
        update_conversation_state,
    )
    from web_external import apply_gov24_answer, apply_public_data_answer, maybe_lookup_gov24, maybe_lookup_public_data


ROOT = Path(__file__).resolve().parent
STATIC_DIR = ROOT / "static"

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 7860
DEFAULT_DB_PATH = "data/services.db"
DEFAULT_ALIAS_DB_PATH = str(DEFAULT_ALIAS_DB_PATH)
DEFAULT_MODEL_NAME_OR_PATH = "Qwen/Qwen2.5-1.5B-Instruct"
DEFAULT_ADAPTER_PATH = "checkpoints_evidence_Qwen2.5-1.5B-Instruct/step-500"
DEFAULT_TORCH_DTYPE = "bf16"
DEFAULT_QUANTIZATION = "none"
DEFAULT_BNB_4BIT_COMPUTE_DTYPE = "bf16"
DEFAULT_BNB_4BIT_QUANT_TYPE = "nf4"
DEFAULT_EVIDENCE_MAX_NEW_TOKENS = 80
DEFAULT_EVIDENCE_TEMPERATURE = 0.02
DEFAULT_PUBLIC_DATA_TIMEOUT = 5.0
DEFAULT_GOV24_TIMEOUT = 5.0
DEFAULT_PUBLIC_DATA_API_KEY = ""


class ChatHandler(BaseHTTPRequestHandler):
    db_path = DEFAULT_DB_PATH
    alias_db_path = DEFAULT_ALIAS_DB_PATH
    show_server_logs = True
    use_model = False
    model = None
    tokenizer = None
    infer_args = None
    enable_public_data = False
    public_data_api_key = DEFAULT_PUBLIC_DATA_API_KEY
    public_data_timeout = DEFAULT_PUBLIC_DATA_TIMEOUT
    enable_gov24 = False
    gov24_timeout = DEFAULT_GOV24_TIMEOUT
    generation_lock = Lock()
    sessions: dict[str, ConversationState] = {}
    sessions_lock = Lock()

    def log_message(self, fmt: str, *args) -> None:
        if self.show_server_logs:
            super().log_message(fmt, *args)

    def send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_file(self, path: Path) -> None:
        if not path.is_file():
            self.send_error(404)
            return
        content = path.read_bytes()
        content_type = mimetypes.guess_type(str(path))[0] or "application/octet-stream"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self) -> None:
        request_path = unquote(self.path.split("?", 1)[0])
        if request_path in {"", "/"}:
            self.send_file(STATIC_DIR / "index.html")
            return
        if request_path.startswith("/static/"):
            relative = request_path.removeprefix("/static/").lstrip("/")
            target = (STATIC_DIR / relative).resolve()
            if STATIC_DIR.resolve() not in target.parents and target != STATIC_DIR.resolve():
                self.send_error(403)
                return
            self.send_file(target)
            return
        self.send_error(404)

    def do_POST(self) -> None:
        if self.path == "/api/chat":
            self.handle_chat_post()
            return
        if self.path == "/api/feedback":
            self.handle_feedback_post()
            return
        self.send_error(404)

    def read_json_payload(self) -> dict | None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, json.JSONDecodeError):
            self.send_json(400, {"error": "요청 형식이 올바르지 않습니다."})
            return None

    def handle_chat_post(self) -> None:
        payload = self.read_json_payload()
        if payload is None:
            return
        question = str(payload.get("message", "")).strip()
        session_id = str(payload.get("session_id") or "").strip() or None
        debug_mode = bool(payload.get("debug_mode"))

        if not question:
            self.send_json(400, {"error": "질문을 입력해 주세요."})
            return

        session_id, state = get_conversation_state(self.sessions, self.sessions_lock, session_id)
        evidence, context_used = resolve_evidence_with_context(question, state, self.db_path, self.alias_db_path)
        gov24_data = maybe_lookup_gov24(
            question,
            evidence,
            enabled=self.enable_gov24,
            timeout=self.gov24_timeout,
        )
        public_data = maybe_lookup_public_data(
            question,
            evidence,
            enabled=self.enable_public_data,
            service_key=self.public_data_api_key,
            timeout=self.public_data_timeout,
        )
        mode = "model" if self.use_model else "template"
        warning = None
        if self.use_model and not context_used:
            try:
                with self.generation_lock:
                    answer = generate_answer(self.model, self.tokenizer, self.infer_args, question)
            except Exception as exc:
                answer = render_basic_answer(evidence)
                warning = f"모델 응답 실패로 내부 자료 기반 답변을 사용했습니다: {exc}"
                mode = "template_fallback"
        else:
            answer = render_basic_answer(evidence)
            if self.use_model and context_used:
                mode = "template_context"
        answer = apply_gov24_answer(answer, evidence, gov24_data)
        answer = apply_public_data_answer(answer, evidence, public_data)
        response_id = make_response_id()
        evidence_data = evidence_to_dict(evidence)
        with self.sessions_lock:
            update_conversation_state(state, response_id, question, answer, evidence, evidence_data, mode, context_used)
        self.send_json(
            200,
            {
                "answer": answer,
                "session_id": session_id,
                "response_id": response_id,
                "debug_mode": debug_mode,
                "context_used": context_used,
                "evidence": evidence_data,
                "gov24": gov24_data.to_dict() if gov24_data else None,
                "public_data": public_data.to_dict() if public_data else None,
                "mode": mode,
                "warning": warning,
            },
        )

    def handle_feedback_post(self) -> None:
        payload = self.read_json_payload()
        if payload is None:
            return
        session_id = str(payload.get("session_id") or "").strip()
        response_id = str(payload.get("response_id") or "").strip()
        rating = str(payload.get("rating") or "").strip().lower()

        if rating not in {"good", "bad"}:
            self.send_json(400, {"error": "rating은 good 또는 bad이어야 합니다."})
            return
        if not session_id or not response_id:
            self.send_json(400, {"error": "세션 또는 응답 정보가 없습니다."})
            return

        with self.sessions_lock:
            state = self.sessions.get(session_id)
            response = state.responses.get(response_id) if state else None
        if not response:
            self.send_json(404, {"error": "피드백 대상 응답을 찾지 못했습니다."})
            return

        result = record_feedback(self.alias_db_path, session_id, response_id, rating, response)
        self.send_json(200, result)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run a small web UI for jinju_bot.")
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--db", default=DEFAULT_DB_PATH)
    parser.add_argument("--alias-db", default=DEFAULT_ALIAS_DB_PATH, help="사용자 피드백과 승격 alias를 저장할 별도 SQLite DB입니다.")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--use-model", action="store_true", help="Load the LoRA model and generate answers through infer.py.")
    parser.add_argument("--model-name-or-path", default=DEFAULT_MODEL_NAME_OR_PATH)
    parser.add_argument("--adapter-path", default=DEFAULT_ADAPTER_PATH)
    parser.add_argument("--torch-dtype", default=DEFAULT_TORCH_DTYPE)
    parser.add_argument("--device-map", default=None)
    parser.add_argument("--trust-remote-code", action=argparse.BooleanOptionalAction, default=False)
    parser.add_argument("--quantization", choices=("none", "4bit", "8bit"), default=DEFAULT_QUANTIZATION)
    parser.add_argument("--bnb-4bit-compute-dtype", default=DEFAULT_BNB_4BIT_COMPUTE_DTYPE)
    parser.add_argument("--bnb-4bit-quant-type", default=DEFAULT_BNB_4BIT_QUANT_TYPE)
    parser.add_argument("--bnb-4bit-use-double-quant", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--evidence-max-new-tokens", type=int, default=DEFAULT_EVIDENCE_MAX_NEW_TOKENS)
    parser.add_argument("--evidence-temperature", type=float, default=DEFAULT_EVIDENCE_TEMPERATURE)
    parser.add_argument("--enable-public-data", action="store_true", default=True, help="DB 답변이 불확실할 때 공공데이터포털 API를 보조 조회합니다.")
    parser.add_argument("--disable-public-data", dest="enable_public_data", action="store_false", help="공공데이터포털 API 보조 조회를 끕니다.")
    parser.add_argument("--public-data-api-key", default=DEFAULT_PUBLIC_DATA_API_KEY, help="공공데이터포털 서비스 키. 없으면 DATA_GO_KR_SERVICE_KEY 환경변수를 사용합니다.")
    parser.add_argument("--public-data-timeout", type=float, default=DEFAULT_PUBLIC_DATA_TIMEOUT)
    parser.add_argument("--enable-gov24", action="store_true", default=True, help="DB 답변이 불확실하거나 공식 최신 자료가 필요할 때 정부24를 직접 조회합니다.")
    parser.add_argument("--disable-gov24", dest="enable_gov24", action="store_false", help="정부24 직접 조회를 끕니다.")
    parser.add_argument("--gov24-timeout", type=float, default=DEFAULT_GOV24_TIMEOUT)
    return parser


def build_web_infer_args(args: argparse.Namespace) -> argparse.Namespace:
    infer_args = build_infer_arg_parser().parse_args([])
    infer_args.services_db = args.db
    infer_args.alias_db = args.alias_db
    infer_args.template_only = not args.use_model
    infer_args.show_evidence = False
    infer_args.model_name_or_path = args.model_name_or_path
    infer_args.adapter_path = args.adapter_path
    infer_args.torch_dtype = args.torch_dtype
    infer_args.device_map = None if args.device_map in {"", "none", "None"} else args.device_map
    infer_args.trust_remote_code = args.trust_remote_code
    infer_args.quantization = args.quantization
    infer_args.bnb_4bit_compute_dtype = args.bnb_4bit_compute_dtype
    infer_args.bnb_4bit_quant_type = args.bnb_4bit_quant_type
    infer_args.bnb_4bit_use_double_quant = args.bnb_4bit_use_double_quant
    infer_args.evidence_max_new_tokens = args.evidence_max_new_tokens
    infer_args.evidence_temperature = args.evidence_temperature
    return infer_args


def main() -> None:
    args = build_arg_parser().parse_args()
    ChatHandler.db_path = args.db
    ChatHandler.alias_db_path = args.alias_db
    init_alias_learning_db(args.alias_db)
    ChatHandler.show_server_logs = not args.quiet
    ChatHandler.use_model = args.use_model
    ChatHandler.infer_args = build_web_infer_args(args)
    ChatHandler.enable_public_data = args.enable_public_data
    ChatHandler.public_data_api_key = args.public_data_api_key
    ChatHandler.public_data_timeout = args.public_data_timeout
    ChatHandler.enable_gov24 = args.enable_gov24
    ChatHandler.gov24_timeout = args.gov24_timeout
    if args.use_model:
        print("[web] loading model; this can take a while...")
        try:
            ChatHandler.model, ChatHandler.tokenizer = load_model_and_tokenizer(ChatHandler.infer_args)
        except Exception as exc:
            ChatHandler.use_model = False
            ChatHandler.infer_args.template_only = True
            print(f"[web:warn] model loading failed; falling back to template mode: {exc}")
        else:
            print("[web] model loaded")
    server = ThreadingHTTPServer((args.host, args.port), ChatHandler)
    print(f"[web] serving http://{args.host}:{args.port}")
    print(f"[web] mode={'model' if ChatHandler.use_model else 'template'}")
    print("[web] press Ctrl+C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
