# jinju_bot Hugging Face Fine-Tuning

This folder contains a small Hugging Face loading and fine-tuning path for a civil-service response chatbot.
** Hugging Face에서 모델을 Load하여, Fine-Tuning 을 거친 후 민원 관련 업무를 처리하는 AI 챗봇을 만드는 프로젝트입니다.

---
## Model

The default model is `Qwen/Qwen2.5-1.5B-Instruct`, an Apache-2.0 licensed instruction model. Training defaults are tuned for RTX 3060 12GB experiments and use LoRA by default. Larger models can be trained with QLoRA by loading the base model in 4-bit or 8-bit.
해당 프로젝트에서 사용한 모델은 상기한 Qwen 2.5 1.5B Instruct 모델이며, Ryzen 5700X3D, 64GB RAM, 3060 12GB 환경에서 LoRA를 이용하여 Training 시켰습니다. 모델은 환경에 따라 원하시는 모델로 바꾸실 수 있고, Training 시간을 절약하기 위한 QLoRA 및 bf16 모드를 지원합니다. BF16을 사용하여 학습 진행 시 768 Token limit을 설정한 상태 기준 VRAM 10GB 정도를 소모하고, 훈련 시간은 10 step 당 약 30초 정도 소요되는 것을 확인했습니다.     

---
## Data

Use JSON or JSONL. For supervised chatbot tuning, each row can be:
json 혹은 jsonl 파일을 이용하여 DB를 생성할 수 있습니다. 대략적인 행들의 구성은 다음과 같습니다. 
```json
{"system":"진주시 민원 응대 챗봇입니다. 확인된 행정 정보만 안내합니다.","instruction":"전입신고는 어디서 하나요?","response":"전입신고는 정부24 또는 주소지 읍면동 행정복지센터에서 신청할 수 있습니다. 본인 확인이 필요한 업무라 실제 신청은 공식 창구에서 진행해야 합니다."}
```

Plain language-modeling rows also work in JSONL or JSON-list form:

```json
{"text":"민원 응대 예시 전체 텍스트..."}
```

---
## Route Aliases

Route training and inference can read `data/route_aliases.json` to map common user expressions to standard route services from `data/train.json` tags.
경량 모델을 기반으로 제작하였기에, route_aliases.json 파일을 통해 사용자의 입력 중 해당 파일 내부에 있는 문자열이 입력된 경우 Route Table을 통해 바로 적절한 출력을 생성할 수 있게 제작하였습니다.

```json
{
  "여권 재발급": ["여권 갱신", "여권 다시 발급", "여권 만료"],
  "가족관계등록부": ["가족관계증명서", "기본증명서", "혼인관계증명서"]
}
```

Aliases affect direct data routing, route candidate ranking, and the LLM route-classification prompt. The service key should match the route service tag in the training data.
Routing의 경우에는, 개발자가 모든 단어를 넣는 것은 한계가 있기 때문에 디버그 모드를 넣어 질문에 대한 Route 결과를 평가할 수 있는 UX를 따로 추가하여, 일정 값 이상 좋아요를 얻는 Aliase 후보는 정식 Aliase로 승격시켜 실제 사용자들이 말하는 민원명과 정식 민원명을 쉽게 연결지을 수 있게 설계했습니다.

---
## Gov24 and Routing Tools

`gov24_search.py` provides a lightweight Government24 lookup tool. It first tries Government24 search/service pages and falls back to the Government24 main page's frequently used services when direct search endpoints are unavailable.
단순히 DB 내부의 데이터를 가져와서 질문에 답변하는 것이 아닌, 공공데이터 OpenAPI 및 정부24 사이트를 크롤링할 수 있는 Agent Tool 또한 제작하여 인터넷에 개재되는 최신 정보들을 빠르게 읽을 수 있게 제작하였습니다. DB 내부에 연관된 데이터가 존재하지 않을 경우, 해당 Tool을 사용하여 인터넷 상의 정보들을 검색할 수 있게 설계하였습니다. 이는 Parameter 설정으로 간단하게 사용 여부를 결정할 수 있습니다.     

```bash
python3 -m jinju_bot.gov24_search "여권 재발급" --json
```

The web server enables Gov24 lookup by default for ambiguous, low-confidence, document/status, or explicitly official/latest/online questions. Use `--disable-gov24` to turn it off, or `--gov24-timeout` to tune network latency. Public Data Portal lookup remains available through `public_data_search.py`.

Routing precision is improved through both curated aliases in `data/route_aliases.json` and automatic alias expansion during DB build. The builder now derives common spoken variants such as `재교부 -> 재발급`, `갱신 -> 재발급`, `개시 -> 개업`, parenthesized names such as `PC방`, compact no-space aliases, and shortened service names. Rebuild the DB after alias changes:

```bash
python3 -m jinju_bot.build_db \
  --xlsx jinju_bot/data/각부서별_업무담당.xlsx \
  --aliases jinju_bot/data/route_aliases.json \
  --output jinju_bot/data/services.db
```

## Install

Install 하기 전, CUDA Driver가 정상적으로 설치되어 있는지, 사용 환경에서 정상적으로 인식되는지 반드시 확인하시기 바랍니다.    

```bash
pip install -r jinju_bot/requirements.txt
```


## Train

이 항목은 모델의 training에 대한 설명입니다. TrainConfig Class는 train.py 파일 상단에 위치하고 있으며, 해당 Parameter들을 조절하여 학습을 사용자가 사전 조절할 수 있습니다.

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
QLoRA를 통한 Quantization의 경우 4bit 환경에서 그닥 성능이 좋지 않게 나왔습니다. 모델이 충분히 크지 않다면 QLoRA 학습은 비추천드립니다.    
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

Training 과정을 시각화하는 방법으로 matplotlib와 Gradio를 통한 Web GUI 두 가지 방법을 모두 지원합니다. log는 `--output_dir` 하위 `metrics.jsonl` 파일에 기록되며, visualize_metrics.py 파일을 이용하여 두 가지 방법으로 Loss 값 변화를 시각화하여 확인하실 수 있습니다.     
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


## Full-Training 
Disable LoRA and run full fine-tuning only if you have enough VRAM:       
VRAM이 충분한 경우 시도하시길 바랍니다. VRAM이 부족한 경우 CUDA Out Of Memory 오류의 원인이 될 수 있습니다.      

```bash
python3 -m jinju_bot.train --no-use-lora --learning-rate 2e-5
```


