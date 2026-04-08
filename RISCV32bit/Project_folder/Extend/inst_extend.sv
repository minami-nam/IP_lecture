`define SIM
module inst_extend(
  input [31:0] inst,
  input [2:0] ImmSrcD,  // 이 부분은 수정

  output [31:0] ImmExtD  
);  
    // State 선언
    localparam int IDLE = 0;
    localparam int I_type = 1;
    localparam int S_type = 2;
    localparam int B_type = 3;
    localparam int U_type = 4;
    localparam int J_type = 5;
    localparam int UNKNOWN = 6;

    reg [31:0] mem;
    assign ImmExtD = mem;

    // RISC-V 공식 스펙에 맞춘 깔끔한 비트 슬라이싱!
    always @(*) begin
        case(ImmSrcD)
            IDLE : mem = 32'b0; 
            
            // 💡 I-type (addi, lw 등): 상위 12비트 [31:20]만 쏙 빼서 부호 확장!
            I_type : mem = {{20{inst[31]}}, inst[31:20]}; 
            
            // 💡 S-type (sw): [31:25]와 [11:7]을 합쳐서 부호 확장
            S_type : mem = {{20{inst[31]}}, inst[31:25], inst[11:7]}; 
            
            // 💡 B-type (beq 등): 복잡하게 섞인 비트들을 재조합 (맨 끝은 무조건 0)
            B_type : mem = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            
            // 💡 U-type (lui 등): [31:12]를 그대로 쓰고 하위 12비트는 0으로 채움
            U_type : mem = {inst[31:12], 12'b0};
            
            // 💡 J-type (jal): 20비트 값을 재조합하여 부호 확장
            J_type : mem = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            
            UNKNOWN : mem = 32'b0;
            default : mem = 32'b0;
        endcase
    end

    `ifdef SIM
        initial mem = 0;
    `endif

endmodule