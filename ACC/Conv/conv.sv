


`define FPGA

module unit_3mac(
    input [23:0] line_value,
    input [23:0] weight_bias,
    input clk,
    input rstn,
    input in_valid,
    output in_ready,

    output reg [23:0] out_value,
    output out_valid,
    input out_ready
);  
    localparam OFF = 1'b0;
    localparam ON = 1'b1;

    reg get_en;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) get_en <= OFF;
        else begin
            if (in_valid) get_en <= ON;
            else get_en <= OFF;
        end
    end

    assign in_ready = 1'b1;
    reg on_calc;
    reg on_send;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            on_calc <= OFF;
            on_send <= OFF;            
        end
        else begin
            if ((out_ready&out_valid)|!on_send) begin   // 주의!
                on_calc <= get_en;
                on_send <= on_calc;
            end
        end       
    end

    reg [7:0] w_bias[0:2];
    reg [7:0] c_value[0:2];

    wire [7:0] mul[0:2];

    genvar i;
    generate 
        for (i=0; i<3; i++) begin : mul_assigned 
            assign mul[i] = w_bias[i] * c_value[i];
        end
    endgenerate

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            w_bias[0] <= 'h00;
            w_bias[1] <= 'h00;
            w_bias[2] <= 'h00;

            c_value[0] <= 'h00;
            c_value[1] <= 'h00;
            c_value[2] <= 'h00;          
        end

        else begin
            if (get_en) begin
                w_bias[0] <= weight_bias[7:0];
                w_bias[1] <= weight_bias[15:8];
                w_bias[2] <= weight_bias[23:16];

                c_value[0] <= line_value[7:0];
                c_value[1] <= line_value[15:8];
                c_value[2] <= line_value[23:16];                 
            end
        end
    end

    assign out_valid = (out_ready & on_send) ? ON : OFF;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) out_value <= 24'h00_0000;
        else begin
            if (on_calc) out_value <= {mul[0], mul[1], mul[2]};
            else out_value <= 24'h00_0000;
        end
    end

    `ifdef SIM
        initial begin
            for (int i=0; i<3; i++) begin
                w_bias[i] = 0;
                c_value[i] = 0;
            end
            out_value = 0;
            get_en = 0;
            on_calc = 0;
            on_send = 0;
        end
    `endif
endmodule