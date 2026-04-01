`define SIM
module ALU_stage(
    // input data
    input [31:0] RD1E,
    input [31:0] RD2E,

    input [31:0] PCE,
    // input [4:0] Rs1E,
    // input [4:0] Rs2E,
    // input [4:0] RdE,
    input [24:0] ImmExtE,
    input [31:0] PCPlus4E,
    
    // Need Muxing
    input [31:0] ResultW,
    input [1:0] ForwardAE,
    input [1:0] ForwardBE,


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
    output ZeroE,
    

    // output data
    output reg [31:0] ALUResultM,
    output reg [4:0] RdM,
    output reg [31:0] PCPlus4M,
    output [31:0] PCTargetE,
    output reg [31:0] WriteDataM
);  
    wire [31:0] SrcAE, SrcBE, WriteDataE;

    // Muxing 관련
    in3_mux mx1(
        .data1(RD1E),
        .data2(ResultW),
        .data3(ALUResultM),
        .sel(ForwardAE),

        .out(SrcAE)
    );

    in3_mux mx2(
        .data1(RD2E),
        .data2(ResultW),
        .data3(ALUResultM),
        .sel(ForwardBE),

        .out(WriteDataE)
    );

    assign SrcBE = (ALUSrcE==1) ? ImmExtE : WriteDataE;


    // ALU 호출 관련
    wire [31:0] wire_ALUresult;

    ALU alu(
        .SrcAE(SrcAE),
        .SrcBE(SrcBE),
        .ALUControlE(ALUControlE),

        .ALUResult(wire_ALUresult),
        .ZeroE(ZeroE)
    );


    // ALU Result 관련
    always @(posedge clk or negedge rstn) begin
        if (!rstn) ALUResultM <= 0;
        else ALUResultM <= wire_ALUresult; 
    end   


    // PC Plus 관련
    always @(posedge clk or negedge rstn) begin
        if (!rstn) PCPlus4M <= 0;
        else PCPlus4M <= PCPlus4E; 
    end

    // PC Target 관련 
    assign PCTargetE = PCE + ImmExtE;

    // WriteDataM 관련
    always @(posedge clk or negedge rstn) begin
        if (!rstn) WriteDataM <= 0;
        else WriteDataM <= WriteDataE; 
    end

    // RdM 관련
    always @(posedge clk or negedge rstn) begin
        if (!rstn) RdM <= 0;
        else RdM <= RdE;     
    end

    // RegWriteM
    always @(posedge clk) begin
        RegWriteM <= RegWriteE;
    end

    // ResultSrcM
    always @(posedge clk) begin
        ResultSrcM <= ResultSrcE;
    end

    // MemWriteE
    always @(posedge clk) begin
        MemWriteM <= MemWriteE;
    end   


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

module in3_mux(
    input [31:0] data1,
    input [31:0] data2,
    input [31:0] data3,
    input [1:0] sel,

    output [31:0] out
);

    reg [31:0] mem;

    always @(*) begin
        case(sel)
            0 : out = data1;
            1 : out = data2;
            2 : out = data3;
            default : out = 0;
        endcase
    end

    `ifdef SIM 
        initial mem = 0;
    `endif
endmodule

