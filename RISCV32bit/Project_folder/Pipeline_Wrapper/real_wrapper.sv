module real_wrapper(
    // inst 입력을 위한 regfile_FORCE 입력 추가
    input clk,
    input inst_i_req,
    input regfile_FORCEWE,
    input [4:0] regfile_FORCEWADDR,
    input [31:0] regfile_FORCEWDATA,
    input [31:0] instmem_FORCEWINST,
    input [31:0] instmem_FORCEWADDR,

    input stage_FORCERESET_n,
    
    // MEM 단에서 출력되는 결과 체크
    output wire [31:0] ResultW,


    // Jump 및 Branch 여부는 확인할 수 있게 출력
    output Jump,
    output Branch,

    // Feed Forward가 이루어지는지 확인하기
    output [1:0] ForwardAE_out,
    output [1:0] ForwardBE_out,

    // 명령이 Imm을 사용하는 경우 표기
    output is_imm,

    // 명령이 PC를 사용하는 경우 표기
    output is_using_pc,

    // Hazard가 탐지되었을 경우 표기
    output is_hazard,

    // ResultW 단에서 어떤 데이터가 출력될지 확인하기
    output [1:0] which_data    
);

    wire filtered_clk;
    BUFG clk_bufg_inst (
        .I(clk),
        .O(filtered_clk)
    );

    sc_riscv_wrapper dut(// 클럭만 버퍼를 통과한 신호로 연결
    // 클럭만 버퍼를 통과한 신호로 연결
        .clk(filtered_clk),

        // 나머지 모든 포트는 동일한 이름으로 매핑 (Named Port Mapping)
        .inst_i_req(inst_i_req),
        .regfile_FORCEWE(regfile_FORCEWE),
        .regfile_FORCEWADDR(regfile_FORCEWADDR),
        .regfile_FORCEWDATA(regfile_FORCEWDATA),
        .instmem_FORCEWINST(instmem_FORCEWINST),
        .instmem_FORCEWADDR(instmem_FORCEWADDR),
        .stage_FORCERESET_n(stage_FORCERESET_n),
        
        .ResultW(ResultW),
        .Jump(Jump),
        .Branch(Branch),
        .ForwardAE_out(ForwardAE_out),
        .ForwardBE_out(ForwardBE_out),
        .is_imm(is_imm),
        .is_using_pc(is_using_pc),
        .is_hazard(is_hazard),
        .which_data(which_data)
    );



endmodule