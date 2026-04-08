`define SIM

module mem_wrapper(
    input RegWriteM,
    input [1:0] ResultSrcM,
    input MemWriteM,
    input [4:0] RdM,
    input [31:0] PCPlus4M,
    input [31:0] WriteDataM,
    input [31:0] ALUResultM,

    input clk, rstn,

    
    output RegWriteW,
    output [31:0] ResultW,
    output [4:0] RdW
);  

    // ALUResultM 관련
    reg [31:0] reg_ALUResultM;
    wire [31:0] wire_ALURM_mux;
    assign wire_ALURM_mux = reg_ALUResultM; 

    always @(posedge clk or negedge rstn) begin
        if (!rstn) reg_ALUResultM <= 0; 
        else reg_ALUResultM <= ALUResultM;
    end

    // ResultSrcW와 MUX I/O 조절 
    // Delay 필요      
    reg [1:0] RSrcW;
    reg [31:0] PCP4W;

    wire [31:0] PCPlus4W;

    // Data Memory 관련
    wire [31:0] ReadDataW;
    data_mem dm(
        .A(ALUResultM),
        .WE(MemWriteM),
        .clk(clk),
        .WD(WriteDataM),
        .RD(ReadDataW)
    );




    // RSrcW - ResultSrcW
    
    wire [1:0] ResultSrcW;
    assign ResultSrcW = RSrcW;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) RSrcW <= 0;
        else RSrcW <= ResultSrcM;
    end




    // PCPlus4M - PCPlus4W 관련
    
    assign PCPlus4W = PCP4W;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) PCP4W <= 0;
        else PCP4W <= PCPlus4M;
    end

    // RegWrite 관련 
    reg RWriteW;
    assign RegWriteW = RWriteW;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) RWriteW <= 0;
        else RWriteW <= RegWriteM;
    end






    // Muxing 관련 I/O 조절
    in3_mux rd_mux(
        .data1(wire_ALURM_mux),
        .data2(ReadDataW),
        .data3(PCPlus4W),
        .sel(ResultSrcW),
        .out(ResultW)
    );


    // RdW 관련

    reg [4:0] reg_RdW;
    assign RdW = reg_RdW;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) reg_RdW <= 0;
        else reg_RdW[4:0] <= RdM;
    end

    `ifdef SIM
        initial begin
            reg_RdW = 0;
            RWriteW = 0;
            RSrcW = 0;
            PCP4W = 0;
            reg_ALUResultM = 0;
        end
    `endif 

endmodule


module data_mem(
    input [31:0] A,
    input [31:0] WD,
    input clk, WE,
    
    output [31:0] RD
);
    // SystemVerilog 문법 사용해보기
    parameter PC = 1024;
    reg [31:0] data_reg[0:PC-1];    // 여기는 원래 Memory에 접근하여 명령어를 들고와야 하나, 편의상 reg로 일단 대체함.

    // Data 이동 관련 서술
    always @(posedge clk) begin
        if (WE) data_reg[A>>2] <= WD;

        else data_reg[A>>2] <= data_reg[A>>2];
    end

    assign RD = (!WE) ? data_reg[A>>2] : 'h0000_0000;

    `ifdef SIM 
        initial begin
            for (int i=0; i<PC; i++) begin
                data_reg[i] = 0;
            end
        end
    `endif

endmodule


//module in3_mux(
//    input [31:0] data1,
//    input [31:0] data2,
//    input [31:0] data3,
//    input [1:0] sel,

//    output [31:0] out
//);

//    assign out = (sel==2'b00) ? data1 : (sel==2'b01) ? data2 : (sel==2'b10) ? data3 : 'h0;
//endmodule
