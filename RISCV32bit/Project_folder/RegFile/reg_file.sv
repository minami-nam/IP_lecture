`define SIM
module reg_file(
    input [4:0] i_addr1,
    input [4:0] i_addr2,
    input [4:0] i_addr3,    // Write
    input clk,
    input WE,
    input [31:0] i_wd1,

    
    output reg [31:0] o_rd1,
    output reg [31:0] o_rd2
);
    reg [31:0] register[0:31];
    
    // WE 신호가 들어올 때 동작 (Timing은 Control Module에서 작성하기)
    always @(posedge clk) begin
        if (WE) register[i_addr3] <= i_wd1; 
    end

    // 정상적인 Read
    always @(*) begin
        o_rd1 = register[i_addr1];
        o_rd2 = register[i_addr2];
    end
    
    `ifdef SIM 
        initial begin
            o_rd1 = 0;
            o_rd2 = 0;
            for (int j=0; j<32; j++) begin
                register[j] = 0;
            end
        end
    `endif

endmodule


module reg_id
(   // Sequential Logic으로 설계
    // Data 부분
    input [31:0] PCD,
    input [4:0] Rs1D,
    input [4:0] Rs2D,
    input [4:0] RdD,
    input [31:0]ImmExtD,


    // Control 부분
    input RegWriteD,
    input [1:0] ResultSrcD,
    input MemWriteD,
    input MemReadD,
    input JumpD,
    input BranchD,
    input [3:0] ALUControlD,
    input ALUSrcD,
    input   ignoreSrcAE_D,
    input      PC_SrcAE_D, 
    input [2:0] LS_opcodeD,

    

    // 기타
    input rstn,
    input clk,

    // Comb logic으로 설계 (이미 Register File에서 reg에 대해 Delay가 발생하기 때문에.)
    input [31:0] RD1,
    input [31:0] RD2,
    input [31:0] PCPlus4D,
    output reg [31:0] RD1E,
    output reg [31:0] RD2E,


    // Sequential logic으로 설계 (Register File을 거치지 않는 경우)
    // Data 부분
    output reg [31:0] PCE,
    output reg [4:0] Rs1E,
    output reg [4:0] Rs2E,
    output reg [4:0] RdE,
    output reg [31:0]ImmExtE,

    // Control 부분
    output reg RegWriteE,
    output reg [1:0] ResultSrcE,
    output reg MemWriteE,
    output reg JumpE,
    output reg BranchE,
    output reg [3:0] ALUControlE,
    output reg ALUSrcE,
    output reg [31:0] PCPlus4E,
    output reg   MemReadE,
    output reg  [2:0] LS_opcodeE,
    output reg   ignoreSrcAE_E,
    output reg      PC_SrcAE_E  
);
    // Sequential Logic 출력 관리 
    always @(posedge clk) begin

        if (!rstn) begin
            // Control 부분
            RegWriteE<=0;
            ResultSrcE<=0;
            MemWriteE<=0;
            JumpE<=0;
            BranchE<=0;
            ALUControlE<=0;
            ALUSrcE<=0;
            MemReadE<=0;
            LS_opcodeE<=0;
            ignoreSrcAE_E <= 0;
            PC_SrcAE_E <= 0;
        end
        else begin
            // Data 부분
            PCE<=PCD;
            Rs1E<=Rs1D;
            Rs2E<=Rs2D;
            RdE<=RdD;
            ImmExtE<=ImmExtD;
            PCPlus4E <= PCPlus4D;

            // Control 부분
            RegWriteE<=RegWriteD;
            ResultSrcE<=ResultSrcD;
            MemWriteE<=MemWriteD;
            JumpE<=JumpD;
            BranchE<=BranchD;
            ALUControlE<=ALUControlD;
            ALUSrcE<=ALUSrcD;
            // ImmSrcE<=ImmSrcD;
            MemReadE<=MemReadD;
            LS_opcodeE<=LS_opcodeD;
            ignoreSrcAE_E <= ignoreSrcAE_D;
            PC_SrcAE_E <= PC_SrcAE_D;
        end
        
    end
    // 수정. RISCV에서 출력은 combinational Logic 혹은 assign 구문으로 처리함.
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            RD1E <= 0;
            RD2E <= 0;
        end
        else begin
            RD1E <= RD1;
            RD2E <= RD2;
        end
    end


    `ifdef SIM
        initial begin
            // Combinational Logic으로 설계 
            RD1E=0;
            RD2E=0;

            // Sequential Logic으로 설계 (Register File을 거치지 않는 경우)
            // Data 부분
            PCE=0;
            Rs1E=0;
            Rs2E=0;
            RdE=0;
            ImmExtE=0;
            PCPlus4E = 0;

            // Control 부분
            RegWriteE=0;
            ResultSrcE=0;
            MemWriteE=0;
            JumpE=0;
            BranchE=0;
            ALUControlE=0;
            ALUSrcE=0;
            // ImmSrcE=0;   
            MemReadE=0;
            LS_opcodeE=0;
            ignoreSrcAE_E=0;
            PC_SrcAE_E=0;   
        end
    `endif

endmodule