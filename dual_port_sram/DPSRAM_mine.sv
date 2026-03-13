// Code your design here
`define FPGA // SIM or Anything else.

module dpsram #(
    parameter int DEPTH = 8,
    parameter int WIDTH = 32,
    parameter int DEPTH_LOG = $clog2(DEPTH) 
)(
    // input 
    input   [WIDTH-1:0]     din_a, 
    input   [DEPTH_LOG-1:0]addr_a, 
    input                    we_a,
    input                    cs_a, 

    input                     clk,

    input   [DEPTH_LOG-1:0]addr_b, 
    input   [WIDTH-1:0]     din_b, 
    input                    we_b,
    input                    cs_b, 
    
    // output
    output reg [WIDTH-1:0]    dout_a,
    output reg [WIDTH-1:0]    dout_b
);

    reg [WIDTH-1:0] dff[0:DEPTH-1];
    wire [1:0]  we;
    assign we = {we_a, we_b};

    wire addr_match = (addr_a == addr_b);

    always @(posedge clk) begin // WRITE      
        if (cs_a&&we_a) begin 
            dff[addr_a] <= din_a;
        end
        if (cs_b&&we_b)   begin  // Priority 설정 : Port A에 우선권 부여
            if (!addr_match||!(cs_a&&we_a))    dff[addr_b] <= din_b;      
        end
    end
    

    always @(posedge clk) begin // READ
        if ((cs_a&&cs_b)&&addr_match) begin
            case(we)
                2'd0 : begin
                    dout_a <= dff[addr_a];
                    dout_b <= dff[addr_b];
                end

                2'd1 :     dout_a <= din_b;
                2'd2 :     dout_b <= din_a;
                default : ;

            endcase

        end


        else begin
            if (cs_a&&!we_a)  dout_a <= dff[addr_a]; 
            if (cs_b&&!we_b)  dout_b <= dff[addr_b];
        end
    end



    `ifdef SIM 
        initial begin
          	dout_a = 0;
          	dout_b = 0;
            for (int i=0; i<DEPTH; i++) begin   // Simulation을 위하여 Cell을 초기화시키는 과정 삽입. 합성에서는 동기화된 RST 사용은 수많은 LUT 사용을 유발할 수 있으니 주의.
                dff[i] = 'h0;
            end 
        end
    `endif
endmodule
