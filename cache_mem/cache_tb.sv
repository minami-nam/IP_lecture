`timescale 1ns/1ps



module tb_cache_256B;
    // Parameter 
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 8;

    // Signals
    reg clk, rst_n;
    reg i_cpu_req, i_cpu_write;
    reg [DATA_WIDTH-1:0] i_cpu_wdata;
    reg [ADDR_WIDTH-1:0] i_cpu_addr;
    wire  [DATA_WIDTH-1:0] o_cpu_rdata;

    reg i_mem_ack;
    reg [DATA_WIDTH-1:0] i_mem_rdata;
    reg [ADDR_WIDTH-1:0] i_mem_raddr;
    wire  [DATA_WIDTH-1:0] o_mem_wdata;
    wire  [ADDR_WIDTH-1:0] o_mem_waddr;

    
    cache_256B dut (.*); // 모든 포트 이름이 tb와 동일하면 해당 방식으로도 작성이 가능함.

    
    always #5 clk = ~clk;


    // DRAM의 동작을 흉내내는 Logic이 있어야 정상적으로 Testbench가 진행됨. 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin   // Reset = 0 이 되는 EDGE 식별 시 초기화
            i_mem_ack <= 'h0;
            i_mem_rdata <= 'h0;
            i_mem_raddr <= 'h0;
        end

        else begin
            if (o_mem_waddr != 0)   begin
                repeat(3) @(posedge clk);   // 3 clk 이후 데이터 전달.
                i_mem_ack <= 'h1;
                i_mem_raddr <= o_mem_waddr;
                i_mem_rdata <= 32'hABCDDCBA;
                @(posedge clk)
                i_mem_ack <= 'h0; 
            end
        end
    end


    // cpu 동작도 흉내내야함. task 구문을 사용하면 Code의 가독성을 높일 수 있음.

    task cpu_read(input [7:0] addr);
        begin
            @(posedge clk);
            i_cpu_req = 1;  // DATA 요청
            i_cpu_addr = addr;  // 입력을 다음과 같이 설정
            i_cpu_write = 0;    // 쓰기는 해당 과정에서 0으로 만들어 놔야 오류 X
            wait(o_cpu_rdata != 0); // 데이터가 나올 때까지 대기

            @(posedge clk);
            i_cpu_req = 0;  // 요청 중지

        end

    endtask


    task cpu_write(input [7:0] addr, input [31:0] data);
        begin
            @(posedge clk);
            i_cpu_req = 0;  
            i_cpu_write = 1;
            i_cpu_addr = addr;
            i_cpu_wdata = data;
            @(posedge clk);
            i_cpu_write = 0;
           
        end
    endtask

    initial begin
        // 초기화
        clk = 0; rst_n = 0;
        i_cpu_req = 0; i_cpu_write = 0;
        i_cpu_wdata = 0;
        #20 rst_n = 1;

        // CASE 1: Compulsory Miss (최초 읽기)
        // 결과: IDLE -> CACHE_CHECK -> NEED_READ_DRAM -> DRAM 응답 대기 -> SEND_CPU
        cpu_read(8'h10); 

        // CASE 2: Cache Hit (방금 읽은 곳 다시 읽기)
        // 결과: IDLE -> CACHE_CHECK -> READ_WAIT1/2 -> SEND_CPU (훨씬 빨라야 함)
        #50;
        cpu_read(8'h10);

        // CASE 3: Cache Write
        #50;
        cpu_write(8'h20, 32'hAAAA_BBBB);

        #100 $finish;
    end
endmodule


