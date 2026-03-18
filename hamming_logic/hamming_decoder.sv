`define SIM

module hamming_logic_decoder(
    input [20:0] A,
    input rstn,
    input clk,
    input i_req,
    
    output err,
    output [15:0] B,
    output o_available
);
    reg [20:0] a_reg;
    reg [15:0] b_reg;
    reg [1:0] cnt;
    reg flag;
    reg done;
    reg o_available_reg;    // Encoder , Decoder의 일관성을 맞추기 위한 장치
    
    wire xor_p1, xor_p2, xor_p4, xor_p8, xor_p16;    // assign 문 써서 연산시킬 생각임.
    wire err_p1, err_p2, err_p4, err_p8, err_p16;
    wire [4:0] parity_case;
    wire [15:0] b_fix;
    

    // Counter
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) cnt <= 0;
        else begin
            if (flag&&!done) cnt <= cnt + 1;
            else cnt <= 0;
        end
    end


    
    // Data I/O ctl 관련

    assign o_available = done;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) o_available_reg <= 0;
        else begin
            if (done) o_available_reg <= 1;
            else o_available_reg <= 0;
        end
    end
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) flag <= 0;
        else if (i_req) flag <= 1; 
        else if (done) flag <= 0;
        else flag <= flag;
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) done <= 0;
        else begin
            if (cnt==2) done <= 1;
            else done <= 0;
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) a_reg <= 0;
        else begin
            if (i_req) a_reg <= A;
            else if (done) a_reg <= 0;
            else a_reg <= a_reg;
        end
    end


    // Decoder 연산 관련
    assign xor_p1 =^{a_reg[20], a_reg[18], a_reg[16], a_reg[14], a_reg[12], a_reg[10], a_reg[8], a_reg[6], a_reg[4], a_reg[2]}; 
    assign xor_p2 = ^{a_reg[18:17], a_reg[14:13], a_reg[10:9], a_reg[6:5], a_reg[2]}; 
    assign xor_p4 = ^{a_reg[20:19], a_reg[14:11], a_reg[6:4]};
    assign xor_p8 = ^{a_reg[8 +: 7]};
    assign xor_p16 = ^{a_reg[15 +: 5]};

    assign err_p1 = (xor_p1!=a_reg[0]) ? 1 : 0;
    assign err_p2 = (xor_p2!=a_reg[1]) ? 1 : 0; 
    assign err_p4 = (xor_p4!=a_reg[3]) ? 1 : 0;
    assign err_p8 = (xor_p8!=a_reg[7]) ? 1 : 0; 
    assign err_p16 = (xor_p16!=a_reg[15]) ? 1 : 0; 

    assign parity_case = {err_p16, err_p8, err_p4, err_p2, err_p1};
    assign err = (parity_case!=0) ? 1 : 0;
    assign b_fix = {a_reg[20:16],a_reg[14:8],a_reg[6:4],a_reg[2]};  

    
    assign B = o_available_reg ? b_reg : 0;

    // Err 판별 후 고치는 Logic 
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) b_reg <= 0;
        else begin
            case(cnt)
                0 : b_reg <= 0;
                1 : b_reg <= b_fix;
                2 : begin 
                    if (err) b_reg[parity_case] <= ~b_reg[parity_case];
                    else b_reg <= b_reg;
                end
                default : b_reg <= b_reg;
            endcase
        end
    end


    `ifdef SIM
        initial begin
            a_reg = 0;
            b_reg = 0;
            cnt = 0;
            done = 0;
            flag = 0;
            o_available_reg = 0;
        end
    `endif

endmodule