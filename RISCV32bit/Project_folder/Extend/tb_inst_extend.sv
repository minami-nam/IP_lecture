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
        logic [24:0] inst;
        logic [2:0] ImmSrcD;
    }  i_ports;

    i_ports case_lists[7] = '{
        '{inst : 25'h1234567, ImmSrcD : 0}, // IDLE
        '{inst : 25'h1234321, ImmSrcD : 1}, // I_type        
        '{inst : 25'h0123321, ImmSrcD : 2}, // S_type 
        '{inst : 25'h0301113, ImmSrcD : 3}, // B_type 
        '{inst : 25'h0202231, ImmSrcD : 4}, // U_type 0001 0000 0001 0001 0001 0000 0000 0000
        '{inst : 25'h1209209, ImmSrcD : 5}, // J_type 
        '{inst : 25'h1123123, ImmSrcD : 6}  // UNKNOWN
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
                    if (ImmExtD==32'h01234567) $display("Passed IDLE State");
                    else $display("Failed IDLE State, %0h", ImmExtD);
                end
                I_type : begin
                    if (ImmExtD==32'hFF234321) $display("Passed I TYPE State");
                    else $display("Failed I TYPE State, %0h", ImmExtD);
                end
                S_type : begin
                    if (ImmExtD==32'h00000081) $display("Passed S TYPE State");
                    else $display("Failed S TYPE State, %0h", ImmExtD);
                end
                B_type : begin
                    if (ImmExtD==32'h00000992) $display("Passed B TYPE State");
                    else $display("Failed B TYPE State, %0h", ImmExtD);
                end
                U_type : begin
                    if (ImmExtD==32'h10111000) $display("Passed U TYPE State");
                    else $display("Failed U TYPE State, %0h", ImmExtD);
                end
                J_type : begin
                    if (ImmExtD==32'hFFF90104) $display("Passed J TYPE State");
                    else $display("Failed J TYPE State, %0h", ImmExtD);
                end
                UNKNOWN : begin
                    if (ImmExtD==32'h00000000) $display("Passed UNKNOWN TYPE State");
                    else $display("Failed UNKNOWN TYPE State, %0h", ImmExtD);
                end
                default : begin
                    if (ImmExtD==32'hzzzz_zzzz) $display("Passed Default State");
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