`timescale 1ps/1ps


module tb_inst_mem;
    logic [31:0] addr;
    logic clk;
    logic rstn;
    logic en;
    logic i_req;
    logic [31:0] i_inst;
    logic [31:0] PCPlus4F;

    

    logic [31:0] inst;
    // logic [31:0] o_pc;
    logic [31:0] PCD;
    logic [31:0] PCPlus4D;


    inst_mem dut(.*);

    initial clk = 0;
    always #3 clk = ~ clk;

    initial begin
        @(posedge clk);
        dut.mem[65] = 32'hFACEFACE;
        dut.mem[66] = 32'hDEFDEFAC;
        dut.mem[67] = 32'h0;
    end  


    initial begin
        rstn = 0;
        addr = 0;
        i_req = 0;
        i_inst = 0;
        en = 0;
        PCPlus4F = 0;

        repeat (2) @(posedge clk);
        $display("Initializing...");
        rstn = 1;
        addr = 32'd260;
        en = 1;
        i_req = 0;
        @(posedge clk);

        if (inst==32'hFACEFACE) $display("HIT : %h", inst);
        else $display("MISS : %h", inst);
        addr = 32'd264;
        PCPlus4F = 4;

        @(posedge clk);
        if (inst==32'hDEFDEFAC) $display("HIT : %h", inst);
        else $display("MISS : %h", inst);

        addr = 32'd268;
        PCPlus4F = 8;

        @(posedge clk);

        @(posedge clk);
        if (inst==0) $display("Empty");
        else $display("Corruption ERROR : %h", inst);

        i_req = 1;
        addr = 32'd100;
        i_inst = 32'hDACB_DACB;
        @(posedge clk);
        if (dut.mem[25]==32'hDACB_DACB) $display("Match");
        else $display("Error occurred : %h", dut.mem[100]);

        #10;
        $finish;
    end



endmodule