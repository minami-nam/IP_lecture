`timescale 1ps/1ps


module tb_inst_mem;
    reg [31:0] addr;
    reg clk;
    reg rstn;
    reg i_req;

    wire [31:0] inst;
    wire o_none;

    parameter int PC = 2 ** 32;

    inst_mem dut(.*);

    initial clk = 0;
    always #3 clk = ~ clk;

    initial begin
        @(posedge clk);
        dut.mem[256] = 32'hFACEFACE;
        dut.mem[257] = 32'hDEFDEFAC;
        dut.mem[258] = 32'h0;
    end  


    initial begin
        rstn = 0;
        addr = 0;
        i_req = 0;

        repeat (2) @(posedge clk);
        rstn = 1;
        addr = 32'd256;
        i_req = 1;
        @(posedge clk);
        addr = 32'd257;


        @(posedge clk);
        addr = 32'd258;
        if (inst==32'hFACEFACE) $display("HIT : %h", inst);
        else $display("MISS : %h", inst);


        @(posedge clk);

        if (inst==32'hDEFDEFAC) $display("HIT : %h", inst);
        else $display("MISS : %h", inst);

        @(posedge clk);
        if (o_none) $display("Empty");
        else $display("Corruption ERROR : %h", inst);

        #10;
        $finish;
    end



endmodule