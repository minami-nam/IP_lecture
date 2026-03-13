// Code your testbench here
// or browse Examples
`timescale 1ns/1ps

module tb_dpsram;

    parameter int DEPTH = 8;
    parameter int WIDTH = 32;
    parameter int DEPTH_LOG = $clog2(DEPTH); 

    // reg 
    reg   [WIDTH-1:0]     din_a; 
    reg   [DEPTH_LOG-1:0]addr_a; 
    reg                    we_a;
    reg                    cs_a; 

    reg                     clk;

    reg   [DEPTH_LOG-1:0]addr_b; 
    reg   [WIDTH-1:0]     din_b; 
    reg                    we_b;
    reg                    cs_b; 
    
    // wire
    wire  [WIDTH-1:0]    dout_a;
    wire  [WIDTH-1:0]    dout_b;

  dpsram #(DEPTH, WIDTH) dpsram_cell(.*);  
    
    initial clk = 0;
    always #3 clk = ~clk;

    
    initial begin
        din_a = 1; 
        addr_a = 0; 
        we_a = 0;
        cs_a = 0; 

        addr_b = 0; 
        din_b = 3; 
        we_b = 0;
        cs_b = 0; 


        #18;
        we_a = 1;
        we_b = 1;
        cs_a = 1;
        cs_b = 1;

        // 같은 주소에 Writing 하는 것 Test
        for (int i=0; i<8; i++) begin
            din_a = din_a + i;
            din_b = din_b + i;

            addr_a = i;
            addr_b = i;

            @(posedge clk);        
        end

        $display("Writing Test Passed");
        // 동시 출력 test
        #15;

        we_a = 0;
        we_b = 0;
        for (int i=0; i<4; i++) begin

            addr_a = i;
            addr_b = i+4;

            @(posedge clk);        
        end
        $display("Reading Test Passed");
        #30;
        
        $display("Feed Forward (Bypass) Test Start");
        // 포트 A는 쓰고, 포트 B는 동일 주소를 읽는 상황
        addr_a = 4; din_a = 32'hFEED_BEEF; we_a = 1; cs_a = 1;
        addr_b = 4; we_b = 0; cs_b = 1; // 동일 주소 4번
        
        @(posedge clk);
        #1; 
        if (dout_b == 32'hFEED_BEEF) 
            $display("SUCCESS: Port A data forwarded to Port B!");
        else 
            $display("FAIL: Port B read old data or X");
        
        // 포트 B는 쓰고, 포트 A는 동일 주소를 읽는 상황
        we_a = 0; we_b = 1; din_b = 32'hAAAA_BBBB;
        @(posedge clk);
        #1;
        if (dout_a == 32'hAAAA_BBBB)
            $display("SUCCESS: Port B data forwarded to Port A!");
        $finish;

    end

    

	initial begin
  		$dumpfile("dump.vcd");
  		$dumpvars(1);
	end
endmodule
