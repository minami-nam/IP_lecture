#create_clock -period 10.000 -name clk [get_ports clk]
## 기존 포트 정의와 함께 사용
#(* IO_BUFFER_TYPE = "none" *) input clk;


create_clock -period 10.000 -name clk_internal [get_pins clk_IBUF_BUFG_inst/O]