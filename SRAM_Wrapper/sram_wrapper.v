
`define FPGA   // Select Target to simulate / synthesis

module SRAM_wrapper #(
    parameter WIDTH = 8,
    parameter DEPTH = 64,
    parameter DEPTH_LOG = $clog2(DEPTH)
)(
    input   clk,
    input   cs,we,
    input   [DEPTH_LOG-1:0] ad,
    input   [WIDTH-1:0] din,

    output  [WIDTH-1:0] dout
);

    
    wire always0;
    assign always0 = cs && we;


    wire [WIDTH-1:0] memout_to_mux;
    wire [WIDTH-1:0] mux;

    reg [WIDTH-1:0] q;

    assign mux = cs ? memout_to_mux : q;
    assign dout = q;
    wire SCLR;
    assign SCLR = 1'h0;
    
    always @(posedge clk or posedge SCLR)   begin
        if (SCLR) begin
            q <= 0;
        end
        else begin
            if (cs && we)   q <= mux;
            else q <= q;
        end
    end
    
    


`ifdef FPGA // FPGA 
    
    sram_cell_8x64_fpga #(WIDTH, DEPTH) fpga_sram(.CLK0(clk),  .DATAIN(din),  .RADDR(ad), .WADDR(ad), .WE(always0), .DATAOUT(memout_to_mux), .ENA1(1'b1));

`elsif ASIC // ASIC

    sram_cell_8x64_asic asic_sram(.CLK0(clk), .DATAIN(din),  .RADDR(ad), .WADDR(ad), .WE(always0), .DATAOUT(memout_to_mux), .ENA1(1'b1));

`else   //SIM

    sram_cell_sim #(WIDTH, DEPTH) sim_sram(.CLK0(clk), .DATAIN(din), .RADDR(ad), .WADDR(ad), .WE(always0), .DATAOUT(memout_to_mux), .ENA1(1'b1));


`endif

endmodule

module sram_cell_8x64_fpga #(
    parameter WIDTH = 8,
    parameter DEPTH = 64,
    parameter DEPTH_LOG = $clog2(DEPTH)
)(
    input   CLK0,
    input   WE,
    input   ENA1,
    input   [DEPTH_LOG-1:0] RADDR,
    input   [DEPTH_LOG-1:0] WADDR,
    input   [WIDTH-1:0] DATAIN,

    output reg  [WIDTH-1:0] DATAOUT

);
    // 6T Cell 역할을 대신할 Reg 생성
    reg [WIDTH-1:0] mem[0:DEPTH-1];


    // 전체적인 동작 구현 (SYNC_RAM)
    always @(posedge CLK0)  begin
        if (ENA1) begin
            if (WE) mem[WADDR] <= DATAIN;   // SRAM에 Write
            else DATAOUT <= mem[RADDR]; // SRAM을 읽기
        end

        else DATAOUT <= 8'h0;   // ENA1==0 이면 R/W 금지.
    end

endmodule

module sram_cell_8x64_asic 
(
    input   CLK0,
    input   ENA1, WE,
    input   [5:0] RADDR,
    input   [5:0] WADDR,
    input   [7:0] DATAIN,

    output reg  [7:0] DATAOUT

);

    // 6T Cell 역할을 대신할 Reg 생성
    reg [7:0] mem[0:63];


    // 전체적인 동작 구현 (SYNC_RAM)
    always @(posedge CLK0)  begin
        if (ENA1) begin
            if (WE) mem[WADDR] <= DATAIN;   // SRAM에 Write
            else DATAOUT <= mem[RADDR]; // SRAM을 읽기
        end

        else DATAOUT <= 8'h0;   // ENA1==0 이면 R/W 금지.
    end

    
endmodule

module sram_cell_sim #(
    parameter WIDTH = 8,
    parameter DEPTH = 64,
    parameter DEPTH_LOG = $clog2(DEPTH)
)(
    input   CLK0,
    input   ENA1, WE,
    input   [5:0] RADDR,
    input   [5:0] WADDR,
    input   [7:0] DATAIN,

    output reg  [7:0] DATAOUT

);

    // 6T Cell 역할을 대신할 Reg 생성
    reg [WIDTH-1:0] mem[0:DEPTH-1];

    // SystemVerilog는 integer i라고 선언할 필요 없이 for 구문에서 바로 int i 선언 가능
    integer i;
    initial begin
        for (i=0; i<DEPTH; i=i+1)   begin
            mem[i] = 8'h0;
            DATAOUT[i] = 8'h0;
        end
    end

    // 전체적인 동작 구현 (SYNC_RAM)
    always @(posedge CLK0)  begin
        if (ENA1) begin
            if (WE) mem[WADDR] <= DATAIN;   // SRAM에 Write
            else DATAOUT <= mem[RADDR]; // SRAM을 읽기
        end

        else DATAOUT <= 8'h0;   // ENA1==0 이면 R/W 금지.
    end

    
endmodule