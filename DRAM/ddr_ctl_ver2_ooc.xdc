# 1. 클럭 정의 (이전과 동일, Wrapper의 클럭 포트 이름과 일치시킴)
create_clock -name clk_core -period 10.000 -waveform {0.000 5.000} [get_ports clk]

