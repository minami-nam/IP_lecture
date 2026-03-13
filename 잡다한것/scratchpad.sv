module mdl (
    input clk,
    input rstn,
    input [7:0] dt_in,
    input [3:0] op,
    input i_req,
    input i_ack,
    

    output o_req,
    output [7:0] dt_out,
    output o_ack
);  
    parameter int IDLE = 0;
    parameter int FLT_IN = 1;
    parameter int DATA_IN = 2;
    parameter int INTERPOLATION = 3;
    parameter int CONV = 4;
    parameter int INIT = 5;

    parameter int FLT_SIZE = 3;
    parameter int PIX_WIDTH = 100;
    parameter int PIX_HEIGHT = 100;

    parameter int WIDTH_PW = $clog2(PIX_WIDTH);
    parameter int WIDTH_PH = $clog2(PIX_HEIGHT);

    parameter int PIXEL_INTERPOLATION = 1;
    parameter int FEATURE_EXTRACTION = 2;

    reg [7:0] flt_r[0:FLT_SIZE-1][0:FLT_SIZE-1];
    reg [7:0] pixel_r[0:PIX_WIDTH-1][0:PIX_HEIGHT-1];
    reg [2:0] state;
    reg [3:0] op_reg;
    reg busy;

    reg [WIDTH_PW-1:0] pw_cnt;
    reg [WIDTH_PH-1:0] ph_cnt;

    assign o_ack = !busy ? 1 : 0;
    reg i_ack_reg;

    always @(posedge clk or negedge rstn)   begin
        if (!rstn) begin
        end        

        else begin
            case(state)
                IDLE : if (i_req) begin
                        op_reg <= op;
                        busy <= 1;
                        state <= INIT;
                        pw_cnt <= 0;
                        ph_cnt <= 0;
                        o_req <= 1;
                    end

                FLT_IN : if (ph_cnt!=FLT_SIZE) begin
                            if (i_ack) begin 
                                i_ack_reg <= 1;
                                o_req <= 0;
                            end
                            if (i_ack_reg) begin
                                if (pw_cnt!=FLT_SIZE) begin
                                    flt_r[pw_cnt][ph_cnt] <= dt_in;
                                    pw_cnt <= pw_cnt+1;
                                end
                                else if (pw_cnt==FLT_SIZE) begin
                                    ph_cnt <= ph_cnt+1;
                                    pw_cnt <= 0;
                                end
                            end
                        end

                        else if (ph_cnt==FLT_SIZE) begin
                            state <= DATA_IN;
                            ph_cnt <= 0;
                            pw_cnt <= 0;
                            o_req <= 1;
                        end

                DATA_IN : if (ph_cnt!=PIX_HEIGHT) begin
                            if (i_ack) begin 
                                i_ack_reg <= 1;
                                o_req <= 0;
                            end

                            if (i_ack_reg) begin
                                if (pw_cnt!=PIX_WIDTH) begin
                                    pixel_r[pw_cnt][ph_cnt] <= dt_in;
                                    pw_cnt <= pw_cnt+1;
                                end
                                else if (pw_cnt==PIX_WIDTH) begin
                                    ph_cnt <= ph_cnt+1;
                                    pw_cnt <= 0;
                                end
                            end
                        end

                        else if (ph_cnt==PIX_HEIGHT) begin
                            if (op_reg==PIXEL_INTERPOLATION) begin
                                state <= INTERPOLATION;
                                ph_cnt <= 0;
                                pw_cnt <= 0;
                                i_ack_reg <= 0;
                            end 
                            else if (op_reg==FEATURE_EXTRACTION) begin
                                state <= CONV;
                                ph_cnt <= 0;
                                pw_cnt <= 0;
                                i_ack_reg <= 0;
                            end
                        end  

                INTERPOLATION :  
                CONV :
                INIT : if (op_reg==PIXEL_INTERPOLATION) state <= DATA_IN;
                       else if (op_reg==FEATURE_EXTRACTION) state <= FLT_IN; 
                default : 
            endcase 
        end
    end


endmodule