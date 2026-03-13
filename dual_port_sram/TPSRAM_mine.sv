`define SIM // SIM 모드 설정 가능

module tpsram #(
    parameter int DEPTH = 8,
    parameter int WIDTH = 32,
    parameter int DEPTH_LOG = $clog2(DEPTH) 
)(
    input clk,
    input [WIDTH-1:0] wd,
    input [DEPTH_LOG-1:0] ra,
    input [DEPTH_LOG-1:0] wa,
    input we,
    input re,

    output reg [WIDTH-1:0] rd
);

    reg [WIDTH-1:0] dff[0:DEPTH-1];

    always @(posedge clk) begin
        if (we) begin
            dff[wa] <= wd;
        end

        if (re) begin
            if (we && (ra==wa)) begin
                rd <= wd;
            end else begin
                rd <= dff[ra];
            end
        end
    end


    `ifdef SIM 
        initial begin
          	rd = 0;
            for (int i=0; i<DEPTH; i++) begin   // Simulation을 위하여 Cell을 초기화시키는 과정 삽입. 합성에서는 동기화된 RST 사용은 수많은 LUT 사용을 유발할 수 있으니 주의.
                dff[i] = 'h0;
            end 
        end
    `endif
endmodule

