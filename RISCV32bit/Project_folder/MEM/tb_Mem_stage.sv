`timescale 1ps/1ps

module tb_mem_stage;
    logic  RegWriteM;
    logic  [1:0] ResultSrcM;
    logic  MemWriteM;
    logic  [4:0] RdM;
    logic  [31:0] PCPlus4M;
    logic  [31:0] WriteDataM;
    logic  [31:0] ALUResultM;

    logic     clk; 
    logic     rstn;

    
    logic RegWriteW;
    logic [31:0] ResultW;
    logic [4:0] RdW;

    // Module
    mem_wrapper dut(.*);

    // clk
    initial clk = 0;
    always #3 clk = ~clk;




    // Testbench 시작
    initial begin

        $display("reset...");
        RegWriteM = 1'b1;
        ResultSrcM = 2'b10;
        MemWriteM = 1'b1;
        RdM = 5'b10110;
        PCPlus4M = 32'h0000_7000;
        WriteDataM = 32'habcd_dcba;
        ALUResultM = 32'h0000_0111;
        rstn = 1'b0;

        @(negedge clk);


        RegWriteM = 1'b1;
        ResultSrcM = 2'b00;
        MemWriteM = 1'b1;
        RdM = 5'b10110;
        PCPlus4M = 32'h0000_7001;
        WriteDataM = 32'habcd_dcba;
        ALUResultM = 32'h0000_0111;
        rstn = 1'b1;

        @(negedge clk);

        if (ResultW==ALUResultM) $display("Successfully Feed Forwarded : %8h", ResultW);
        else $display("Feed Forward Test Failed : %8h", ResultW);

        if (dut.dm.data_reg[ALUResultM]==WriteDataM) $display("Data was written successfully. : %8h", dut.dm.data_reg[ALUResultM]);
        else $display("Data was NOT sucessfully written. : %8h", dut.dm.data_reg[ALUResultM]);

        RegWriteM = 1'b0;
        ResultSrcM = 2'b01;
        MemWriteM = 1'b0;
        RdM = 5'b10111;
        PCPlus4M = 32'h0000_7002;
        WriteDataM = 32'h0000_0000;
        ALUResultM = 32'h0000_0111;
        rstn = 1'b1;
        
        @(negedge clk);

        if (ResultW==dut.ReadDataW) $display("Read Successfully. : %8h", ResultW);
        else $display("Read Failed : %8h", ResultW);

        repeat(3) @(posedge clk);

        $display("---------- TEST FINISHED ----------");
        $finish;
    end



endmodule