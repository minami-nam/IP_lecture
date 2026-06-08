# jinju_bot Hugging Face Fine-Tuning

This folder contains a small Hugging Face loading and fine-tuning path for a civil-service response chatbot.

## Model

The default model is `Qwen/Qwen2.5-1.5B-Instruct`, an Apache-2.0 licensed instruction model. Training defaults are tuned for RTX 3060 12GB experiments and use LoRA by default. Larger models can be trained with QLoRA by loading the base model in 4-bit or 8-bit.

## Data

Use JSON or JSONL. For supervised chatbot tuning, each row can be:

```json
{"system":"진주시 민원 응대 챗봇입니다. 확인된 행정 정보만 안내합니다.","instruction":"전입신고는 어디서 하나요?","response":"전입신고는 정부24 또는 주소지 읍면동 행정복지센터에서 신청할 수 있습니다. 본인 확인이 필요한 업무라 실제 신청은 공식 창구에서 진행해야 합니다."}
```

Plain language-modeling rows also work in JSONL or JSON-list form:

```json
{"text":"민원 응대 예시 전체 텍스트..."}
```


## Route Aliases

Route training and inference can read `data/route_aliases.json` to map common user expressions to standard route services from `data/train.json` tags.

```json
{
  "여권 재발급": ["여권 갱신", "여권 다시 발급", "여권 만료"],
  "가족관계등록부": ["가족관계증명서", "기본증명서", "혼인관계증명서"]
}
```

Aliases affect direct data routing, route candidate ranking, and the LLM route-classification prompt. The service key should match the route service tag in the training data.

## Install

```bash
pip install -r jinju_bot/requirements.txt
```

## Train

The defaults in `TrainConfig` are enough for a first LoRA run:

```bash
python3 -m jinju_bot.train
```

You can override any default with argparse. Standard LoRA keeps the base model in fp16/bf16 and trains only the adapter:

```bash
python3 -m jinju_bot.train \
  --output-dir jinju_bot/checkpoints/qwen2_5_lora_okminwon \
  --batch-size 1 \
  --grad-accum-steps 8 \
  --epochs 2 \
  --max-length 512 \
  --learning-rate 2e-4 \
  --use-lora \
  --lora-r 16 \
  --lora-alpha 32 \
  --lora-dropout 0.05
```

Use QLoRA for larger models on 12GB GPUs. `--quantization 4bit` automatically uses a device map and prepares the k-bit model before applying LoRA:

```bash
python3 -m jinju_bot.train \
  --model-name-or-path LGAI-EXAONE/EXAONE-3.5-7.8B-Instruct \
  --trust-remote-code \
  --output-dir jinju_bot/checkpoints/exaone_3_5_7_8b_qlora_okminwon \
  --batch-size 1 \
  --grad-accum-steps 16 \
  --epochs 2 \
  --max-length 512 \
  --learning-rate 2e-4 \
  --use-lora \
  --quantization 4bit \
  --bnb-4bit-compute-dtype fp16 \
  --bnb-4bit-quant-type nf4 \
  --bnb-4bit-use-double-quant \
  --lora-r 16 \
  --lora-alpha 32
```

To run inference with a QLoRA adapter, load the base model with the same quantization mode:

```bash
python3 -m jinju_bot.infer \
  --model-name-or-path LGAI-EXAONE/EXAONE-3.5-7.8B-Instruct \
  --trust-remote-code \
  --adapter-path jinju_bot/checkpoints/exaone_3_5_7_8b_qlora_okminwon/final \
  --quantization 4bit
```


## Training Metrics

Training writes loss and eval logs to `metrics.jsonl` under `--output-dir` by default.

Save a matplotlib plot:

```bash
python3 -m jinju_bot.visualize_metrics \
  --metrics-file checkpoints_route/metrics.jsonl \
  --output-file checkpoints_route/metrics.png \
  --smooth-window 5
```

Open a Gradio dashboard while training is running:

```bash
python3 -m jinju_bot.visualize_metrics \
  --mode gradio \
  --metrics-file checkpoints_route/metrics.jsonl \
  --smooth-window 5
```

The Gradio view reads the JSONL file on refresh, so it can be used during or after training.

Disable LoRA and run full fine-tuning only if you have enough VRAM:

```bash
python3 -m jinju_bot.train --no-use-lora --learning-rate 2e-5
```

The final adapter or model is saved to `jinju_bot/checkpoints/final`, or to the `final` folder under your custom `--output-dir`.
