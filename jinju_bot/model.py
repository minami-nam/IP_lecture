from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass
class HFModelConfig:
    model_name_or_path: str = "Qwen/Qwen2.5-1.5B-Instruct"
    torch_dtype: str = "fp16"
    device_map: Optional[str] = None
    trust_remote_code: bool = False
    gradient_checkpointing: bool = True
    quantization: str = "none"
    bnb_4bit_compute_dtype: str = "fp16"
    bnb_4bit_quant_type: str = "nf4"
    bnb_4bit_use_double_quant: bool = True


def _resolve_torch_dtype(dtype_name: str):
    import torch

    if dtype_name == "auto":
        return "auto"

    dtype_map = {
        "float32": torch.float32,
        "fp32": torch.float32,
        "float16": torch.float16,
        "fp16": torch.float16,
        "bfloat16": torch.bfloat16,
        "bf16": torch.bfloat16,
    }
    if dtype_name not in dtype_map:
        choices = ", ".join(sorted(dtype_map.keys()) + ["auto"])
        raise ValueError(f"Unknown torch_dtype={dtype_name!r}. Choose one of: {choices}")
    return dtype_map[dtype_name]


def load_tokenizer(model_name_or_path: str, trust_remote_code: bool = False):
    from transformers import AutoTokenizer

    tokenizer = AutoTokenizer.from_pretrained(
        model_name_or_path,
        trust_remote_code=trust_remote_code,
        use_fast=True,
    )
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    return tokenizer


def load_causal_lm(config: HFModelConfig):
    from transformers import AutoModelForCausalLM

    tokenizer = load_tokenizer(
        config.model_name_or_path,
        trust_remote_code=config.trust_remote_code,
    )
    quantization_config = None
    if config.quantization != "none":
        try:
            from transformers import BitsAndBytesConfig
        except ImportError as exc:
            raise RuntimeError("Quantized loading requires transformers with BitsAndBytesConfig support.") from exc

        if config.quantization == "4bit":
            quantization_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_compute_dtype=_resolve_torch_dtype(config.bnb_4bit_compute_dtype),
                bnb_4bit_quant_type=config.bnb_4bit_quant_type,
                bnb_4bit_use_double_quant=config.bnb_4bit_use_double_quant,
            )
        elif config.quantization == "8bit":
            quantization_config = BitsAndBytesConfig(load_in_8bit=True)
        else:
            raise ValueError("quantization must be one of: none, 4bit, 8bit")

    device_map = config.device_map
    if quantization_config is not None and device_map is None:
        device_map = "auto"

    model = AutoModelForCausalLM.from_pretrained(
        config.model_name_or_path,
        torch_dtype=_resolve_torch_dtype(config.torch_dtype),
        device_map=device_map,
        trust_remote_code=config.trust_remote_code,
        quantization_config=quantization_config,
    )
    model.config.pad_token_id = tokenizer.pad_token_id

    if config.gradient_checkpointing:
        model.gradient_checkpointing_enable()
        model.config.use_cache = False
        if hasattr(model, "enable_input_require_grads"):
            model.enable_input_require_grads()

    return model, tokenizer
