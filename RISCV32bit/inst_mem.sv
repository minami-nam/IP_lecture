`define FPGA

module inst_mem 
(
    input [31:0] addr,
    input clk,
    input rstn,
    input i_req,
    

    output reg [31:0] inst,
    output o_none,
    output reg [31:0] o_pc; 
    
    // output o_req
);
    // SystemVerilog 문법 사용해보기
    parameter PC = 2 ** 32;
    typedef reg [31:0] inst_reg[0:PC-1];    // 여기는 원래 Memory에 접근하여 명령어를 들고와야 하나, 편의상 reg로 일단 대체함.

    inst_reg mem;
    wire [6:0] opcode;
    reg [31:0] mid_reg;

    // 입력 값 임시 저장 reg 동작 구성
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)  mid_reg <= 0;
        else begin
            if (i_req) mid_reg <= mem[addr];
            else mid_reg <= 0;
        end
    end

    reg none_reg;
    assign opcode = mem[addr][31 -: 7];
    assign o_none = none_reg;
    
    // opcode 조건에 따라 none 판별
    always @(*) begin
        if (opcode==0) none_reg = 1;
        else none_reg = 0; 
    end

    // mid_res 판별 후 출력하는 회로
    always @(*) begin
        if (opcode!=0) inst = mid_reg;
        else inst = 0;
    end

    always @(posedge clk or negedge rstn) begin
        if (!rstn) o_pc <= 0;
        else o_pc <= addr;
    end 



    `ifdef SIM
        initial begin
            none_reg = 0;
            mid_reg = 0;  
            for (int i=0; i<PC; i++) begin
                mem[i] = 0;
            end   
            inst = 0;
            o_pc = 0;
        end
    `endif 

 

endmodule

module program_counter (
    input [31:0] in,
    input rstn,
    input clk,

    output [31:0] o_addr
);

    reg [31:0] reg_cnt;
    assign output = reg_cnt;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) reg_cnt <= 'd7000;  
        else reg_cnt <= in;
    end

    `ifdef SIM
        initial begin
            reg_cnt = 0;
        end
    `endif

endmodule