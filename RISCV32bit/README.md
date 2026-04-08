## Readme : RISC-V 기반 32Bit CPU 설계 정리 문서
32Bit CPU의 경우, 장기적으로 프로젝트가 길어질 것 같아 미리 문서의 틀을 어느 정도 잡아가면서 프로젝트를 진행하려 한다. 

---
### 프로젝트 진행 중 학습한 내용 요약
> **SystemVerilog 공통**
 - typedef enum, typedef struct packed/unpacked 에 대해 학습함. typedef enum의 경우에는 enum 뒤에 type와 length를 선언하고, {} 안에 `define 처럼 특정 값에 대한 출력 문자열 등을 할당시킬 수 있다.     
 이는 나중에 Testbench를 구성할 때 직접 출력 값을 입력할 필요없이 출력 값에 대응하는 문자열을 입력해줘도 같은 동작을 수행하기 때문에 가독성 부분에서 유용하다.     
 typedef struct의 경우에는 packed와 unpacked로 구분할 수 있으며, C에서 typedef struct를 사용하듯 우리가 직접 구조체의 속성을 정의할 수 있다. {} 안에 type, bit length, 신호 이름 구성으로 정의를 내려 사용할 수 있으며, 해당 신호들을 가진 구조체를 생성함으로써 일일히 reg나 wire를 회로 code 내부에 선언할 필요 없이 그냥 해당 type를 가진 변수를 선언하면 된다.      
 또한, packed와 unpacked는 엄격히 구분되니, 반드시 구분해서 작성할 필요가 있다.    
 - package - endpackage 문법을 학습함. package를 만들어 내부에 사용자 지정 struct나 task, function, enum 등을 넣을 수 있으며, 사용하고자 하는 회로 Code 내부에서 `import package_name 으로 불러올 수 있다. 또한, *::;을 package_name 뒤에 붙여 package_name 내부의 모든 요소들을 불러올 수 있다.       
 - .vh 파일 사용법을 학습함. .vh 파일은 Verilog Header로써 기능하며, 해당 파일 내부에는 ifndef - endif 구문이나 define 구문을 사용하여 특정 변수에 특정 값을 할당할 수 있으며, 또한 localparam 등을 사용하여 특정 값을 여러 변수에 사용하게 만들 수도 있다. 이는 특정 변수를 여러 Code에서 사용해야 하는 상황이나, 가독성을 향상시키는데 도움이 된다.             
 사용하고자 하는 회로 Code 내부에서 `include "dir/file_name.vh" 로 불러올 수 있으며, .vh 파일 내부에 있는 Parameter들을 사용하려고 할 때는 Parameter 앞에 반드시 ``` (markdown 환경에서 작성중이라 3개를 사용했으나, 1개만 붙여야 함)을 붙여줘야 정상적으로 Parameter로써 기능한다.      
> **SystemVerilog Testbench**
 - task - endtask 문법을 학습함. task는 반복 작업을 미리 function처럼 정의하여 (Python의 def처럼) 사용할 수 있게 도와주는 Code이다. Verilog에서 function과 task의 차이점이라면 function은 진짜 이름값대로 값 반환이 가능하며, 함수명에 할당 시 출력을 반환 가능하다. 근데 task는 굳이 출력을 반환할 필요가 없이 input으로만 구성해도 문제가 없으며, Code 반복을 줄이는 것에 더 큰 중점을 두고 있다.        
 주의할 점은, task 내부에는 clk 신호를 따로 넣어주지 않는 이상 clk를 감지할 방법이 없기에 @(posedge clk); 과 같은 Code 사용이 불가능하다는 것이다.      
 추가적으로, for 구문 등을 사용해서 여러번 task를 불러올 경우, task automatic 구문을 사용하면 자동 변수 할당을 통해 이후 변수 사용에서 혼란을 방지할 수 있다.
 - Testbench에서 각각 module의 입력과 출력을 선언해놓은 typedef enum type의 변수를 생성한 후, module의 입력과 출력을 그 변수와 연결시켜주면, 이후 simulation에서 변수명.port_name의 값을 enum 내부에서 정의한 문자열로 출력할 수 있다.    
 - foreach - end 문법을 학습함. foreach는 for 구문처럼 (int i;...) 로 정의하는 것이 아니라, 변수명과 iterator로 선언할 수 있다. 이는 우리가 typedef로 선언한 변수들을 반복적으로 실행시키는데 있어 for 보다 간결하게 Code를 작성할 수 있다는 장점이 있다.
 - class - endclass 문법을 학습함. class는 내부에 여러 개의 변수를 담고, function 및 constraint까지 동시에 포함할 수 있는, 파이썬의 class와 비슷하다고 생각하면 된다. class는 Non-Synthesizable하기에 chip design 과정에서는 사용할 수 없다. rand bit와 같은 변수 선언과 .randomize()의 사용으로 변수가 으로 random한 값을 참조하게 할 수 있다.         
 - constraint 사용법을 학습함. constraint의 경우에는 규칙이라고 생각하면 편하며, class과 같이 사용하면 매우 편리하다. 여러가지 method (inside, dist 등)가 존재하여 규칙을 생성하는데 도움이 된다. 특이한 점은 begin - end 구문이 아닌 {} 구문을 사용하여 규칙을 정의한다는 점이다.

> **설계 관련**
 - clock gating을 진행할 때, 예를 들어 assign local_clk = en ? clk : 0; 으로 정의할 경우 Slack 등으로 인해 clk를 정상적으로 받지 못하는 상황이 발생할 수 있다. 이를 해결하기 위해서는 always_comb 구문을 이용하여 if (en) local_clk = clk; 와 같은 방식으로 gating을 진행시켜줘야 clk를 정상적으로 gating할 수 있다. 

> **Synthesis/Implementation 관련**
 - Synthesis/Implementation을 진행할 때, Settings 항목에서 Vivado의 합성 규칙을 지정해줄 수 있다.         
 - Implementation을 통한 Timing Analysis / Power Consumption 측정 시 wrapper를 이용하여 내부 module에게 BUFG로 정제된 CLK 신호를 받을 수 있게 만들어야 한다. (즉, module과 clk 핀 직결 금지)      
 - OOC (out of context)를 사용할 경우, 반드시 Settings 항목에서 -mode out_of_context를 입력했는지 확인하고, .xdc 파일 또한 out_of_context 용도로 설정되었는지, get_ports 'port_name' 부분에서 port_name이 wrapper의 port_name과 일치하는지 확인해야 한다. 

---
### 개선/수정점 기록 :
> **수정점 관련 내역**
 - U-Type LUI 명령어 지원 추가. (ignoreSrcAE wire 추가). 해당 명령어는 inst[31:12], 12'b0 값을 그대로 Rd로 보내는 명령임.       
 해당 명령은 ignoreSrcAE I/O를 Control 단 및 ALU Stage 단에 추가하여 ALU Stage 내부에서 SrcAE의 값을 0으로 만들고, SrcBE의 값은 ImmExtE 값을 선택할 수 있게 mux로 구성함.   

> **개선점 관련 내역**
 - 원래 기존의 5 stage Pipeline에서는 ALU가 1개지만, 해당 Code에서는 산술 연산을 담당하는 ALU_arith와 논리 연산을 담당하는 ALU_logic를 나누어 배치하고, 기존의 ALUSrcE의 비트 수를 1bit 늘려 연산 별로 무슨 ALU를 사용할지 선택할 수 있게 구성함.     

> **한계점 관련 내역**
 - 원래는 32bit Mem Addr를 지원하기 때문에 Data Memory나 inst mem array가 엄청 커져야하지만, 문제는 이럴 경우 Vivado에서 Simulation 시 정상적으로 값을 R/W 할 수 없는 문제점이 발생하여 부득이하게 1024개로 조절하였다.       

---


