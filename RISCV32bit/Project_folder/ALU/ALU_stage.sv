`define SIM
module ALU_stage(
    // input data
    input [31:0] RD1E,
    input [31:0] RD2E,

    input [31:0] PCE,
    // input [4:0] Rs1E,
    // input [4:0] Rs2E,
    input [4:0] RdE,
    input [31:0] ImmExtE,
    input [31:0] PCPlus4E,
    
    // Need Muxing
    input [31:0] ResultW,
    input [1:0] ForwardAE,
    input [1:0] ForwardBE,
    input JumpE,
    // LS / U type 구현을 위해 추가.
    input ignoreSrcAE_E,
    input PC_SrcAE_E,
    input [2:0] LS_opcodeE,



    // input ctl
    input RegWriteE,
    input [1:0] ResultSrcE,
    input MemWriteE,
    input MemReadE,
    input [3:0] ALUControlE,
    input ALUSrcE,
    input clk, rstn,

    // output ctl
    output reg RegWriteM,
    output reg [1:0] ResultSrcM,
    output reg MemWriteM,
    output ZeroE,
    output reg [2:0] LS_opcodeM,
    output reg MemReadM,
    

    // output data
    output reg [31:0] ALUResultM,
    output reg [4:0] RdM,
    output reg [31:0] PCPlus4M,
    output      [31:0] PCTargetE,
    output reg [31:0] WriteDataM

);  
    wire [31:0] SrcAE, SrcBE, ori_SrcAE, WriteDataE;

    // Muxing 관련
    in3_mux mx1(
        .data1(RD1E),
        .data2(ResultW),
        .data3(ALUResultM),
        .sel(ForwardAE),

        .out(ori_SrcAE)
    );

    in3_mux mx2(
        .data1(RD2E),
        .data2(ResultW),
        .data3(ALUResultM),
        .sel(ForwardBE),

        .out(WriteDataE)
    );

    assign SrcAE = (PC_SrcAE_E) ? PCE : (ignoreSrcAE_E) ? 0 : ori_SrcAE;
    assign SrcBE = (ALUSrcE==1 | ignoreSrcAE_E | PC_SrcAE_E) ? ImmExtE : WriteDataE;


    // ALU 호출 및 ctl 관련
    wire [2:0] wire_ALUCtl_arith, wire_ALUCtl_logic;
    assign wire_ALUCtl_arith = ALUControlE[3] ? ALUControlE[2:0] : 0;
    assign wire_ALUCtl_logic = !ALUControlE[3] ? ALUControlE[2:0] : 0; 

    wire ZeroE_arith, ZeroE_logic;
    assign ZeroE = ALUControlE[3] ? ZeroE_arith : ZeroE_logic;

    wire [31:0] wire_ALUresult, wire_ALUresult_arith, wire_ALUresult_logic;
    assign wire_ALUresult = ALUControlE[3] ? wire_ALUresult_arith : wire_ALUresult_logic;

    ALU_Arithmetic alu_arith(
        .SrcAE(SrcAE),

        .SrcBE(SrcBE),
        .ALUControlE(wire_ALUCtl_arith),

        .ALUResult(wire_ALUresult_arith),
        .ZeroE(ZeroE_arith)
    );

    ALU_Logical alu_logic(
        .SrcAE(SrcAE),

        .SrcBE(SrcBE),
        .ALUControlE(wire_ALUCtl_logic),

        .ALUResult(wire_ALUresult_logic),
        .ZeroE(ZeroE_logic)
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
    assign PCTargetE =  (ALUSrcE & JumpE) ? wire_ALUresult : (PCE + ImmExtE);

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
    always @(posedge clk or negedge rstn) begin
        if (!rstn) RegWriteM <= 0;
        else RegWriteM <= RegWriteE;
    end

    // ResultSrcM
    always @(posedge clk or negedge rstn) begin
        if (!rstn) ResultSrcM <= 0;
        else ResultSrcM <= ResultSrcE;
    end

    // MemWriteE
    always @(posedge clk or negedge rstn) begin
        if (!rstn) MemWriteM <= 0;        
        else MemWriteM <= MemWriteE;
    end

    // MemReadE
    always @(posedge clk or negedge rstn) begin
        if (!rstn ) MemReadM<= 0;
        else MemReadM <= MemReadE;
    end

    // LS_opcodeE
    always @(posedge clk or negedge rstn) begin
        if (!rstn) LS_opcodeM <= 0;
        else LS_opcodeM <= LS_opcodeE;
    end       

    `ifdef SIM
        initial begin
            RegWriteM = 0;
            ResultSrcM = 0;
            MemWriteM = 0;
            
            // output data
            ALUResultM = 0;
            RdM = 0;
            PCPlus4M = 0;
            // PCTargetE = 0;
            WriteDataM = 0;
            LS_opcodeM = 0;
            MemReadM = 0;
        end
    `endif


endmodule


module ALU_Logical(
    input [31:0] SrcAE,
    input [31:0] SrcBE,
    input [2:0] ALUControlE,

    output reg [31:0] ALUResult,
    output ZeroE
);
    localparam  sSll= 1;
    localparam  sSrl= 2;
    localparam  sSlt= 3;
    localparam  sSltu= 4;
    localparam  sXOR= 5;
    localparam  sOR= 6;
    localparam  sAND= 7;


    wire [31:0] Sll, Srl, Slt, Sltu, XOR, OR, AND;


    assign Sll = SrcAE << SrcBE;
    assign Srl = SrcAE >> SrcBE;
    assign Slt = ($signed(SrcAE) < $signed(SrcBE)) ? 32'd1 : 32'd0;
    assign Sltu = (SrcAE < SrcBE) ? 32'd1 : 32'd0;
    assign XOR = SrcAE ^ SrcBE;
    assign OR = SrcAE | SrcBE;
    assign AND = SrcAE & SrcBE;

    
    // Case 구문으로 입력에 맞게 선택 후 출력함.
    always @(*) begin
        case(ALUControlE)
            default : ALUResult = 0;
            sSll : ALUResult = Sll;
            sSrl : ALUResult = Srl;
            sSlt : ALUResult = Slt;
            sSltu : ALUResult = Sltu;
            sXOR : ALUResult = XOR;
            sOR : ALUResult = OR;
            sAND : ALUResult = AND;
        endcase

        // if (ALUResult==0) ZeroE = 1;
        // else ZeroE = 0;
    end

    assign ZeroE = (ALUResult==0);
    `ifdef SIM
        initial begin
            ALUResult = 0;
        end
    `endif

endmodule


module ALU_Arithmetic(
    input [31:0] SrcAE,
    input [31:0] SrcBE,
    input [2:0] ALUControlE,
    output reg [31:0] ALUResult,
    output ZeroE
);
    localparam sADD = 1;
    localparam sSUB = 2;
    localparam sSla = 3;
    localparam sSra = 4;
    localparam sMUL = 5;
    localparam sDIV = 6;
    localparam sREM = 7;
    wire [31:0] ADD, SUB, Sla, Sra, MUL, DIV, REM;

    assign ADD = SrcAE + SrcBE;
    assign SUB = SrcAE - SrcBE;
    assign Sla = SrcAE <<< SrcBE;
    assign Sra = $signed(SrcAE) >>> SrcBE[4:0];
    assign MUL = SrcAE * SrcBE;
    assign DIV = SrcAE / SrcBE;
    assign REM = SrcAE % SrcBE;

    
    // Case 구문으로 입력에 맞게 선택 후 출력함.
    always @(*) begin
        case(ALUControlE)
            default : ALUResult = 0;
            sADD : ALUResult = ADD;
            sSUB : ALUResult = SUB;
            sSla : ALUResult = Sla;
            sSra : ALUResult = Sra;
            sMUL : ALUResult = MUL;
            sDIV : ALUResult = DIV;
            sREM : ALUResult = REM;
        endcase

        // if (ALUResult==0) ZeroE = 1;
        // else ZeroE = 0;
    end

    assign ZeroE = (ALUResult==0);

    `ifdef SIM
        initial begin
            ALUResult = 0;
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

    assign out = (sel==2'b00) ? data1 : (sel==2'b01) ? data2 : (sel==2'b10) ? data3 : 'h0;
endmodule



