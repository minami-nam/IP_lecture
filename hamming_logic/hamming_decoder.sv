`define SIM

module hamming_logic_decoder(
    input [20:0] A,
    input rstn,
    input clk,
    input i_req,
    
    output err,
    output [15:0] B,
    output o_available
);
    reg [20:0] a_reg;
    reg [15:0] b_reg;

    





    `ifdef SIM
        initial begin
            a_reg = 0;
        end
    `endif

endmodule