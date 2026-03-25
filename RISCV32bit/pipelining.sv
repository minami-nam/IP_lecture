// 노이만 구조의 inst/data input을 동시에 넣을 수 없다는 한계를 해결하기 위하여, 
// 하버드 구조를 사용하여 inst/data를 ctl unit과 둘 다 다른 bus를 통하여 통신하게 구성해놓음

// Pipelining 구조 설계 시 CPU 내부의 Register에 전부 계산 결과를 뿌림 (즉각적인 update를 일어날 수 있게 만들어줌.)
// Control Hazard는 Branch (Jump) 처럼 갑자기 pc가 확 늘어나는 경우, 버블을 사용하여 
// pc+4 != next_pc 인 경우 Hazard Detection 유닛에 flush 명령을 내림. 그럼 중간을 Bubble로 채워준다 이말임.
// 당연히 효율적인 flush를 위해서는 단계별로 뭔가 추가를 해야겠죠? 그걸 작성하면 된다는 것.
