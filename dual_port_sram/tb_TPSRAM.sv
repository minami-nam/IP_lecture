`timescale 1ns/1ps

module tb_tpsram;
    parameter int DEPTH = 8;
    parameter int WIDTH = 32;
    parameter int DEPTH_LOG = $clog2(DEPTH);

    reg clk;
    reg [WIDTH-1:0] wd;
    reg [DEPTH_LOG-1:0] ra;
    reg [DEPTH_LOG-1:0] wa;
    reg we;
    reg re;

    wire    [WIDTH-1:0] rd;


    initial clk = 0;
    always #5 clk = ~clk;
  
  tpsram #(.WIDTH(WIDTH), .DEPTH(DEPTH)) dut (.*);



    initial begin
      
        wd = 0;
        ra = 0;
    	wa = 0;
    	we = 0;
    	re = 0;
        #20;
		
      	
      	repeat(6) begin
          	wa = wa + 1;
          	we = 1;
          	wd = wd + 2;
          	#10;
      	end
		
      	wd = 0;
        ra = 0;
    	wa = 0;
    	we = 0;
    	re = 0;
      	
        repeat(6) begin
          	ra = ra + 1;
          	re = 1;
          	#10;
      	end

  
        #10;

        $display("Testbench Finished");
        $finish;
    end
	initial begin
  		$dumpfile("dump.vcd");
  		$dumpvars(1);
	end
endmodule
