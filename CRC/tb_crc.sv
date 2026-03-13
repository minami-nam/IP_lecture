module tb_crc;
    parameter WAIT_CLK = 4;
    reg i_DV;
    reg [7:0] i_Data;
    reg rstn; 
    reg clk;

    wire [15:0] o_CRC;
    wire [15:0] o_CRC_Xor;
    wire [15:0] o_CRC_Xor_Reversed;
    wire [15:0] o_CRC_Reversed;

    crc dut(.*);

    initial clk = 0;
    always #3 clk=~clk;

    initial begin
        rstn = 0;
        i_DV = 1;
        i_Data = 8'hAF;

        $display("CRC module turned on.");
        @(posedge clk);
        rstn = 1;
        wait(dut.state==1);
        

        $display("CRC-16-CCITT Testing...");
        wait(dut.done_reg==1);
        @(posedge clk);

        if (o_CRC==16'hA5F5) $display("Your CRC-16-CCITT mode is 0xFFFF. The CRC value is : %h", o_CRC);
        else if (o_CRC==16'h4405) $display("Your CRC-16-CCITT mode is XModem. The CRC value is : %h", o_CRC);
        else $display("CRC-16-CCITT Testing Failed. The CRC value is : %h", o_CRC);

        repeat(4) @(posedge clk);
        $finish;
    end


endmodule