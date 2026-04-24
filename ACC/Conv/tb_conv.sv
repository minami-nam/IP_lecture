class random_value;
    rand bit [23:0] line_value;
    rand bit [23:0] weight_bias;

    constraint range_value {
        line_value[7:0] inside {[0:16]};
        line_value[15:8] inside {[0:16]};
        line_value[23:16] inside {[0:16]};

        weight_bias[7:0] inside {[0:14]};
        weight_bias[15:8] inside {[0:14]};
        weight_bias[23:16] inside {[0:14]};
    } 
    function new();
        
    endfunction //new()
endclass //random_value



module tb_unit_3mac;

    logic [23:0] line_value;
    logic [23:0] weight_bias;
    logic clk;
    logic rstn;
    logic in_valid;
    logic in_ready;

    logic [23:0] out_value;
    logic out_valid;
    logic out_ready; 

    localparam OFF = 1'b0;
    localparam ON = 1'b1;
    localparam int NUM_TEST = 100;

    initial clk = 0;
    always #2 clk = ~clk;

    initial begin
        rstn = OFF;
        repeat(2) @(posedge clk);
        rstn = ON;
    end

    

    unit_3mac dut(.*);  
    random_value rv;
    initial begin
        $display("Initializing...");
        rv = new();
        in_valid = OFF;
        out_ready = OFF;
        line_value = 24'h0;
        weight_bias = 24'h0;
        wait(rstn);
        out_ready = ON;
        in_valid = ON;
        for (int i=0; i<NUM_TEST; i++) begin
            if (!rv.randomize()) $display("Failed to Randomize");
            else $display("the %3dth test begins", i);

            line_value = rv.line_value;
            weight_bias = rv.weight_bias;

            $display("value 0 : %8h, value 1 : %8h, value 2 : %8h", line_value[23:16], line_value[15:8], line_value[7:0]);
            $display("weight 0 : %8h, weight 1 : %8h, weight 2 : %8h", weight_bias[23:16], weight_bias[15:8], weight_bias[7:0]);

            @(posedge clk);
        end
        
        #10;
        $display("Test Done.");
        $finish;
    end
    
    int rest;
    
    always @(posedge clk) begin
        if (out_valid) begin
            
            $display("the %3dth test done.", (rest+1));
            $display("result 0 : %8h, result 1 : %8h, result 2 : %8h", out_value[7:0], out_value[15:8], out_value[23:16]);
            rest <= rest+1;
        end 
    end
endmodule