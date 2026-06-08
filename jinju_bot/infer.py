from __future__ import annotations

import argparse
import contextlib
import json
import os
import re
from typing import Iterable, Optional

try:
    import torch
except ImportError:  # --template-only mode can run without PyTorch installed.
    torch = None

try:
    from .tools import EvidencePackage, FIELD_LABELS, build_evidence, evidence_to_dict, fallback_answer, reception_fee_text, render_basic_answer
except ImportError:
    from tools import EvidencePackage, FIELD_LABELS, build_evidence, evidence_to_dict, fallback_answer, reception_fee_text, render_basic_answer


DEFAULT_SYSTEM_PROMPT = (
    "진주시 민원 응대 챗봇입니다. 조회 근거에 있는 정보만 사용해 민원인에게 직접 답변합니다. "
    "창구, 수수료, 절차, 연락처를 임의로 만들지 않습니다."
)
FALLBACK_ANSWER = "정확한 민원 정보를 확인하기 어렵습니다. 민원명이나 신청하려는 업무명을 조금 더 구체적으로 알려 주세요."
SUSPICIOUS_ANSWER_PATTERNS = ("카카오", "안드로이드", "택톡", "포장", "notify", "办理")
STRUCTURED_LEAK_PATTERNS = (
    "업무명:", "창구:", "수수료:", "조회 근거", "후보", "민원인 질문", "###",
    "Human:", "Assistant:", "User:", "질문>", "답변>",
)
TURN_LEAK_PATTERN = re.compile(r"\s*(?:Human|Assistant|User|System)\s*[:：].*", re.IGNORECASE | re.DOTALL)
CLI_TURN_LEAK_PATTERN = re.compile(r"\s*(?:질문|답변)\s*>.*", re.DOTALL)
HANJA_PATTERN = re.compile(r"[一-龥]")
PROMPT_MARKER_PATTERN = re.compile(r"\s*#{2,3}\s*(?:시스템|질문|답변)\b.*", re.DOTALL)
BROKEN_KOREAN_SPACE_PATTERN = re.compile(r"[가-힣]\s+[가-힣](?:\s+[가-힣])")


INTENT_LABELS = {
    "route": "담당 창구 문의",
    "fee": "수수료 문의",
    "license_tax": "등록면허세 문의",
    "documents": "구비서류 문의",
    "status": "처리 가능 여부 문의",
    "general": "일반 문의",
}


def adapter_exists(path: Optional[str]) -> bool:
    return bool(path) and os.path.isdir(path) and os.path.isfile(os.path.join(path, "adapter_config.json"))


def tokenizer_exists(path: str) -> bool:
    tokenizer_files = ("tokenizer.json", "tokenizer.model", "vocab.json")
    return os.path.isdir(path) and any(os.path.isfile(os.path.join(path, name)) for name in tokenizer_files)


def read_train_config(path: Optional[str]) -> dict:
    if not path:
        return {}
    config_path = os.path.join(path, "train_config.json")
    if not os.path.isfile(config_path):
        return {}
    with open(config_path, "r", encoding="utf-8") as f:
        return json.load(f)


def resolve_base_model(args: argparse.Namespace) -> str:
    if args.model_name_or_path:
        return args.model_name_or_path
    train_config = read_train_config(args.adapter_path)
    if train_config.get("model_name_or_path"):
        return train_config["model_name_or_path"]
    return "Qwen/Qwen2.5-1.5B-Instruct"


def render_prompt(question: str, system_prompt: str) -> str:
    parts = []
    system_prompt = system_prompt.strip()
    if system_prompt:
        parts.append(f"### 시스템\n{system_prompt}\n")
    parts.append(f"### 질문\n{question.strip()}\n\n### 답변\n")
    return "".join(parts)


def required_status_text(status: str, label: str) -> str:
    return {
        "required": f"{label} 납부가 필요한 민원",
        "not_required": f"{label} 납부가 필요하지 않은 민원",
        "conditional": f"조건에 따라 {label}가 달라질 수 있는 민원",
        "unknown": f"{label} 납부 여부가 자료에서 명확하지 않은 민원",
    }.get(status, f"{label} 납부 여부가 자료에서 명확하지 않은 민원")


def fee_status_text(status: str) -> str:
    return required_status_text(status, "수수료")


def evidence_fee_note(service) -> str:
    note = (service.fee_note or "").strip()
    if not note:
        return "자료 없음"
    redundant_notes = {
        "수수료 납부가 필요한 민원으로 표시되어 있습니다.",
        "접수 수수료가 필요하지 않은 민원으로 표시되어 있습니다.",
    }
    if note in redundant_notes:
        return "자료 없음"
    if service.reception_fee and note == reception_fee_text(service.reception_fee):
        return "자료 없음"
    return note


def license_tax_status_text(status: str) -> str:
    return required_status_text(status, "등록면허세")


def evidence_license_tax_note(service) -> str:
    note = (service.license_tax_note or "").strip()
    if not note:
        return "자료 없음"
    redundant_notes = {
        "등록면허세 납부가 필요한 민원으로 표시되어 있습니다.",
        "등록면허세 납부가 필요하지 않은 민원으로 표시되어 있습니다.",
    }
    if note in redundant_notes:
        return "자료 없음"
    return note


def render_evidence_block(evidence: EvidencePackage) -> str:
    service = evidence.selected_service
    requested = ", ".join(FIELD_LABELS.get(field, field) for field in evidence.requested_fields)
    lines = [
        f"질문 의도: {INTENT_LABELS.get(evidence.intent, evidence.intent)}",
        f"요청 정보: {requested}",
        f"검색 신뢰도: {evidence.confidence:.3f}",
        f"모호 여부: {'예' if evidence.ambiguous else '아니오'}",
    ]
    if not service:
        lines.append("선택 업무: 없음")
    else:
        lines.extend(
            [
                f"선택 업무: {service.service_name}",
                f"담당 창구: {service.window}",
                f"수수료: {fee_status_text(service.fee_status)}",
                f"접수 수수료: {service.reception_fee or '자료 없음'}",
                f"수수료 비고: {evidence_fee_note(service)}",
                f"등록면허세: {license_tax_status_text(service.license_tax_status)}",
                f"등록면허세 비고: {evidence_license_tax_note(service)}",
                f"구비서류 비고: {service.document_note or '자료 없음'}",
                f"처리 비고: {service.status_note or '자료 없음'}",
            ]
        )
    if evidence.matches:
        lines.append("검색 후보:")
        for idx, match in enumerate(evidence.matches[:3], start=1):
            lines.append(f"{idx}. {match.service.service_name} / {match.service.window} / 점수 {match.score:.3f}")
    return "\n".join(lines)


def render_evidence_prompt(question: str, evidence: EvidencePackage) -> str:
    lines = [
        "아래 조회 근거만 사용해 민원인에게 바로 답변하세요.",
        "답변은 1~2문장으로 작성하세요.",
        "요청 정보에 있는 항목은 모두 답변에 포함하세요.",
        "업무명과 창구는 조회 근거의 표현을 유지하되, 표 형태나 항목명은 출력하지 마세요.",
        "한자, 앱 이름, 전화번호, 후보에 없는 절차, 후보에 없는 수수료 금액이나 등록면허세 정보는 쓰지 마세요.",
        "검색 결과가 모호하거나 선택 업무가 없으면 질문 의도에 맞춰 어떤 정보를 확인하기 어려운지 말하세요.",
        "",
        "조회 근거",
        render_evidence_block(evidence),
        "",
        f"민원인 질문: {question.strip()}",
        "최종 답변:",
    ]
    return render_prompt("\n".join(lines), DEFAULT_SYSTEM_PROMPT)


def strip_generated_prompt_markers(answer: str) -> str:
    answer = PROMPT_MARKER_PATTERN.sub("", answer)
    answer = TURN_LEAK_PATTERN.sub("", answer)
    answer = CLI_TURN_LEAK_PATTERN.sub("", answer)
    return answer.strip()


def split_sentences(text: str) -> list[str]:
    return [part.strip() for part in re.split(r"(?<=[.!?。！？])\s+", text.strip()) if part.strip()]


def sanitize_answer(answer: str) -> str:
    answer = strip_generated_prompt_markers(answer)
    answer = re.sub(r"\s+", " ", answer.strip())
    answer = (
        answer.replace("민원여권 과", "민원여권과")
        .replace("창 구", "창구")
        .replace("납 부", "납부")
        .replace("민원 입니다", "민원입니다")
    )
    sentences = split_sentences(answer)
    if not sentences and answer:
        sentences = [answer]
    return " ".join(sentences[:2]).strip()


def extract_window_numbers(text: str) -> set[str]:
    return set(re.findall(r"(\d+)\s*번", text))


def mentions_related_service_with_wrong_name(answer: str, service_name: str) -> bool:
    normalized_answer = normalize_for_answer_check(answer)
    normalized_service = normalize_for_answer_check(service_name)
    if normalized_service in normalized_answer:
        return False
    service_terms = [term for term in ("영화상영관", "여권", "차고지", "건강기능식품", "노래연습장") if term in service_name]
    return any(normalize_for_answer_check(term) in normalized_answer for term in service_terms)


def normalize_for_answer_check(text: str) -> str:
    return re.sub(r"[^0-9a-z가-힣]+", "", text.lower())


def is_suspicious_answer(answer: str, question: str, evidence: EvidencePackage) -> bool:
    if not answer:
        return True
    if len(answer) > 180:
        return True
    if HANJA_PATTERN.search(answer):
        return True
    if any(pattern in answer for pattern in STRUCTURED_LEAK_PATTERNS):
        return True
    if BROKEN_KOREAN_SPACE_PATTERN.search(answer):
        return True
    if any(pattern in answer and pattern not in question for pattern in SUSPICIOUS_ANSWER_PATTERNS):
        return True

    service = evidence.selected_service
    if service:
        if mentions_related_service_with_wrong_name(answer, service.service_name):
            return True
        allowed_window_numbers = extract_window_numbers(service.window)
        answer_window_numbers = extract_window_numbers(answer)
        if allowed_window_numbers and answer_window_numbers and not answer_window_numbers <= allowed_window_numbers:
            return True
        if not allowed_window_numbers and answer_window_numbers and "창구" in answer:
            return True
        if "창구" in answer and service.window not in answer:
            service_mentions_window = bool(allowed_window_numbers) or "창구" in service.window
            if service_mentions_window and answer_window_numbers == allowed_window_numbers:
                pass
            elif service_mentions_window:
                return True

        if any(term in answer for term in ("폐업", "변경", "재발급", "정정", "취소", "말소", "지위승계")):
            allowed_text = service.service_name + " " + question
            if any(term in answer and term not in allowed_text for term in ("폐업", "변경", "재발급", "정정", "취소", "말소", "지위승계")):
                return True
    return False


def build_generation_kwargs(args: argparse.Namespace, max_new_tokens: Optional[int] = None, temperature: Optional[float] = None) -> dict:
    temperature = args.temperature if temperature is None else temperature
    do_sample = temperature > 0
    generation_kwargs = {
        "max_new_tokens": max_new_tokens or args.max_new_tokens,
        "do_sample": do_sample,
        "repetition_penalty": args.repetition_penalty,
        "no_repeat_ngram_size": args.no_repeat_ngram_size,
    }
    if do_sample:
        generation_kwargs.update({"temperature": temperature, "top_p": args.top_p, "top_k": args.top_k})
    return generation_kwargs


def generate_from_prompt(model, tokenizer, args: argparse.Namespace, prompt: str, max_new_tokens: Optional[int] = None, temperature: Optional[float] = None) -> str:
    no_grad = torch.no_grad if torch is not None else contextlib.nullcontext
    with no_grad():
        inputs = tokenizer(prompt, return_tensors="pt")
        input_device = getattr(model, "device", None) or next(model.parameters()).device
        inputs = {key: value.to(input_device) for key, value in inputs.items()}

        generation_kwargs = build_generation_kwargs(args, max_new_tokens=max_new_tokens, temperature=temperature)
        generation_kwargs.update({
            "pad_token_id": tokenizer.pad_token_id,
            "eos_token_id": tokenizer.eos_token_id,
        })
        output_ids = model.generate(**inputs, **generation_kwargs)
        new_tokens = output_ids[0, inputs["input_ids"].shape[-1] :]
        return tokenizer.decode(new_tokens, skip_special_tokens=True).strip()


def generate_answer(model, tokenizer, args: argparse.Namespace, question: str) -> str:
    evidence = build_evidence(
        question,
        db_path=args.services_db,
        limit=args.db_candidate_limit,
        min_score=args.db_min_score,
        ambiguity_margin=args.db_ambiguity_margin,
    )

    if args.show_evidence:
        print(json.dumps(evidence_to_dict(evidence), ensure_ascii=False, indent=2))

    if args.template_only or model is None or tokenizer is None:
        return render_basic_answer(evidence)
    if (not evidence.selected_service or evidence.ambiguous) and not args.allow_ambiguous_generation:
        return render_basic_answer(evidence)

    prompt = render_evidence_prompt(question, evidence)
    raw_answer = generate_from_prompt(
        model,
        tokenizer,
        args,
        prompt,
        max_new_tokens=args.evidence_max_new_tokens,
        temperature=args.evidence_temperature,
    )
    answer = sanitize_answer(raw_answer)
    if is_suspicious_answer(answer, question, evidence):
        return render_basic_answer(evidence)
    return answer


def load_model_and_tokenizer(args: argparse.Namespace):
    if torch is None:
        raise RuntimeError("LLM inference requires PyTorch. Use --template-only for DB-only answers.")
    try:
        from .model import HFModelConfig, load_causal_lm, load_tokenizer
    except ImportError:
        from model import HFModelConfig, load_causal_lm, load_tokenizer

    base_model = resolve_base_model(args)
    model, tokenizer = load_causal_lm(
        HFModelConfig(
            model_name_or_path=base_model,
            torch_dtype=args.torch_dtype,
            device_map=args.device_map,
            trust_remote_code=args.trust_remote_code,
            gradient_checkpointing=False,
            quantization=args.quantization,
            bnb_4bit_compute_dtype=args.bnb_4bit_compute_dtype,
            bnb_4bit_quant_type=args.bnb_4bit_quant_type,
            bnb_4bit_use_double_quant=args.bnb_4bit_use_double_quant,
        )
    )

    if adapter_exists(args.adapter_path):
        from peft import PeftModel

        model = PeftModel.from_pretrained(model, args.adapter_path)
        if tokenizer_exists(args.adapter_path):
            tokenizer = load_tokenizer(args.adapter_path, trust_remote_code=args.trust_remote_code)
    elif args.adapter_path:
        print(f"[warn] LoRA adapter not found at {args.adapter_path!r}. Using the base model only.")

    if args.device_map is None and args.quantization == "none":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        model.to(device)

    model.eval()
    model.config.use_cache = True
    if getattr(model, "generation_config", None) is not None:
        model.generation_config.do_sample = False
        for attr in ("temperature", "top_p", "top_k"):
            if hasattr(model.generation_config, attr):
                setattr(model.generation_config, attr, None)
    return model, tokenizer


def interactive_loop(model, tokenizer, args: argparse.Namespace) -> None:
    print("[ready] 질문을 입력하세요. 종료하려면 빈 줄, /q, /quit 중 하나를 입력하세요.")
    while True:
        try:
            question = input("\n질문> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return

        if not question or question in {"/q", "/quit"}:
            return

        answer = generate_answer(model, tokenizer, args, question)
        print(f"답변> {answer}")


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Run DB-grounded inference for jinju_bot.")
    parser.add_argument("--model-name-or-path", default="Qwen/Qwen2.5-1.5B-Instruct")
    parser.add_argument("--adapter-path", default="checkpoints_evidence_Qwen2.5-1.5B-Instruct/step-1000")
    parser.add_argument("--question", default=None, help="Run one question and exit.")
    parser.add_argument("--services-db", default="data/services.db")
    parser.add_argument("--template-only", action="store_true", help="Skip LLM generation and return deterministic DB answers.")
    parser.add_argument("--show-evidence", action="store_true", help="Print retrieved DB evidence before the answer.")
    parser.add_argument("--db-candidate-limit", type=int, default=5)
    parser.add_argument("--db-min-score", type=float, default=0.08)
    parser.add_argument("--db-ambiguity-margin", type=float, default=0.08)
    parser.add_argument("--allow-ambiguous-generation", action="store_true")
    parser.add_argument("--max-new-tokens", type=int, default=256)
    parser.add_argument("--evidence-max-new-tokens", type=int, default=80)
    parser.add_argument("--evidence-temperature", type=float, default=0.0)
    parser.add_argument("--temperature", type=float, default=0.1)
    parser.add_argument("--top-p", type=float, default=0.9)
    parser.add_argument("--top-k", type=int, default=50)
    parser.add_argument("--repetition-penalty", type=float, default=1.05)
    parser.add_argument("--no-repeat-ngram-size", type=int, default=6)
    parser.add_argument("--torch-dtype", default="fp16")
    parser.add_argument("--device-map", default=None)
    parser.add_argument("--trust-remote-code", action=argparse.BooleanOptionalAction, default=False)
    parser.add_argument("--quantization", choices=("none", "4bit", "8bit"), default="none")
    parser.add_argument("--bnb-4bit-compute-dtype", default="bf16")
    parser.add_argument("--bnb-4bit-quant-type", default="nf4")
    parser.add_argument("--bnb-4bit-use-double-quant", action=argparse.BooleanOptionalAction, default=True)
    return parser


def main(argv: Optional[Iterable[str]] = None) -> None:
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    model = tokenizer = None
    if not args.template_only:
        model, tokenizer = load_model_and_tokenizer(args)

    if args.question:
        print(generate_answer(model, tokenizer, args, args.question))
        return

    interactive_loop(model, tokenizer, args)


if __name__ == "__main__":
    main()
