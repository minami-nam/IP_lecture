module tb_mdl;

    parameter int WIDTH = 64;
    parameter int DATA = 8;
    parameter int ROW = 64;
    parameter int COL = 64;
    parameter int DQN = $clog2(WIDTH/DATA);
    parameter int DQ = WIDTH/DATA;
    
    parameter int ADDR_ROW = $clog2(ROW); 
    parameter int ADDR_COL = $clog2(COL);

    reg clk; 
    reg rst_n;
    reg r_req;
    reg w_req;
    logic [DATA-1:0]   dq;
    reg [DATA-1:0]   dq_reg;
    reg en;
    reg [(ADDR_ROW+ADDR_COL)-1:0] addr;

    wire busy;
    reg ready_receive;
    
    assign dq = (en) ? dq_reg : 'hz;

    initial clk=0;
    always #3 clk = ~clk;

    mdl #(.*) mdl_int(.*);

    initial begin
        rst_n = 1;
        r_req = 0;
        w_req = 0;
        dq_reg = 0;
        en = 0;
        addr = 0;
        ready_receive = 0;

        repeat(5) @(posedge clk);
        // Write
        w_req = 1;
        addr = 'habba;
        en = 1;

        @(posedge clk);
        dq_reg = 2;

        @(posedge clk);
        dq_reg = 4;

        
        @(posedge clk);
        dq_reg = 6;

        
        @(posedge clk);
        dq_reg = 8;

        
        @(posedge clk);
        dq_reg = 10;

        
        @(posedge clk);
        dq_reg = 12;

        
        @(posedge clk);
        dq_reg = 14;

        
        @(posedge clk);
        dq_reg = 16;

        // Read

        repeat(5) @(posedge clk);

        w_req = 0;
        r_req = 1;
        en = 0;
        ready_receive = 1;

        repeat(8) @(posedge clk);

        if (dq==16) begin
            $display("Reading TB Done!");
        end
        else $display ("Reading TB Failed.");

        #30;

        $finish;
    end 
    


endmodule