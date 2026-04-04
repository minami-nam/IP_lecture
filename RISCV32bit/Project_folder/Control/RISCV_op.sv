package riscv_op_pkg;

    
    // 보고서에 반드시 기록해야 할 부분
    // opcode에 따른 명령어 종류

    // R type : Opcode 0110011
    // funct3, funct7 bit를 추가로 확인해서 세부 연산 결정
    // 명령어 : add, sub, and, or, xor, sll, srl, sra, slt, sltu

    // I type : Opcode 001, 000, 110 0011 (0111 JALR ONLY)
    // 001 : ALU : addi, andi, ori, xori, slli, srli, srai, slti
    // 000 : Load : lw, lh, lb, lhu, lbu
    // 110 : JALR : jalr (레지스터 기반 점프)

    // S type : Opcode 0100011
    // 주요 명령어 : sw, sh, sb
    // rs1 rs2 only

    // B type : 1100011
    // 주요 명령어: beq, bne, blt, bge, bltu, bgeu
    // rs1 rs2 compare 한 후 PC에 immidiate 값 더하여 jump

    // U type : 상위 20bit 즉치값을 다룸.
    // LUI : 0110111 Load Upper Immediate
    // AUIPC : Add Upper Immediate to PC

    // J type : 1101111
    // 무조건 jump, 돌아올 주소 저장 : jal (jump and link)

    // 기타 : System & Fence
    // 1110011 : System : ecall, ebreak, CSR
    // 0001111 : fence : mem order

    
    // opcode list
    // 1. Opcode Definition
    typedef enum logic [6:0] {
        R_type       = 7'b0110011,
        I_type_ALU   = 7'b0010011,
        I_type_LOAD  = 7'b0000011,
        I_type_JALR  = 7'b1100111,
        B_type       = 7'b1100011,
        U_type_LUI   = 7'b0110111,
        U_type_AUIPC = 7'b0010111,
        J_type       = 7'b1101111,
        S_type       = 7'b0100011,
        System       = 7'b1110011,
        Fence        = 7'b0001111
    } opcode_type;


    // 2. {funct3, funct7} 10-bit Definition
    // funct7 필드를 온전히 사용하는 명령어들 (R-Type)
    typedef enum logic [9:0] {
        // R-type ALU
        ADD  = 10'b000_0000000,
        SUB  = 10'b000_0100000,
        SLL  = 10'b001_0000000,
        SLT  = 10'b010_0000000,
        SLTU = 10'b011_0000000, 
        XOR  = 10'b100_0000000,
        SRL  = 10'b101_0000000,
        SRA  = 10'b101_0100000,
        OR   = 10'b110_0000000,
        AND  = 10'b111_0000000
    } func_R_10bit;

    // 추가

    typedef enum logic [9:0] { 
        // I-type ALU (Shift Operations)
        SLLI = 10'b001_0000000,
        SRLI = 10'b101_0000000,
        SRAI = 10'b101_0100000
    } func_I_ALU_10bit;


    // 3. {funct3} 3-bit Definition
    // funct7 자리를 Immediate가 차지하여 funct3(3비트)만으로 구분해야 하는 명령어들
    typedef enum logic [2:0] {
        // I-type ALU (Immediate Arithmetic)
        F3_ADDI  = 3'b000,
        F3_SLTI  = 3'b010,
        F3_SLTIU = 3'b011,
        F3_XORI  = 3'b100,
        F3_ORI   = 3'b110,
        F3_ANDI  = 3'b111
    } func_I_ALU_3bit;


    typedef enum logic [2:0] {
        // Load Instructions (I-type)
        F3_LB    = 3'b000,
        F3_LH    = 3'b001,
        F3_LW    = 3'b010,
        F3_LBU   = 3'b100,
        F3_LHU   = 3'b101
    } func_I_LOAD_3bit;

    typedef enum logic [2:0] {
        F3_SB    = 3'b000,
        F3_SH    = 3'b001,
        F3_SW    = 3'b010
    } func_S_3bit;

    typedef enum logic [2:0] { 
        // Branch Instructions (B-type)
        F3_BEQ   = 3'b000,
        F3_BNE   = 3'b001,
        F3_BLT   = 3'b100,
        F3_BGE   = 3'b101,
        F3_BLTU  = 3'b110,
        F3_BGEU  = 3'b111
    } func_B_3bit;

    typedef enum logic [2:0] {
        // System Instructions (CSR)
        F3_CSRRW = 3'b001,
        F3_CSRRS = 3'b010,
        F3_CSRRC = 3'b011,
        F3_CSRRWI= 3'b101,
        F3_CSRRSI= 3'b110,
        F3_CSRRCI= 3'b111 
    } func_System_3bit;
endpackage