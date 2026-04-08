`define SIM

module hazard_detection(
    input [4:0] Rs1D,
    input [4:0] Rs2D,

    input [4:0] Rs1E,
    input [4:0] Rs2E,
    input [4:0] RdE,
    input ZeroE,
    input JumpE,
    input BranchE,
    input [1:0] ResultSrcE, 

    input [4:0] RdM,
    input [4:0] RdW,
    input RegWriteM,
    input RegWriteW,

    output StallIF_n,
    output StallID_n,
    output FlushD,
    output FlushE,
    output [1:0] ForwardAE,
    output [1:0] ForwardBE,
    output pc_en
);
    // Structural Hazard : Memory Access와 Instruction Fetch가 동시에 Memory Access를 요구하는 경우
    // 근데 내 구조는 Instruction Memory와 Data Memory를 분리할거라.. 글쎄다


    // Data Hazard : 현재 명령어가 이전 명령어를 참고하는 경우 발생하는 현상. Hazard라고 볼 수 있음.
    // 크게 RAW, WAW, WAR로 나뉘고, Write될 값의 timing issue로 인해 발생한다고 볼 수 있음.
    // Read After Write : 
    // ALU로 들어온 레지스터 주소들이 이전 명령어들의 결과 주소를 참조하는 경우를 체크.
    wire match_1E_M, match_2E_M, match_1E_W, match_2E_W;
    // Forwarding 용
    assign match_1E_M = (Rs1E == RdM) & (RdM != 5'b0);
    assign match_2E_M = (Rs2E == RdM) & (RdM != 5'b0);
    assign match_1E_W = (Rs1E == RdW) & (RdW != 5'b0);
    assign match_2E_W = (Rs2E == RdW) & (RdW != 5'b0);

    // 아래 2개는 OoO 환경에서 발생하는 Hazard임.

    // Write After Read : 

    // Write After Write : 

    // Control Hazard : Branch 명령어에서 발생함. 해결 방법은 Decoding Stage에서 조건을 미리 판별함.
    // 물론 나중에 Pipeline의 깊이가 너무 깊어지면 Flush를 장난아니게 해야하는 상황이 발생하기 때문에, 해당 방법 대신 Branch Prediction을 사용하여 최대한 HIT를 높임.


    wire PCSrcE;
    assign PCSrcE = (ZeroE&BranchE) | JumpE;
    assign pc_en = PCSrcE;

    wire lwstall;
    assign lwstall = (ResultSrcE == 2'b01) & ((Rs1D == RdE) | (Rs2D == RdE)) & (RdE != 5'd0);
    assign StallID_n = !lwstall;
    assign StallIF_n = !lwstall;

    // ID에서 결과가 나오면, 이후의 값들은 Flush 해주어야 함.
    assign FlushD = PCSrcE;
    assign FlushE = PCSrcE | lwstall;

    // Forwarding

    assign ForwardAE = (RegWriteM & match_1E_M) ? 2'b10 : (RegWriteW & match_1E_W) ? 2'b01 : 2'b00;
    assign ForwardBE = (RegWriteM & match_2E_M) ? 2'b10 : (RegWriteW & match_2E_W) ? 2'b01 : 2'b00;  

    


endmodule