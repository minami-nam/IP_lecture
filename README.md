# 🚀 Intro
### 안녕하세요, 해당 repository는 개인적인 학습 기록 용도로 사용 중입니다.      
### 지속적으로 업데이트 중이며, Verilog 이외에도 Python과 같은 타 분야 프로젝트 결과물 또한 게시할 예정입니다.

---

## 🛠️ Goals
- **Digital/Analog Circuit Design**: 독학의 한계를 넘어 실무 수준의 설계 역량을 갖추기 위해 심화 학습 중입니다.
- **AI & LLM**: Computer Vision과 LLM을 결합하여 실무에 도움을 주는 Agent 제작을 목표로 합니다.

---

## 💎 대표 Project 요약

### 1. SDR DRAM Controller Design
> **"타이밍 정합성 확보와 모듈 독립성 강화"**

- **Key Challenge**
  - Cell과 컨트롤러 사이의 Timing Issue로 인한 데이터 로드 실패 발생.
- **Solution**
  - 컨트롤러 Clock을 Cell 대비 **1-clk Delay** 설계하여 타이밍 정합성 확보.
  - `inout` 포트 주도권 제어를 위한 `Hi-z` 처리로 데이터 충돌 방지.
- **Growth**
  - 각 레지스터별 역할에 따라 독립적인 `always` 구문을 구성하여 가독성과 디버깅 편의성 향상.
  - Positive Edge 검출 방식을 적용하여 모듈의 안정성 확보.

---

### 2. High-Performance SRAM Wrapper
> **"BRAM Inference 최적화 및 Static Timing Analysis 수행"**

- **Architecture**
  - Registered Output `q`를 추가하여 Glitch에 강하고 고속 동작에 최적화된 아키텍처 설계.
- **Optimization**
  - FPGA 내부 전용 자원(**BRAM**)의 합성을 방해하는 요소를 제거하여 효율적인 하드웨어 리소스 활용 확인.
- **Validation**
  - **Vivado OOC(Out-of-Context)** 환경 구축 및 `.xdc` 파일 작성을 통한 STA 수행.
- **Result**
  - **WNS: 1.516ns / WHS: 0.118ns**의 Positive Slack 확보로 안정적 동작 검증.

---

### 3. CRC-16 Module Design
> **"하드웨어 로직 구현 및 합성 전 잠재 결함 분석"**

- **Design**
  - CRC-16-CCITT 알고리즘을 분석하여 Shift Register와 XOR Gate 기반 하드웨어 로직 구현.
- **Insight**
  - Linting Schematic 분석 중 발생한 **Latch**의 원인이 불완전한 상태 정의(Condition)임을 파악하고 해결.
- **Efficiency**
  - `wait` 함수 등 테스트벤치 기법을 고도화하여 디버깅 용이성 확보 및 설계 시간 단축.

---

### 4. Image Enhancement using Gaussian Filter and CNN Model
> **"경량 Low-Light Image Enhancement를 위한 CNN 기반 Model 설계"**

| Before (원본 이미지) | After (모델 적용 후) |
| :---: | :---: |
| ![입력](/잡다한것/datasets/inference/1.png) | ![모델 출력](/잡다한것/saved_results/base_50_gaussian_with_gradloss/('1.png',).png)|

| Before (TV Loss 적용 전) | After (TV Loss 적용 후) |
| :---: | :---: |
| ![입력](/잡다한것/saved_results/base_50_gaussian_with_gradloss/('1.png',).png)|| ![tv 적용](/잡다한것/saved_results/base_50_gaussian_with_tvloss/('1.png',).png)|

| 전체적인 Model Diagram |
| :---: |
| ![diagram](/잡다한것/Enhancement_proj/diagram.png)|

- **Main Idea**
  - Gaussian Filter를 이용한 출력 이미지의 Texture Degradation 방지 및 자연스러운 Image Enhancement를 위한 CNN 기반 모델 고안.
- **Additional Idea**
  - RGB를 HSV로 변환하여 원본 이미지의 색은 보존하면서 Saturation 및 Value만 자연스럽게 조절.
  - Pixel 별 인접 Pixel 간 grad 값을 계산하여, Target Image의 그것과 비교하여 차이를 Loss로 설계함. 
  - 계단 현상 방지를 위한 Total Variation Loss를 설계하고, 이를 Tone Curve에 적용하여 자연스러운 색감을 출력할 수 있게 유도함.
  - SSIM의 특성 중 하나인 값이 작아질수록 Target과 유사한 이미지라는 특성을 이용하여, (1-SSIM)을 이용한 SSIM Loss 설계.

---

## 📚 Tech Stack & Skills

| 분류 | 기술 및 도구 |
| :--- | :--- |
| **Languages** | Verilog, SystemVerilog, Python |
| **Hardware Tools** | Vivado, Quartus, Cadence Virtuoso |
| **AI & Software** | Langchain, PydanticAI, PyTorch |
| **Infrastructure** | Proxmox, Ubuntu Server (CLI), Home Server 운영 |

---
