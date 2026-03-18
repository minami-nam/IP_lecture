`define FPGA    // Simulation을 위한 설정.

module hamming_logic_encoder(
    input [15:0] A,
    input rstn,
    input clk,
    input i_req,

    output [20:0] B,
    output o_available
);
    // reg 설정
    reg [20:0] b_reg;
    // Busy와 같은 의미임.
    reg o_available_reg;
    reg flag;
    reg [20:0] mem;
    // 이게 되네 ㅋㅋㅋㅋ 
    // 새롭게 배운 신호 연산 방법 : 단일 신호의 각 Bit에 대하여 특정 연산을 진행시키고 싶다면, (op_sign)(signal_name) 형식으로 간단하게 진행시킬 수 있음. (Reduction)
    wire xor_p1, xor_p2, xor_p4, xor_p8, xor_p16;
    assign xor_p1 =^{mem[20], mem[18], mem[16], mem[14], mem[12], mem[10], mem[8], mem[6], mem[4], mem[2]}; 
    assign xor_p2 = ^{mem[18:17], mem[14:13], mem[10:9], mem[6:5], mem[2]}; 
    assign xor_p4 = ^{mem[20:19], mem[11 +: 4], mem[6:4]};
    assign xor_p8 = ^{mem[8 +: 7]};
    assign xor_p16 = ^{mem[16 +:5]};

    assign o_available = o_available_reg;
    assign B = b_reg;
    
    // flag (계산 중인 경우 표기) 및 데이터 출력에 관련된 Sequential Logic
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            mem <= 0;
            flag <= 0;
            b_reg <= 0;
            o_available_reg <= 0;
        end  
        else begin
            if (i_req) begin
                mem <= {A[15:11],1'b0,A[10:4],1'b0,A[3:1], 1'b0, A[0], 2'b00}; 
                flag <= 1;
                b_reg <= 0;
                o_available_reg <= 0;
            end
            else begin
                if (o_available) begin
                    flag <= 0;
                    b_reg <= mem;
                    o_available_reg <= 0;
                end
                else begin
                    if (flag) begin
                        mem[0] <= xor_p1;
                        mem[1] <= xor_p2;
                        mem[3] <= xor_p4;
                        mem[7] <= xor_p8;
                        mem[15] <= xor_p16;
                        flag <= 0;
                        o_available_reg <= 1;
                    end
                    
                    else b_reg <= 0;
                end
            end
        end
    end


    // Simulation 상황을 위한 init 환경에서 Reg 값 초기 설정.
    `ifdef SIM
        initial begin
            b_reg=0;
            flag=0;
            mem=0;
            o_available_reg = 0;
        end
    `endif

endmodule