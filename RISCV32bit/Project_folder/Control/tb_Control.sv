`timescale 1ps/1ps
import riscv_op_pkg::*;
`include "definition.vh"

module tb_Control;

    // logic [6:0] op;
    // logic [2:0] funct3;
    // logic [6:0] funct7;

    logic RegWriteD;
    logic [1:0] ResultSrcD;
    logic MemWriteD;
    logic JumpD;
    logic BranchD;
    logic [3:0] ALUControlD;
    logic ALUSrcD;
    logic [2:0] ImmSrcD;
    logic    ignoreSrcAE_D;
    logic    PC_SrcAE_D;
    logic    MemReadD;
    logic [2:0] LS_opcodeD;



    typedef struct packed {
        logic [6:0] op;
        logic [2:0] funct3;
        logic [6:0] funct7;
    } input_list;

    input_list input_cases [36] = '{
        '{op : `R_type, funct3 : 3'b000, funct7 : 7'b0000000},   // R type ADD
        '{op : `R_type, funct3 : 3'b000, funct7 : 7'b0100000},   // R type SUB
        '{op : `R_type, funct3 : 3'b001, funct7 : 7'b0000000},   // R type SLL
        '{op : `R_type, funct3 : 3'b010, funct7 : 7'b0000000},   // R type SLT
        '{op : `R_type, funct3 : 3'b011, funct7 : 7'b0000000},   // R type SLTU
        '{op : `R_type, funct3 : 3'b100, funct7 : 7'b0000000},   // R type XOR
        '{op : `R_type, funct3 : 3'b101, funct7 : 7'b0000000},   // R type SRL
        '{op : `R_type, funct3 : 3'b101, funct7 : 7'b0100000},   // R type SRA
        '{op : `R_type, funct3 : 3'b110, funct7 : 7'b0000000},   // R type OR
        '{op : `R_type, funct3 : 3'b111, funct7 : 7'b0000000},   // R type AND


        '{op : `I_type_ALU, funct3 : 3'b000, funct7 : 7'b0000000},   // I type ALU ADDI
        '{op : `I_type_ALU, funct3 : 3'b010, funct7 : 7'b0000000},   // I type ALU SLTI
        '{op : `I_type_ALU, funct3 : 3'b011, funct7 : 7'b0000000},   // I type ALU SLTUI
        '{op : `I_type_ALU, funct3 : 3'b100, funct7 : 7'b0000000},   // I type ALU XORI
        '{op : `I_type_ALU, funct3 : 3'b110, funct7 : 7'b0000000},   // I type ALU ORI
        '{op : `I_type_ALU, funct3 : 3'b111, funct7 : 7'b0000000},   // I type ALU ANDI
        '{op : `I_type_ALU, funct3 : 3'b001, funct7 : 7'b0000000},   // I type ALU SLLI
        '{op : `I_type_ALU, funct3 : 3'b101, funct7 : 7'b0000000},   // I type ALU SRLI
        '{op : `I_type_ALU, funct3 : 3'b101, funct7 : 7'b0100000},   // I type ALU SRAI
        
        '{op : `I_type_LOAD, funct3 : 3'b000, funct7 : 7'b0000000},   // I type Load LB
        '{op : `I_type_LOAD, funct3 : 3'b001, funct7 : 7'b0000000},   // I type Load LH
        '{op : `I_type_LOAD, funct3 : 3'b010, funct7 : 7'b0000000},   // I type Load LW
        '{op : `I_type_LOAD, funct3 : 3'b100, funct7 : 7'b0000000},   // I type Load LBU
        '{op : `I_type_LOAD, funct3 : 3'b101, funct7 : 7'b0000000},   // I type Load LHU

        '{op : `S_type, funct3 : 3'b000, funct7 : 7'b0000000},   // S type STORE SB
        '{op : `S_type, funct3 : 3'b001, funct7 : 7'b0000000},   // S type STORE SH
        '{op : `S_type, funct3 : 3'b010, funct7 : 7'b0000000},   // S type STORE SW


        '{op : `I_type_JALR, funct3 : 3'b000, funct7 : 7'b0000000},   // I type JALR

        '{op : `B_type, funct3 : 3'b000, funct7 : 7'b0000000},   // B type BEQ
        '{op : `B_type, funct3 : 3'b001, funct7 : 7'b0000000},   // B type BNE
        '{op : `B_type, funct3 : 3'b100, funct7 : 7'b0000000},   // B type BLT
        '{op : `B_type, funct3 : 3'b101, funct7 : 7'b0000000},   // B type BGE
        '{op : `B_type, funct3 : 3'b110, funct7 : 7'b0000000},   // B type BLTU
        '{op : `B_type, funct3 : 3'b111, funct7 : 7'b0000000},   // B type BGEU

        '{op : `U_type_LUI, funct3 : 3'b000, funct7 : 7'b0000000},   // U type LUI
        '{op : `U_type_AUIPC, funct3 : 3'b000, funct7 : 7'b0000000}   // U type AUIPC
    };



    input_list real_input;

    control_unit dut(
        .op(real_input.op),
        .funct3(real_input.funct3),
        .funct7(real_input.funct7),

        .RegWriteD(RegWriteD),
        .ResultSrcD(ResultSrcD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .BranchD(BranchD),
        .ALUControlD(ALUControlD),
        .ALUSrcD(ALUSrcD),
        .ImmSrcD(ImmSrcD),
        .ignoreSrcAE_D(ignoreSrcAE_D),
        .PC_SrcAE_D(PC_SrcAE_D),
        .MemReadD(MemReadD),
        .LS_opcodeD(LS_opcodeD)
    );

    initial begin
        #3;

        $display("initializing...");

        #3;

        foreach (input_cases[i]) begin
            real_input = input_cases[i];
            $display("operation type : %0d, funct3 : %0b, funct7 : %0b", real_input.op, real_input.funct3, real_input.funct7);

            #2; 

            $display("Testing...");

            #4;

            $display("OUTPUT RESULT : Register Write : %0b, Result Select : %0b, Memory Write : %0b, JUMP : %0b, Branch : %0b, ALU Control : %0b, ALU Select : %0b, Immediate Value : %0b", RegWriteD, ResultSrcD, MemWriteD, JumpD, BranchD, ALUControlD, ALUSrcD, ImmSrcD);
            if ((real_input.op==`I_type_JALR)&(ResultSrcD==2'b10)) $display("JALR detected and it works.");
            else if ((real_input.op==`I_type_JALR)&(ResultSrcD!=2'b10)) $display("JALR detected and it failed to work.");

            if ((real_input.op==`U_type_LUI)&(ignoreSrcAE_D)) $display("LUI detected and it works.");
            else if ((real_input.op==`U_type_LUI)&(!ignoreSrcAE_D)) $display("LUI detected and it failed to work.");  

            if ((real_input.op==`U_type_AUIPC)&(PC_SrcAE_D)) $display("AUIPC detected and it works.");
            else if ((real_input.op==`U_type_AUIPC)&(!PC_SrcAE_D)) $display("AUIPC detected and it failed to work.");                
            #1;
        end 

        #1;

        $finish;
    end
    initial begin
        $dumpfile("Pipeline_Controller_waveform.vcd");
        $dumpvars(0, dut);
    end
    

endmodule