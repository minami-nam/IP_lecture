`define ON 1
`define OFF 0

module tb_reg_file;
// reg_file만 test. reg_id는 진짜 별 기능 없어서 생략.
    logic [31:0] o_rd1;
    logic [31:0] o_rd2;

    logic clk;

    // PORT Connection

    typedef struct packed {
        logic [4:0] i_addr1;
        logic [4:0] i_addr2;
        logic [4:0] i_addr3;    // Write
        logic WE;
        logic [31:0] i_wd1;

    } i_reg_file_list;
    

    function automatic i_reg_file_list regfile_list(
        logic [4:0] i_addr1,
        logic [4:0] i_addr2,
        logic [4:0] i_addr3,    // Write
        logic WE,
        logic [31:0] i_wd1
    );
        regfile_list.i_addr1 = i_addr1;
        regfile_list.i_addr2 = i_addr2;
        regfile_list.i_addr3 = i_addr3;
        regfile_list.WE = WE;
        regfile_list.i_wd1 = i_wd1;

    endfunction

    i_reg_file_list regfile_input[3];
    i_reg_file_list tb_list;

    initial begin
        regfile_input[0] = regfile_list(0,1,3,`ON, 32'd128);
        regfile_input[1] = regfile_list(3,7,2,`ON, 32'd64);
        regfile_input[2] = regfile_list(3,2,0,`OFF, 32'd0);
    end

    // clk;
    initial clk = 0;
    always #2 clk = ~clk;
    reg_file dut(
        .i_addr1(tb_list.i_addr1),
        .i_addr2(tb_list.i_addr2),
        .i_addr3(tb_list.i_addr3),
        .WE(tb_list.WE),
        .i_wd1(tb_list.i_wd1),

        .clk(clk),

        .o_rd1(o_rd1),
        .o_rd2(o_rd2)
    );

    // test

    initial begin 

        tb_list = regfile_list(0,0,0,`OFF, 0);
        @(posedge clk);

        @(posedge clk);


        for (int i=0; i<3; i++) begin
            tb_list = regfile_input[i];
            @(posedge clk);
            #1;
            if (tb_list.WE==`ON)    $display("the value %8d write at addr %8d", dut.register[tb_list.i_addr3], tb_list.i_addr3);
            else $display("Read.... RD1 : %8d, RD2 : %8d.", o_rd1, o_rd2);
        end

        #10;
        $finish;


    end 







endmodule