module tb_ddrctl;
    reg clk, rstn, i_req, i_write;
    reg [7:0] i_addr;
    reg [63:0] i_wdata;
    wire o_ack, o_rd_en;
    wire [63:0] o_rdata;
    wire ck_t, ck_c, cke, csn, actn, dqs_t, dqs_c;
    wire [1:0] bg, ba;
    wire [17:0] a;
    wire [7:0] dq;

    ddrctl_v2 dut (.*);

    initial clk = 0;
    always #3 clk = ~clk;


    initial begin
        // 초기화
        rstn = 0; i_req = 0; i_write = 0; i_addr = 8'hFF; i_wdata = 0;
        repeat (10) @(posedge clk);
        rstn = 1;
        @(posedge clk);
        i_addr = 8'h0;
        
        wait(cke == 1);

        $display("--- MRS Entry ---");
        @(posedge clk);
        // 컨트롤러가 MRS 상태로 진입할 때까지 대기
        wait(dut.c_state == 1); 
        $display("PASS : State is MRS");

        // MRS 설정값 및 IDLE 이동
        i_addr = 8'h06;
        wait(dut.c_state == 2); // IDLE 진입 대기
        $display("PASS : State is IDLE");

        // 3. WRITE Sequence
        $display("--- Write Sequence ---");
        i_req = 1; i_write = 1; i_addr = 8'h08; i_wdata = 64'hAAAA_BBBB_CCCC_DDDD;
        wait(o_ack);
        @(posedge clk);
        i_req = 0;

        // tRCD 후 Column 주소 인가
        repeat (7) @(posedge clk);
        i_addr = 8'h09;
        
        // 데이터 전송 및 DQS 관찰 (tCWL 대기)
        wait(dut.start == 1);
        $display("DQS is toggling now...");
        
        wait(dut.c_state == 2);

        // 4. READ Sequence
        $display("--- Read Sequence ---");
        i_req = 1; i_write = 0; i_addr = 8'h08;
        wait(o_ack);
        @(posedge clk);
        i_req = 0;

        repeat (7) @(posedge clk);
        i_addr = 8'h09;

        wait(o_rd_en == 1);
        repeat (8) @(posedge clk);

        if (o_rdata == 64'hAAAA_BBBB_CCCC_DDDD)
            $display("SUCCESS: Data Match!");
        else
            $display("FAIL: Data Mismatch. Got %h", o_rdata);   // 값을 참고할 때는 이런 식으로 표기.

        repeat (10) @(posedge clk);

        $finish;
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_ddrctl);
    end
endmodule