// Arithmetic Shift Operator >>> <<< 및 $signed 사용 관련 숙지.

`define SIM

module leakyrelu_blk (
    input clk,
    input rstn,
  	input [7:0] din,
    input i_req,

  	output reg [7:0] dout,
    output reg neg,
    output o_ack
);
    parameter int IDLE = 0;
    parameter int INIT = 1;
    parameter int FIN = 2;
    parameter int SLOPE = 3;
    

  	reg [7:0] din_reg;
    reg [1:0]   status;
    assign o_ack = (i_req && status==IDLE);

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            status <= IDLE;
        end

        else begin
            case(status)
                IDLE : if (i_req) status <= INIT;
              	INIT : if (din_reg[7]==1) status <= FIN;
                else status <= FIN;
                FIN : status <= IDLE; 
                default : status <= IDLE; 
            endcase
        end
    end 

    always @(*) begin
        case(status)
            IDLE : if (i_req) begin
                din_reg = din;
                neg = 0;
            end
            INIT : if (din_reg[7]==1) begin
                dout = din_reg>>>SLOPE;
                neg = 1;
            end
            else begin
                dout = din_reg;
                neg = 0;
            end
            FIN : begin
                dout = 0;
                din_reg = 0;
                neg = 0;
            end
            default : begin
                dout = 0;
                din_reg = 0;
                neg = 0;
            end
        endcase
    end


    `ifdef SIM
        initial begin
            din_reg = 0;
            status = IDLE;
            dout = 0;
            neg = 0;
        end
    `endif

endmodule