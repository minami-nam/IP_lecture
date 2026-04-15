`timescale 1ps/1ps
`define LB 0
`define LH 1
`define LW 2
`define LBU 4
`define LHU 5

module tb_mem_stage;
    logic  RegWriteM;
    logic  [1:0] ResultSrcM;
    logic  MemWriteM;
    logic  [4:0] RdM;
    logic  [31:0] PCPlus4M;
    logic  [31:0] WriteDataM;
    logic  [31:0] ALUResultM;
    logic [2:0] LS_opcodeM;
    logic  MemReadM;

    logic     clk; 
    logic     rstn;

    
    logic RegWriteW;
    logic [31:0] ResultW;
    logic [4:0] RdW;

    // Module
    mem_wrapper dut(.*);

    // clk
    initial clk = 0;
    always #3 clk = ~clk;

    // function

    function automatic logic [31:0] load_calc_result(
        logic [31:0] addr,
        logic [2:0]  LS_opcodeM,
        logic        MemReadM,
        logic [31:0] ALUResultM
        // [FIXED] 마지막 인자 뒤 쉼표 제거
    );
        logic [31:0] data_extracted;
        data_extracted = 32'b0;  // [FIXED] 기본값 먼저 설정 (undriven 방지)

        if (MemReadM) begin      // [FIXED] MemWriteM → MemReadM (Load니까)
            if (LS_opcodeM == `LB) begin
                case (ALUResultM[1:0])
                    2'b00 : data_extracted = {{24{dut.dm.data_reg[addr>>2][7]}},  dut.dm.data_reg[addr>>2][7:0]};
                    2'b01 : data_extracted = {{24{dut.dm.data_reg[addr>>2][15]}}, dut.dm.data_reg[addr>>2][15:8]};
                    2'b10 : data_extracted = {{24{dut.dm.data_reg[addr>>2][23]}}, dut.dm.data_reg[addr>>2][23:16]};
                    2'b11 : data_extracted = {{24{dut.dm.data_reg[addr>>2][31]}}, dut.dm.data_reg[addr>>2][31:24]};
                endcase
            end
            else if (LS_opcodeM == `LH) begin
                case (ALUResultM[1])
                    1'b0 : data_extracted = {{16{dut.dm.data_reg[addr>>2][15]}}, dut.dm.data_reg[addr>>2][15:0]};
                    1'b1 : data_extracted = {{16{dut.dm.data_reg[addr>>2][31]}}, dut.dm.data_reg[addr>>2][31:16]};
                endcase
            end
            else if (LS_opcodeM == `LW) begin
                data_extracted = dut.dm.data_reg[addr>>2];
            end
            else if (LS_opcodeM == `LBU) begin
                case (ALUResultM[1:0])
                    2'b00 : data_extracted = {24'b0, dut.dm.data_reg[addr>>2][7:0]};
                    2'b01 : data_extracted = {24'b0, dut.dm.data_reg[addr>>2][15:8]};
                    2'b10 : data_extracted = {24'b0, dut.dm.data_reg[addr>>2][23:16]};
                    2'b11 : data_extracted = {24'b0, dut.dm.data_reg[addr>>2][31:24]};
                endcase
            end
            else if (LS_opcodeM == `LHU) begin
                case (ALUResultM[1])
                    1'b0 : data_extracted = {16'b0, dut.dm.data_reg[addr>>2][15:0]};
                    1'b1 : data_extracted = {16'b0, dut.dm.data_reg[addr>>2][31:16]};
                endcase
            end
        end
        else begin
            data_extracted = 32'b0;
            $display("data extraction failed");
        end

        return data_extracted;  // [FIXED] 반환

    endfunction





    // Testbench 시작
    initial begin
        logic [31:0] exp;
        $display("reset...");
        exp = 32'h0;
        RegWriteM = 1'b1;
        ResultSrcM = 2'b10;
        MemWriteM = 1'b1;
        RdM = 5'b10110;
        PCPlus4M = 32'h0000_0012;
        WriteDataM = 32'habcd_dcba;
        ALUResultM = 32'h0000_0128;
        LS_opcodeM = 3'b001;
        MemReadM = 0;
        rstn = 1'b0;

        @(posedge clk);
        #1;


        RegWriteM = 1'b1;
        ResultSrcM = 2'b00;
        MemWriteM = 1'b1;
        RdM = 5'b10110;
        PCPlus4M = 32'h0000_0012;
        WriteDataM = 32'habcd_dcba;
        ALUResultM = 32'h0000_0132;
        rstn = 1'b1;

        @(posedge clk);
        #1;

        if (ResultW==ALUResultM) $display("Successfully Feed Forwarded : %8h", ResultW);
        else $display("Feed Forward Test Failed : %8h", ResultW);

        if ((dut.dm.data_reg[ALUResultM>>2][31:16]==WriteDataM[15:0])&(LS_opcodeM==3'b001)) $display("Data was written successfully. : %8h", dut.dm.data_reg[ALUResultM>>2][31:16]);

        else $display("Data was NOT sucessfully written. : %8h", dut.dm.data_reg[ALUResultM>>2][15:0]);

        RegWriteM = 1'b0;
        MemReadM = 1'b1;
        ResultSrcM = 2'b01;
        MemWriteM = 1'b0;
        RdM = 5'b10111;
        PCPlus4M = 32'h0000_1024;
        WriteDataM = 32'h0000_0000;
        ALUResultM = 32'h0000_0132;
        rstn = 1'b1;
        
        repeat(2) @(posedge clk);
        #1;

        @(posedge clk); // 두 번째 대기
        #1;

        // 직접 내부 값 찍기
        $display("DEBUG | data_reg[0x4C]: %8h", dut.dm.data_reg[32'h0000_0132>>2]);
        $display("DEBUG | RSrcW: %0b", dut.RSrcW);
        $display("DEBUG | ReadDataW: %8h", dut.ReadDataW);
        $display("DEBUG | ReadDataW_Fix: %8h", dut.ReadDataW_Fix);
        $display("DEBUG | ResultSrcW: %0b", dut.ResultSrcW);
        $display("DEBUG | ResultW: %8h", ResultW);

        exp = load_calc_result(ALUResultM, LS_opcodeM, MemReadM, ALUResultM);
        $display("DEBUG | exp: %8h", exp);
        exp = load_calc_result(ALUResultM, LS_opcodeM, MemReadM, ALUResultM);
        if (ResultW==exp) $display("Read Successfully. : %8h", ResultW);
        else $display("Read Failed : %8h", ResultW);

        repeat(3) @(posedge clk);

        $display("---------- TEST FINISHED ----------");
        $finish;
    end



endmodule