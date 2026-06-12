from __future__ import annotations

import argparse
import json
import math
import os
import random
import re
import time
from collections import Counter
from dataclasses import asdict, dataclass
from typing import Any, Dict, Iterable, List, Optional

try:
    import torch
    from torch.nn.utils import clip_grad_norm_
    from torch.utils.data import DataLoader, Dataset
except ImportError:  # --help and static checks can run without PyTorch installed.
    torch = None
    clip_grad_norm_ = None
    DataLoader = None
    Dataset = object

try:
    from .model import HFModelConfig, load_causal_lm
    from .routing import RouteEntry, extract_route_from_tags, load_route_entries, rank_routes, render_route_candidate_label
except ImportError:
    from model import HFModelConfig, load_causal_lm
    from routing import RouteEntry, extract_route_from_tags, load_route_entries, rank_routes, render_route_candidate_label


@dataclass
class TrainConfig:
    model_name_or_path: str = "Qwen/Qwen2.5-1.5B-Instruct"
    train_file: str = "data/evidence_train.json"
    validation_file: Optional[str] = None
    output_dir: str = "checkpoints_evidence_Qwen2.5-1.5B-Instruct"

    text_column: str = "text"
    prompt_column: str = "instruction"
    response_column: str = "response"
    system_column: str = "system"

    max_length: int = 768
    batch_size: int = 1
    grad_accum_steps: int = 8
    epochs: int = 5
    max_steps: Optional[int] = None
    learning_rate: float = 2e-4
    weight_decay: float = 0.01
    warmup_ratio: float = 0.03
    max_grad_norm: float = 1.0
    seed: int = 32

    eval_ratio: float = 0.01
    log_interval: int = 5
    eval_interval: int = 50
    eval_max_rows: Optional[int] = 1000
    eval_max_batches: Optional[int] = None
    eval_batch_size: Optional[int] = None
    save_interval: int = 100
    num_workers: int = 0
    mixed_precision: str = "auto"
    torch_dtype: str = "bf16"
    device_map: Optional[str] = None
    trust_remote_code: bool = False
    gradient_checkpointing: bool = True
    gradient_checkpointing_kwargs={"use_reentrant": False}
    quantization: str = "none"
    bnb_4bit_compute_dtype: str = "bf16"
    bnb_4bit_quant_type: str = "nf4"
    bnb_4bit_use_double_quant: bool = True
    response_loss_only: bool = True
    sanitize_responses: bool = True
    training_task: str = "evidence_answer"
    route_candidate_limit: int = 20
    route_alias_file: Optional[str] = "data/route_aliases.json"
    metrics_file: Optional[str] = None
    resume_from_checkpoint: Optional[str] = None

    use_lora: bool = True
    lora_r: int = 16
    lora_alpha: int = 32
    lora_dropout: float = 0.05
    lora_target_modules: str = "q_proj,k_proj,v_proj,o_proj,gate_proj,up_proj,down_proj"
    lora_bias: str = "none"
    lora_task_type: str = "CAUSAL_LM"


TRAINING_STATE_FILE = "training_state.pt"


class JsonlSFTDataset(Dataset):
    def __init__(self, rows: List[Dict[str, Any]], tokenizer, cfg: TrainConfig):
        self.rows = rows
        self.tokenizer = tokenizer
        self.cfg = cfg

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, idx: int) -> Dict[str, torch.Tensor]:
        item = self.rows[idx]
        input_ids, labels = encode_example(item, self.tokenizer, self.cfg)
        return {
            "input_ids": torch.tensor(input_ids, dtype=torch.long),
            "labels": torch.tensor(labels, dtype=torch.long),
        }


def require_torch() -> None:
    if torch is None or DataLoader is None or clip_grad_norm_ is None:
        raise RuntimeError("Training requires PyTorch. Install project dependencies with: pip install -r requirements.txt")


def set_seed(seed: int) -> None:
    require_torch()
    random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def read_json_rows(path: str) -> List[Dict[str, Any]]:
    if not os.path.isfile(path):
        raise FileNotFoundError(f"Training data file not found: {path}")

    with open(path, "r", encoding="utf-8") as f:
        content = f.read().strip()

    if not content:
        raise ValueError(f"No training rows found in {path}")

    if content.startswith("["):
        try:
            rows = json.loads(content)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Invalid JSON at {path}") from exc
        if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
            raise ValueError(f"JSON training data must be a list of objects: {path}")
        return rows

    rows: List[Dict[str, Any]] = []
    for line_no, line in enumerate(content.splitlines(), start=1):
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Invalid JSON at {path}:{line_no}") from exc
        if not isinstance(row, dict):
            raise ValueError(f"JSONL row must be an object at {path}:{line_no}")
        rows.append(row)
    if not rows:
        raise ValueError(f"No training rows found in {path}")
    return rows


def split_rows(rows: List[Dict[str, Any]], eval_ratio: float, seed: int):
    if len(rows) < 2 or eval_ratio <= 0:
        return rows, []

    shuffled = rows[:]
    random.Random(seed).shuffle(shuffled)
    eval_size = max(1, int(len(shuffled) * eval_ratio))
    return shuffled[eval_size:], shuffled[:eval_size]


def split_rows_by_service(rows: List[Dict[str, Any]], eval_ratio: float, seed: int):
    if len(rows) < 2 or eval_ratio <= 0:
        return rows, []

    service_names = sorted({normalize_text(row.get("service_name")) for row in rows if normalize_text(row.get("service_name"))})
    if len(service_names) < 2:
        return split_rows(rows, eval_ratio, seed)

    random.Random(seed).shuffle(service_names)
    eval_size = max(1, int(len(service_names) * eval_ratio))
    eval_services = set(service_names[:eval_size])
    train_rows = [row for row in rows if normalize_text(row.get("service_name")) not in eval_services]
    eval_rows = [row for row in rows if normalize_text(row.get("service_name")) in eval_services]

    if not train_rows or not eval_rows:
        return split_rows(rows, eval_ratio, seed)

    print(
        f"[data] service_group_split train_services={len(service_names) - len(eval_services)}, "
        f"eval_services={len(eval_services)}, eval_ratio={eval_ratio}"
    )
    return train_rows, eval_rows


def limit_eval_rows(eval_rows: List[Dict[str, Any]], max_rows: Optional[int], seed: int) -> List[Dict[str, Any]]:
    if max_rows is None or max_rows <= 0 or len(eval_rows) <= max_rows:
        return eval_rows

    sampled = eval_rows[:]
    random.Random(seed).shuffle(sampled)
    limited = sampled[:max_rows]
    print(f"[data:eval] limited rows from {len(eval_rows)} to {len(limited)} with eval_max_rows={max_rows}")
    return limited


def normalize_text(value: Any) -> str:
    return "" if value is None else str(value).strip()


META_INSTRUCTION_PATTERNS = (
    "안내해 주세요",
    "권해 주세요",
    "안내하는 것이 원칙",
    "확인하도록 안내",
    "통화하도록 안내",
    "부서 안내만 진행합니다",
    "연결까지만 진행합니다",
    "임의로 판단하지 말고",
    "하지 말고",
    "답변하기 어려운 내용은",
    "스스로 생각해서",
)

DIRECT_RESPONSE_REPLACEMENTS = (
    ("담당부서 주무관과 직접 통화하도록 안내해 주세요", "담당부서 주무관과 직접 통화해 확인하시면 됩니다"),
    ("담당 주무관과 직접 통화하도록 안내해 주세요", "담당 주무관과 직접 통화해 확인하시면 됩니다"),
    ("담당부서 또는 담당 주무관과 직접 통화하도록 안내하는 것이 원칙입니다", "담당부서 또는 담당 주무관과 직접 통화해 확인하시면 됩니다"),
    ("담당 창구 또는 담당부서 확인을 권해 주세요", "담당 창구 또는 담당부서에 확인하시면 됩니다"),
    ("담당 창구나 담당부서 확인을 권해 주세요", "담당 창구나 담당부서에 확인하시면 됩니다"),
    ("민원별 특이사항은 담당부서 확인을 권해 주세요", "민원별 특이사항은 담당부서에 확인하시면 됩니다"),
    ("확인하도록 안내합니다", "확인하시면 됩니다"),
    ("통화하도록 안내합니다", "통화해 확인하시면 됩니다"),
    ("수수료는 금액을 단정해 안내하지 말고, 납부 필요 여부 중심으로 설명한 뒤 담당 창구 또는 담당부서 확인을 권해 주세요", "수수료는 납부 필요 여부 중심으로 확인하시면 됩니다. 정확한 금액은 담당 창구 또는 담당부서에 확인하시면 됩니다"),
    ("안내해 주세요", "안내받으시면 됩니다"),
    ("권해 주세요", "권장됩니다"),
)


def split_sentences(text: str) -> List[str]:
    return [part.strip() for part in re.split(r"(?<=[.!?。！？])\s+", text.strip()) if part.strip()]


def sanitize_response_for_user(response: str) -> str:
    response = re.sub(r"\s+", " ", normalize_text(response))
    for source, target in DIRECT_RESPONSE_REPLACEMENTS:
        response = response.replace(source, target)

    sentences = []
    for sentence in split_sentences(response):
        if any(pattern in sentence for pattern in META_INSTRUCTION_PATTERNS):
            continue
        sentences.append(sentence)

    return " ".join(sentences).strip()


def render_route_classification_prompt(question: str, candidates: List[tuple[int, RouteEntry]]) -> str:
    lines = [
        "사용자 질문이 아래 민원 업무 중 어느 것인지 분류하세요.",
        "질문자의 모호한 표현, 축약어, 별칭, 생활 표현을 해석해 후보 목록 안의 표준 업무와 의미가 같은지 판단하세요.",
        "창구 번호나 답변 문장을 생성하지 말고, 일치하는 업무의 번호만 출력하세요.",
        "후보 목록 안에 의미가 같은 업무가 없거나 확실하지 않으면 NONE만 출력하세요.",
        "",
        "업무 목록:",
    ]
    for local_idx, (_route_idx, _score, route) in enumerate(candidates, start=1):
        lines.append(f"[{local_idx}] {render_route_candidate_label(route)}")
    lines.extend(["", f"사용자 질문: {question}", "선택:"])
    return "\n".join(lines)


def same_route(left: RouteEntry, right: RouteEntry) -> bool:
    return left.service == right.service and left.window == right.window


def build_route_classification_rows(
    rows: List[Dict[str, Any]],
    routes: List[RouteEntry],
    cfg: TrainConfig,
    split_name: str,
) -> List[Dict[str, Any]]:
    converted = []
    dropped = 0
    forced = 0

    for row in rows:
        question = normalize_text(row.get(cfg.prompt_column))
        route = extract_route_from_tags(row.get("tags", []))
        if not question or not route:
            dropped += 1
            continue

        candidates = rank_routes(question, routes, limit=cfg.route_candidate_limit)
        route_idx = next((idx for idx, candidate in enumerate(routes) if same_route(candidate, route)), None)
        if route_idx is None:
            dropped += 1
            continue

        choice = None
        for local_idx, (_candidate_idx, _score, candidate) in enumerate(candidates, start=1):
            if same_route(candidate, route):
                choice = local_idx
                break

        if choice is None:
            candidates = candidates[: max(0, cfg.route_candidate_limit - 1)] + [(route_idx, 1.0, route)]    # choice가 없을 경우 그냥 제일 높은 값 찾아버리기
            choice = len(candidates)
            forced += 1

        converted.append(
            {
                cfg.system_column: (
                    "민원 업무 분류기입니다. 질문자의 축약어, 별칭, 생활 표현을 해석해 "
                    "표준 업무 후보 중 하나로 분류합니다."
                ),
                cfg.prompt_column: render_route_classification_prompt(question, candidates),
                cfg.response_column: str(choice),
                "tags": [route.window, route.service, "route_classification"],
            }
        )

    print(f"[data:{split_name}] route_classification converted={len(converted)}, dropped={dropped}, forced_candidates={forced}")
    return converted


def prepare_rows_for_task(
    rows: List[Dict[str, Any]],
    routes: List[RouteEntry],
    cfg: TrainConfig,
    split_name: str,
) -> List[Dict[str, Any]]:
    if cfg.training_task in {"answer", "evidence_answer"}:
        return sanitize_rows(rows, cfg, split_name)
    if cfg.training_task == "route":
        return build_route_classification_rows(rows, routes, cfg, split_name)
    raise ValueError("training_task must be one of: evidence_answer, answer, route")


def sanitize_rows(rows: List[Dict[str, Any]], cfg: TrainConfig, split_name: str) -> List[Dict[str, Any]]:
    if not cfg.sanitize_responses:
        return rows

    sanitized_rows = []
    dropped = 0
    changed = 0
    for row in rows:
        row = dict(row)
        response = normalize_text(row.get(cfg.response_column))
        if response:
            sanitized = sanitize_response_for_user(response)
            if not sanitized:
                dropped += 1
                continue
            if sanitized != response:
                changed += 1
            row[cfg.response_column] = sanitized
        sanitized_rows.append(row)

    print(f"[data:{split_name}] sanitized_responses changed={changed}, dropped={dropped}")
    return sanitized_rows


def render_prompt_response(item: Dict[str, Any], cfg: TrainConfig) -> tuple[str, str]:
    system = normalize_text(item.get(cfg.system_column))
    prompt = normalize_text(item.get(cfg.prompt_column))
    response = normalize_text(item.get(cfg.response_column))
    if cfg.sanitize_responses:
        response = sanitize_response_for_user(response)

    if not prompt or not response:
        raise ValueError(
            "Each SFT row must contain either a text field or both "
            f"{cfg.prompt_column!r} and {cfg.response_column!r}."
        )

    parts = []
    if system:
        parts.append(f"### 시스템\n{system}\n")
    parts.append(f"### 질문\n{prompt}\n\n### 답변\n")
    return "".join(parts), response



def row_text_for_stats(item: Dict[str, Any], cfg: TrainConfig) -> str:
    message_text = None
    messages = item.get("messages")
    if messages:
        rendered = []
        for message in messages:
            role = normalize_text(message.get("role", "user"))
            content = normalize_text(message.get("content"))
            rendered.append(f"### {role}\n{content}\n")
        message_text = "\n".join(rendered)
    if message_text is not None:
        return message_text

    text = normalize_text(item.get(cfg.text_column))
    if text:
        return text

    prompt_text, response_text = render_prompt_response(item, cfg)
    return prompt_text + response_text


def percentile(values: List[int], pct: float) -> int:
    if not values:
        return 0
    ordered = sorted(values)
    idx = min(len(ordered) - 1, max(0, int(round((len(ordered) - 1) * pct))))
    return ordered[idx]


def print_data_summary(rows: List[Dict[str, Any]], tokenizer, cfg: TrainConfig, split_name: str) -> None:
    if not rows:
        print(f"[data:{split_name}] rows=0")
        return
    intent_counts = Counter(normalize_text(row.get("intent", "unknown")) or "unknown" for row in rows)
    token_lengths = []
    truncated = 0
    for row in rows:
        text = row_text_for_stats(row, cfg)
        encoded = tokenizer(text, add_special_tokens=False)
        length = len(encoded["input_ids"])
        token_lengths.append(length)
        if length > cfg.max_length:
            truncated += 1

    combined_rows = sum(1 for row in rows if "+" in normalize_text(row.get("intent")))
    print(
        f"[data:{split_name}] rows={len(rows)}, combined_rows={combined_rows}, "
        f"tokens avg={sum(token_lengths)//len(token_lengths)}, p95={percentile(token_lengths, 0.95)}, "
        f"max={max(token_lengths)}, max_length={cfg.max_length}, truncated={truncated}"
    )
    top_intents = ", ".join(f"{name}:{count}" for name, count in intent_counts.most_common(8))
    print(f"[data:{split_name}] intents {top_intents}")
    if truncated:
        print(f"[warn:data:{split_name}] {truncated} rows exceed max_length and will be truncated. Consider --max-length {percentile(token_lengths, 0.99)} or higher.")

def render_messages(item: Dict[str, Any], tokenizer) -> Optional[str]:
    messages = item.get("messages")
    if not messages:
        return None
    if hasattr(tokenizer, "apply_chat_template") and tokenizer.chat_template:
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=False,
        )

    rendered = []
    for message in messages:
        role = normalize_text(message.get("role", "user"))
        content = normalize_text(message.get("content"))
        rendered.append(f"### {role}\n{content}\n")
    return "\n".join(rendered)


def encode_example(item: Dict[str, Any], tokenizer, cfg: TrainConfig):
    eos = tokenizer.eos_token or ""

    message_text = render_messages(item, tokenizer)
    if message_text is not None:
        text = message_text + eos
        encoded = tokenizer(text, truncation=True, max_length=cfg.max_length, add_special_tokens=False)
        input_ids = encoded["input_ids"]
        return input_ids, input_ids[:]

    text = normalize_text(item.get(cfg.text_column))
    if text:
        text = text + eos
        encoded = tokenizer(text, truncation=True, max_length=cfg.max_length, add_special_tokens=False)
        input_ids = encoded["input_ids"]
        return input_ids, input_ids[:]

    prompt_text, response_text = render_prompt_response(item, cfg)
    full_text = prompt_text + response_text + eos
    full = tokenizer(full_text, truncation=True, max_length=cfg.max_length, add_special_tokens=False)
    input_ids = full["input_ids"]
    labels = input_ids[:]

    if cfg.response_loss_only:
        prefix = tokenizer(
            prompt_text,
            truncation=True,
            max_length=cfg.max_length,
            add_special_tokens=False,
        )
        prefix_len = min(len(prefix["input_ids"]), len(labels))
        labels[:prefix_len] = [-100] * prefix_len
        if all(label == -100 for label in labels) and labels:
            labels[-1] = input_ids[-1]

    return input_ids, labels


def collate_batch(batch: List[Dict[str, torch.Tensor]], pad_token_id: int):
    max_len = max(item["input_ids"].numel() for item in batch)
    input_ids = torch.full((len(batch), max_len), pad_token_id, dtype=torch.long)
    labels = torch.full((len(batch), max_len), -100, dtype=torch.long)

    for row, item in enumerate(batch):
        length = item["input_ids"].numel()
        input_ids[row, :length] = item["input_ids"]
        labels[row, :length] = item["labels"]

    attention_mask = (input_ids != pad_token_id).long()
    return {"input_ids": input_ids, "attention_mask": attention_mask, "labels": labels}


def get_device() -> torch.device:
    return torch.device("cuda" if torch.cuda.is_available() else "cpu")


def parse_lora_target_modules(value: str) -> List[str]:
    return [part.strip() for part in value.split(",") if part.strip()]


def is_quantized_model(model) -> bool:
    return bool(getattr(model, "is_loaded_in_4bit", False) or getattr(model, "is_loaded_in_8bit", False))


def prepare_model_for_lora_training(model, cfg: TrainConfig):
    if cfg.quantization == "none" or not is_quantized_model(model):
        return model

    try:
        from peft import prepare_model_for_kbit_training
    except ImportError as exc:
        raise RuntimeError("QLoRA training requires peft. Install with: pip install peft") from exc

    return prepare_model_for_kbit_training(
        model,
        use_gradient_checkpointing=cfg.gradient_checkpointing,
    )


def apply_lora_if_enabled(model, cfg: TrainConfig):
    if not cfg.use_lora:
        if cfg.quantization != "none":
            raise ValueError("Quantized training requires LoRA. Use --use-lora with --quantization 4bit or 8bit.")
        return model

    model = prepare_model_for_lora_training(model, cfg)
    if cfg.resume_from_checkpoint:
        try:
            from peft import PeftModel
        except ImportError as exc:
            raise RuntimeError("LoRA checkpoint resume requires peft. Install with: pip install peft") from exc

        model = PeftModel.from_pretrained(model, cfg.resume_from_checkpoint, is_trainable=True)
        print(f"[resume] loaded trainable LoRA adapter from {cfg.resume_from_checkpoint}")
        model.print_trainable_parameters()
        return model

    try:
        from peft import LoraConfig, get_peft_model
    except ImportError as exc:
        raise RuntimeError("LoRA training requires peft. Install with: pip install peft") from exc

    lora_config = LoraConfig(
        r=cfg.lora_r,
        lora_alpha=cfg.lora_alpha,
        lora_dropout=cfg.lora_dropout,
        bias=cfg.lora_bias,
        task_type=cfg.lora_task_type,
        target_modules=parse_lora_target_modules(cfg.lora_target_modules),
    )
    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()
    return model


def get_autocast_dtype(cfg: TrainConfig):
    if cfg.mixed_precision == "no":
        return None
    if cfg.mixed_precision == "fp16":
        return torch.float16
    if cfg.mixed_precision == "bf16":
        return torch.bfloat16
    if cfg.mixed_precision == "auto":
        if torch.cuda.is_available() and torch.cuda.is_bf16_supported():
            return torch.bfloat16
        if torch.cuda.is_available():
            return torch.float16
        return None
    raise ValueError("mixed_precision must be one of: auto, no, fp16, bf16")


def lr_at_step(step: int, total_steps: int, warmup_steps: int, base_lr: float) -> float:
    if step < warmup_steps:
        return base_lr * float(step + 1) / max(1, warmup_steps)
    progress = (step - warmup_steps) / max(1, total_steps - warmup_steps)
    return base_lr * 0.5 * (1.0 + math.cos(math.pi * progress))


def evaluate(model, loader: DataLoader, device: torch.device, max_batches: Optional[int] = None) -> float:
    require_torch()
    if len(loader) == 0:
        return float("nan")

    model.eval()
    total_loss = 0.0
    total_batches = 0
    with torch.no_grad():
        for batch in loader:
            batch = {key: value.to(device) for key, value in batch.items()}
            output = model(**batch)
            total_loss += float(output.loss.detach().cpu())
            total_batches += 1
            if max_batches is not None and max_batches > 0 and total_batches >= max_batches:
                break
    model.train()
    return total_loss / max(1, total_batches)


def save_model(output_dir: str, model, tokenizer, cfg: TrainConfig, step: int) -> None:
    os.makedirs(output_dir, exist_ok=True)
    model.save_pretrained(output_dir)
    tokenizer.save_pretrained(output_dir)
    with open(os.path.join(output_dir, "train_config.json"), "w", encoding="utf-8") as f:
        json.dump({**asdict(cfg), "step": step}, f, ensure_ascii=False, indent=2)


def checkpoint_state_path(checkpoint_dir: str) -> str:
    return os.path.join(checkpoint_dir, TRAINING_STATE_FILE)


def torch_load_checkpoint(path: str) -> Dict[str, Any]:
    try:
        return torch.load(path, map_location="cpu", weights_only=False)
    except TypeError:
        return torch.load(path, map_location="cpu")


def collect_rng_state() -> Dict[str, Any]:
    state: Dict[str, Any] = {
        "python": random.getstate(),
        "torch": torch.get_rng_state(),
    }
    if torch.cuda.is_available():
        state["cuda"] = torch.cuda.get_rng_state_all()
    return state


def restore_rng_state(state: Dict[str, Any]) -> None:
    if not state:
        return
    if "python" in state:
        random.setstate(state["python"])
    if "torch" in state:
        torch.set_rng_state(state["torch"])
    if torch.cuda.is_available() and "cuda" in state:
        torch.cuda.set_rng_state_all(state["cuda"])


def save_training_state(output_dir: str, optimizer, scaler, step: int, epoch: int) -> None:
    os.makedirs(output_dir, exist_ok=True)
    state = {
        "step": step,
        "epoch": epoch,
        "optimizer": optimizer.state_dict(),
        "scaler": scaler.state_dict(),
        "rng_state": collect_rng_state(),
    }
    torch.save(state, checkpoint_state_path(output_dir))
    print(f"[checkpoint] saved training state={checkpoint_state_path(output_dir)}")


def load_training_state(checkpoint_dir: str, optimizer, scaler) -> tuple[int, int]:
    state_path = checkpoint_state_path(checkpoint_dir)
    if not os.path.isfile(state_path):
        print(f"[resume:warn] no {TRAINING_STATE_FILE} found at {checkpoint_dir}; model weights will resume but optimizer/scaler will start fresh")
        return 0, 0

    state = torch_load_checkpoint(state_path)
    optimizer_state = state.get("optimizer")
    if optimizer_state:
        optimizer.load_state_dict(optimizer_state)
    scaler_state = state.get("scaler")
    if scaler_state:
        scaler.load_state_dict(scaler_state)
    restore_rng_state(state.get("rng_state", {}))

    step = int(state.get("step", 0))
    epoch = int(state.get("epoch", 0))
    print(f"[resume] loaded training state from {state_path}: step={step}, epoch={epoch + 1}")
    return step, epoch


def resolve_metrics_file(cfg: TrainConfig) -> str:
    if cfg.metrics_file:
        return cfg.metrics_file
    return os.path.join(cfg.output_dir, "metrics.jsonl")


def append_metric(metrics_file: str, metric: Dict[str, Any]) -> None:
    with open(metrics_file, "a", encoding="utf-8") as f:
        f.write(json.dumps(metric, ensure_ascii=False) + "\n")


def print_training_summary(train_metrics: List[Dict[str, Any]], eval_metrics: List[Dict[str, Any]], metrics_file: str) -> None:
    print(f"[metrics] saved={metrics_file}")
    if train_metrics:
        first = train_metrics[0]
        last = train_metrics[-1]
        print(
            f"[summary] train_loss first={first['loss']:.4f} last={last['loss']:.4f} "
            f"steps={len(train_metrics)}"
        )
    if eval_metrics:
        best = min(eval_metrics, key=lambda item: item["loss"])
        last = eval_metrics[-1]
        print(
            f"[summary] eval_loss last={last['loss']:.4f} ppl={last['ppl']:.2f} "
            f"best={best['loss']:.4f}@step{best['step']}"
        )


def build_loaders(cfg: TrainConfig, tokenizer):
    train_rows = read_json_rows(cfg.train_file)
    if cfg.validation_file:
        eval_rows = read_json_rows(cfg.validation_file)
    elif cfg.training_task == "evidence_answer":
        train_rows, eval_rows = split_rows_by_service(train_rows, cfg.eval_ratio, cfg.seed)
    else:
        train_rows, eval_rows = split_rows(train_rows, cfg.eval_ratio, cfg.seed)

    routes: List[RouteEntry] = []
    if cfg.training_task == "route":
        routes = load_route_entries(cfg.train_file, cfg.route_alias_file)
        if not routes:
            raise ValueError("No route entries found. Route training requires rows with window/service tags.")

    eval_rows = limit_eval_rows(eval_rows, cfg.eval_max_rows, cfg.seed)

    train_rows = prepare_rows_for_task(train_rows, routes, cfg, "train")
    eval_rows = prepare_rows_for_task(eval_rows, routes, cfg, "eval")
    print_data_summary(train_rows, tokenizer, cfg, "train")
    print_data_summary(eval_rows, tokenizer, cfg, "eval")

    train_ds = JsonlSFTDataset(train_rows, tokenizer, cfg)
    eval_ds = JsonlSFTDataset(eval_rows, tokenizer, cfg) if eval_rows else None
    collate = lambda batch: collate_batch(batch, tokenizer.pad_token_id)

    train_loader = DataLoader(
        train_ds,
        batch_size=cfg.batch_size,
        shuffle=True,
        num_workers=cfg.num_workers,
        collate_fn=collate,
        pin_memory=torch.cuda.is_available(),
    )
    eval_loader = None
    if eval_ds is not None:
        eval_loader = DataLoader(
            eval_ds,
            batch_size=cfg.eval_batch_size or cfg.batch_size,
            shuffle=False,
            num_workers=cfg.num_workers,
            collate_fn=collate,
            pin_memory=torch.cuda.is_available(),
        )
    return train_loader, eval_loader


def train(cfg: TrainConfig) -> None:
    require_torch()
    set_seed(cfg.seed)
    os.makedirs(cfg.output_dir, exist_ok=True)

    model_name_or_path = cfg.resume_from_checkpoint if cfg.resume_from_checkpoint and not cfg.use_lora else cfg.model_name_or_path
    model, tokenizer = load_causal_lm(
        HFModelConfig(
            model_name_or_path=model_name_or_path,
            torch_dtype=cfg.torch_dtype,
            device_map=cfg.device_map,
            trust_remote_code=cfg.trust_remote_code,
            gradient_checkpointing=cfg.gradient_checkpointing,
            quantization=cfg.quantization,
            bnb_4bit_compute_dtype=cfg.bnb_4bit_compute_dtype,
            bnb_4bit_quant_type=cfg.bnb_4bit_quant_type,
            bnb_4bit_use_double_quant=cfg.bnb_4bit_use_double_quant,
        )
    )
    model = apply_lora_if_enabled(model, cfg)

    device = get_device()
    if cfg.device_map is None and cfg.quantization == "none":
        model.to(device)

    train_loader, eval_loader = build_loaders(cfg, tokenizer)
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=cfg.learning_rate,
        weight_decay=cfg.weight_decay,
    )

    steps_per_epoch = math.ceil(len(train_loader) / max(1, cfg.grad_accum_steps))
    total_steps = cfg.max_steps or (steps_per_epoch * cfg.epochs)
    warmup_steps = int(total_steps * cfg.warmup_ratio)
    autocast_dtype = get_autocast_dtype(cfg)
    scaler = torch.amp.GradScaler('cuda', enabled=(autocast_dtype == torch.float16))

    print(f"[model] {model_name_or_path}")
    if cfg.resume_from_checkpoint:
        print(f"[resume] checkpoint={cfg.resume_from_checkpoint}")
    print(f"[quantization] mode={cfg.quantization}, 4bit_compute_dtype={cfg.bnb_4bit_compute_dtype}, 4bit_quant_type={cfg.bnb_4bit_quant_type}, double_quant={cfg.bnb_4bit_use_double_quant}")
    print(f"[lora] enabled={cfg.use_lora}, r={cfg.lora_r}, alpha={cfg.lora_alpha}, targets={cfg.lora_target_modules}")
    print(f"[data] train_batches={len(train_loader)}, eval_batches={len(eval_loader) if eval_loader else 0}")
    print(f"[task] training_task={cfg.training_task}, train_file={cfg.train_file}, route_candidate_limit={cfg.route_candidate_limit}")
    print(f"[train] total_steps={total_steps}, warmup_steps={warmup_steps}, device={device}")

    metrics_file = resolve_metrics_file(cfg)
    os.makedirs(os.path.dirname(metrics_file) or ".", exist_ok=True)
    if cfg.resume_from_checkpoint and os.path.exists(metrics_file):
        print(f"[metrics] appending to existing metrics file during resume: {metrics_file}")
    else:
        open(metrics_file, "w", encoding="utf-8").close()
    train_metrics: List[Dict[str, Any]] = []
    eval_metrics: List[Dict[str, Any]] = []

    model.train()
    optimizer.zero_grad(set_to_none=True)
    step = 0
    start_epoch = 0
    if cfg.resume_from_checkpoint:
        step, start_epoch = load_training_state(cfg.resume_from_checkpoint, optimizer, scaler)
        start_epoch = min(start_epoch, max(0, cfg.epochs - 1))
        if step >= total_steps:
            print(f"[resume] checkpoint step={step} is already >= total_steps={total_steps}; nothing to train")
            print_training_summary(train_metrics, eval_metrics, metrics_file)
            return
    started_at = time.time()

    for epoch in range(start_epoch, cfg.epochs):
        for micro_step, batch in enumerate(train_loader, start=1):
            lr = lr_at_step(step, total_steps, warmup_steps, cfg.learning_rate)
            for group in optimizer.param_groups:
                group["lr"] = lr

            batch = {key: value.to(device, non_blocking=True) for key, value in batch.items()}
            with torch.autocast(
                device_type=device.type,
                dtype=autocast_dtype,
                enabled=(autocast_dtype is not None),
            ):
                output = model(**batch)
                loss = output.loss / cfg.grad_accum_steps

            if scaler.is_enabled():
                scaler.scale(loss).backward()
            else:
                loss.backward()

            should_update = micro_step % cfg.grad_accum_steps == 0 or micro_step == len(train_loader)
            if not should_update:
                continue

            if scaler.is_enabled():
                scaler.unscale_(optimizer)
            clip_grad_norm_(model.parameters(), cfg.max_grad_norm)

            if scaler.is_enabled():
                scaler.step(optimizer)
                scaler.update()
            else:
                optimizer.step()
            optimizer.zero_grad(set_to_none=True)
            step += 1

            if cfg.log_interval > 0 and step % cfg.log_interval == 0:
                elapsed = max(1e-6, time.time() - started_at)
                train_loss = loss.item() * cfg.grad_accum_steps
                metric = {
                    "type": "train",
                    "step": step,
                    "epoch": epoch + 1,
                    "loss": train_loss,
                    "lr": lr,
                    "elapsed_s": elapsed,
                }
                train_metrics.append(metric)
                append_metric(metrics_file, metric)
                print(f"[step {step}] epoch={epoch + 1} loss={train_loss:.4f} lr={lr:.2e} elapsed={elapsed:.1f}s")

            if eval_loader and cfg.eval_interval > 0 and step % cfg.eval_interval == 0:
                eval_loss = evaluate(model, eval_loader, device, cfg.eval_max_batches)
                eval_ppl = math.exp(min(eval_loss, 20))
                metric = {
                    "type": "eval",
                    "step": step,
                    "epoch": epoch + 1,
                    "loss": eval_loss,
                    "ppl": eval_ppl,
                }
                eval_metrics.append(metric)
                append_metric(metrics_file, metric)
                print(f"[eval {step}] loss={eval_loss:.4f} ppl={eval_ppl:.2f}")

            if cfg.save_interval > 0 and step % cfg.save_interval == 0:
                checkpoint_dir = os.path.join(cfg.output_dir, f"step-{step}")
                save_model(checkpoint_dir, model, tokenizer, cfg, step)
                save_training_state(checkpoint_dir, optimizer, scaler, step, epoch)

            if step >= total_steps:
                checkpoint_dir = os.path.join(cfg.output_dir, "final")
                save_model(checkpoint_dir, model, tokenizer, cfg, step)
                save_training_state(checkpoint_dir, optimizer, scaler, step, epoch)
                print_training_summary(train_metrics, eval_metrics, metrics_file)
                return

    checkpoint_dir = os.path.join(cfg.output_dir, "final")
    save_model(checkpoint_dir, model, tokenizer, cfg, step)
    save_training_state(checkpoint_dir, optimizer, scaler, step, max(0, cfg.epochs - 1))
    print_training_summary(train_metrics, eval_metrics, metrics_file)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Fine-tune a Hugging Face causal LM for jinju_bot.")
    for field_name, field_def in TrainConfig.__dataclass_fields__.items():
        default = field_def.default
        arg_name = "--" + field_name.replace("_", "-")
        if isinstance(default, bool):
            parser.add_argument(arg_name, action=argparse.BooleanOptionalAction, default=default)
        elif default is None:
            int_fields = {"max_steps", "eval_max_rows", "eval_max_batches", "eval_batch_size"}
            value_type = int if field_name in int_fields else str
            parser.add_argument(arg_name, type=value_type, default=None)
        else:
            parser.add_argument(arg_name, type=type(default), default=default)
    return parser


def main(argv: Optional[Iterable[str]] = None) -> None:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    train(TrainConfig(**vars(args)))


if __name__ == "__main__":
    main()
