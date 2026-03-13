// Code your design here
`define SIM // Simulation Mode
module DRAM_interface #(
    parameter int N_ROW = 16,
    parameter int N_COL = 16,

  	parameter int R_ADDR = $clog2(N_ROW),
  	parameter int C_ADDR = $clog2(N_COL),
    parameter int WIDTH_ADDR = R_ADDR + C_ADDR,
    parameter int NUM_INBANK = 1,
    parameter int NUM_INGROUP = 1

     
)(
    input   ck_t, ck_c,
    input   cke,
    input   csn, actn,
  	input   [$clog2(NUM_INGROUP+1)-1:0] bg, 
  	input   [$clog2(NUM_INBANK+1)-1:0]  ba,
    input   [(WIDTH_ADDR+9):0]  a,
    // Burst 관련, 나중에 수정 필요.
    input   burst,
    input   [3:0]burst_count,

    inout   [7:0]   dq,
    inout   dqs_t, dqs_c,
    output reg  wait_ctl,
    output reg [3:0]   tCWL, tCL  
);
    // {csn, actn, rasn, casn, wen}
    localparam  [4:0] ACT = 5'b00111;
    localparam  [4:0] WR = 5'b01100; 
    localparam  [4:0] RD = 5'b01101; 
    localparam  [4:0] MRS = 5'b01000; 
    localparam  [4:0] PRECHARGE = 5'b01111;  // Opcode Settings
    localparam  tRCD=9, tRP=8;  // 강의 내부 Code에는 9라고 표기됨?

    localparam IDLE = 'h0;
    localparam WAIT_tRCD = 'h1; // Row 선택 후 Col 선택까지 걸리는 시간
    localparam WAIT_tRP = 'h2;  // 다음 행에 접근하기 위해 걸리는 시간
    localparam WAIT_tCWL = 'h3; // Writing 시 열린 메모리 뱅크에 쓰는 시간
    localparam WAIT_tCL = 'h4;  // 메모리에서 R/W 진행할 때 걸리는 시간
    localparam DATAOUT_READY = 'h5;

    reg [1:0]               MPR_state;
    reg [3:0]                row, col;
    reg [4:0]                     cnt;
    reg [7:0]                    dq_o;
    reg [63:0]              curr_data;
    reg [2:0]              curr_state;
    reg             write_op, read_op;
    reg [3:0]         burst_count_reg;
    reg [3:0]         burst_count_reg2;

    reg                      can_send;
    wire                                             

    


    
    wire [4:0]                 opcode;
    reg [4:0]              opcode_reg;

    wire rasn, casn, wen;
    assign {rasn, casn, wen} = {a[16], a[15], a[14]};  // 일단 width 고정
    assign opcode = {csn, actn, rasn, casn, wen};
    

    wire       dq_oe;
    wire [7:0]  dq_f;
    
    assign dq_oe = read_op&&(curr_state==DATAOUT_READY);
    assign dq = dq_oe ? dq_o : 'bz;         // Hi Impedance 설정으로 값 세팅.
    assign dq_f = dq;

    assign dqs_t = dq_oe ? ck_t : 1'bz;
    assign dqs_c = dq_oe ? ck_c : 1'bz;

    reg [63:0]  mem[0:N_ROW-1][0:N_COL-1];

    always @(posedge ck_t) opcode_reg = opcode;


    always @(posedge ck_t)  begin
        if (opcode==MRS) begin
            tCL <= a[3:0];
            tCWL <= a[3:0]+1;
        end
    end

    always @(posedge ck_t)  begin
        case(curr_state)
            default : curr_state <= IDLE;
            IDLE : begin 
                if (!csn&&opcode_reg==ACT) begin     
                    cnt <= 0;
                    curr_data <= 0;
                    curr_state <= WAIT_tRCD;
                    row <= a[(C_ADDR+R_ADDR-1):(C_ADDR)];
                    if (burst) begin
                        burst_count_reg <= burst_count;
                        burst_count_reg2 <= 0;
                    end
                end
            end

            WAIT_tRCD : begin
                if (cnt == tRCD - 1) begin
                    if (opcode_reg==RD) begin
                        read_op <= 1;
                        curr_state <= WAIT_tCL;
                        col <= a[(C_ADDR-1):0];
                        cnt <= 0;
                        wait_ctl <= 1'b0;
                    end
                    else if (opcode_reg==WR) begin
                        write_op <= 1;
                        curr_state <= WAIT_tCWL;
                        col <= a[(C_ADDR-1):0];
                        cnt <= 0;
                        wait_ctl <= 1'b0;
                    end
                    else begin
                        curr_state <= IDLE;
                        cnt <= 0;
                    end
                end
                else begin
                    cnt++;
                    wait_ctl <= 1'b1;
                end
            end

            WAIT_tRP : begin
                if (cnt == tRP - 1) begin
                    curr_state <= WAIT_tRCD;
                    cnt <= 0;
                end
                else if (cnt == tRP - 2) begin
                    row++;
                    col <= 0;
                    if begin
                        
                    end
                end
                else begin
                    cnt++;
                    wait_ctl <= 1'b1;
                end
                
            end

            WAIT_tCL : begin
                if (cnt == tCL - 2) begin
                    cnt <= 0;
                    curr_data <= mem[row][col];
                    can_send <= 1'b1;
                    if (burst_count_reg>8) begin
                        
                    end    
                end 
                else cnt++;

            end

            WAIT_tCWL : begin
                if (cnt == tCWL - 1) begin
                    cnt <= 0;
                    if (opcode_reg==PRECHARGE) begin 
                        curr_state <= WAIT_tRP;
                        wait_ctl = 1'b0;
                        burst_count_reg2 <= 0;
                    end 
                    else begin
                        curr_state <= IDLE;
                        burst_count_reg2 <= 0;
                        burst_count_reg <= 0;
                        write_op <= 0;
                        row <= 0;
                        col <= 0;
                        wait_ctl = 1'b0;
                    end 

                    
                end
                else begin
                    if (dqs_t||dqs_c) begin
                        if (burst_count_reg<8)  begin
                            if (burst_count_reg2!=burst_count_reg) begin
                                mem[row][col][(8*burst_count_reg2) +: 8] <= dq_f;
                                burst_count_reg2++;
                                cnt++;
                                wait_ctl = 1'b1;
                            end
                            else begin
                                cnt++;
                                wait_ctl = 1'b1;
                            end
                        end
                        else begin
                            if (burst_count_reg2!=8) begin
                                mem[row][col][(8*burst_count_reg2) +: 8] <= dq_f;
                                burst_count_reg2++;
                                cnt++;
                                wait_ctl = 1'b1;
                            end
                            else begin
                                cnt++;
                                wait_ctl = 1'b1;
                            end
                        end
                    end
                end
            end

        endcase
        
    end

    always @(posedge ck_t)  begin

    end

    `ifdef SIM
        initial begin
            MPR_state = 0;
            tCWL = 0; 
            tCL = 0;
            row = 0; 
            col = 0;
            cnt = 0;
            dq_o = 0;
            curr_data = 0;
            can_send = 0;
            curr_state = 0;
            write_op = 0; 
            read_op = 0;
            burst_count_reg = 0;
            burst_count_reg2 = 0;
            opcode_reg = 0;

            for (int i=0; i<N_ROW; i++) begin
                for (int j=0; j<N_COL; j++) begin
                    mem[i][j] = 'h0;
                end
            end
        end
    `endif

endmodule