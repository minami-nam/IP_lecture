module tb_inst_extend;
    // logic [24:0] inst;
    // logic [2:0] ImmSrcD;  // 이 부분은 수정

    logic [31:0] ImmExtD;


    // State 선언
    localparam int IDLE = 0;
    localparam int I_type = 1;
    localparam int S_type = 2;
    localparam int B_type = 3;
    localparam int U_type = 4;
    localparam int J_type = 5;
    localparam int UNKNOWN = 6;


    typedef struct packed {
        logic [31:0] inst;
        logic [2:0] ImmSrcD;
    }  i_ports;

    i_ports case_lists[7] = '{
        '{inst : 32'h01234567, ImmSrcD : 0}, // IDLE    [FIXED]
        '{inst : 32'h01234321, ImmSrcD : 1}, // I_type  [FIXED]
        '{inst : 32'h00123321, ImmSrcD : 2}, // S_type  [FIXED]
        '{inst : 32'h00301113, ImmSrcD : 3}, // B_type  [FIXED]
        '{inst : 32'h00202231, ImmSrcD : 4}, // U_type  [FIXED]
        '{inst : 32'h01209209, ImmSrcD : 5}, // J_type  [FIXED]
        '{inst : 32'h01123123, ImmSrcD : 6}  // UNKNOWN [FIXED]
    };
    
    i_ports input_cases;

    inst_extend dut(
        // input
        .inst(input_cases.inst),
        .ImmSrcD(input_cases.ImmSrcD),
        // output
        .ImmExtD(ImmExtD)
    );


    initial begin
        #3;

        foreach (case_lists[i]) begin
            input_cases = case_lists[i];
            $display("State : %0d", i);
            #3;
            case(i)
                IDLE : begin
                    if (ImmExtD == 32'h00000000) $display("Passed IDLE State");      // [FIXED] 0 → 32'h00000000
                    else $display("Failed IDLE State, %0h", ImmExtD);
                end
                I_type : begin
                    if (ImmExtD == 32'h00000012) $display("Passed I TYPE State");    // [FIXED]
                    else $display("Failed I TYPE State, %0h", ImmExtD);
                end
                S_type : begin
                    if (ImmExtD == 32'h00000006) $display("Passed S TYPE State");    // [FIXED]
                    else $display("Failed S TYPE State, %0h", ImmExtD);
                end
                B_type : begin
                    if (ImmExtD == 32'h00000002) $display("Passed B TYPE State");    // [FIXED]
                    else $display("Failed B TYPE State, %0h", ImmExtD);
                end
                U_type : begin
                    if (ImmExtD == 32'h00202000) $display("Passed U TYPE State");    // [FIXED]
                    else $display("Failed U TYPE State, %0h", ImmExtD);
                end
                J_type : begin
                    if (ImmExtD == 32'h00009012) $display("Passed J TYPE State");    // [FIXED]
                    else $display("Failed J TYPE State, %0h", ImmExtD);
                end
                UNKNOWN : begin
                    if (ImmExtD == 32'h00000000) $display("Passed UNKNOWN TYPE State");
                    else $display("Failed UNKNOWN TYPE State, %0h", ImmExtD);
                end
                default : begin
                    if (ImmExtD == 32'hzzzzzzzz) $display("Passed Default State");
                    else $display("Failed Default TYPE State, %0h", ImmExtD);
                end
            endcase
            #1;
        end
        #2;
        $finish;
    end


    initial begin
        $dumpfile("inst_extend_waveform.vcd");
        $dumpvars(0, dut);
    end

endmodule