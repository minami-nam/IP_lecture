// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

module tb_DRAM_ctl;

    // Parameters
	parameter	INIT=0,MRS=1,IDLE=2,ACT=3,WR=4,RD=5,PRE=6;
	parameter	tRCD=9,tCWL=11,tCL=10,tRP=8;
	parameter 	phase_bit=$clog2(7);
    parameter   BANKGROUP_NUM = 6;
    parameter   BANKARRAY_NUM = 6;
    parameter   WIDTH_BG = $clog2((BANKGROUP_NUM-1));
    parameter   WIDTH_BA = $clog2((BANKARRAY_NUM-1));
    parameter   WIDTH_ADDR = WIDTH_BA + WIDTH_BG + 8;

    // Signals
	logic	clk;
    logic   rstn;

	logic			i_req;
	logic			o_ack;
	logic			i_write;
	logic [WIDTH_ADDR-1:0]	    i_addr;
	logic [63:0]	i_wdata;
	logic			o_rd_en;
	logic [63:0] 	o_rdata;
    logic [2:0] current_phase_out;

	logic			ck_t; 
    logic           ck_c;
	wire		    cke;
	wire		    csn; 
    wire            actn;
	wire	[WIDTH_BG-1:0]	bg; 
    wire    [WIDTH_BA-1:0]  ba;
	wire    [17:0]  a;	//rasn 16, casn 15, wen 14, bcn 12, ap 10

	wire [7:0]		dq;
	wire			dqs_t;
    wire            dqs_c;   




    ddr_ctrl dut (.*);

    initial clk = 0;  
    always #3 clk = ~clk;
    
    // Test Sequence
    initial begin
        rstn = 0;
        @(posedge clk);
        rstn = 1;
        @(posedge clk);

        
        i_addr = 14'h3FAB;
        i_req = 0;
        i_write = 0;
        i_wdata = 0;

        repeat (2) @(posedge clk); 
        if (cke==1) $display("PASS : this module could enter the MRS mode.");
        else $display("FAIL : this module couldn't enter the MRS mode.");

        // WR seq.
        
        i_write = 1;
        

        wait(o_ack == 1); 
    
        i_wdata = 64'hABBA_CDDC;
        wait(o_ack == 0); 
        if ((actn==0)&&(cke==1)) $display("PASS : this module could enter the ACT mode."); 
        else $display("FAIL : this module couldn't enter the ACT mode.");

        repeat (tRCD) @(posedge clk);
        @(posedge clk);

        $display("Testing the WR mode...");
        @(negedge o_ack); 
        if (a=={1'b0, 3'b111, 14'b0}) $display("PASS : this module could enter the PRE mode.");
        else $display("FAIL : this module couldn't enter the PRE mode.");

        i_write = 0;
        i_addr = 'h0;   

        repeat (tRP) @(posedge clk);
        if (a=={1'b0, 3'b111, 14'b0}) $display("PASS : this module passed the WR Sequence.");
        else $display("FAIL : this module couldn't pass the WR Sequence.");

        repeat (3) @(posedge clk);

        // RD seq.
        i_req = 1;
        wait(o_ack == 1); // RD 상태 진입
        wait(o_ack == 0); // 데이터 수집 완료 및 PRE 진입 시점
        @(posedge clk);  // 한 클럭 더 기다려 r_reg_data가 완전히 업데이트되도록 함
        if (o_rdata == 64'hABBA_CDDC) 
        $display("PASS : this module passed the RD Sequence.");

        #5;

        $display("Test Done.");

        $finish;
    end
  
  
	initial begin
  		$dumpfile("dump.vcd");
  		$dumpvars;
	end
  
  	

endmodule