module tb_SRAM;
    localparam P_WIDTH = 8;
    localparam P_DEPTH = 64;
    localparam P_ADDR = $clog2(P_DEPTH);

    reg   clk;
    reg   cs,we;
    reg   [P_ADDR-1:0] ad;
    reg   [P_WIDTH-1:0] din;

    wire  [P_WIDTH-1:0] dout;


    integer count;

    initial clk = 0;
    always #5 clk = ~clk;
    
    SRAM_wrapper #(P_WIDTH, P_DEPTH) sram_in(.clk(clk), .cs(cs), .we(we), .ad(ad), .din(din), .dout(dout));

    initial begin

        cs = 1'b0;
        we = 1'b0;
        ad = 0;
        din = 0;

        @(posedge clk);

        for (count=0; count<8; count=count+1)    begin
            cs = 1'b1;
            we = 1'b1; // write

            ad = count;
            din = 'h1+count;
            @(posedge clk);
        end

        cs = 0; 
        we = 0;

        for (count=0; count<8; count=count+1)   begin
            cs = 1'b1;
            we = 1'b0; // Read

            ad = count;
            @(posedge clk);
        end
        

        repeat (3)  @(posedge clk);
        $finish;
        


    end

    
endmodule