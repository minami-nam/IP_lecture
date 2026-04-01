`define SIM
module reg_file(
    input [4:0] i_addr1,
    input [4:0] i_addr2,
    input [4:0] i_addr3,    // Write
    input clk_n,
    input WE,
    input [31:0] i_wd1,

    
    output reg [31:0] o_rd1,
    output reg [31:0] o_rd2
);
    reg [31:0] register[0:31];
    reg [4:0] i_addr_reg[0:2];
    
    // WE 신호가 들어올 때 동작 (Timing은 Control Module에서 작성하기)
    always @(negedge clk_n) begin
        i_addr_reg[0] <= i_addr3;
        for (int i=0; i<2; i++) begin
            i_addr_reg[i+1] <= i_addr_reg[i];
        end
        if (WE) register[i_addr_reg[2]] <= i_wd1; 
        else register[i_addr_reg[2]] <= register[i_addr_reg[2]];
    end

    // 정상적인 Read
    always @(negedge clk_n) begin
        o_rd1 <= register[i_addr1];
        o_rd2 <= register[i_addr2];
    end
    
    `ifdef SIM 
        initial begin
            o_rd1 = 0;
            o_rd2 = 0;
            for (int j=0; j<32; j++) begin
                register[j] = 0;
            end
            for (int h=0; h<3; h++) begin
                i_addr_reg[h] = 0;
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
    input [24:0]ImmExtD,


    // Control 부분
    input RegWriteD,
    input [1:0] ResultSrcD,
    input MemWriteD,
    input JumpD,
    input BranchD,
    input [2:0] ALUControlD,
    input ALUSrcD,
    input [1:0] ImmSrcD,

    // 기타
    input rstn,
    input clk,

    // Comb logic으로 설계 (이미 Register File에서 reg에 대해 Delay가 발생하기 때문에.)
    input [31:0] RD1,
    input [31:0] RD2,
    output reg [31:0] RD1E,
    output reg [31:0] RD2E,

    // Sequential logic으로 설계 (Register File을 거치지 않는 경우)
    // Data 부분
    output reg [31:0] PCE,
    output reg [4:0] Rs1E,
    output reg [4:0] Rs2E,
    output reg [4:0] RdE,
    output reg [24:0]ImmExtE,

    // Control 부분
    output reg RegWriteE,
    output reg [1:0] ResultSrcE,
    output reg MemWriteE,
    output reg JumpE,
    output reg BranchE,
    output reg [2:0] ALUControlE,
    output reg ALUSrcE,
    output reg [1:0] ImmSrcE
);
    // Sequential Logic 출력 관리 
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            // Data 부분
            PCE<=0;
            Rs1E<=0;
            Rs2E<=0;
            RdE<=0;
            ImmExtE<=0;

            // Control 부분
            RegWriteE<=0;
            ResultSrcE<=0;
            MemWriteE<=0;
            JumpE<=0;
            BranchE<=0;
            ALUControlE<=0;
            ALUSrcE<=0;
            ImmSrcE<=0;
        end
        else begin
            // Data 부분
            PCE<=PCD;
            Rs1E<=Rs1D;
            Rs2E<=Rs2D;
            RdE<=RdD;
            ImmExtE<=ImmExtD;

            // Control 부분
            RegWriteE<=RegWriteD;
            ResultSrcE<=ResultSrcD;
            MemWriteE<=MemWriteD;
            JumpE<=JumpD;
            BranchE<=BranchD;
            ALUControlE<=ALUControlD;
            ALUSrcE<=ALUSrcD;
            ImmSrcE<=ImmSrcD;
        end
    end
    // Combinational Logic이 필요한 Data 출력 관련 (Regfile로 인한 Delay)
    always @(*) begin
        RD1E = RD1;
        RD2E = RD2;
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

            // Control 부분
            RegWriteE=0;
            ResultSrcE=0;
            MemWriteE=0;
            JumpE=0;
            BranchE=0;
            ALUControlE=0;
            ALUSrcE=0;
            ImmSrcE=0;       
        end
    `endif

endmodule