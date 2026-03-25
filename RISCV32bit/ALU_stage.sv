`define SIM
module ALU_stage(
    // input data
    input [31:0] RD1E,
    input [31:0] RD2E,

    input [31:0] PCE,
    input [4:0] Rs1E,
    input [4:0] Rs2E,
    input [4:0] RdE,
    input [24:0] ImmExtE,
    input [31:0] PCPlus4E,
    
    // Need Muxing
    input [31:0] ResultW,

    // input ctl
    input RegWriteE,
    input [1:0] ResultSrcE,
    input MemWriteE,
    input [2:0] ALUControlE,
    input ALUSrcE,

    // output ctl
    output reg RegWriteM,
    output reg [1:0] ResultSrcM,
    output reg MemWriteM,

    // output data
    output reg [31:0] ALUResultM,
    output reg [4:0] RdM,
    output reg [31:0] PCPlus4M,
    output reg [31:0] WriteDataM
);

endmodule


module ALU(
    input [31:0] SrcAE,
    input [31:0] SrcBE,
    input [2:0] ALUControlE,

    output reg [31:0] ALUResult,
    output reg ZeroE
);
    localparam sADD = 1;
    localparam sSUB = 2;
    localparam sMUL = 3;
    localparam sDIV = 4;
    localparam sINC = 5;
    localparam sDEC = 6;
    localparam sNEG = 7;
    wire [31:0] ADD, SUB, MUL, DIV, INC, DEC, NEG;

    assign ADD = SrcAE + SrcBE;
    assign SUB = SrcAE - SrcBE;
    assign MUL = SrcAE * SrcBE;
    assign DIV = SrcAE / SrcBE;
    assign INC = SrcAE + 1;
    assign DEC = SrcAE - 1;
    assign NEG = ~SrcAE + 1;

    
    // Case 구문으로 입력에 맞게 선택 후 출력함.
    always @(*) begin
        case(ALUControlE)
            default : ALUResult = 0;
            sADD : ALUResult = ADD;
            sSUB : ALUResult = SUB;
            sMUL : ALUResult = MUL;
            sDIV : ALUResult = DIV;
            sINC : ALUResult = INC;
            sDEC : ALUResult = DEC;
            sNEG : ALUResult = NEG;
        endcase

        if (ALUResult==0) ZeroE = 1;
        else ZeroE = 0;
    end


    `ifdef SIM
        initial begin
            ALUResult = 0;
            ZeroE = 0;
        end
    `endif

endmodule


