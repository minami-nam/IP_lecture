module tb_relu;
    reg clk;
    reg rstn;

    reg in_valid;
    wire in_ready;
    reg [W_DATA-1:0] in_data;

    wire out_vaild;
    reg out_ready;
    wire [W_DATA-1:0] out_data;

    localparam int IDLE = 2'b00;
    localparam int GOT_VALID = 2'b01;
    localparam int CALC = 2'b10;
    localparam int SEND = 2'b11;

    localparam ON = 1'b1;
    localparam OFF = 1'b0;

    relu dut(.*);

    initial clk = OFF;
    always #2 clk = ~clk ;

    initial begin
        rstn = OFF;
        repeat(2) @(posedge clk);
        rstn = ON;
    end

    initial begin
        // 1. in_vaild를 보낸 후 in_data 삽입 
        wait(rstn);

        in_valid = ON;
        in_data = 'h0000_0000;
        out_ready = OFF;

        @(posedge clk);
        
        in_data = 'hab10_63ba;  // ab ba는 0으로 출력, 10과 63은 그대로 출력
        $display("Initializing...");
        wait(dut.state==SEND);
        @(posedge clk);

        out_ready = ON;
        $display("Result : %8h", out_data);
        #3;
        $display("Test Done");
        $finish;

    end


endmodule