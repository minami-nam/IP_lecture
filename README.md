# 🚀 Intro
안녕하세요, 현재 홍익대학교 전자전기공학부 소속으로 휴학 중인 남기화입니다.
휴학 기간 동안 진행하고 있는 디지털/아날로그 회로 설계 프로젝트, 인공지능 관련 프로젝트들을 포트폴리오화 시켜야 할 필요성을 느끼고, 해당 Repository를 열게 되었습니다.
해당 README에서는 각 프로젝트들의 간단한 설명과, 현재 진행하고 있거나 진행 예정인 프로젝트들에 대해 이야기하려 합니다.
---
# 🛠️ Goals
디지털/아날로그 회로 설계 및 인공지능 분야에 흥미를 가지고 있어, 꾸준히 해당 분야들에 대한 학습을 진행하고 있습니다.
디지털 회로 설계의 경우, 독학으로 진행하다 학습 속도 및 이해도에 대해 한계를 느껴 현재 삼코치님의 디지털 회로 설계 유료 강의를 수강하고 있습니다. 따라서 Verilog Code들은 대부분 해당 강의에서 나온 과제에 대한 Code가 많습니다.
인공지능 분야의 경우, 컴퓨터 비전 및 LLM 분야에 관심을 두고 있으며, LLM 모델을 사용하여 AI Agent를 만드는 것까지가 현재 목표입니다. 

---

## 💎 대표 Project 요약 설명 

### 1. SDR DRAM Controller Design

**Key Challenge**: Cell과 컨트롤러 사이의 Timing Issue로 인해 시뮬레이션에서 정상적으로 값을 읽어오지 못하는 상황이 발생했었습니다.
**Solution**: 컨트롤러의 Clock을 Cell 대비 1-clk 늦춰 설계하여 타이밍 정합성을 확보하고, `inout` 포트의 주도권을 고려하여 `Hi-z` 처리를 통해 데이터 충돌을 방지하였습니다.
**Growth**: 하나의 Sequential Logic에 여러 데이터를 처리하던 습관을 버리고, 각 레지스터별 역할에 따라 독립적인 `always` 구문을 구성하여 가독성과 디버깅 편리성을 높이는 방법을 학습하였습니다.

해당 프로젝트의 경우에는 Verilog 특성 상 CLK의 상승/하강 edge 모두를 검출하는 방법을 쓰지 않았고, 임시로 Positive Edge만 검출하는 방법을 써 해당 Module을 설계하였습니다.

### 2. High-Performance SRAM Wrapper


**Architecture**: Registered Output `q`를 추가하여 Glitch에 Robust하고 고속 동작에 최적화된 아키텍처를 설계했습니다.
**Optimization**: FPGA 내부 전용 자원(BRAM)의 정상적인 합성을 유도하기 위해, Inference를 방해하는 요소를 제거하여 LUT가 아닌 BRAM으로 정확히 합성됨을 확인하였습니다.
**Validation**: Vivado Manual(UG905)을 바탕으로 OOC(Out-of-Context) 환경을 구축하여 실제 보드 없이도 정확한 Static Timing Analysis를 수행했습니다.
**Result**: WNS 1.516ns, WHS 0.118ns의 Positive Slack을 확보하여 안정적인 타이밍 마진 결과를 확보했습니다.

해당 프로젝트의 경우 Implementation 과정까지 진행하였고, OOC 환경을 구축하는 과정에서 .xdc 파일 작성 방법과 같이 3학년 학부 단계에서는 배우지 않은 것들에 대해 학습하였습니다.

### 3. CRC-16 Module Design


**Design**: CRC-16-CCITT 알고리즘을 분석하여 Shift Register와 XOR Gate 기반의 하드웨어 로직으로 직접 구현하였습니다.
**Insight**: Linting Schematic 분석 중 State 레지스터에서 발생한 Latch를 발견하고 이를 분석하여 합성 전 잠재적 결함을 파악하는 과정을 경험했습니다.
**Efficiency**: `wait` 함수 등 테스트벤치 기법을 고도화하여 기존보다 디버깅 용이성을 높이고 설계 완성 시간을 단축하였습니다.

해당 프로젝트의 경우, Linting 과정에서 발생한 Latch들을 발견하고, 의도되지 않게 설계된 Latch는 조합/순차 회로에서 모든 경우에 대하여 정확한 상태를 작성하지 않은 것이 주 원인이라는 것을 학습했습니다.

---

## 📚 현재 학습 / 경험 중인 것들

| Category | Skills & Tools |
| :--- | :--- |
| **Languages** | Verilog, SystemVerilog, Python|
| **Hardware Tools** | Vivado, Quartus, Cadence Virtuoso|
| **AI & Software** | Langchain, PydanticAI, Pytorch 등 |
| **Infrastructure** | Proxmox를 통한 개발 서버 환경 조성, CLI 환경에서 Ubuntu 사용 가능 등|

---

