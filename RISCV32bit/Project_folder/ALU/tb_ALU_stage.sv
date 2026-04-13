`define CHECK(idx, actual, expected, label) \
    if ((actual) === (expected)) \
        $display("[Index %02d] PASS  %-6s | Got: %08h", idx, label, actual); \
    else begin \
        $display("[Index %02d] FAIL  %-6s | Expected: %08h, Got: %08h", idx, label, expected, actual); \
        cnt++; \
    end

module tb_ALU_stage;

    logic clk, rstn;

    logic        RegWriteM;
    logic [1:0]  ResultSrcM;
    logic        MemWriteM;
    logic        ZeroE;
    logic [2:0]  LS_opcodeM;
    logic        MemReadM;
    logic [31:0] ALUResultM;
    logic [4:0]  RdM;
    logic [31:0] PCPlus4M;
    logic [31:0] PCTargetE;
    logic [31:0] WriteDataM;

    // ------------------------------------------------------------------
    // ALUControlE encoding  {MSB=1→Arith, MSB=0→Logic}
    // ------------------------------------------------------------------
    // Arithmetic
    localparam [3:0] cADD  = 4'b1001;
    localparam [3:0] cSUB  = 4'b1010;
    localparam [3:0] cSRA  = 4'b1100;
    // Logical
    localparam [3:0] cSLL  = 4'b0001;
    localparam [3:0] cSRL  = 4'b0010;
    localparam [3:0] cSLT  = 4'b0011;
    localparam [3:0] cSLTU = 4'b0100;
    localparam [3:0] cXOR  = 4'b0101;
    localparam [3:0] cOR   = 4'b0110;
    localparam [3:0] cAND  = 4'b0111;

    // Forwarding select
    localparam [1:0] FWD_REG = 2'b00;  // data1 = RD1E
    localparam [1:0] FWD_WB  = 2'b01;  // data2 = ResultW   (WB stage)  [FIXED]
    localparam [1:0] FWD_MEM = 2'b10;  // data3 = ALUResultM (MEM stage) [FIXED]

    // ------------------------------------------------------------------
    // Stimulus struct  (all fields 32-bit clean)
    // ------------------------------------------------------------------
    typedef struct packed {
        logic [31:0] RD1E;
        logic [31:0] RD2E;
        logic [31:0] PCE;
        logic [31:0] ImmExtE;
        logic [31:0] PCPlus4E;
        logic [31:0] ResultW;
        logic [1:0]  ForwardAE;
        logic [1:0]  ForwardBE;
        logic        JumpE;
        logic        ignoreSrcAE_E;
        logic        PC_SrcAE_E;
        logic [2:0]  LS_opcodeE;
        logic        RegWriteE;
        logic [1:0]  ResultSrcE;
        logic        MemWriteE;
        logic        MemReadE;
        logic [3:0]  ALUControlE;
        logic        ALUSrcE;
        logic [4:0]  RdE;
    } input_ports;

    // ------------------------------------------------------------------
    // Test vectors
    // ------------------------------------------------------------------

    localparam int NUM_VEC = 18;
    input_ports test_vectors [NUM_VEC];

    // helper task to avoid repeating boilerplate
    // (packed struct literal is verbose; use individual assignments)
    // function을 이용하여 미리 I/O 정의를 할 수 있음.
    function automatic input_ports make_vec(
        input logic [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E, ResultW,
        input logic [1:0]  ForwardAE, ForwardBE,
        input logic        JumpE, ignoreSrcAE_E, PC_SrcAE_E,
        input logic [2:0]  LS_opcodeE,
        input logic        RegWriteE,
        input logic [1:0]  ResultSrcE,
        input logic        MemWriteE, MemReadE,
        input logic [3:0]  ALUControlE,
        input logic        ALUSrcE,
        input logic [4:0]  RdE
    );
        make_vec.RD1E         = RD1E;
        make_vec.RD2E         = RD2E;
        make_vec.PCE          = PCE;
        make_vec.ImmExtE      = ImmExtE;
        make_vec.PCPlus4E     = PCPlus4E;
        make_vec.ResultW      = ResultW;
        make_vec.ForwardAE    = ForwardAE;
        make_vec.ForwardBE    = ForwardBE;
        make_vec.JumpE        = JumpE;
        make_vec.ignoreSrcAE_E= ignoreSrcAE_E;
        make_vec.PC_SrcAE_E   = PC_SrcAE_E;
        make_vec.LS_opcodeE   = LS_opcodeE;
        make_vec.RegWriteE    = RegWriteE;
        make_vec.ResultSrcE   = ResultSrcE;
        make_vec.MemWriteE    = MemWriteE;
        make_vec.MemReadE     = MemReadE;
        make_vec.ALUControlE  = ALUControlE;
        make_vec.ALUSrcE      = ALUSrcE;
        make_vec.RdE          = RdE;
    endfunction

    // 해당 Testbench 부분은 Claude의 도움을 받아 작성함. 원리는 보고서에 추가할 예정임.
    initial begin
        //                  RD1E         RD2E         PCE          ImmExtE      PCPlus4E
        //                  ResultW      FwdA    FwdB Jump IgnA PCA LSop
        //                  RgW  ResSrc MWr MRd  ALUCtl  ASrc RdE

        // [00] Reset / idle
        test_vectors[0]  = make_vec(
            32'd0,       32'd0,       32'h000, 32'd0,       32'h004,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            0, 2'b00, 0, 0, 4'b0000, 0, 5'd0);

        // ---- ARITHMETIC ALU ----

        // [01] ADD  :  10 + 20 = 30
        test_vectors[1]  = make_vec(
            32'd10,      32'd20,      32'h100, 32'd0,       32'h104,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cADD, 0, 5'd1);

        // [02] SUB  :  50 - 30 = 20
        test_vectors[2]  = make_vec(
            32'd50,      32'd30,      32'h104, 32'd0,       32'h108,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cSUB, 0, 5'd2);

        // [03] SUB  :  result = 0  →  ZeroE must assert
        //              5 - 5 = 0
        test_vectors[3]  = make_vec(
            32'd5,       32'd5,       32'h108, 32'd0,       32'h10C,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cSUB, 0, 5'd3);

        // [04] SRA  :  -4 >>> 1 = -2   (sign bit must replicate)
        //              SrcB from ImmExtE=1
        test_vectors[4]  = make_vec(
            32'hFFFF_FFFC, 32'd0,     32'h10C, 32'd1,       32'h110,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cSRA, 1, 5'd4);

        // ---- LOGICAL ALU ----

        // [05] AND  :  0xFF & 0x0F = 0x0F   (SrcB from Imm)
        test_vectors[5]  = make_vec(
            32'h0000_00FF, 32'd99,    32'h110, 32'h0000_000F, 32'h114,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cAND, 1, 5'd5);

        // [06] OR   :  10 | 5 = 15   (SrcA from ResultW via FWD_WB)
        test_vectors[6]  = make_vec(
            32'd0,       32'd5,       32'h114, 32'd0,       32'h118,
            32'd10,      FWD_WB,  FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cOR, 0, 5'd6);

        // [07] XOR  :  0xA5A5_A5A5 ^ 0xFFFF_FFFF = 0x5A5A_5A5A
        test_vectors[7]  = make_vec(
            32'hA5A5_A5A5, 32'hFFFF_FFFF, 32'h118, 32'd0, 32'h11C,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cXOR, 0, 5'd7);

        // [08] SLL  :  1 << 8 = 0x100   (SrcB from Imm)
        test_vectors[8]  = make_vec(
            32'd1,       32'd0,       32'h11C, 32'd8,       32'h120,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cSLL, 1, 5'd8);

        // [09] SRL  :  0x8000_0000 >> 1 = 0x4000_0000  (no sign fill)
        test_vectors[9]  = make_vec(
            32'h8000_0000, 32'd1,     32'h120, 32'd0,       32'h124,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cSRL, 0, 5'd9);

        // [10] SLT  :  -10 < 5  →  result = 1  (signed)
        test_vectors[10] = make_vec(
            32'hFFFF_FFF6, 32'd5,     32'h124, 32'd0,       32'h128,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cSLT, 0, 5'd10);

        // [11] SLT  :  5 < -10  →  result = 0  (signed, opposite direction)
        test_vectors[11] = make_vec(
            32'd5,       32'hFFFF_FFF6, 32'h128, 32'd0,    32'h12C,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cSLT, 0, 5'd11);

        // [12] SLTU :  1 <u 0xFFFF_FFFF  →  result = 1  (unsigned)
        test_vectors[12] = make_vec(
            32'd1,       32'hFFFF_FFFF, 32'h12C, 32'd0,    32'h130,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cSLTU, 0, 5'd12);

        // ---- SPECIAL DATAPATH ----

        // [13] LUI  :  ignoreSrcAE=1 → SrcA=0, SrcB=ImmExt=0x5000
        //              0 + 0x5000 = 0x5000
        test_vectors[13] = make_vec(
            32'd999,     32'd0,       32'h130, 32'h0000_5000, 32'h134,
            32'd0,       FWD_REG, FWD_REG, 0, 1, 0, 3'b0,
            1, 2'b00, 0, 0, cADD, 1, 5'd13);

        // [14] AUIPC:  PC_SrcAE=1 → SrcA=PCPlus4E=0x138, SrcB=ImmExt=0x3000
        //              NOTE: DUT uses PCPlus4E (not PCE) - known DUT bug #3
        //              checker matches DUT behavior (PCPlus4E + Imm)
        test_vectors[14] = make_vec(
            32'd999,     32'd0,       32'h134, 32'h0000_3000, 32'h138,
            32'd0,       FWD_REG, FWD_REG, 0, 0, 1, 3'b0,
            1, 2'b00, 0, 0, cADD, 1, 5'd14);

        // [15] JAL: PCTargetE = PCE(0x13C) + ImmExt(0x40) = 0x17C
        //           ALUResultM은 don't care지만 ALUSrcE=0으로 명시
        test_vectors[15] = make_vec(
            32'd0, 32'd0, 32'h13C, 32'h0000_0040, 32'h140,
            32'd0, FWD_REG, FWD_REG, 1, 0, 0, 3'b0,
            1, 2'b10, 0, 0, cADD, 0, 5'd15);  // ALUSrcE=0 확인

        // [16] Forwarding - FWD_MEM (ALUResultM feeds back as SrcA)
        //      SrcA = ALUResultM of previous cycle (we force via ResultW trick:
        //      use FWD_WB with ResultW set to the value we want)
        //      OR  :  0xDEAD | 0x0001 = 0xDEAD   (FWD_WB on SrcA)
        test_vectors[16] = make_vec(
            32'd0,       32'd1,       32'h140, 32'd0,       32'h144,
            32'h0000_DEAD, FWD_WB, FWD_REG, 0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cOR, 0, 5'd16);

        // [17] ADD with both operands from forwarding
        //      SrcA = ResultW(100) FWD_WB, SrcB = ResultW(200) FWD_WB via Imm path?
        //      Use ALUSrcE=0 so SrcB = WriteDataE (ForwardBE=FWD_WB → ResultW=200)
        //      100 + 200 = 300
        test_vectors[17] = make_vec(
            32'd0,       32'd0,       32'h144, 32'd0,       32'h148,
            32'd100,     FWD_WB,  FWD_WB,  0, 0, 0, 3'b0,
            1, 2'b00, 0, 0, cADD, 0, 5'd17);
    end

    // ------------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------------
    initial clk = 0;
    always #3 clk = ~clk;

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    input_ports tb_stimulus;

    ALU_stage dut (
        .RD1E          (tb_stimulus.RD1E),
        .RD2E          (tb_stimulus.RD2E),
        .PCE           (tb_stimulus.PCE),
        .RdE           (tb_stimulus.RdE),
        .ImmExtE       (tb_stimulus.ImmExtE),
        .PCPlus4E      (tb_stimulus.PCPlus4E),
        .ResultW       (tb_stimulus.ResultW),
        .ForwardAE     (tb_stimulus.ForwardAE),
        .ForwardBE     (tb_stimulus.ForwardBE),
        .JumpE         (tb_stimulus.JumpE),
        .ignoreSrcAE_E (tb_stimulus.ignoreSrcAE_E),
        .PC_SrcAE_E    (tb_stimulus.PC_SrcAE_E),
        .LS_opcodeE    (tb_stimulus.LS_opcodeE),
        .RegWriteE     (tb_stimulus.RegWriteE),
        .ResultSrcE    (tb_stimulus.ResultSrcE),
        .MemWriteE     (tb_stimulus.MemWriteE),
        .MemReadE      (tb_stimulus.MemReadE),
        .ALUControlE   (tb_stimulus.ALUControlE),
        .ALUSrcE       (tb_stimulus.ALUSrcE),
        .clk           (clk),
        .rstn          (rstn),
        .RegWriteM     (RegWriteM),
        .ResultSrcM    (ResultSrcM),
        .MemWriteM     (MemWriteM),
        .ZeroE         (ZeroE),
        .LS_opcodeM    (LS_opcodeM),
        .MemReadM      (MemReadM),
        .ALUResultM    (ALUResultM),
        .RdM           (RdM),
        .PCPlus4M      (PCPlus4M),
        .PCTargetE     (PCTargetE),
        .WriteDataM    (WriteDataM)
    );

    // ------------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------------
    int cnt;

    initial begin
        rstn = 0;
        cnt  = 0;
        tb_stimulus = test_vectors[0];

        @(posedge clk);
        rstn = 1;
        repeat(2) @(posedge clk);

        for (int i = 1; i < NUM_VEC; i++) begin : test_loop

            // --- declarations MUST come before any procedural statement ---
            logic [31:0] exp_SrcA, exp_SrcB, exp_ALUResult, exp_PCTarget;
            logic        exp_Zero;

            // Apply stimulus
            tb_stimulus = test_vectors[i];
            @(posedge clk);   // DUT captures inputs on this edge
            #1;               // wait past clock edge for output to settle

            // ---- expected SrcA (mirrors DUT mux priority) ----
            // NOTE: PC_SrcAE_E selects PCPlus4E in the DUT (not PCE)
            //       This is a known DUT bug - checker intentionally matches DUT.
            if      (tb_stimulus.PC_SrcAE_E)               exp_SrcA = tb_stimulus.PCE;
            else if (tb_stimulus.ignoreSrcAE_E)             exp_SrcA = 32'd0;
            else if (tb_stimulus.ForwardAE == FWD_WB)       exp_SrcA = tb_stimulus.ResultW;
            else if (tb_stimulus.ForwardAE == FWD_MEM)      exp_SrcA = ALUResultM; 
            else                                            exp_SrcA = tb_stimulus.RD1E;

            // ---- expected SrcB ----
            if      (tb_stimulus.ALUSrcE)                   exp_SrcB = tb_stimulus.ImmExtE;
            else if (tb_stimulus.ignoreSrcAE_E)             exp_SrcB = tb_stimulus.ImmExtE;
            else if (tb_stimulus.ForwardBE == FWD_WB)       exp_SrcB = tb_stimulus.ResultW;
            else if (tb_stimulus.ForwardBE == FWD_MEM)      exp_SrcB = ALUResultM;
            else                                            exp_SrcB = tb_stimulus.RD2E;

            // ---- expected ALU result ----
            case (tb_stimulus.ALUControlE)
                cADD : exp_ALUResult = exp_SrcA + exp_SrcB;
                cSUB : exp_ALUResult = exp_SrcA - exp_SrcB;
                cSRA : exp_ALUResult = $signed(exp_SrcA) >>> exp_SrcB[4:0];
                cSLL : exp_ALUResult = exp_SrcA << exp_SrcB[4:0];
                cSRL : exp_ALUResult = exp_SrcA >> exp_SrcB[4:0];
                cSLT : exp_ALUResult = ($signed(exp_SrcA) < $signed(exp_SrcB)) ? 32'd1 : 32'd0;
                cSLTU: exp_ALUResult = (exp_SrcA < exp_SrcB)                   ? 32'd1 : 32'd0;
                cXOR : exp_ALUResult = exp_SrcA ^ exp_SrcB;
                cOR  : exp_ALUResult = exp_SrcA | exp_SrcB;
                cAND : exp_ALUResult = exp_SrcA & exp_SrcB;
                default: exp_ALUResult = 32'd0;
            endcase

            exp_Zero      = (exp_ALUResult == 32'd0);
            exp_PCTarget  = tb_stimulus.PCE + tb_stimulus.ImmExtE;

            // ---- display header ----
            $display("--------------------------------------------------");
            $display("[Index %02d] ALUCtl=%04b  SrcA=%08h  SrcB=%08h",
                     i, tb_stimulus.ALUControlE, exp_SrcA, exp_SrcB);
            // CHECK 매크로 호출 바로 위에 추가
            $display("  DEBUG [%02d] JumpE=%b PCE=%08h ImmExtE=%08h PCTargetE=%08h",
                    i, tb_stimulus.JumpE, tb_stimulus.PCE, 
                    tb_stimulus.ImmExtE, PCTargetE);
            // ---- check ALU result ----
            `CHECK(i, ALUResultM, exp_ALUResult, "ALURes")

            // ---- check Zero flag ----
            `CHECK(i, ZeroE, exp_Zero, "Zero")

            // ---- check PCTargetE when Jump ----
            if (tb_stimulus.JumpE)
                `CHECK(i, PCTargetE, exp_PCTarget, "PCTgt")

            // ---- check control signal passthrough ----
            `CHECK(i, RegWriteM,  tb_stimulus.RegWriteE,  "RgW")
            `CHECK(i, MemWriteM,  tb_stimulus.MemWriteE,  "MWr")
            `CHECK(i, MemReadM,   tb_stimulus.MemReadE,   "MRd")
            `CHECK(i, ResultSrcM, tb_stimulus.ResultSrcE, "ResSrc")

        end

        $display("==================================================");
        if (cnt == 0)
            $display("All %0d vectors PASSED.", NUM_VEC - 1);
        else
            $display("FAILED: %0d error(s) detected.", cnt);
        $display("==================================================");
        $finish;
    end

    // ------------------------------------------------------------------
    // Waveform dump
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("ALUstage_Simulation_Waveform.vcd");
        $dumpvars(0, tb_ALU_stage);
    end

endmodule