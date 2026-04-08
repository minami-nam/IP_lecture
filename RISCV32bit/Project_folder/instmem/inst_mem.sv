`define SIM

module inst_mem 
(
    input [31:0] addr,
    input clk,
    input rstn,
    input en,
    input i_req,
    input [31:0] i_inst,
    input [31:0] PCPlus4F,

    

    output reg [31:0] inst,
    // output reg [31:0] o_pc,
    output reg [31:0] PCD,
    output reg [31:0] PCPlus4D
    
    // output o_req
);
    // SystemVerilog 문법 사용해보기
    parameter PC = 1024;
    typedef reg [31:0] inst_reg[0:PC-1];    // 여기는 원래 Memory에 접근하여 명령어를 들고와야 하나, 편의상 reg로 일단 대체함.

    inst_reg mem;
    wire [6:0] opcode;

    // reg [31:0] mid_reg;
    
    // wire local_clk;
    // assign local_clk = en ? clk : 0;

    // 입력 값 임시 저장 reg 동작 구성
    always_ff @(posedge clk) begin
        if (en&!i_req) inst <= mem[addr>>2];

    end

    // inst 입력 reg 동작 구성
    always_ff @(posedge clk) begin
        if (en&i_req) mem[addr>>2] <= i_inst;
    end

    assign opcode = mem[addr>>2][31 -: 7];



    // // mid_res 판별 후 출력하는 회로
    // always @(posedge clk) begin
    //     if (!i_req&((opcode!=0)&en)) inst <= mid_reg;
    //     else inst <= 0;
    // end

    // always @(posedge local_clk or negedge rstn) begin
    //     if (!rstn) o_pc <= 0;
    //     else begin
    //         if (!i_req) o_pc <= addr;
    //         else o_pc <= 0;
    //     end
    // end 

    always @(posedge clk) begin
        if (en&!i_req) PCD <= addr;

    end

    
    always @(posedge clk ) begin
        if (en&!i_req) PCPlus4D <= PCPlus4F;

    end



    `ifdef SIM
        initial begin
            for (int i=0; i<PC; i++) begin
                mem[i] = 0;
            end   
            inst = 0;
            // o_pc = 0;
            PCD = 0;
            PCPlus4D = 0;
        end
    `endif 

 

endmodule

module program_counter (
    input [31:0] in,
    input rstn,
    input clk,
    input en,

    output reg [31:0] o_addr
);
    // wire local_clk;
    // assign local_clk = en ? clk : 0;

    // 이거 주의. 이런식으로 gating 했다가는 피본다.
    // Glitch 발생으로 인해 정상적으로 작동 보장 X


    always @(posedge clk or negedge rstn) begin
        if (!rstn) o_addr <= 'd0008;
        else begin
            if (en) o_addr <= in;
            else o_addr <= 'd0008;
        end
    end

    `ifdef SIM
        initial begin
            o_addr = 'd0008;
        end
    `endif

endmodule