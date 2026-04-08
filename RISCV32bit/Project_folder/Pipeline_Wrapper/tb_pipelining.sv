import tb_task_list::*;
`include "./bin_list.vh"
import riscv_op_pkg::*;

class Randominst;
    rand bit [6:0] opcode;
    rand bit [4:0] rs1, rs2, rd;
    rand bit [2:0] funct3;
    rand bit [6:0] funct7;
    rand bit [31:0] imm;

    constraint c_opcode_list {
        // constraint 사용법 확인하기
        opcode dist {
            `R_type  := 1,  
            `I_type_ALU  := 1, 
            7'b0000011  := 1,    // I_type_LOAD
            `S_type  := 1
            }; 
    }

    constraint c_registers {    
        rs1 inside {[1:31]};
        rs2 inside {[1:31]};
        rd  inside {[1:31]};

    }

    constraint c_funct_match {
            if (opcode == `R_type) { 
                // funct3는 3비트이므로 별도 제한 없이 모든 값(000~111) 허용
                if (funct3 == 3'b000 || funct3 == 3'b101) { 
                    funct7 inside {7'b0000000, 7'b0100000}; 
                } else { 
                    funct7 == 7'b0000000; 
                }
            }
            else if (opcode == `I_type_ALU) {
                // Shift 연산 (SLLI, SRLI, SRAI)일 경우 funct7 존재
                if (funct3 == 3'b001 || funct3 == 3'b101) {
                    funct7 inside {7'b0000000, 7'b0100000};
                    imm inside {[0:31]}; // Shift 양은 5비트를 넘지 않도록 제한
                } else {
                    funct7 == 7'b0000000;
                    imm inside {[0:127]}; 
                }
            }
            else if (opcode == `I_type_JALR) {
                funct3 == 3'b000;
                imm inside {[0:64]}; 
                imm[0] == 1'b0; // 점프 타겟은 무조건 짝수(Even)여야함. 스타트를 짝수부터 하고, 4씩 증가하니까.
            }
            else if (opcode == 7'b0000011) { 
                funct3 inside {3'b000, 3'b001, 3'b010, 3'b100, 3'b101};
                imm inside {[0:128]}; 
            }
            else if (opcode == `S_type) {
                funct3 inside {3'b000, 3'b001, 3'b010};
                imm inside {[0:128]};
            }
            else if (opcode == `B_type) {
                funct3 inside {3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111};
                imm inside {[0:64]};  
                imm[0] == 1'b0;         // 점프 타겟은 무조건 짝수
            }
            else if (opcode == `U_type_LUI || opcode == `U_type_AUIPC) {
                // U-Type은 상위 20비트만 쓰므로, 하위 12비트는 깔끔하게 0으로 비움
                imm[11:0] == 12'b0;
            }
            else {
                funct3 == 3'b000;
                funct7 == 7'b0000000;
                imm    == 0;
            }
        }
    

    // function 사용하는 방법 숙지. return 문을 통해서 출력이 가능함.
    function bit [31:0] get_machine_code();
        case(opcode)
            `R_type : begin
                return {funct7, rs2, rs1, funct3, rd, opcode};
            end
            
            `I_type_ALU : begin
                
                if (funct3 == 3'b001 || funct3 == 3'b101) 
                    return {funct7, imm[4:0], rs1, funct3, rd, opcode};
                else 
                    return {imm[11:0], rs1, funct3, rd, opcode};
            end
            
            `I_type_JALR, 7'b0000011 : begin
                return {imm[11:0], rs1, funct3, rd, opcode};
            end
            
            `S_type : begin
                
                return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
            end
            
            `B_type : begin
                return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
            end
            
            `U_type_LUI, `U_type_AUIPC : begin
                // U-Type: imm의 상위 20비트[31:12]를 가져옴
                return {imm[31:12], rd, opcode};
            end

            default : begin
                return 32'h00000000; // NOP 또는 쓰레기값 방지
            end
        endcase
    endfunction
endclass

module tb_sc_riscv_wrapper;
    // inst 입력을 위한 regfile_FORCE 입력 추가
    logic clk;

    logic stage_FORCERESET_n;

    tb_input_set writeinst_input_list = '{inst_i_req : 1'b1, regfile_FORCEWE : 1'b0, regfile_FORCEWADDR : 1'b0, regfile_FORCEWDATA : 1'b0, instmem_FORCEWINST : 32'd0, instmem_FORCEWADDR : 32'd0008};

    
    // Register 초기 값 쓰기
    tb_input_set writereg_input_list [19] = '{
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X0, regfile_FORCEWDATA : 0, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X1, regfile_FORCEWDATA : 8, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X2, regfile_FORCEWDATA : 4, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X3, regfile_FORCEWDATA : 16, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X4, regfile_FORCEWDATA : 8, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X5, regfile_FORCEWDATA : 4, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X6, regfile_FORCEWDATA : 2, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X7, regfile_FORCEWDATA : 8, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X8, regfile_FORCEWDATA : 11, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X9, regfile_FORCEWDATA : 13, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},

        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X10, regfile_FORCEWDATA : 21, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X11, regfile_FORCEWDATA : 7, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X12, regfile_FORCEWDATA : 1, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X13, regfile_FORCEWDATA : 9, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X14, regfile_FORCEWDATA : 20, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X15, regfile_FORCEWDATA : 26, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X16, regfile_FORCEWDATA : 81, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X17, regfile_FORCEWDATA : 52, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0},
        '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b1, regfile_FORCEWADDR : `X18, regfile_FORCEWDATA : 33, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0}
    };

    tb_input_set calc_alu_state = '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b0, regfile_FORCEWADDR : 1'b0, regfile_FORCEWDATA : 1'b0, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0};
    tb_input_set set_initial = '{inst_i_req : 1'b0, regfile_FORCEWE : 1'b0, regfile_FORCEWADDR : 1'b0, regfile_FORCEWDATA : 1'b0, instmem_FORCEWINST : 1'b0, instmem_FORCEWADDR : 1'b0};
    tb_input_set sti_input;
    tb_output_set sti_output;

    opcode_type op_detect;

    sc_riscv_wrapper dut(
        .clk(clk),
        .inst_i_req(sti_input.inst_i_req),
        .regfile_FORCEWE(sti_input.regfile_FORCEWE),
        .regfile_FORCEWADDR(sti_input.regfile_FORCEWADDR),
        .regfile_FORCEWDATA(sti_input.regfile_FORCEWDATA),
        .instmem_FORCEWINST(sti_input.instmem_FORCEWINST),
        .instmem_FORCEWADDR(sti_input.instmem_FORCEWADDR),
        .stage_FORCERESET_n(stage_FORCERESET_n),
        
        .ResultW(sti_output.ResultW),

        .Jump(sti_output.Jump),
        .Branch(sti_output.Branch),
        .ForwardAE_out(sti_output.ForwardAE_out),
        .ForwardBE_out(sti_output.ForwardBE_out),
        .is_imm(sti_output.is_imm),
        .is_using_pc(sti_output.is_using_pc),
        .is_hazard(sti_output.is_hazard),
        .which_data(sti_output.which_data)
    );



    initial clk = 0;
    always #3 clk = ~clk;

    initial begin
        Randominst create_inst;
        bit [31:0] instruction_in[100];
        create_inst = new();
        sti_input = calc_alu_state;
        stage_FORCERESET_n = 0;
        @(posedge clk);
 

        for (int i = 0; i<50; i++) begin
            if (!create_inst.randomize()) $display("inst 생성 실패 : Code 확인 요망");
            sti_input = writeinst_input_list;
            sti_input.instmem_FORCEWADDR = 8+4*i;
            // 배열 초기화 안 시켜주면 큰일나요
            instruction_in[i] = create_inst.get_machine_code();
            sti_input.instmem_FORCEWINST = instruction_in[i];
            op_detect = opcode_type'(instruction_in[i][6:0]);
            $display("Inst Type : %s", op_detect.name());
            @(posedge clk);
            inst_insert_and_wait(sti_input);
            #1;
            winst_output_check((8+4*i)>>2, dut.instmem.mem[(8+4*i)>>2]);
        end

        foreach (writereg_input_list[i]) begin
            sti_input = writereg_input_list[i];
            @(posedge clk);
            regfile_insert_and_wait(sti_input);
            #1;
            wreg_output_check(dut.reg_file.i_addr3, dut.reg_file.register[dut.reg_file.i_addr3]);
        end
        @(posedge clk);
        stage_FORCERESET_n = 1;
        sti_input = calc_alu_state;

        for (int i=0; i<55; i++) begin
            @(posedge clk);
            test_alu(sti_input, i);
            calc_result(sti_output, i);
        end

        @(posedge clk);
        $finish;

    end

    initial begin
        $dumpfile("pipeline_waveform.vcd");
    end

endmodule