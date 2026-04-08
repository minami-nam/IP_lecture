`timescale 1ps/1ps
`include "define.vh"
import hazard_package_list::*;

module tb_hazard;
    // logic [4:0] Rs1D;
    // logic [4:0] Rs2D;

    // logic [4:0] Rs1E;
    // logic [4:0] Rs2E;
    // logic [4:0] RdE;
    // logic ZeroE;
    // logic JumpE;
    // logic BranchE;
    // logic ResultSrcE; 

    // logic [4:0] RdM;
    // logic [4:0] RdW;
    // logic RegWriteM;
    // logic RegWriteW;

    logic StallIF_n;
    logic StallID_n;
    logic FlushD;
    logic FlushE;
    logic [1:0] ForwardAE;
    logic [1:0] ForwardBE;
    logic pc_en_n;

    input_reg_list input_register [4] = '{
        '{Rs1D : `STRUCTURAL_1D, Rs2D : `STRUCTURAL_2D, Rs1E : 5, Rs2E : 6, RdE : `STRUCTURAL_1D, RdM : `STRUCTURAL_1D+4, RdW : `STRUCTURAL_1D+8},    // Structural Hazard
        '{Rs1D : 9, Rs2D : 10, Rs1E : `STRUCTURAL_1D, Rs2E : `STRUCTURAL_2D, RdE : `STRUCTURAL_2D-4 , RdM : `STRUCTURAL_2D, RdW : `STRUCTURAL_2D+4},    // Data Hazard
        '{Rs1D : 6, Rs2D : 5, Rs1E : `STRUCTURAL_1D, Rs2E : `STRUCTURAL_2D, RdE : `STRUCTURAL_1D-8, RdM : `STRUCTURAL_1D-4, RdW : `STRUCTURAL_1D},    // Data Hazard
        '{Rs1D : `STRUCTURAL_1D, Rs2D : `STRUCTURAL_2D, Rs1E : `STRUCTURAL_1D, Rs2E : `STRUCTURAL_2D, RdE : `STRUCTURAL_1D-4, RdM : `STRUCTURAL_1D, RdW : `STRUCTURAL_1D+4}   
    };
    input_ctl_list input_control [4] = '{
        '{ZeroE : `OFF, JumpE : `OFF, BranchE : `OFF, ResultSrcE : `OFF, RegWriteM : `ON, RegWriteW : `OFF},
        '{ZeroE : `OFF, JumpE : `OFF, BranchE : `OFF, ResultSrcE : `ON, RegWriteM : `ON, RegWriteW : `OFF},
        '{ZeroE : `OFF, JumpE : `OFF, BranchE : `OFF, ResultSrcE : `ON, RegWriteM : `OFF, RegWriteW : `ON},
        '{ZeroE : `ON, JumpE : `OFF, BranchE : `ON, ResultSrcE : `OFF, RegWriteM : `ON, RegWriteW : `OFF}
    };


    // For 전용
    input_reg_list sti_input_reg;
    input_ctl_list sti_input_ctl;

    hazard_detection dut(
        .Rs1D(sti_input_reg.Rs1D),
        .Rs2D(sti_input_reg.Rs2D),
        .Rs1E(sti_input_reg.Rs1E),
        .Rs2E(sti_input_reg.Rs2E),
        .RdE(sti_input_reg.RdE),
        .RdM(sti_input_reg.RdM),
        .RdW(sti_input_reg.RdW),

        .ZeroE(sti_input_ctl.ZeroE),
        .JumpE(sti_input_ctl.JumpE),
        .BranchE(sti_input_ctl.BranchE),
        .ResultSrcE(sti_input_ctl.ResultSrcE),
        .RegWriteM(sti_input_ctl.RegWriteM),
        .RegWriteW(sti_input_ctl.RegWriteW),

        .StallIF_n(StallIF_n),
        .StallID_n(StallID_n),
        .FlushD(FlushD),
        .FlushE(FlushE),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .pc_en_n(pc_en_n)
    );

    initial begin
        #1;

        $display("initializing...");

        for (int i=0; i<4; i++) begin
            sti_input_reg = input_register[i];
            sti_input_ctl = input_control[i];

            #3;

            if (StallIF_n!=1) $display("IF stage is stalled.");
            if (StallID_n!=1) $display("ID stage is stalled");
            if (FlushD==1) $display("ID stage is flushed");
            if (FlushE==1) $display("EX stage is flushed");
            if (pc_en_n!=1) $display("Program Counter is disabled");
            
            case(ForwardAE)
                `RD1E : $display("RD1E is selected");
                `RESULTW: $display("RESULTW is selected : Feed Forward");
                `ALURESULT : $display("ALURESULT is selected : Feed Forward");
                `UNKNOWN : $display("UNKNOWN is selected");
            endcase

            case(ForwardBE)
                `RD2E : $display("RD2E is selected");
                `RESULTW: $display("RESULTW is selected : Feed Forward");
                `ALURESULT : $display("ALURESULT is selected : Feed Forward");
                `UNKNOWN : $display("UNKNOWN is selected");
            endcase

            #1;
        end
        $finish;

    end
    
    initial begin
        $dumpfile("tb_Hazard_waveform.vcd");
        $dumpvars(0, dut);
    end







endmodule