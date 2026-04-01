module tb_ALU_stage;

    // I/O Setting
    // logic [31:0] RD1E;
    // logic [31:0] RD2E;

    // logic [31:0] PCE;

    // logic [24:0] ImmExtE;
    // logic [31:0] PCPlus4E;
    
    // // Need Muxing
    // logic [31:0] ResultW;
    // logic [1:0] ForwardAE;
    // logic [1:0] ForwardBE;

    // logic RegWriteE;
    // logic [1:0] ResultSrcE;
    // logic MemWriteE;
    // logic [2:0] ALUControlE;
    // logic ALUSrcE;

    logic clk;
    logic rstn;


    logic RegWriteM;
    logic [1:0] ResultSrcM;
    logic MemWriteM;
    logic ZeroE;
    
    logic [31:0] ALUResultM;
    logic [4:0] RdM;
    logic [31:0] PCPlus4M;
    logic [31:0] PCTargetE;
    logic [31:0] WriteDataM;


    


    initial clk = 0;
    always #3 clk = ~clk;

    // ALUControlE로 연산 종류 설정
    // RD1E, RD2E로 값 대입
    // ForwardAE, ForwardBE로 MUX 조절 가능

    typedef struct packed{
        logic [31:0] RD1E;
        logic [31:0] RD2E;

        logic [31:0] PCE;

        logic [24:0] ImmExtE;
        logic [31:0] PCPlus4E;
        
        // Need Muxing
        logic [31:0] ResultW;
        logic [1:0] ForwardAE;
        logic [1:0] ForwardBE;

        logic RegWriteE;
        logic [1:0] ResultSrcE;
        logic MemWriteE;
        logic [2:0] ALUControlE;
        logic ALUSrcE;
        logic [4:0] RdE;

    } input_ports;


    // 2. ALU 제어 신호 파라미터 정의
    localparam logic [2:0] IDLE = 3'b000;
    localparam logic [2:0] sADD = 3'b001;
    localparam logic [2:0] sSUB = 3'b010;
    localparam logic [2:0] sMUL = 3'b011;
    localparam logic [2:0] sDIV = 3'b100;
    localparam logic [2:0] sINC = 3'b101;
    localparam logic [2:0] sDEC = 3'b110;
    localparam logic [2:0] sNEG = 3'b111;

    localparam logic [1:0] FWD_REG = 2'b00; // 기본 레지스터 값 사용
    localparam logic [1:0] FWD_WB  = 2'b01; // Writeback 단계에서 포워딩
    localparam logic [1:0] FWD_MEM = 2'b10; // Memory 단계에서 포워딩



    input_ports test_vectors [8] = '{

        // [index -1] init
        '{RD1E: 32'd0, RD2E: 32'd0, PCE: 32'h00, ImmExtE: 25'd0, PCPlus4E: 32'h000,
          ResultW: 32'd0, ForwardAE: FWD_REG, ForwardBE: FWD_REG,
          RegWriteE: 1'b0, ResultSrcE: 2'b00, MemWriteE: 1'b0, ALUControlE: 0, ALUSrcE: 1'b0, RdE : 5'd0},
        
        // [Index 0] 일반적인 더하기 (sADD)
        // SrcA = RD1E(10), SrcB = RD2E(20) -> 예상 결과: 30
        '{RD1E: 32'd10, RD2E: 32'd20, PCE: 32'h100, ImmExtE: 25'd0, PCPlus4E: 32'h104,
          ResultW: 32'd0, ForwardAE: FWD_REG, ForwardBE: FWD_REG,
          RegWriteE: 1'b1, ResultSrcE: 2'b00, MemWriteE: 1'b0, ALUControlE: sADD, ALUSrcE: 1'b0, RdE : 5'd1},

        // [Index 1] 포워딩을 동반한 빼기 (sSUB)
        // SrcA = RD1E(50), SrcB = ResultW(15) (ForwardB 사용) -> 예상 결과: 50 - 15 = 35
        '{RD1E: 32'd50, RD2E: 32'd0, PCE: 32'h104, ImmExtE: 25'd0, PCPlus4E: 32'h108,
          ResultW: 32'd15, ForwardAE: FWD_REG, ForwardBE: FWD_WB,
          RegWriteE: 1'b1, ResultSrcE: 2'b00, MemWriteE: 1'b0, ALUControlE: sSUB, ALUSrcE: 1'b0, RdE : 5'd2},

        // [Index 2] 즉치값을 이용한 곱하기 (sMUL)
        // SrcA = RD1E(5), SrcB = ImmExtE(4) (ALUSrcE=1) -> 예상 결과: 5 * 4 = 20
        '{RD1E: 32'd5, RD2E: 32'd99, PCE: 32'h108, ImmExtE: 25'd4, PCPlus4E: 32'h10C,
          ResultW: 32'd0, ForwardAE: FWD_REG, ForwardBE: FWD_REG,
          RegWriteE: 1'b1, ResultSrcE: 2'b00, MemWriteE: 1'b0, ALUControlE: sMUL, ALUSrcE: 1'b1, RdE : 5'd3},

        // [Index 3] 양방향 포워딩을 동반한 나누기 (sDIV)
        // SrcA = ResultW(100), SrcB = ResultW(20) (둘 다 WB에서 포워딩) -> 예상 결과: 100 / 100 = 1
        '{RD1E: 32'd0, RD2E: 32'd0, PCE: 32'h10C, ImmExtE: 25'd0, PCPlus4E: 32'h110,
          ResultW: 32'd100, ForwardAE: FWD_WB, ForwardBE: FWD_WB, // 둘 다 ResultW 값을 가져옴 (편의상 동일값)
          RegWriteE: 1'b1, ResultSrcE: 2'b00, MemWriteE: 1'b0, ALUControlE: sDIV, ALUSrcE: 1'b0, RdE : 5'd4},

        // [Index 4] 값 증가 (sINC) 
        // SrcA = RD1E(99) -> 예상 결과: 100 (ALU 내부에서 +1 처리한다고 가정)
        '{RD1E: 32'd99, RD2E: 32'd0, PCE: 32'h110, ImmExtE: 25'd0, PCPlus4E: 32'h114,
          ResultW: 32'd0, ForwardAE: FWD_REG, ForwardBE: FWD_REG,
          RegWriteE: 1'b1, ResultSrcE: 2'b00, MemWriteE: 1'b0, ALUControlE: sINC, ALUSrcE: 1'b0, RdE : 5'd5},

        // [Index 5] 포워딩 값을 감소 (sDEC)
        // SrcA = ResultW(8) (ForwardA 사용) -> 예상 결과: 7 (ALU 내부에서 -1 처리한다고 가정)
        '{RD1E: 32'd0, RD2E: 32'd0, PCE: 32'h114, ImmExtE: 25'd0, PCPlus4E: 32'h118,
          ResultW: 32'd8, ForwardAE: FWD_WB, ForwardBE: FWD_REG,
          RegWriteE: 1'b1, ResultSrcE: 2'b00, MemWriteE: 1'b0, ALUControlE: sDEC, ALUSrcE: 1'b0, RdE : 5'd6},

        // [Index 6] 2의 보수 부호 반전 (sNEG)
        // SrcA = RD1E(5) -> 예상 결과: -5 (32'hFFFFFFFB)
        '{RD1E: 32'd5, RD2E: 32'd0, PCE: 32'h118, ImmExtE: 25'd0, PCPlus4E: 32'h11C,
          ResultW: 32'd0, ForwardAE: FWD_REG, ForwardBE: FWD_REG,
          RegWriteE: 1'b1, ResultSrcE: 2'b00, MemWriteE: 1'b0, ALUControlE: sNEG, ALUSrcE: 1'b0, RdE : 5'd7}
    };

    input_ports tb_stimulus;

    ALU_stage dut(
        .RD1E(tb_stimulus.RD1E),
        .RD2E(tb_stimulus.RD2E),
        .PCE(tb_stimulus.PCE),

        .ImmExtE(tb_stimulus.ImmExtE),
        .PCPlus4E(tb_stimulus.PCPlus4E),
        
        // Need Muxing
        .ResultW(tb_stimulus.ResultW),
        .ForwardAE(tb_stimulus.ForwardAE),
        .ForwardBE(tb_stimulus.ForwardBE),

        .RegWriteE(tb_stimulus.RegWriteE),
        .ResultSrcE(tb_stimulus.ResultSrcE),
        .MemWriteE(tb_stimulus.MemWriteE),
        .ALUControlE(tb_stimulus.ALUControlE),
        .ALUSrcE(tb_stimulus.ALUSrcE),
        .RdE(tb_stimulus.RdE),

        // 여기서부터 상위 모듈의 I/O 직결
        // clk rstn
        .clk(clk),
        .rstn(rstn),

        // outputs
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .MemWriteM(MemWriteM),
        .ZeroE(ZeroE),
            
        .ALUResultM(ALUResultM),
        .RdM(RdM),
        .PCPlus4M(PCPlus4M),
        .PCTargetE(PCTargetE),
        .WriteDataM(WriteDataM)


    );

    reg [3:0] cnt;

    // TB 작성
    initial begin
        rstn <= 0;
        tb_stimulus <= 0;
        cnt <= 0;
        repeat(2) @(posedge clk);
        rstn <= 1;
        repeat(2) @(posedge clk);

        foreach (test_vectors[i]) begin
            tb_stimulus <= test_vectors[i];
            @(posedge clk);
        end

        repeat(5) @(posedge clk);
        $finish;
    end

    initial begin
        wait(rstn);
        repeat(4) @(posedge clk);


        for (int i=0; i<8; i++) begin
            input_ports check_vaild = test_vectors[i];

            case(check_vaild.ALUControlE)
                    1 : begin
                        if (ALUResultM==(check_vaild.RD1E+check_vaild.RD2E)) $display("Injecting Case : ADD, Pass");    
                        else begin
                            $display("Injecting Case : ADD, Error : %5d", ALUResultM);
                            cnt <= cnt+1;
                        end
                    end
                    2 : begin
                        if (ALUResultM==(check_vaild.RD1E-check_vaild.ResultW)) $display("Injecting Case : sSUB, Pass");
                        else begin
                            $display("Injecting Case : sSUB, Error : %5d", ALUResultM);
                            cnt <= cnt+1;
                        end
                    end
                    3 : begin
                        if (ALUResultM==(check_vaild.RD1E*check_vaild.ImmExtE)) $display("Injecting Case : sMUL, Pass");
                        else begin
                            $display("Injecting Case : sMUL, Error : %5d", ALUResultM);
                            cnt <= cnt+1;
                        end
                    end
                    4 : begin
                        if (ALUResultM==1'b1) $display("Injecting Case : sDIV, Pass");
                        else begin
                            $display("Injecting Case : sDIV, Error : %5d", ALUResultM);
                            cnt <= cnt+1;
                        end
                    end
                    5 : begin
                        if (ALUResultM==(check_vaild.RD1E+1)) $display("Injecting Case : sINC, Pass");
                        else begin
                            $display("Injecting Case : sINC, Error : %5d", ALUResultM);
                            cnt <= cnt+1;
                        end
                    end
                    6 : begin
                        if (ALUResultM==(check_vaild.ResultW-1)) $display("Injecting Case : sDEC, Pass");
                        else begin
                            $display("Injecting Case : sDEC, Error : %5d", ALUResultM);
                            cnt <= cnt+1;
                        end
                    end
                    7 : begin
                        if (ALUResultM==(~check_vaild.RD1E+1)) $display("Injecting Case : sNEG, Pass");
                        else begin
                            $display("Injecting Case : sNEG, Error : %5d", ALUResultM);
                            cnt <= cnt+1;
                        end
                    end

                    0 : $display("Initializing...");
            endcase
            @(posedge clk);
        end

        $display("Exiting...");
    end


    // Waveform Settings
    initial begin
        $dumpfile("ALUstage_Simulation_Waveform.vcd");
        $dumpvars(0, dut);
    end




endmodule