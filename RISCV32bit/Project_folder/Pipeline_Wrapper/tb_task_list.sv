
package tb_task_list;
    // input 및 output을 한뭉탱이로 묶어 정의

    typedef struct packed {
        logic inst_i_req;
        logic regfile_FORCEWE;
        logic [4:0] regfile_FORCEWADDR;
        logic [31:0] regfile_FORCEWDATA;
        logic [31:0] instmem_FORCEWINST;
        logic [31:0] instmem_FORCEWADDR;
    } tb_input_set;

    typedef struct packed {
        logic [31:0] ResultW;
        logic Jump;
        logic Branch;
        logic [1:0] ForwardAE_out;
        logic [1:0] ForwardBE_out;
        logic is_imm;
        logic is_using_pc;
        logic is_hazard;
        logic [1:0] which_data;
    } tb_output_set;




    // task setting 
    // 내부 변수에서 여러 번 호출되는 경우 automatic을 붙여 오류 방지 
    task automatic regfile_insert_and_wait(input tb_input_set set_input);
        if (set_input.regfile_FORCEWE) $display("Insert input data %0h at addr %0h", set_input.regfile_FORCEWDATA, set_input.regfile_FORCEWADDR); 
        else $display("Can't insert addr/data");      
    endtask

    task automatic inst_insert_and_wait(input tb_input_set set_input);
        if (set_input.inst_i_req) $display("Insert input data %0h.", set_input.instmem_FORCEWINST); 
        else $display("Can't insert addr/data");
    endtask

    task automatic wreg_output_check(input [4:0] addr, input [31:0] data);
        if ((data==0)&(addr==0)) $display("maybe your data isnt saved well. plz check your input.");
        else $display("your data is saved at regfile %5d, value %0h", addr, data);
    endtask

    task automatic winst_output_check(input [31:0] addr, input [31:0] data);
        if ((data==0)&(addr==0)) $display("maybe your data isnt saved well. plz check your input.");
        else $display("your data is saved at instmem %5h, value %0h", addr, data);
    endtask

    task automatic test_alu(input tb_input_set set_input, input int i);
        if (!set_input.regfile_FORCEWE & !set_input.inst_i_req) begin
            $display("phase %8d start, plz wait...", i);
        end
        else $display("Please Check your regfile_FORCEWE and inst_i_req signal");
    endtask

    task automatic calc_result(input tb_output_set set_output, input int i);

        $display("your %0d th Result : %0h", i, set_output.ResultW);
        if (set_output.Jump|set_output.Branch) $display("B or JALR DETECTED");
        if (set_output.is_imm) $display("Using Immediate Field DETECTED");
        if (set_output.is_hazard) $display("HAZARD DETECTED");
        case(set_output.ForwardAE_out)
            2'b00 : $display("ForwardAE : No Feed Forward.");
            2'b01 : $display("ForwardAE : ResultW");
            2'b10 : $display("ForwardAE : ALUResultM");
            2'b11 : $display("AE Unknown.");
        endcase

        case(set_output.ForwardBE_out)
            2'b00 : $display("ForwardBE : No Feed Forward.");
            2'b01 : $display("ForwardBE : ResultW");
            2'b10 : $display("ForwardBE : ALUResultM");
            2'b11 : $display("BE Unknown.");
        endcase

        case(set_output.which_data)
            2'b00 : $display("ALUResult is out.");
            2'b01 : $display("Reading Data Mem...");
            2'b10 : $display("Reading Program Counter...");
            2'b11 : $display("Storing Data or Need Debugging");
        endcase
        
    endtask 
endpackage