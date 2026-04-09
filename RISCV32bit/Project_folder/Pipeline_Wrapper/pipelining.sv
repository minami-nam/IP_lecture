`define SIM
// 해당 include 경로는 수정 가능. 이후 프로젝트 수정 시 변경할 것.
`include "definition.vh"

module sc_riscv_wrapper(
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
    // instruction mem + program counter 부분
    wire PCSrcE;

    wire [31:0] PCF, PCD;
    wire [31:0] PCPlus4E, PCPlus4D, PCPlus4F;
    wire [31:0] mux_pc;
    wire [31:0] PCTargetE;

    assign PCPlus4F = PCF + 4;
    assign mux_pc = PCSrcE ? PCTargetE : PCPlus4F; 
    assign is_using_pc = PCSrcE;
    wire StallIF_n, StallID_n, FlushD, FlushE;

    wire flush_selD, flush_selE;

    wire instmem_en_real;
    assign instmem_en_real = StallIF_n | inst_i_req;
    assign flush_selD = !FlushD & stage_FORCERESET_n;
    assign flush_selE = !FlushE & stage_FORCERESET_n;

    program_counter pc(
        .in(mux_pc),
        .rstn(flush_selD),
        .clk(clk),
        .en(instmem_en_real),

        .o_addr(PCF)
    );


    wire [31:0] instrD;

    wire [31:0] sel_PCF;
    assign sel_PCF = inst_i_req ? instmem_FORCEWADDR : PCF;
    inst_mem instmem(
        .addr(sel_PCF),
        .PCPlus4F(PCPlus4F),
        .clk(clk),
        .rstn(flush_selD),
        .en(instmem_en_real),
        .i_req(inst_i_req),
        .i_inst(instmem_FORCEWINST),

        .inst(instrD),
        // .o_pc(PCPlus4F),
        .PCD(PCD),
        .PCPlus4D(PCPlus4D)
    
    );




    wire [4:0] A1, A2, A3, Rs1D, Rs2D, RdD, RdW;
    wire [6:0] op;
    wire [2:0] funct3;
    wire [6:0] funct7;

    wire RegWriteM, RegWriteW;
    wire [31:0] RD1, RD2;
    
    assign {funct7, Rs2D, Rs1D, funct3, RdD, op} = instrD;   // 31:25 24:20 19:15 11:7 6:0  
    assign A1 = Rs1D;
    assign A2 = Rs2D;
    assign A3 = regfile_FORCEWE ? regfile_FORCEWADDR : RdW;

    wire we3;
    wire [31:0] WData;
    assign WData = regfile_FORCEWE ? regfile_FORCEWDATA : ResultW;
    assign we3 = regfile_FORCEWE ? 1'b1 : RegWriteW;


    
    
    // Extend module

    wire [2:0] ImmSrcD;
    wire [31:0] ImmExtD;


    inst_extend instext(
        .inst(instrD),
        .ImmSrcD(ImmSrcD), 
        .ImmExtD(ImmExtD)  
    );

    // Register File 부분
    reg_file reg_file(
        .i_addr1(A1),    // loc 1
        .i_addr2(A2),    // loc 2
        .i_addr3(A3),    // Write addr
        .clk(clk),
        .WE(we3),
        .i_wd1(WData),

                
        .o_rd1(RD1),
        .o_rd2(RD2)
    );

    wire RegWriteD;
    wire [1:0] ResultSrcD;
    wire MemWriteD;
    wire JumpD;
    wire BranchD;
    wire [3:0] ALUControlD;
    wire ALUSrcD;

    wire [31:0] PCE, ImmExtE, RD1E, RD2E;
    wire [4:0] Rs1E, Rs2E, RdE;

    wire RegWriteE;
    wire [1:0] ResultSrcE;
    wire MemWriteE;
    wire JumpE;
    wire BranchE;
    wire [3:0] ALUControlE;
    wire ALUSrcE;
    wire [2:0] ImmSrcE;

    // Jump 및 Branch는 E 단계에서 결정함
    assign Jump = JumpE;
    assign Branch = BranchE;

    wire ignoreSrcAE_D, ignoreSrcAE_E;
    wire PC_SrcAE_D, PC_SrcAE_E;
    wire [2:0] LS_opcodeD, LS_opcodeE, LS_opcodeM;
    wire MemReadD, MemReadE, MemReadM;
    

    reg_id reg_id(
        // Data 부분
        .PCD(PCD),
        .Rs1D(Rs1D),
        .Rs2D(Rs2D),
        .RdD(RdD),
        .ImmExtD(ImmExtD),
        // Control 부분
        .RegWriteD(RegWriteD),
        .ResultSrcD(ResultSrcD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .BranchD(BranchD),
        .ALUControlD(ALUControlD),
        .ALUSrcD(ALUSrcD),
        .PCPlus4D(PCPlus4D),
        .PC_SrcAE_D(PC_SrcAE_D),
        .ignoreSrcAE_D(ignoreSrcAE_D),
        .MemReadD(MemReadD),
        .LS_opcodeD(LS_opcodeD),
        // 기타
        .rstn(flush_selE),
        .clk(clk),
        // Comb logic으로 설계 (이미 Register File에서 reg에 대해 Delay가 발생하기 때문에.)
        .RD1(RD1),
        .RD2(RD2),
        .RD1E(RD1E),
        .RD2E(RD2E),
        // Sequential logic으로 설계 (Register File을 거치지 않는 경우)
        // Data 부분
        .PCE(PCE),
        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RdE(RdE),
        .ImmExtE(ImmExtE),
        // Control 부분
        .RegWriteE(RegWriteE),
        .ResultSrcE(ResultSrcE),
        .MemWriteE(MemWriteE),
        .JumpE(JumpE),
        .BranchE(BranchE),
        .ALUControlE(ALUControlE),
        .ALUSrcE(ALUSrcE),
        .PCPlus4E(PCPlus4E),
        .ignoreSrcAE_E(ignoreSrcAE_E),
        .PC_SrcAE_E(PC_SrcAE_E),
        .MemReadE(MemReadE),
        .LS_opcodeE(LS_opcodeE)
    );




    // Controller
    control_unit ctlunit(
        .op(op),
        .funct3(funct3),
        .funct7(funct7),

        .RegWriteD(RegWriteD),
        .ResultSrcD(ResultSrcD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .ignoreSrcAE_D(ignoreSrcAE_D),
        .PC_SrcAE_D(PC_SrcAE_D),
        .BranchD(BranchD),
        .ALUControlD(ALUControlD),
        .ALUSrcD(ALUSrcD),
        .ImmSrcD(ImmSrcD),
        .LS_opcodeD(LS_opcodeD),
        .MemReadD(MemReadD)
    );


    // hazard detection

    wire [4:0] RdM;
    wire ZeroE;
    wire pc_en;
    assign PCSrcE = pc_en;
    hazard_detection hazard_detection_mdl(
        .Rs1D(Rs1D),
        .Rs2D(Rs2D),

        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RdE(RdE),
        .ZeroE(ZeroE),
        .JumpE(JumpE),
        .BranchE(BranchE),
        .ResultSrcE(ResultSrcE), 

        .RdM(RdM),
        .RdW(RdW),
        .RegWriteM(RegWriteM),
        .RegWriteW(RegWriteW),

        .StallIF_n(StallIF_n),
        .StallID_n(StallID_n),
        .FlushD(FlushD),
        .FlushE(FlushE),
        .ForwardAE(ForwardAE_out),
        .ForwardBE(ForwardBE_out),
        .pc_en(pc_en)       
    );

    // output ctl
    // wire RegWriteM;
    wire [1:0] ResultSrcM;
    wire MemWriteM;


    // output data
    wire [31:0] ALUResultM;
    // wire [4:0] RdM;
    wire [31:0] PCPlus4M;

    wire [31:0] WriteDataM;
    ALU_stage multi_alu_stage(
        // input data
        .RD1E(RD1E),
        .RD2E(RD2E),
        .PCE(PCE),
        .RdE(RdE),
        .ImmExtE(ImmExtE),
        .PCPlus4E(PCPlus4E),
        .JumpE(JumpE),
    
        // Need Muxing
        .ResultW(ResultW),
        .ForwardAE(ForwardAE_out),
        .ForwardBE(ForwardBE_out),

        // input ctl
        .RegWriteE(RegWriteE),
        .ResultSrcE(ResultSrcE),
        .MemWriteE(MemWriteE),
        .ALUControlE(ALUControlE),
        .ALUSrcE(ALUSrcE),
        .ignoreSrcAE_E(ignoreSrcAE_E),
        .PC_SrcAE_E(PC_SrcAE_E),
        .clk(clk), 
        .rstn(stage_FORCERESET_n),
        .MemReadE(MemReadE),
        .LS_opcodeE(LS_opcodeE),

        // output ctl
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .MemWriteM(MemWriteM),
        .ZeroE(ZeroE),

        // output data
        .ALUResultM(ALUResultM),
        .RdM(RdM),
        .PCPlus4M(PCPlus4M),
        .PCTargetE(PCTargetE),
        .WriteDataM(WriteDataM),
        .MemReadM(MemReadM),
        .LS_opcodeM(LS_opcodeM)        
    );

    // Memory Stage
    mem_wrapper mem_stage(
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .MemWriteM(MemWriteM),
        .RdM(RdM),
        .PCPlus4M(PCPlus4M),
        .WriteDataM(WriteDataM),
        .ALUResultM(ALUResultM),
        .MemReadM(MemReadM),
        .LS_opcodeM(LS_opcodeM),  

        .clk(clk), 
        .rstn(stage_FORCERESET_n),

            
        .RegWriteW(RegWriteW),
        .ResultW(ResultW),
        .RdW(RdW)      
    );

    // WB stage는 MEM에 통합.
    assign is_imm = (op==`R_type) ? 0 : 1;
    assign is_hazard = !StallIF_n | !StallID_n | FlushD | FlushE | (ForwardAE_out!=2'b00) | (ForwardBE_out!=2'b00) | pc_en;

    assign which_data = mem_stage.ResultSrcW;




endmodule