`define SIM

module ddr_ctrl #(
    parameter   BANKGROUP_NUM = 6,
    parameter   BANKARRAY_NUM = 6,
    parameter   WIDTH_BG = $clog2((BANKGROUP_NUM-1)),
    parameter   WIDTH_BA = $clog2((BANKARRAY_NUM-1)),
    parameter   WIDTH_ADDR = WIDTH_BA + WIDTH_BG + 8
)(
	input	clk, rstn,	
	input			i_req,
	output reg			o_ack,
	input			i_write,
	input [WIDTH_ADDR-1:0]	    i_addr,
	input [63:0]	i_wdata,
	output			o_rd_en,
	output [63:0] 	o_rdata,
	output			ck_t, ck_c,
	output reg		cke,
	output reg		csn, actn,
	output reg	[WIDTH_BG-1:0]	bg, 
    output reg  [WIDTH_BA-1:0]  ba,
	output reg	[17:0]  a,
    output  [2:0] current_phase_out,
	inout [7:0]		dq,
	inout			dqs_t, dqs_c
);
	parameter	INIT=0,MRS=1,IDLE=2,ACT=3,WR=4,RD=5,PRE=6;
	parameter	tRCD=9,tCWL=11,tCL=10,tRP=8;
	parameter 	phase_bit=$clog2(7);

    reg  [phase_bit-1:0] current_phase;
    assign current_phase_out = current_phase;
    reg  [5:0] cnt; // 카운터 범위를 조금 더 넓힘
    reg  [3:0] data_cnt;
    reg  [WIDTH_ADDR-1:0]	addr_reg;
    reg  [63:0] w_reg_data, r_reg_data;
    reg MRS_flag, rstart;
    reg i_req_reg, i_write_reg;
    reg [5:0] tCL_reg, tCWL_reg, tRCD_reg, tRP_reg;

    wire [3:0] w_row, w_col;
    wire [WIDTH_BG-1:0] w_bg; 
    wire [WIDTH_BA-1:0] w_ba; 
    assign {w_row, w_col, w_bg, w_ba} = addr_reg;
    assign ck_t = clk;
    assign ck_c = ~ck_t;

    wire [7:0] w_data[7:0];
    assign {w_data[7], w_data[6], w_data[5], w_data[4], w_data[3], w_data[2], w_data[1], w_data[0]} = w_reg_data;

    wire [7:0] dqw_data;
    assign dqw_data = (i_write_reg && rstart) ? w_data[data_cnt[2:0]] : 8'hzz;
    assign o_rd_en = (current_phase == RD && cnt >= tCL_reg && cnt < tCL_reg + 8); 
    assign dqs_t = (i_write_reg && rstart) ? ck_t : 1'bz; 
    assign dqs_c = (i_write_reg && rstart) ? ck_c : 1'bz;
    assign dq = (i_write_reg && rstart) ? dqw_data : 8'bz;
    assign o_rdata = r_reg_data;

    dram_interface_fix #(    
        .DQ(8), .BG(BANKGROUP_NUM), .BA(BANKARRAY_NUM),
        .tRCD(tRCD), .tRP(tRP), .tCL(tCL), .tCWL(tCWL))  
    dram_cell ( .ck_c(ck_c), .ck_t(ck_t), .cke(cke), .csn(csn), .actn(actn), 
                .bg(bg), .ba(ba), .a(a), .dq(dq), .dqs_c(dqs_c), .dqs_t(dqs_t) );

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            current_phase <= 0; cnt <= 0; data_cnt <= 0; MRS_flag <= 0;
        end else begin
            case(current_phase)
                INIT : if (i_addr==14'h3FAB) current_phase <= MRS;
                MRS : if (MRS_flag==0) MRS_flag <= 1;
                      else begin
                          tCL_reg <= tCL; tCWL_reg <= tCWL; tRCD_reg <= tRCD; tRP_reg <= tRP;
                          current_phase <= IDLE; r_reg_data <= 0; w_reg_data <= 0; rstart <= 0;
                      end
                IDLE : if (i_req ^ i_write) begin
                            i_req_reg <= i_req; i_write_reg <= i_write; addr_reg <= i_addr;
                            current_phase <= ACT; cnt <= 0; data_cnt <= 0; o_ack <= 0; rstart <= 0;
                       end
                ACT : begin
                    cnt <= cnt+1;
                    if (cnt==tRCD_reg-1) begin
                        cnt <= 0;
                        if (i_req_reg) current_phase <= RD;
                        else if (i_write_reg) begin
                            current_phase <= WR; w_reg_data <= i_wdata;
                        end
                    end
                end
                WR, RD: begin
                    cnt <= cnt + 1;
                    if (current_phase==WR) begin
                        if (cnt == tCWL_reg - 1) rstart <= 1;
                        if (rstart && data_cnt < 8) data_cnt <= data_cnt + 1;
                        if (cnt == tCWL_reg + 7) begin
                            cnt <= 0; rstart <= 0; data_cnt <= 0; current_phase <= PRE;
                        end
                    end else begin // RD
                        if (cnt >= tCL_reg && data_cnt < 8) begin
                            data_cnt <= data_cnt + 1;
                            r_reg_data <= {dq, r_reg_data[63:8]};
                        end
                        if (cnt == tCL_reg + 7) begin
                            cnt <= 0; data_cnt <= 0; current_phase <= PRE; o_ack <= 1; // 완료 시점에 ack
                        end
                    end
                end
                PRE : begin
                    cnt <= cnt+1; o_ack <= 0;
                    if (cnt==tRP_reg-1) begin
                        cnt <= 0; if (MRS_flag!=0) MRS_flag <= 0; current_phase <= IDLE;
                    end
                end
                default : current_phase <= INIT;
            endcase
        end
    end

    always @(*) begin
        case(current_phase)
            INIT : begin cke=0; csn=1; actn=1; bg=0; ba=0; a=0; end 
            MRS  : begin a=0; cke=1; actn=1; csn=0; end
            IDLE : begin cke=1; csn=1; actn=1; a={1'b0, 3'b111, 14'b0}; end
            ACT  : begin cke=1; actn=0; bg=w_bg; ba=w_ba; a={1'b0, 3'b111, addr_reg[13:10], 4'b0, addr_reg[5:0]}; csn=0; end
            WR   : begin cke=1; bg=w_bg; ba=w_ba; a={1'b0, 3'b100, 4'b0, addr_reg[9:6], 6'b0}; actn=1; csn=0; end
            RD   : begin cke=1; bg=w_bg; ba=w_ba; a={1'b0, 3'b101, 4'b0, addr_reg[9:6], 6'b0}; actn=1; csn=0; end
            PRE  : begin cke=1; bg=w_bg; ba=w_ba; a={1'b0, 3'b111, 14'b0}; actn=1; csn=0; end
        endcase
    end
endmodule

module dram_interface_fix #(
    parameter DQ=8, BG=6, BA=6, tRCD=9, tRP=8, tCL=2, tCWL=1
)(
    input ck_t, ck_c, cke, csn, actn,
    input [$clog2(BG)-1:0] bg, input [$clog2(BA)-1:0] ba, input [17:0] a,
    inout [7:0] dq, inout dqs_t, dqs_c
);  
    localparam [4:0] ACT=5'b00111, CMD_WR=5'b01100, CMD_RD=5'b01101, MRS=5'b01000, PRECHARGE=5'b01111;  
    wire [4:0] opcode = {csn, actn, a[16], a[15], a[14]};
    reg read_op, write_op, start;
    wire read_start = read_op && start;
    wire write_start = write_op && start;
    reg [4:0] opcode_reg;
    reg [$clog2(BG)-1:0] bg_reg; reg [$clog2(BA)-1:0] ba_reg;
    reg [3:0] row_reg; // Row 주소 래치용
    wire [3:0] row = a[13:10], col = a[9:6];

    reg [7:0] dq_o;
    wire dq_oe = read_start;
    assign dqs_t = dq_oe ? ck_t : 'hz;
    assign dqs_c = dq_oe ? ck_c : 'hz;
    assign dq = dq_oe ? dq_o : 'hz;

    reg [5:0] cnt;
    reg [63:0] mem[0:15][0:15][0:BG-1][0:BA-1];
    reg [3:0] cnt_out;

    always @(posedge ck_t) begin
        opcode_reg <= opcode;
        if (opcode==ACT) begin
            bg_reg <= bg; ba_reg <= ba; row_reg <= row; cnt <= 0;
        end else if (opcode_reg==ACT && cnt < tRCD) cnt <= cnt+1;

        if (opcode==CMD_WR && !write_op) begin cnt <= 0; write_op <= 1; end
        else if (write_op && !start) begin
            cnt <= cnt + 1; if (cnt == tCWL-1) begin cnt <= 0; start <= 1; end
        end

        if (opcode==CMD_RD && !read_op) begin cnt <= 0; read_op <= 1; end
        else if (read_op && !start) begin
            cnt <= cnt + 1; if (cnt == tCL-1) begin cnt <= 0; start <= 1; end
        end

        if (start) begin
            if (write_start) mem[row_reg][col][bg_reg][ba_reg][8*cnt_out +: 8] <= dq;
            if (read_start) dq_o <= mem[row_reg][col][bg_reg][ba_reg][8*cnt_out +: 8];
            cnt_out <= cnt_out + 1;
            if (cnt_out == 7) begin start <= 0; read_op <= 0; write_op <= 0; cnt_out <= 0; end
        end

        if (opcode==PRECHARGE) begin read_op <= 0; write_op <= 0; start <= 0; end
    end

    initial begin
        for (int i=0; i<16; i++) for (int j=0; j<16; j++)
        for (int k=0; k<BG; k++) for (int l=0; l<BA; l++) mem[i][j][k][l] = 0;
        cnt_out = 0; read_op = 0; write_op = 0; start = 0;
    end
endmodule