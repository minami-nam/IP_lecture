module io_dcache #(
    parameter ADDR_BIT = 32;
    parameter DATA_BIT = 32;
    parameter NUM_CACHE = 16;    
)(
    input [ADDR_BIT-1:0] i_raddr,

    input [ADDR_BIT-1:0] i_waddr,
    input [DATA_BIT-1:0] i_wdata,

    input clk,
    input rstn,

    input i_rvalid,
    output o_rready,

    input i_wvalid,
    output o_wready,

    output [DATA_BIT-1:0] o_rdata,
    output [1:0] o_rresp,

    output [1:0] o_wresp
);  
    reg [ADDR_BIT-1:0] reg_ADDR[0:NUM_CACHE-1];
    reg [DATA_BIT-1:0] reg_DATA[0:NUM_CACHE-1];

    reg [0:NUM_CACHE-1] reg_valid;

    wire cache_empty = !(|reg_valid);
    wire cache_full = (&reg_valid);

    wire r_out = i_rvalid & o_rready;
    wire w_in = i_wvalid & o_wready;
    
    // // Address에 해당하는 valid한 값이 Cache 내부에 있는지 function으로 알아내기
    // function automatic [$clog2(NUM_CACHE):0] match_addr;
    //     input [ADDR_BIT-1:0] addr;
    //     input [ADDR_BIT-1:0] target;
    //     input [$clog2(NUM_CACHE):0] index;
    //     begin
    //         match_addr = (addr==target) ? index : '0;
    //     end
    // endfunction

    // generate 구문 사용해서 Cache를 검사하는 회로를 분할하여 처리함.
    genvar i;
    genvar j;
    localparam int NUM_LOGIC = 4;
    localparam int NUM_GROUP = NUM_CACHE / NUM_LOGIC;

    reg [0:NUM_CACHE-1] match;



    // read 부분 match 되는지 검사하는 logic 생성.
    generate
        for (i=0; i<NUM_GROUP; i++) begin : instantiate_always_group
            always @(*) begin
                for (j=0; j<NUM_LOGIC; j++) begin : check_details
                    if (reg_valid[(4*i+j)] && (i_raddr==reg_ADDR[(4*i+j)])) begin   // Matching이 되는 무언가가 있을 경우
                        match[(4*i+j)] = '1;
                    end
                    else match[(4*i+j)] ='0;    // 없을 경우
                end
            end
        end
    endgenerate
    
    always @(*) begin
        if ()
    end



    // valid 관련 
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            
        end
        else begin  // valid의 case를 나누는 것도 방법이긴 한데 일단 이렇게 설계
            if (r_out & w_in) begin

            end
            else if (r_out) begin
                
            end 
            else if (w_in) begin
                
            end 
            else begin
                
            end   
        end
    end    


    // READ 
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            
        end
        else begin
            if (i_rvalid)        
        end
    end

    // WRITE
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            
        end
        else begin
            
        end
    end

endmodule