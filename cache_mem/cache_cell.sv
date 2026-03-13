module tpsram #(
    parameter WIDTH = 4,
    parameter DEPTH = 4,
    parameter MEM_ADDR = $clog2(DEPTH)    
)(
    input clk,
    input [WIDTH-1:0] wd,
    input [MEM_ADDR-1:0] ra,
    input [MEM_ADDR-1:0] wa,
    input we,
    input re,

    output reg [WIDTH-1:0] rd

);

    wire [WIDTH-1:0] cellout;

    always @(posedge clk) begin
        rd <= cellout;  // 1C Delay
    end

    mem_cell #(WIDTH, DEPTH) dut (.CLK0(clk), .DATAIN(wd), .RADDR(ra), .WADDR(wa), .WE(we), .RE(re),.DATAOUT(cellout));

endmodule




module  mem_cell #(
    parameter WIDTH = 4,
    parameter DEPTH = 4,
    parameter MEM_ADDR = $clog2(DEPTH)

)(
    input CLK0,
    input [WIDTH-1:0] DATAIN,
    input [MEM_ADDR-1:0] RADDR,
    input [MEM_ADDR-1:0] WADDR,
    input WE,
    input RE,
    output reg [WIDTH-1:0] DATAOUT

);
    reg [WIDTH-1:0] midreg[0:DEPTH-1];
    
    always @(posedge CLK0)  begin
        if (WE)  midreg[WADDR] <= DATAIN;
        
        if (RE) begin
            if (WE&&(RADDR==WADDR)) begin
                DATAOUT <= DATAIN;
            end
            else DATAOUT <= midreg[RADDR]; 
        end
    end

endmodule