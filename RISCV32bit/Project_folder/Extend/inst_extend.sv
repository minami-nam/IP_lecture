`define FPGA
module inst_extend(
  input [24:0] inst,
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

    // output을 위한 reg/wire 설정
    reg [31:0] mem;
    assign ImmExtD = mem;

    // S type
    wire [6:0] s_ins1; 
    wire [4:0] s_ins2;

    assign s_ins1 = inst[24:18];    // 7bits
    assign s_ins2 = inst[4:0];      // 5bits

    // B type
    wire [12:0] b_inst;
    assign b_inst = {inst[24], inst[0], inst[23:18], inst[4:1], 1'b0};

    // J type 
    wire [20:0] j_inst;
    assign j_inst = {inst[24], inst[12:5], inst[13], inst[23:14], 1'b0};


    // 올바른 값을 mem에 할당
    always @(*) begin
        case(ImmSrcD)
            IDLE : mem = {{7{1'b0}}, inst}; 
            // addi, lw
            I_type : mem = {{7{inst[24]}}, inst}; 
            S_type : mem = {{20{inst[24]}}, s_ins1, s_ins2}; 
            B_type : mem = {{19{inst[24]}}, b_inst};
            U_type : mem = {inst[24:5], {12{1'b0}}};
            J_type : mem = {{11{inst[24]}}, j_inst};
            UNKNOWN : mem = 0;
            default : mem = 'hzzzz;
        endcase
    end

    `ifdef SIM
        initial mem = 0;
    `endif


endmodule