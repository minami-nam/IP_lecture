import parameter_package::*;
`define FPGA


module relu(
    input clk,
    input rstn,

    input in_valid,
    output in_ready,
    input [W_DATA-1:0] in_data,

    output out_valid,
    input out_ready,
    output reg [W_DATA-1:0] out_data
);  
    // Localparam 설정 부분

    localparam int IDLE = 2'b00;
    localparam int GOT_VALID = 2'b01;
    localparam int CALC = 2'b10;
    localparam int SEND = 2'b11;

    localparam int OFF = 1'b0;
    localparam int ON = 1'b1;

    localparam RANGE_INT = 8;
    localparam NUM_WIRE = W_DATA / RANGE_INT;


    
    // FSM
    reg [1:0] state;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) state <= IDLE;
        else begin
            case(state)
                IDLE : if (in_valid&in_ready) state <= GOT_VALID; 
                GOT_VALID : state <= CALC;  // Margin 남겨 놓고 데이터 입력 받기
                CALC : state <= SEND;
                SEND : if (out_ready&out_valid) state <= IDLE;
            endcase
        end
    end

    // DATA 연산 처리 : generate 써서 만들기
    wire [W_DATA-1:0] concat;
    genvar i;
    generate 
        for (i=0; i<NUM_WIRE; i++) begin : signal_relu_gen
            assign concat[8*i+7 -: 8] =
                (in_data[8*i+7]) ? 8'd0 : in_data[8*i+7 -: 8];
        end
    endgenerate

        
    // DATA 출력 관련
    always @(posedge clk or negedge rstn) begin
        if (!rstn) out_data <= 'h0000;
        else begin
            if (state==CALC) out_data <= concat;
            else if (in_valid&in_ready) out_data <= 'h0000;
            else out_data <= out_data;
        end
    end


    // vaild / ready logic
    assign in_ready = (state==IDLE) ? ON : OFF;
    assign out_valid = ((state==SEND)&(out_ready==ON)) ? ON : OFF;

    `ifdef SIM
        initial begin
            state = IDLE;
            out_data = 'h0000_0000;
        end
    `endif

endmodule