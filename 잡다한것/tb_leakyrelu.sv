// Code your testbench here
// or browse Examples
// Code your testbench here
// or browse Examples

module tb_leakyrelu;

    reg clk;
    reg rstn;
    reg [7:0] din;
    reg i_req;

    wire [7:0] dout;
    wire neg;
    wire o_ack;   

  	leakyrelu_blk dut(.*);

    initial clk=0;

    always #2 clk=~clk;

    initial begin
        rstn = 0;
        i_req = 0;
        din = 0;

        repeat (3) @(posedge clk);

        rstn = 1;
        
        @(posedge clk);

        i_req = 1;
        din = 8'b01001010;

        @(posedge clk);
        i_req = 0;
        

		@(posedge clk);
        if (dout==din) begin
            $display("positive num test passed");
        end
        else $display("positive num test failed");

      	repeat (4) @(posedge clk);
        i_req = 1;
        din = 8'b11000101;

        @(posedge clk);
        i_req = 0;
  

      	@(posedge clk);
      	if (dout==(din>>>3)) begin
            $display("negative num test passed");
        end
      	else $display("negative num test failed");
      	#6;

        $finish;
        
    end

	initial begin
  		$dumpfile("dump.vcd");
  		$dumpvars(1);
	end
endmodule