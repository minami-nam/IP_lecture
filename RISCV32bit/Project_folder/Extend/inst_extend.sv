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

    always @(*) begin
        case(ImmSrcD)
            IDLE : mem = 32'b0; 
            
            // 💡 I-type (addi, lw 등)
            I_type : mem = {{20{inst[31]}}, inst[31:20]}; 
            
            // 💡 S-type (sw)
            S_type : mem = {{20{inst[31]}}, inst[31:25], inst[11:7]}; 
            
            // 💡 B-type (beq 등)
            B_type : mem = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
            
            // 💡 U-type (lui 등)
            U_type : mem = {inst[31:12], 12'b0};
            
            // 💡 J-type (jal)
            J_type : mem = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
            
            UNKNOWN : mem = 32'b0;
            default : mem = 32'b0;
        endcase
    end

    `ifdef SIM
        initial mem = 0;
    `endif

endmodule