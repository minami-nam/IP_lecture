
// Direct-mapped Cache memory 설계 

module cache_256B #(
    parameter int MEM_SIZE = 256,   // Memory의 Size                    2 Tag bits (8-2-4)
    parameter int BLK_SIZE = 4,     // Block의 Size                     2 offset bits
    parameter int CACHE_SIZE = 16,  // Cache의 Size                     4 index bits
    
    parameter int INDEX = $clog2(CACHE_SIZE),
    parameter int OFFSET = $clog2(BLK_SIZE),
    parameter int TAG = ADDR_WIDTH - INDEX - OFFSET,

    parameter int DATA_WIDTH = BLK_SIZE*8,          // bit로 계산해서 판단해야 함. BLK Size가 하나의 Cacheline에 몇 개의 DATA가 저장될 수 있는가를 설정하는 것.
    parameter int ADDR_WIDTH = $clog2(MEM_SIZE),    
    parameter int CELL_DEPTH = CACHE_SIZE,          // index가 가리킬 수 있는 총 line 수. Direct Mapped라서 그냥 CACHE SIZE로 바로 삽입함.

    parameter int COUNTER = 10,                     // 해당 숫자에 해당되는 CLK가 지난 이후에는 Counter가 증가하지 않음.
    parameter int BIT_COUNTER = $clog2(COUNTER),
    parameter int BIT_TABLE = TAG + BIT_COUNTER     // Table의 전체 bit 수를 반환함.
)(
    // CLK, Reset
    input clk, rst_n,

    // CPU - Cache 간 통신 관련
    input             i_cpu_req, i_cpu_write,              // CPU로부터 req / write 신호를 받음.
    input    [DATA_WIDTH-1:0]    i_cpu_wdata,              // CPU으로부터 DATA를 읽어와 Cell에 써야 함.
    input    [ADDR_WIDTH-1:0]    i_cpu_addr,               // CPU으로부터 Memory의 어느 주소에 쓰기를 할 것인지를 결정하는 해당 값을 사용하여 Cache HIT/MISS 여부 확인.
    output reg  [DATA_WIDTH-1:0]    o_cpu_rdata,              // CPU에게 전달해야 할 Data가 출력되는 port   
          

    // Cache - DRAM(Memory)간 통신 관련
    input                    i_mem_ack,                    // DRAM으로부터 ack 신호를 받음.
    input   [DATA_WIDTH-1:0] i_mem_rdata,                  // DRAM 내부의 정보 들고 와야하므로 입력으로 설정.
    input   [ADDR_WIDTH-1:0] i_mem_raddr,             
    output reg [DATA_WIDTH-1:0] o_mem_wdata,                  // CPU가 요청시 Memory의 특정 addr에 저장된 Data를 Update 시켜줘야 함.
    output reg [ADDR_WIDTH-1:0] o_mem_waddr                                            
                                           
);
    
    // Address 입력 신호의 분리. Tag + Index + Offset 형태로 구성됨.

    wire    [INDEX-1:0] index_addr;
    wire    [OFFSET-1:0] offset_addr;
    wire    [TAG-1:0] tag_addr;


    wire    [INDEX-1:0] index_addr_mem;
    wire    [OFFSET-1:0] offset_addr_mem;
    wire    [TAG-1:0] tag_addr_mem;

    assign {tag_addr, index_addr, offset_addr} = i_cpu_addr;
    assign {tag_addr_mem, index_addr_mem, offset_addr_mem} = i_mem_raddr;

    // Vaild, Tag 확인 가능한 Table을 생성함. 최상위 비트는 Vaild Bit로 설정하여 (Vaild + Counter + Tag) 구조 채택.
    reg         [BIT_TABLE:0] table_reg[0:CELL_DEPTH-1];   

    // Match 되는지, Vaild한지 확인해야 하므로, reg에서 신호 따로 빼서 생성함.
    wire        table_vaild[0:CELL_DEPTH-1];
    wire        [BIT_COUNTER-1:0] table_counter[0:CELL_DEPTH-1];
    wire        [TAG-1:0] table_tag[0:CELL_DEPTH-1];

    // generate 사용해서 각 index 별로 신호 출력 설정.
    genvar j;
    generate
        for (j=0; j<CELL_DEPTH; j++) begin : table_assign
            assign {table_vaild[j], table_counter[j], table_tag[j]} = table_reg[j];
        end
    endgenerate

    // Cache HIT/MISS 판별
    wire cache_HM;
    assign cache_HM = (tag_addr==table_tag[index_addr]) ? 1 : 0;    // 1 hit, 0 miss 

    // FSM이 필요한 것으로 판단되어 State가 필요함.
    reg [3:0]   now_state, next_state;
    

    //  공통 state
    localparam IDLE = 4'h0;

    //  Read의 경우
    localparam CACHE_CHECK = 4'h1;
    localparam READ_WAIT1 = 4'h2;
    localparam READ_WAIT2 = 4'h3;
    localparam SEND_CPU = 4'h4;

    localparam NEED_READ_DRAM = 4'h5;
    
    //  Write의 경우
    localparam WRITE_UPDATE_CACHE = 4'h6;
    localparam NEED_WRITE_DRAM = 4'h7;


    // TPSRAM 모듈을 위한 wire 준비

    wire [DATA_WIDTH-1:0] write_data_cache_w;
    wire [DATA_WIDTH-1:0] read_data_cache_w;



    wire we, re;
    assign we = !(cache_HM&&table_vaild[index_addr]) || i_cpu_write;       //  NEED_READ_DRAM 조건에 CPU가 직접 Writing하는 항목 추가.
    assign re = (cache_HM&&table_vaild[index_addr]) || !i_mem_ack;         //  READ_WAIT 조건에 mem ack가 0이면 read 하여 출력하는 항목임. 

    reg [ADDR_WIDTH-1:0] wa, ra;
    wire [ADDR_WIDTH-1:0] wa_w, ra_w;

    assign wa_w = wa;
    assign ra_w = ra;




    // Reset 등 Counter 부분을 일단 먼저 구현. REG를 Seq/Comb에서 동시에 사용하면 안 되기 때문에 아래에 조건 추가.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i=0; i<CELL_DEPTH; i++)  table_reg[i] <= 'h0; 
        end    

        else begin
            for (int i=0; i<CELL_DEPTH; i++)    begin
                if (table_vaild[i]==1)  begin
                    if (table_vaild[i]!=COUNTER)  table_reg[i][(TAG+BIT_COUNTER)-1:TAG] <= table_reg[i][(TAG+BIT_COUNTER)-1:TAG]+1; // Counter 갱신
                    else table_reg[i][(TAG+BIT_COUNTER)-1:TAG] <= table_reg[i][(TAG+BIT_COUNTER)-1:TAG];
                end
                else table_reg[i] <= 'h0;    // 유효하지 않은 값은 삭제.
            end

            if (i_cpu_req||i_cpu_write)  now_state <= next_state;     
            else    now_state <= IDLE;

            if ((next_state==NEED_READ_DRAM) || (next_state==WRITE_UPDATE_CACHE)) begin
                table_reg[index_addr] <= {1'b1, {(BIT_COUNTER-1){1'b0}}, 1'b1, tag_addr}; 
            end

        end
    end


    // FSM에 따라 Comb Logic의 출력을 결정할 것. 
    always @(*)  begin

        // 초기값을 미리 지정하고 시작하면서 Latch를 방지하기.
        next_state = now_state;
        ra = 'h0;
        wa = 'h0;
        o_cpu_rdata = 'h0;
        o_mem_waddr = 'h0;
        o_mem_wdata = 'h0;

        case(now_state)
            default : begin
                    if (i_cpu_req)  next_state = CACHE_CHECK;  // 계속 켜져있다면 다음으로 진행함.
                    else next_state = now_state; // 아니라면 이전 것을 계속 업데이트함.
                end
            CACHE_CHECK : begin 
                    if (cache_HM&&table_vaild[index_addr])   next_state = READ_WAIT1;       // Vaild하고 Hit -> 정상적으로 Read 과정 진행 가능.
                    else next_state = NEED_READ_DRAM;                                      // Invaild하거나, Miss인 경우 -> DRAM 참조해야 함.
                end
            READ_WAIT1 : begin
                    next_state = READ_WAIT2;
                    ra = index_addr;
                end 
            READ_WAIT2 : begin
                    o_cpu_rdata = read_data_cache_w;
                    next_state = SEND_CPU;                    
                end
            SEND_CPU : begin
                    if (!i_cpu_req) begin       // CPU가 더 이상 해당 값이 req하지 않다고 보내면 IDLE
                        next_state = IDLE;
                        ra = 'h0;
                        o_cpu_rdata = 0;
                    end
                    else next_state = SEND_CPU;    // 계속 필요하면 계속 공급해줌 (Pipelining 할 때는 수정해야함.)
                end
            NEED_READ_DRAM : begin
                    o_mem_waddr = i_cpu_addr;
                    o_mem_wdata = 'h0;
                    wa = i_mem_raddr;
                    if (i_mem_ack&&(next_state!=NEED_WRITE_DRAM))  begin       // DRAM에서 응답하면
                        o_cpu_rdata = i_mem_rdata; // Feed Forwarding
                        write_data_cache_w = i_mem_rdata;
                        next_state = SEND_CPU;
                        wa = 'h0;
                        o_mem_waddr = 'h0;
                    end
                    else next_state = NEED_READ_DRAM;

                end


            // WRITE
            WRITE_UPDATE_CACHE : begin
                if (i_cpu_write)  begin
                    write_data_cache_w = i_cpu_wdata; 
                    wa = index_addr;
                    next_state = NEED_WRITE_DRAM;
                end

                else next_state = WRITE_UPDATE_CACHE;
            end   

            NEED_WRITE_DRAM : begin
                if (!i_mem_ack)  begin   // update 우선
                    o_mem_wdata = i_cpu_wdata;
                    o_mem_waddr = i_cpu_addr;
                end
                else begin
                    wa = 0;
                    o_mem_waddr = 0;
                    o_mem_wdata = 0;
                    next_state = IDLE;
                end

            end
        endcase
    end









    // Module instance.
    tpsram #(DATA_WIDTH, CELL_DEPTH) sram_cell(
        .clk(clk),
        .wd(write_data_cache_w),  // data in (입력 받은 data write)
        .ra(ra_w),  // read address
        .wa(wa_w),  // write address
        .we(we),  // write enable
        .re(re),  // read enable

        .rd(read_data_cache_w)   // data out (cell에서 read한 data 출력)

    );



endmodule