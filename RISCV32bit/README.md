## Readme : RISC-V 기반 32Bit CPU 설계 정리 문서
32Bit CPU의 경우, 장기적으로 프로젝트가 길어질 것 같아 미리 문서의 틀을 어느 정도 잡아가면서 프로젝트를 진행하려 한다. 일단 내가 CPU를 설계하면서 고려해야 할 항목들은 다음과 같다.

### 1. Core의 개수
### 2. Pipelining 및 OoO 방법 (Scoreboard)
### 3. (Arithmetic, Bitwise, Data Movement, Graphics) 지원 명령어 및 최적화 방법
### 4. Data / Structure Hazard 처리 + Hamming Logic?

따라서, 이번 HW 보고서를 작성할 때 상기한 4가지 부분에 대해 내가 어떠한 방법으로 설계를 진행하였는지 작성할 예정이고, Module Hierarchy 또한 작성하여 계층 별로 CPU를 디자인 할 계획이다.



