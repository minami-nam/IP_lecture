`define FPGA

module inst_mem 
(
    input [31:0] addr,
    input clk,
    input rstn,
    input i_req,

    output reg [31:0] inst,
    output o_none
);
    parameter int PC =2; // 나중에 편집할 것.
    reg [31:0] mem[0:1023]; 
    wire [6:0] opcode;
    
    reg [31:0] mid_reg;


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
    

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) none_reg <= 0;
        else begin
            if (opcode==0) none_reg <= 1;
            else none_reg <= 0; 
        end
    end

    always_ff @(posedge clk) begin
        if (opcode!=0) inst <= mid_reg;
        else inst <= 0;
    end





    `ifdef SIM
        initial begin
            none_reg = 0;
            mid_reg = 0;  
            for (int i=0; i<PC; i++) begin
                mem[i] = 0;
            end   
            inst = 0;
        end
    `endif 

 

endmodule