import riscv_op_pkg::*;

module control_unit(
    input  logic [6:0] op,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,

    output logic       RegWriteD,
    output logic [1:0] ResultSrcD,
    output logic       MemWriteD,
    output logic       JumpD,
    output logic       BranchD,
    output logic [3:0] ALUControlD, // 오타 수정 (ALUContolD -> ALUControlD)
    output logic       ALUSrcD,
    output logic [2:0] ImmSrcD
);
    // Opcode만 enum.
    opcode_type op_type;
    assign op_type = opcode_type'(op);

    // 10-bit funct 조합 (R-type 및 I-type Shift 구분에 사용)
    wire [9:0] funct = {funct3, funct7};


    
    // ALU 연산 관련
    wire is_ALU_arith     = (op_type == R_type)     & ((funct == ADD) | (funct == SUB));
    wire is_ALU_arith_imm = (op_type == I_type_ALU) & (funct3 == F3_ADDI);
    
    // 비교 연산자(=) 누락 수정
    wire is_ALU_shift     = (op_type == R_type)     & ((funct == SLL)  | (funct == SRL)  | (funct == SRA));
    wire is_ALU_shift_imm = (op_type == I_type_ALU) & ((funct == SLLI) | (funct == SRLI) | (funct == SRAI));
    
    wire is_ALU_logic     = (op_type == R_type)     & ((funct == SLT) | (funct == SLTU) | (funct == XOR) | (funct == OR) | (funct == AND));
    wire is_ALU_logic_imm = (op_type == I_type_ALU) & ((funct3 == F3_SLTI) | (funct3 == F3_SLTIU) | (funct3 == F3_XORI) | (funct3 == F3_ORI) | (funct3 == F3_ANDI));

    // Load 및 Store 관련
    wire is_load  = (op_type == I_type_LOAD) & ((funct3 == F3_LB) | (funct3 == F3_LH) | (funct3 == F3_LW) | (funct3 == F3_LBU) | (funct3 == F3_LHU));
    wire is_store = (op_type == S_type)      & ((funct3 == F3_SB) | (funct3 == F3_SH) | (funct3 == F3_SW));
    
    // Branch 및 Jump 관련
    wire is_branch = (op_type == B_type) & ((funct3 == F3_BEQ) | (funct3 == F3_BNE) | (funct3 == F3_BLT) | (funct3 == F3_BGE) | (funct3 == F3_BLTU) | (funct3 == F3_BGEU));
    wire is_jump   = (op_type == I_type_JALR) | (op_type == J_type); // JAL도 Jump에 포함되도록 추가 권장

    // System 관련
    wire is_system = (op_type == System) & ((funct3 == F3_CSRRW) | (funct3 == F3_CSRRS) | (funct3 == F3_CSRRC) | (funct3 == F3_CSRRWI) | (funct3 == F3_CSRRSI) | (funct3 == F3_CSRRCI));

    // 기타 (추후 추가용)
    wire is_lui   = (op_type == U_type_LUI);
    wire is_auipc = (op_type == U_type_AUIPC);
    wire is_fence = (op_type == Fence);

    // -----------------------------------------------------------------------
    // 출력 제어 신호 할당
    // -----------------------------------------------------------------------

    assign RegWriteD  = (op_type == R_type) | (op_type == I_type_ALU) | (op_type == I_type_LOAD) | (op_type == I_type_JALR) | (op_type == J_type) | (op_type == U_type_AUIPC) | (op_type == U_type_LUI);
    assign ResultSrcD = ((op_type == I_type_ALU) | (op_type == R_type) | (op_type == U_type_LUI) | (op_type == U_type_AUIPC)) ? 2'b00 : 
                        (op_type == I_type_LOAD) ? 2'b01 : 
                        ((op_type == I_type_JALR) | (op_type == J_type)) ? 2'b10 : 2'b11;

    assign MemWriteD = is_store;
    assign JumpD     = is_jump;
    assign BranchD   = is_branch;
    

    assign ALUSrcD   = (op_type == I_type_ALU) | (op_type == I_type_LOAD) | (op_type == S_type) | (op_type == U_type_AUIPC);

    wire sel_arith_logic = (is_ALU_arith | is_ALU_arith_imm | ((op_type == R_type) & (funct == SRA)) | ((op_type == I_type_ALU) & (funct == SRAI)) | is_load | is_store | is_branch | is_jump);
    
    logic [2:0] alu_ctl;
    assign ALUControlD = {sel_arith_logic, alu_ctl};

    // ALU 제어 로직 (funct3, funct 직접 비교)
    always_comb begin
        alu_ctl = 3'b000;

        if (is_ALU_arith | is_ALU_logic) begin
            case(funct)
                ADD : alu_ctl = 3'b001;
                SUB : alu_ctl = 3'b010;
                SLT : alu_ctl = 3'b011;
                SLTU: alu_ctl = 3'b100;
                XOR : alu_ctl = 3'b101;
                OR  : alu_ctl = 3'b110;
                AND : alu_ctl = 3'b111;
                default: alu_ctl = 3'b000;
            endcase
        end
        else if (is_ALU_arith_imm | is_ALU_logic_imm) begin
            case(funct3)
                F3_ADDI : alu_ctl = 3'b001;
                F3_SLTI : alu_ctl = 3'b011;
                F3_SLTIU: alu_ctl = 3'b100;
                F3_XORI : alu_ctl = 3'b101;
                F3_ORI  : alu_ctl = 3'b110;
                F3_ANDI : alu_ctl = 3'b111;
                default : alu_ctl = 3'b000;
            endcase
        end
        else if (is_ALU_shift) begin
            case(funct)
                SLL : alu_ctl = 3'b001;
                SRL : alu_ctl = 3'b010;
                SRA : alu_ctl = 3'b100;
                default: alu_ctl = 3'b000;
            endcase
        end
        else if (is_ALU_shift_imm) begin
            case(funct)
                SLLI: alu_ctl = 3'b001;
                SRLI: alu_ctl = 3'b010;
                SRAI: alu_ctl = 3'b100;
                default: alu_ctl = 3'b000;
            endcase
        end
        else if (is_load) begin
            case(funct3)
                F3_LB, F3_LH, F3_LW, F3_LBU, F3_LHU: alu_ctl = 3'b001;
                default: alu_ctl = 3'b000;
            endcase
        end
        else if (is_store) begin
            case(funct3)
                F3_SB, F3_SH, F3_SW: alu_ctl = 3'b001;
                default: alu_ctl = 3'b000;
            endcase
        end
        else if (is_branch) begin
            case(funct3)
                F3_BEQ, F3_BNE, F3_BLT, F3_BGE, F3_BLTU, F3_BGEU: alu_ctl = 3'b001;
                default: alu_ctl = 3'b000;
            endcase
        end
        else if (is_system) begin
            case(funct3)
                F3_CSRRW, F3_CSRRS, F3_CSRRC, F3_CSRRWI, F3_CSRRSI, F3_CSRRCI: alu_ctl = 3'b001;
                default: alu_ctl = 3'b000;
            endcase
        end
        else if ((op_type == I_type_JALR) | (op_type == U_type_LUI) | (op_type == U_type_AUIPC) | is_fence) begin
            alu_ctl = 3'b001;
        end
    end
    
    logic [2:0] imm_ctl;
    assign ImmSrcD = imm_ctl;

    // ImmSrcD case문 에러 수정 (정확한 enum 사용)
    always_comb begin
        imm_ctl = 3'b000;
        case(op_type)
            I_type_ALU, I_type_LOAD, I_type_JALR : imm_ctl = 3'b001;
            S_type                               : imm_ctl = 3'b010;
            B_type                               : imm_ctl = 3'b011;
            U_type_LUI, U_type_AUIPC             : imm_ctl = 3'b100;
            J_type                               : imm_ctl = 3'b101;
            default                              : imm_ctl = 3'b000;
        endcase
    end

endmodule