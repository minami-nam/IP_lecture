module tb_hamming_logic_encoder;

    reg [15:0] A;
    reg rstn;
    reg clk;
    reg i_req;

    wire [20:0] B;
    wire o_available;

    hamming_logic_encoder dut(.*);

    initial clk = 0;
    always #3 clk=~clk;

    initial begin
        rstn = 0;
        i_req = 0;
        A = 0;

        repeat (2) @(posedge clk);

        $display("Testing...");

        rstn = 1;
        i_req = 1;
        A = 16'b1001110010010011;
        
        @(posedge clk);
        i_req = 0;

        // o_available이 reg에 의해 Control되기 때문에 일단 o_available이 켜지고 난 후 clk를 기다려야 하지만,
        // Module Code 작성 과정에서 o_available이 켜지는 순간 flag를 내려 바로 o_available_reg 값을 0으로 지정하기 때문에,
        // 해당 구문들을 사용하여 TB 작성을 진행하였습니다.
        wait(o_available);

        wait(!o_available);

        // B 값이 정상적으로 출력되는지 Log로 띄워주는 Code
        if (B==21'b100111100100110010110) $display("Test Succeeded : Output %h is vaild.", B);
        else $display("Test Failed : Output : %h", B);

        #10;
        $finish;
    end


endmodule