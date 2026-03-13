`define SIM

module crc(
    input i_DV,
    input [7:0] i_Data,
    input rstn, clk,

    output [15:0] o_CRC,
    output [15:0] o_CRC_Xor,
    output [15:0] o_CRC_Xor_Reversed,
    output [15:0] o_CRC_Reversed
);
    localparam INIT=0;
    localparam IDLE=1;
    localparam CHECK=2;
    localparam DONE=3;
    localparam CCITT = 16'h1021;
    localparam CCITT_REV = 16'h8408;
    parameter WAIT_CLK = 4;

    reg [15:0] table_reg, table_rev_reg;
    reg [15:0] crc_reg, crc_rev_reg; 
    reg [7:0] input_reg;
    reg [7:0] res_reg, res_rev_reg;

    reg [4:0] cnt;
    reg [1:0] state, n_state; 
    reg done_reg;

    wire done;



    assign done = done_reg;

    // CNT 및 상태 전이
    always @(posedge clk or negedge rstn) begin
        if (!rstn) cnt <= 0;
        else begin
            if ((state!=n_state)||(state==IDLE)) begin
                cnt <= 0;
                state <= n_state;
            end
            else cnt <= cnt + 1;
        end
    end  

    // FSM out
    always @(*) begin
        case(state)
            INIT : if (cnt==4) n_state = IDLE; 
            IDLE : if (i_DV) n_state = CHECK;
            CHECK : if (done) n_state = DONE;
            DONE : if (cnt==WAIT_CLK) n_state = IDLE;
        endcase
    end 



    // output crc_reg

    assign o_CRC= crc_reg;
    assign o_CRC_Xor = (crc_reg ^ 16'hFFFF);
    always @(posedge clk) begin
        if (i_DV&&state==IDLE) begin
            input_reg <= i_Data;
            res_reg <= 0;
            table_reg <= 0;
            crc_reg <= 0;
        end
        else if (cnt==0 && state==CHECK) begin
            table_reg <= 16'h0000;
        end
        else if ((cnt<9&&cnt!=0) && state==CHECK) begin
            if (table_reg[15] ^ input_reg[8-cnt]) table_reg <= {table_reg[14:0], 1'b0} ^ CCITT;
            else table_reg <= {table_reg[14:0], 1'b0};
        end
        else if (cnt==9&&state==CHECK) begin
            crc_reg <= {table_reg};
            input_reg <= 0;
        end
    end 

    // output crc_rev_reg
    
    assign o_CRC_Reversed = crc_rev_reg;
    assign o_CRC_Xor_Reversed = (crc_rev_reg ^ 16'hFFFF);
    always @(posedge clk) begin
        if (i_DV&&state==IDLE) begin
            table_rev_reg <= 0;
            res_rev_reg <= 0;
            crc_rev_reg <= 0;
            done_reg <= 0;
        end
        else if (cnt==0 && state==CHECK) table_rev_reg <= 16'hFFFF;
        else if ((cnt<9&&cnt!=0) && state==CHECK) begin
            if (table_rev_reg[15] ^ input_reg[8-cnt]) table_rev_reg <= {table_rev_reg[14:0], 1'b0} ^ CCITT_REV;
            else table_rev_reg <= {table_rev_reg[14:0], 1'b0};
        end
        else if (cnt==9&&state==CHECK) begin
            crc_rev_reg <= {table_rev_reg};
            done_reg <= 1;
        end
    end
    
    `ifdef SIM
        initial begin
            table_reg = 0; 
            table_rev_reg = 0;
            crc_reg = 0; 
            crc_rev_reg = 0; 
            input_reg = 0;
            res_reg = 0; 
            res_rev_reg = 0;
            cnt = 0;
            state = 0; 
            n_state = 0; 
            done_reg = 0;
        end

    `endif

endmodule