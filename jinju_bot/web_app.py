from __future__ import annotations

import argparse
import json
import mimetypes
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock
from urllib.parse import unquote

try:
    from .infer import build_arg_parser as build_infer_arg_parser
    from .infer import generate_answer, load_model_and_tokenizer
    from .public_data_search import PublicDataLookup, lookup_public_service, summarize_public_result
    from .tools import build_evidence, evidence_to_dict, render_basic_answer
except ImportError:
    from infer import build_arg_parser as build_infer_arg_parser
    from infer import generate_answer, load_model_and_tokenizer
    from public_data_search import PublicDataLookup, lookup_public_service, summarize_public_result
    from tools import build_evidence, evidence_to_dict, render_basic_answer


ROOT = Path(__file__).resolve().parent
STATIC_DIR = ROOT / "static"


class ChatHandler(BaseHTTPRequestHandler):
    db_path = "data/services.db"
    show_server_logs = True
    use_model = False
    model = None
    tokenizer = None
    infer_args = None
    enable_public_data = False
    public_data_api_key = ""
    public_data_timeout = 5.0
    generation_lock = Lock()

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
        if self.path != "/api/chat":
            self.send_error(404)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
            question = str(payload.get("message", "")).strip()
        except (ValueError, json.JSONDecodeError):
            self.send_json(400, {"error": "요청 형식이 올바르지 않습니다."})
            return

        if not question:
            self.send_json(400, {"error": "질문을 입력해 주세요."})
            return

        evidence = build_evidence(question, db_path=self.db_path)
        public_data = maybe_lookup_public_data(question, evidence)
        mode = "model" if self.use_model else "template"
        warning = None
        if self.use_model:
            try:
                with self.generation_lock:
                    answer = generate_answer(self.model, self.tokenizer, self.infer_args, question)
            except Exception as exc:
                answer = render_basic_answer(evidence)
                warning = f"모델 응답 실패로 DB 답변을 사용했습니다: {exc}"
                mode = "template_fallback"
        else:
            answer = render_basic_answer(evidence)
        answer = apply_public_data_answer(answer, evidence, public_data)
        self.send_json(
            200,
            {
                "answer": answer,
                "evidence": evidence_to_dict(evidence),
                "public_data": public_data.to_dict() if public_data else None,
                "mode": mode,
                "warning": warning,
            },
        )


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run a small web UI for jinju_bot.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=7860)
    parser.add_argument("--db", default="data/services.db")
    parser.add_argument("--quiet", action="store_true")
    parser.add_argument("--use-model", action="store_true", help="Load the LoRA model and generate answers through infer.py.")
    parser.add_argument("--model-name-or-path", default="Qwen/Qwen2.5-1.5B-Instruct")
    parser.add_argument("--adapter-path", default="checkpoints_evidence_Qwen2.5-1.5B-Instruct/step-1000")
    parser.add_argument("--torch-dtype", default="bf16")
    parser.add_argument("--device-map", default=None)
    parser.add_argument("--trust-remote-code", action=argparse.BooleanOptionalAction, default=False)
    parser.add_argument("--quantization", choices=("none", "4bit", "8bit"), default="none")
    parser.add_argument("--bnb-4bit-compute-dtype", default="bf16")
    parser.add_argument("--bnb-4bit-quant-type", default="nf4")
    parser.add_argument("--bnb-4bit-use-double-quant", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--evidence-max-new-tokens", type=int, default=80)
    parser.add_argument("--evidence-temperature", type=float, default=0.0)
    parser.add_argument("--enable-public-data", action="store_true", default=True, help="DB 답변이 불확실할 때 공공데이터포털 API를 보조 조회합니다.")
    parser.add_argument("--disable-public-data", dest="enable_public_data", action="store_false", help="공공데이터포털 API 보조 조회를 끕니다.")
    parser.add_argument("--public-data-api-key", default="", help="공공데이터포털 서비스 키. 없으면 DATA_GO_KR_SERVICE_KEY 환경변수를 사용합니다.")
    parser.add_argument("--public-data-timeout", type=float, default=5.0)
    return parser


def is_public_data_lookup_needed(question, evidence) -> bool:
    service = evidence.selected_service

    if any(word in question for word in ("공공데이터", "정부24", "인터넷", "최신", "공식자료", "API")):
        return True
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


def maybe_lookup_public_data(question: str, evidence) -> PublicDataLookup | None:
    if not ChatHandler.enable_public_data or not is_public_data_lookup_needed(question, evidence):
        return None
    return lookup_public_service(
        public_data_query(question, evidence),
        service_key=ChatHandler.public_data_api_key,
        timeout=ChatHandler.public_data_timeout,
    )


def apply_public_data_answer(answer: str, evidence, public_data: PublicDataLookup | None) -> str:
    if not public_data:
        return answer
    if not public_data.ok or not public_data.result:
        if evidence.ambiguous and public_data.enabled:
            return f"{answer} 공공데이터에서도 바로 일치하는 결과를 찾지 못했습니다."
        return answer

    public_summary = summarize_public_result(public_data, evidence.requested_fields)
    if evidence.ambiguous or not evidence.selected_service:
        return f"Local DB에서는 정확한 업무를 특정하기 어렵습니다. 대신 {public_summary}"
    return f"{answer} 추가로 {public_summary}"


def build_web_infer_args(args: argparse.Namespace) -> argparse.Namespace:
    infer_args = build_infer_arg_parser().parse_args([])
    infer_args.services_db = args.db
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
    ChatHandler.show_server_logs = not args.quiet
    ChatHandler.use_model = args.use_model
    ChatHandler.infer_args = build_web_infer_args(args)
    ChatHandler.enable_public_data = args.enable_public_data
    ChatHandler.public_data_api_key = args.public_data_api_key
    ChatHandler.public_data_timeout = args.public_data_timeout
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
