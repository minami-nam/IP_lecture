`define SIM    // For Simulation
module ddrctl_v2 (
    input	clk, rstn,	
	input			i_req,
	output			o_ack,
	input			i_write,
	input [7:0]		i_addr,
	input [63:0]	i_wdata,
	output			o_rd_en,
	output [63:0] 	o_rdata,


	output			ck_t, ck_c,
	output reg		cke,
	output reg		csn, actn,
	output reg	[1:0]	bg, ba, 
	output reg	[17:0]  a,	//rasn 16, casn 15, wen 14, bcn 12, ap 10


	inout [7:0]		dq,
	inout			dqs_t, dqs_c
);
    localparam	INIT=0,MRS=1,IDLE=2,ACT=3,WR=4,RD=5,PRE=6;
	parameter	tRCD=9,tCWL=11,tCL=10,tRP=8;

    reg [2:0] c_state;
    reg [7:0] addr_reg;
    reg [4:0] cnt;
    reg [2:0] data_cnt;
    reg [63:0] data_reg;
    reg start;
    reg start_reg;
    reg write_op;
    reg o_ack_reg;

    wire dq_oe;
    wire [7:0] dq_r;
    wire [7:0] dq_w;
    wire dqs_t_delay;

    assign ck_t = cke ? clk : 1'b0;
    assign ck_c = cke ? ~clk : 1'b0;
    assign o_ack = o_ack_reg;
    
    assign dqs_t = (write_op && start) ? ck_t : 'hz;
    assign dqs_c = (write_op && start) ? ck_c : 'hz;
    assign dq_oe = (c_state==WR && start);
    assign dqs_t_delay = (write_op && start_reg) ? ck_t : 'hz;
    

    dram dram(.*);
    reg [2:0] n_state;

    // FSM 
    always @(posedge clk or negedge rstn) begin
        if (!rstn) c_state <= INIT;
        else       c_state <= n_state;
    end

    always @(*) begin
        if (rstn) begin
            case(c_state)
                INIT : if (i_addr == 8'hFF) n_state = MRS; 
                MRS  : if (cnt >= 4)        n_state = IDLE; 
                IDLE : if (i_req)           n_state = ACT;
                ACT  : if (cnt >= tRCD)     n_state = write_op ? WR : RD;
                WR   : if (cnt >= tCWL+8)   n_state = PRE;
                RD   : if (cnt >= tCL+8)    n_state = PRE;
                PRE  : if (cnt >= tRP)    n_state = IDLE;
            endcase
        end
    end

    always @(posedge ck_t or negedge rstn) begin
        if (!rstn) cnt <= 0;
        else begin
            if (c_state != n_state) // next_state를 사용하거나 아래처럼 구현
                cnt <= 0;
            else 
                cnt <= cnt + 1;
        end
    end
    
    always @(posedge ck_t) begin
        start_reg <= start;
    end

    always @(posedge dqs_t_delay) begin // Delay
        if (c_state==WR && cnt>tCWL) data_cnt <= data_cnt+1;
        else if (c_state==RD && cnt>tCL) data_cnt <= data_cnt+1;
        else if (data_cnt==7) data_cnt <= 0;    // Bankarray / Bankgroup에 따라 해당 값 수정 (parameter화 필요.)
        else data_cnt <= 0;
    end

    always @(posedge ck_t or negedge rstn) begin
        if (!rstn) start <= 0;
        else begin
            if ((c_state == WR && cnt == tCWL-1) || (c_state == RD && cnt == tCL-1))
                start <= 1;
            else if (data_cnt==7) 
                start <= 0;
        end
    end



    // o_rd_en 관련
    reg o_rd_en_reg;

    always @(posedge ck_t) begin
        if (c_state==RD && cnt == tCL+8) o_rd_en_reg <= 1;
        else if (c_state==IDLE || c_state == ACT) o_rd_en_reg <= 0;
    end

    wire [7:0] split_wire;
    assign split_wire = (dq_oe) ? (data_reg >> (8 * data_cnt)) : 8'h00;  // 수정 사항 기록
    assign dq_r = dq;   
    assign o_rd_en = o_rd_en_reg;
    assign o_rdata = o_rd_en ? data_reg : 64'h0;
    assign dq_w = split_wire;
    assign dq = dq_oe ? dq_w : 'hz; 

    // Address Timing 관련
    always @(posedge ck_t) begin
        if (c_state==MRS) addr_reg <= i_addr;
        if (c_state == IDLE && i_req) begin // IDLE에서 요청을 받는 순간
            write_op <= i_write;
        end
        if (c_state==ACT & cnt==0) begin
            addr_reg <= i_addr;  //  row
        end
        else if ((c_state==WR || c_state==RD) & cnt==0) addr_reg <= i_addr; // col 
    end

    // Datapath Timing 관련
    always @(posedge ck_t) begin
        if (c_state==RD && start) begin
            data_reg <= {dq_r, data_reg[63:8]};
        end
        else if (c_state==ACT) data_reg <= i_wdata;
    end


    // 출력 관련 Combinational Logic
    always @(*) begin
        case(c_state)
            INIT: begin cke = 0; csn = 1; actn = 1; a = 0; bg = 0; ba = 0; end
            MRS : begin a = {1'b0, 3'b000, 6'b000001, addr_reg}; ba = 2'b00; bg = 0; cke = 1; csn = 0; actn = 1; end  // 이 부분은 나중에 필요하면 MRS 기능에 맞추어 수정이 가능함.
            IDLE: begin a = {1'b0, 3'b111, 14'b0}; csn = 1;  actn = 1; bg = 0; ba = 0; cke = 1; end
            ACT : begin a = {1'b0, 3'b111, 6'b0, addr_reg}; actn = 0; bg = 0; ba = 0; cke = 1; csn = 0; end
            WR  : begin a = {1'b0, 3'b100, 6'b0, addr_reg}; bg = 0; ba = 0; cke = 1; csn = 0; actn = 1; end
            RD  : begin a = {1'b0, 3'b101, 6'b0, addr_reg}; bg = 0; ba = 0; cke = 1; csn = 0; actn = 1; end
            PRE : begin a = {1'b0, 3'b111, 14'b0}; csn = 1; actn = 1; a = 0; bg = 0; ba = 0; cke = 1; end
        endcase
    end
    // o_ack
    always @(posedge clk) begin
        if (i_req) o_ack_reg <= 1;
        else o_ack_reg <= 0;
    end    

    `ifdef SIM 
        initial begin
            o_rd_en_reg = 0;
            c_state = 0;
            addr_reg = 0;
            cnt = 0;
            data_cnt = 0;
            data_reg = 0;
            start = 0;
            cke = 0;
            write_op = 0;
            csn = 0;
            actn = 0;
            bg = 0; 
            ba = 0;
            a = 0;
            n_state = 0;
            o_ack_reg = 0;
        end
    `endif
endmodule

/// dram ///
module dram(
	input		ck_t, ck_c,
	input		cke,
	input		csn, actn,
	input [1:0]	bg, ba,
	input [17:0] a,	//rasn 16, casn 15, wen 14, bcn 12, ap 10

	inout [7:0]	dq,
	inout		dqs_t, dqs_c
);
	parameter [4:0] ACT=5'b00111, WR=5'b01100, RD=5'b01101,MRS=5'b01000;	//opcode
	parameter	tRCD=9;
    parameter   tRP=8;
	
	reg  [3:0]	tCWL; 
    reg  [3:0]   tCL;
	wire	rasn = a[16];
	wire	casn = a[15];
	wire	wen  = a[14];

	wire [4:0] opcode = {csn,actn,rasn,casn,wen};

	reg [3:0] 	row, col;
	reg 		write_op, read_op;
	reg [4:0] 	cnt;
	reg [63:0] 	curr_data;
	reg 		data_write;

	reg  [7:0] 	dq_o;
	wire		dq_oe;
	wire [7:0] 	dq_i;

	assign dq = dq_oe ? dq_o: 'bZ;
	assign dq_i = dq;

	reg [63:0] mem[15:0][15:0];

	always @(posedge ck_t) begin
		case (opcode) 
			ACT: 	row <= a[3:0];
			WR,RD: 	col <= a[3:0];
		endcase
	end

	always @(posedge ck_t) begin
			 if (opcode == ACT) write_op <= 0;
		else if (opcode == WR)  write_op <= 1;
		else if (cnt == tCWL+8) write_op <= 0;

			 if (opcode == ACT) read_op <= 0;
		else if (opcode == RD)  read_op <= 1;
		else if (cnt == tCL+8) read_op <= 0;
	end

	always @(posedge ck_t)
			 if (opcode == ACT) cnt <= 0;
		else if (write_op) cnt <= cnt == tCWL+8? 0: cnt + 1;
		else if (read_op)  cnt <= cnt == tCL+8? 0: cnt + 1;

       // Synthesis 문제 때문에 dqs_t 하나의 posedge만 감지하는 방법을 사용하려 함. (물론 원래는 dqs의 모든 edge를 검출하는게 맞음.) 

	always @(posedge dqs_t)
		if (cnt == tCWL) 	curr_data[ 7:0 ] <= dq_i;
        else if (cnt == tCWL+1) 	curr_data[15:8 ] <= dq_i;
		else if (cnt == tCWL+2) 	curr_data[23:16] <= dq_i;
        else if (cnt == tCWL+3) 	curr_data[31:24] <= dq_i;
		else if (cnt == tCWL+4) 	curr_data[39:32] <= dq_i;
        else if (cnt == tCWL+5) 	curr_data[47:40] <= dq_i;
		else if (cnt == tCWL+6) 	curr_data[55:48] <= dq_i;
        else if (cnt == tCWL+7) 	curr_data[63:56] <= dq_i;

	always @(posedge ck_t)
		if (write_op && cnt == tCWL+8) data_write <= 1;
		else data_write <= 0;


	always @(posedge ck_t)
		if (data_write) mem[row][col] <= curr_data;

	assign dqs_t = dq_oe ? ck_t : 'bZ;
	assign dqs_c = dq_oe ? ck_c : 'bZ;
	assign dq_oe = read_op && (cnt >= tCL && cnt <= tCL+7);

	wire [63:0] read_data = mem[row][col];	

	always @(posedge dqs_t) begin
		if (read_op) begin
            if (cnt == tCL) 	    dq_o <= read_data[ 7:0 ];
            else if (cnt == tCL+1) 	dq_o <= read_data[15:8 ];
            else if (cnt == tCL+2) 	dq_o <= read_data[23:16];
            else if (cnt == tCL+3) 	dq_o <= read_data[31:24];
            else if (cnt == tCL+4) 	dq_o <= read_data[39:32];
            else if (cnt == tCL+5) 	dq_o <= read_data[47:40];
            else if (cnt == tCL+6) 	dq_o <= read_data[55:48];
            else if (cnt == tCL+7) 	dq_o <= read_data[63:56];
        end 
	end

	always @(posedge ck_t)
		if (opcode == MRS) begin
			if ({bg[0],ba} == 0) begin
                tCL = {a[6:4],a[2]} == 'b0001 ? 10: 9;
                tCWL = a[9:7] == 'b010 ? 11: 10;
            end
		end




    `ifdef SIM
        initial begin
            for (int i=0; i<16; i++) begin
                for (int j=0; j<16; j++) begin
                    mem[i][j] = 0;
                end
            end
            row = 0;
            col = 0;
            write_op = 0; 
            read_op = 0;
            cnt = 0;
            curr_data = 0;
            data_write = 0;
            dq_o = 0;


        end
    `endif
endmodule