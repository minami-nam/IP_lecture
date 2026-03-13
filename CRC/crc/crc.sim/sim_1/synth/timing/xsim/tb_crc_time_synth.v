// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
// Date        : Thu Mar 12 07:12:54 2026
// Host        : minamidev running 64-bit Ubuntu 24.04.4 LTS
// Command     : write_verilog -mode timesim -nolib -sdf_anno true -force -file
//               /home/minami/Coding_IPDesign/IP_lecture/CRC/crc/crc.sim/sim_1/synth/timing/xsim/tb_crc_time_synth.v
// Design      : crc
// Purpose     : This verilog netlist is a timing simulation representation of the design and should not be modified or
//               synthesized. Please ensure that this netlist is used with the corresponding SDF file.
// Device      : xc7z007sclg400-2
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps
`define XIL_TIMING

(* CCITT = "16'b0001000000100001" *) (* CCITT_REV = "16'b1000010000001000" *) (* CHECK = "2" *) 
(* DONE = "3" *) (* IDLE = "1" *) (* INIT = "0" *) 
(* WAIT_CLK = "4" *) 
(* NotValidForBitStream *)
module crc
   (i_DV,
    i_Data,
    rstn,
    clk,
    o_CRC,
    o_CRC_Xor,
    o_CRC_Xor_Reversed,
    o_CRC_Reversed);
  input i_DV;
  input [7:0]i_Data;
  input rstn;
  input clk;
  output [15:0]o_CRC;
  output [15:0]o_CRC_Xor;
  output [15:0]o_CRC_Xor_Reversed;
  output [15:0]o_CRC_Reversed;

  wire clk;
  wire clk_IBUF;
  wire clk_IBUF_BUFG;
  wire \cnt[0]_i_1_n_0 ;
  wire \cnt[1]_i_1_n_0 ;
  wire \cnt[2]_i_1_n_0 ;
  wire \cnt[3]_i_1_n_0 ;
  wire \cnt[4]_i_1_n_0 ;
  wire \cnt[4]_i_2_n_0 ;
  wire \cnt[4]_i_3_n_0 ;
  wire [4:0]cnt_reg;
  wire \crc_reg[15]_i_2_n_0 ;
  wire done;
  wire done_reg_i_1_n_0;
  wire i_DV;
  wire i_DV_IBUF;
  wire [7:0]i_Data;
  wire [7:0]i_Data_IBUF;
  wire input_reg1;
  wire input_reg15_out;
  wire \input_reg[7]_i_1_n_0 ;
  wire \input_reg[7]_i_2_n_0 ;
  wire \input_reg_reg_n_0_[0] ;
  wire \input_reg_reg_n_0_[1] ;
  wire \input_reg_reg_n_0_[2] ;
  wire \input_reg_reg_n_0_[3] ;
  wire \input_reg_reg_n_0_[4] ;
  wire \input_reg_reg_n_0_[5] ;
  wire \input_reg_reg_n_0_[6] ;
  wire \input_reg_reg_n_0_[7] ;
  wire [1:0]n_state;
  wire n_state__0;
  wire \n_state_reg[0]_i_1_n_0 ;
  wire \n_state_reg[1]_i_1_n_0 ;
  wire \n_state_reg[1]_i_2_n_0 ;
  wire [15:0]o_CRC;
  wire [15:0]o_CRC_OBUF;
  wire [15:0]o_CRC_Reversed;
  wire [15:0]o_CRC_Reversed_OBUF;
  wire [15:0]o_CRC_Xor;
  wire [15:0]o_CRC_Xor_OBUF;
  wire [15:0]o_CRC_Xor_Reversed;
  wire [15:0]o_CRC_Xor_Reversed_OBUF;
  wire [15:1]p_0_in;
  wire p_0_in0_in;
  wire p_0_in3_in;
  wire rstn;
  wire rstn_IBUF;
  wire \state[0]_i_1_n_0 ;
  wire \state[1]_i_1_n_0 ;
  wire \state_reg_n_0_[0] ;
  wire \state_reg_n_0_[1] ;
  wire table_reg1;
  wire \table_reg[0]_i_1_n_0 ;
  wire \table_reg[12]_i_1_n_0 ;
  wire \table_reg[12]_i_3_n_0 ;
  wire \table_reg[12]_i_4_n_0 ;
  wire \table_reg[15]_i_1_n_0 ;
  wire \table_reg[5]_i_1_n_0 ;
  wire \table_reg_reg_n_0_[0] ;
  wire \table_reg_reg_n_0_[10] ;
  wire \table_reg_reg_n_0_[11] ;
  wire \table_reg_reg_n_0_[12] ;
  wire \table_reg_reg_n_0_[13] ;
  wire \table_reg_reg_n_0_[14] ;
  wire \table_reg_reg_n_0_[1] ;
  wire \table_reg_reg_n_0_[2] ;
  wire \table_reg_reg_n_0_[3] ;
  wire \table_reg_reg_n_0_[4] ;
  wire \table_reg_reg_n_0_[5] ;
  wire \table_reg_reg_n_0_[6] ;
  wire \table_reg_reg_n_0_[7] ;
  wire \table_reg_reg_n_0_[8] ;
  wire \table_reg_reg_n_0_[9] ;
  wire table_rev_reg1;
  wire \table_rev_reg[0]_i_1_n_0 ;
  wire \table_rev_reg[10]_i_1_n_0 ;
  wire \table_rev_reg[11]_i_1_n_0 ;
  wire \table_rev_reg[12]_i_1_n_0 ;
  wire \table_rev_reg[13]_i_1_n_0 ;
  wire \table_rev_reg[14]_i_1_n_0 ;
  wire \table_rev_reg[15]_i_1_n_0 ;
  wire \table_rev_reg[15]_i_2_n_0 ;
  wire \table_rev_reg[15]_i_3_n_0 ;
  wire \table_rev_reg[1]_i_1_n_0 ;
  wire \table_rev_reg[2]_i_1_n_0 ;
  wire \table_rev_reg[3]_i_1_n_0 ;
  wire \table_rev_reg[4]_i_1_n_0 ;
  wire \table_rev_reg[5]_i_1_n_0 ;
  wire \table_rev_reg[6]_i_1_n_0 ;
  wire \table_rev_reg[7]_i_1_n_0 ;
  wire \table_rev_reg[8]_i_1_n_0 ;
  wire \table_rev_reg[9]_i_1_n_0 ;
  wire \table_rev_reg_reg_n_0_[15] ;

initial begin
 $sdf_annotate("tb_crc_time_synth.sdf",,,,"tool_control");
end
  BUFG clk_IBUF_BUFG_inst
       (.I(clk_IBUF),
        .O(clk_IBUF_BUFG));
  IBUF clk_IBUF_inst
       (.I(clk),
        .O(clk_IBUF));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT5 #(
    .INIT(32'h40100001)) 
    \cnt[0]_i_1 
       (.I0(cnt_reg[0]),
        .I1(\state_reg_n_0_[0] ),
        .I2(\state_reg_n_0_[1] ),
        .I3(n_state[0]),
        .I4(n_state[1]),
        .O(\cnt[0]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h6000060000000006)) 
    \cnt[1]_i_1 
       (.I0(cnt_reg[1]),
        .I1(cnt_reg[0]),
        .I2(\state_reg_n_0_[0] ),
        .I3(\state_reg_n_0_[1] ),
        .I4(n_state[0]),
        .I5(n_state[1]),
        .O(\cnt[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT4 #(
    .INIT(16'h006A)) 
    \cnt[2]_i_1 
       (.I0(cnt_reg[2]),
        .I1(cnt_reg[1]),
        .I2(cnt_reg[0]),
        .I3(\cnt[4]_i_3_n_0 ),
        .O(\cnt[2]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT5 #(
    .INIT(32'h00006AAA)) 
    \cnt[3]_i_1 
       (.I0(cnt_reg[3]),
        .I1(cnt_reg[2]),
        .I2(cnt_reg[0]),
        .I3(cnt_reg[1]),
        .I4(\cnt[4]_i_3_n_0 ),
        .O(\cnt[3]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h000000006AAAAAAA)) 
    \cnt[4]_i_1 
       (.I0(cnt_reg[4]),
        .I1(cnt_reg[3]),
        .I2(cnt_reg[1]),
        .I3(cnt_reg[0]),
        .I4(cnt_reg[2]),
        .I5(\cnt[4]_i_3_n_0 ),
        .O(\cnt[4]_i_1_n_0 ));
  LUT1 #(
    .INIT(2'h1)) 
    \cnt[4]_i_2 
       (.I0(rstn_IBUF),
        .O(\cnt[4]_i_2_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT4 #(
    .INIT(16'h7FDE)) 
    \cnt[4]_i_3 
       (.I0(n_state[1]),
        .I1(n_state[0]),
        .I2(\state_reg_n_0_[1] ),
        .I3(\state_reg_n_0_[0] ),
        .O(\cnt[4]_i_3_n_0 ));
  FDCE #(
    .INIT(1'b0)) 
    \cnt_reg[0] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .CLR(\cnt[4]_i_2_n_0 ),
        .D(\cnt[0]_i_1_n_0 ),
        .Q(cnt_reg[0]));
  FDCE #(
    .INIT(1'b0)) 
    \cnt_reg[1] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .CLR(\cnt[4]_i_2_n_0 ),
        .D(\cnt[1]_i_1_n_0 ),
        .Q(cnt_reg[1]));
  FDCE #(
    .INIT(1'b0)) 
    \cnt_reg[2] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .CLR(\cnt[4]_i_2_n_0 ),
        .D(\cnt[2]_i_1_n_0 ),
        .Q(cnt_reg[2]));
  FDCE #(
    .INIT(1'b0)) 
    \cnt_reg[3] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .CLR(\cnt[4]_i_2_n_0 ),
        .D(\cnt[3]_i_1_n_0 ),
        .Q(cnt_reg[3]));
  FDCE #(
    .INIT(1'b0)) 
    \cnt_reg[4] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .CLR(\cnt[4]_i_2_n_0 ),
        .D(\cnt[4]_i_1_n_0 ),
        .Q(cnt_reg[4]));
  LUT3 #(
    .INIT(8'h20)) 
    \crc_reg[15]_i_1 
       (.I0(i_DV_IBUF),
        .I1(\state_reg_n_0_[1] ),
        .I2(\state_reg_n_0_[0] ),
        .O(input_reg15_out));
  LUT6 #(
    .INIT(64'h0000000000000800)) 
    \crc_reg[15]_i_2 
       (.I0(cnt_reg[0]),
        .I1(cnt_reg[3]),
        .I2(cnt_reg[2]),
        .I3(p_0_in3_in),
        .I4(cnt_reg[1]),
        .I5(cnt_reg[4]),
        .O(\crc_reg[15]_i_2_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[0] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[0] ),
        .Q(o_CRC_OBUF[0]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[10] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[10] ),
        .Q(o_CRC_OBUF[10]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[11] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[11] ),
        .Q(o_CRC_OBUF[11]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[12] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[12] ),
        .Q(o_CRC_OBUF[12]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[13] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[13] ),
        .Q(o_CRC_OBUF[13]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[14] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[14] ),
        .Q(o_CRC_OBUF[14]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[15] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in0_in),
        .Q(o_CRC_OBUF[15]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[1] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[1] ),
        .Q(o_CRC_OBUF[1]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[2] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[2] ),
        .Q(o_CRC_OBUF[2]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[3] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[3] ),
        .Q(o_CRC_OBUF[3]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[4] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[4] ),
        .Q(o_CRC_OBUF[4]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[5] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[5] ),
        .Q(o_CRC_OBUF[5]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[6] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[6] ),
        .Q(o_CRC_OBUF[6]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[7] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[7] ),
        .Q(o_CRC_OBUF[7]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[8] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[8] ),
        .Q(o_CRC_OBUF[8]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_reg_reg[9] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_reg_reg_n_0_[9] ),
        .Q(o_CRC_OBUF[9]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[0] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[1]),
        .Q(o_CRC_Reversed_OBUF[0]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[10] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[11]),
        .Q(o_CRC_Reversed_OBUF[10]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[11] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[12]),
        .Q(o_CRC_Reversed_OBUF[11]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[12] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[13]),
        .Q(o_CRC_Reversed_OBUF[12]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[13] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[14]),
        .Q(o_CRC_Reversed_OBUF[13]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[14] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[15]),
        .Q(o_CRC_Reversed_OBUF[14]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[15] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg_reg_n_0_[15] ),
        .Q(o_CRC_Reversed_OBUF[15]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[1] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[2]),
        .Q(o_CRC_Reversed_OBUF[1]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[2] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[3]),
        .Q(o_CRC_Reversed_OBUF[2]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[3] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[4]),
        .Q(o_CRC_Reversed_OBUF[3]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[4] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[5]),
        .Q(o_CRC_Reversed_OBUF[4]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[5] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[6]),
        .Q(o_CRC_Reversed_OBUF[5]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[6] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[7]),
        .Q(o_CRC_Reversed_OBUF[6]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[7] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[8]),
        .Q(o_CRC_Reversed_OBUF[7]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[8] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[9]),
        .Q(o_CRC_Reversed_OBUF[8]),
        .R(input_reg15_out));
  FDRE #(
    .INIT(1'b0)) 
    \crc_rev_reg_reg[9] 
       (.C(clk_IBUF_BUFG),
        .CE(\crc_reg[15]_i_2_n_0 ),
        .D(p_0_in[10]),
        .Q(o_CRC_Reversed_OBUF[9]),
        .R(input_reg15_out));
  (* SOFT_HLUTNM = "soft_lutpair3" *) 
  LUT5 #(
    .INIT(32'hEE0EEEEE)) 
    done_reg_i_1
       (.I0(done),
        .I1(\crc_reg[15]_i_2_n_0 ),
        .I2(\state_reg_n_0_[0] ),
        .I3(\state_reg_n_0_[1] ),
        .I4(i_DV_IBUF),
        .O(done_reg_i_1_n_0));
  FDRE #(
    .INIT(1'b0)) 
    done_reg_reg
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(done_reg_i_1_n_0),
        .Q(done),
        .R(1'b0));
  IBUF i_DV_IBUF_inst
       (.I(i_DV),
        .O(i_DV_IBUF));
  IBUF \i_Data_IBUF[0]_inst 
       (.I(i_Data[0]),
        .O(i_Data_IBUF[0]));
  IBUF \i_Data_IBUF[1]_inst 
       (.I(i_Data[1]),
        .O(i_Data_IBUF[1]));
  IBUF \i_Data_IBUF[2]_inst 
       (.I(i_Data[2]),
        .O(i_Data_IBUF[2]));
  IBUF \i_Data_IBUF[3]_inst 
       (.I(i_Data[3]),
        .O(i_Data_IBUF[3]));
  IBUF \i_Data_IBUF[4]_inst 
       (.I(i_Data[4]),
        .O(i_Data_IBUF[4]));
  IBUF \i_Data_IBUF[5]_inst 
       (.I(i_Data[5]),
        .O(i_Data_IBUF[5]));
  IBUF \i_Data_IBUF[6]_inst 
       (.I(i_Data[6]),
        .O(i_Data_IBUF[6]));
  IBUF \i_Data_IBUF[7]_inst 
       (.I(i_Data[7]),
        .O(i_Data_IBUF[7]));
  LUT4 #(
    .INIT(16'hA2AA)) 
    \input_reg[7]_i_1 
       (.I0(\crc_reg[15]_i_2_n_0 ),
        .I1(\state_reg_n_0_[0] ),
        .I2(\state_reg_n_0_[1] ),
        .I3(i_DV_IBUF),
        .O(\input_reg[7]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hAEAA)) 
    \input_reg[7]_i_2 
       (.I0(\crc_reg[15]_i_2_n_0 ),
        .I1(\state_reg_n_0_[0] ),
        .I2(\state_reg_n_0_[1] ),
        .I3(i_DV_IBUF),
        .O(\input_reg[7]_i_2_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \input_reg_reg[0] 
       (.C(clk_IBUF_BUFG),
        .CE(\input_reg[7]_i_2_n_0 ),
        .D(i_Data_IBUF[0]),
        .Q(\input_reg_reg_n_0_[0] ),
        .R(\input_reg[7]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \input_reg_reg[1] 
       (.C(clk_IBUF_BUFG),
        .CE(\input_reg[7]_i_2_n_0 ),
        .D(i_Data_IBUF[1]),
        .Q(\input_reg_reg_n_0_[1] ),
        .R(\input_reg[7]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \input_reg_reg[2] 
       (.C(clk_IBUF_BUFG),
        .CE(\input_reg[7]_i_2_n_0 ),
        .D(i_Data_IBUF[2]),
        .Q(\input_reg_reg_n_0_[2] ),
        .R(\input_reg[7]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \input_reg_reg[3] 
       (.C(clk_IBUF_BUFG),
        .CE(\input_reg[7]_i_2_n_0 ),
        .D(i_Data_IBUF[3]),
        .Q(\input_reg_reg_n_0_[3] ),
        .R(\input_reg[7]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \input_reg_reg[4] 
       (.C(clk_IBUF_BUFG),
        .CE(\input_reg[7]_i_2_n_0 ),
        .D(i_Data_IBUF[4]),
        .Q(\input_reg_reg_n_0_[4] ),
        .R(\input_reg[7]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \input_reg_reg[5] 
       (.C(clk_IBUF_BUFG),
        .CE(\input_reg[7]_i_2_n_0 ),
        .D(i_Data_IBUF[5]),
        .Q(\input_reg_reg_n_0_[5] ),
        .R(\input_reg[7]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \input_reg_reg[6] 
       (.C(clk_IBUF_BUFG),
        .CE(\input_reg[7]_i_2_n_0 ),
        .D(i_Data_IBUF[6]),
        .Q(\input_reg_reg_n_0_[6] ),
        .R(\input_reg[7]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \input_reg_reg[7] 
       (.C(clk_IBUF_BUFG),
        .CE(\input_reg[7]_i_2_n_0 ),
        .D(i_Data_IBUF[7]),
        .Q(\input_reg_reg_n_0_[7] ),
        .R(\input_reg[7]_i_1_n_0 ));
  (* XILINX_LEGACY_PRIM = "LD" *) 
  (* XILINX_TRANSFORM_PINMAP = "VCC:GE GND:CLR" *) 
  LDCE #(
    .INIT(1'b0)) 
    \n_state_reg[0] 
       (.CLR(1'b0),
        .D(\n_state_reg[0]_i_1_n_0 ),
        .G(\n_state_reg[1]_i_2_n_0 ),
        .GE(1'b1),
        .Q(n_state[0]));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT3 #(
    .INIT(8'hCB)) 
    \n_state_reg[0]_i_1 
       (.I0(done),
        .I1(\state_reg_n_0_[1] ),
        .I2(\state_reg_n_0_[0] ),
        .O(\n_state_reg[0]_i_1_n_0 ));
  (* XILINX_LEGACY_PRIM = "LD" *) 
  (* XILINX_TRANSFORM_PINMAP = "VCC:GE GND:CLR" *) 
  LDCE #(
    .INIT(1'b0)) 
    \n_state_reg[1] 
       (.CLR(1'b0),
        .D(\n_state_reg[1]_i_1_n_0 ),
        .G(\n_state_reg[1]_i_2_n_0 ),
        .GE(1'b1),
        .Q(n_state[1]));
  (* SOFT_HLUTNM = "soft_lutpair3" *) 
  LUT3 #(
    .INIT(8'h62)) 
    \n_state_reg[1]_i_1 
       (.I0(\state_reg_n_0_[0] ),
        .I1(\state_reg_n_0_[1] ),
        .I2(done),
        .O(\n_state_reg[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT5 #(
    .INIT(32'hCAFCCA0C)) 
    \n_state_reg[1]_i_2 
       (.I0(i_DV_IBUF),
        .I1(n_state__0),
        .I2(\state_reg_n_0_[1] ),
        .I3(\state_reg_n_0_[0] ),
        .I4(done),
        .O(\n_state_reg[1]_i_2_n_0 ));
  LUT5 #(
    .INIT(32'h00000002)) 
    \n_state_reg[1]_i_3 
       (.I0(cnt_reg[2]),
        .I1(cnt_reg[0]),
        .I2(cnt_reg[1]),
        .I3(cnt_reg[3]),
        .I4(cnt_reg[4]),
        .O(n_state__0));
  OBUF \o_CRC_OBUF[0]_inst 
       (.I(o_CRC_OBUF[0]),
        .O(o_CRC[0]));
  OBUF \o_CRC_OBUF[10]_inst 
       (.I(o_CRC_OBUF[10]),
        .O(o_CRC[10]));
  OBUF \o_CRC_OBUF[11]_inst 
       (.I(o_CRC_OBUF[11]),
        .O(o_CRC[11]));
  OBUF \o_CRC_OBUF[12]_inst 
       (.I(o_CRC_OBUF[12]),
        .O(o_CRC[12]));
  OBUF \o_CRC_OBUF[13]_inst 
       (.I(o_CRC_OBUF[13]),
        .O(o_CRC[13]));
  OBUF \o_CRC_OBUF[14]_inst 
       (.I(o_CRC_OBUF[14]),
        .O(o_CRC[14]));
  OBUF \o_CRC_OBUF[15]_inst 
       (.I(o_CRC_OBUF[15]),
        .O(o_CRC[15]));
  OBUF \o_CRC_OBUF[1]_inst 
       (.I(o_CRC_OBUF[1]),
        .O(o_CRC[1]));
  OBUF \o_CRC_OBUF[2]_inst 
       (.I(o_CRC_OBUF[2]),
        .O(o_CRC[2]));
  OBUF \o_CRC_OBUF[3]_inst 
       (.I(o_CRC_OBUF[3]),
        .O(o_CRC[3]));
  OBUF \o_CRC_OBUF[4]_inst 
       (.I(o_CRC_OBUF[4]),
        .O(o_CRC[4]));
  OBUF \o_CRC_OBUF[5]_inst 
       (.I(o_CRC_OBUF[5]),
        .O(o_CRC[5]));
  OBUF \o_CRC_OBUF[6]_inst 
       (.I(o_CRC_OBUF[6]),
        .O(o_CRC[6]));
  OBUF \o_CRC_OBUF[7]_inst 
       (.I(o_CRC_OBUF[7]),
        .O(o_CRC[7]));
  OBUF \o_CRC_OBUF[8]_inst 
       (.I(o_CRC_OBUF[8]),
        .O(o_CRC[8]));
  OBUF \o_CRC_OBUF[9]_inst 
       (.I(o_CRC_OBUF[9]),
        .O(o_CRC[9]));
  OBUF \o_CRC_Reversed_OBUF[0]_inst 
       (.I(o_CRC_Reversed_OBUF[0]),
        .O(o_CRC_Reversed[0]));
  OBUF \o_CRC_Reversed_OBUF[10]_inst 
       (.I(o_CRC_Reversed_OBUF[10]),
        .O(o_CRC_Reversed[10]));
  OBUF \o_CRC_Reversed_OBUF[11]_inst 
       (.I(o_CRC_Reversed_OBUF[11]),
        .O(o_CRC_Reversed[11]));
  OBUF \o_CRC_Reversed_OBUF[12]_inst 
       (.I(o_CRC_Reversed_OBUF[12]),
        .O(o_CRC_Reversed[12]));
  OBUF \o_CRC_Reversed_OBUF[13]_inst 
       (.I(o_CRC_Reversed_OBUF[13]),
        .O(o_CRC_Reversed[13]));
  OBUF \o_CRC_Reversed_OBUF[14]_inst 
       (.I(o_CRC_Reversed_OBUF[14]),
        .O(o_CRC_Reversed[14]));
  OBUF \o_CRC_Reversed_OBUF[15]_inst 
       (.I(o_CRC_Reversed_OBUF[15]),
        .O(o_CRC_Reversed[15]));
  OBUF \o_CRC_Reversed_OBUF[1]_inst 
       (.I(o_CRC_Reversed_OBUF[1]),
        .O(o_CRC_Reversed[1]));
  OBUF \o_CRC_Reversed_OBUF[2]_inst 
       (.I(o_CRC_Reversed_OBUF[2]),
        .O(o_CRC_Reversed[2]));
  OBUF \o_CRC_Reversed_OBUF[3]_inst 
       (.I(o_CRC_Reversed_OBUF[3]),
        .O(o_CRC_Reversed[3]));
  OBUF \o_CRC_Reversed_OBUF[4]_inst 
       (.I(o_CRC_Reversed_OBUF[4]),
        .O(o_CRC_Reversed[4]));
  OBUF \o_CRC_Reversed_OBUF[5]_inst 
       (.I(o_CRC_Reversed_OBUF[5]),
        .O(o_CRC_Reversed[5]));
  OBUF \o_CRC_Reversed_OBUF[6]_inst 
       (.I(o_CRC_Reversed_OBUF[6]),
        .O(o_CRC_Reversed[6]));
  OBUF \o_CRC_Reversed_OBUF[7]_inst 
       (.I(o_CRC_Reversed_OBUF[7]),
        .O(o_CRC_Reversed[7]));
  OBUF \o_CRC_Reversed_OBUF[8]_inst 
       (.I(o_CRC_Reversed_OBUF[8]),
        .O(o_CRC_Reversed[8]));
  OBUF \o_CRC_Reversed_OBUF[9]_inst 
       (.I(o_CRC_Reversed_OBUF[9]),
        .O(o_CRC_Reversed[9]));
  OBUF \o_CRC_Xor_OBUF[0]_inst 
       (.I(o_CRC_Xor_OBUF[0]),
        .O(o_CRC_Xor[0]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[0]_inst_i_1 
       (.I0(o_CRC_OBUF[0]),
        .O(o_CRC_Xor_OBUF[0]));
  OBUF \o_CRC_Xor_OBUF[10]_inst 
       (.I(o_CRC_Xor_OBUF[10]),
        .O(o_CRC_Xor[10]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[10]_inst_i_1 
       (.I0(o_CRC_OBUF[10]),
        .O(o_CRC_Xor_OBUF[10]));
  OBUF \o_CRC_Xor_OBUF[11]_inst 
       (.I(o_CRC_Xor_OBUF[11]),
        .O(o_CRC_Xor[11]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[11]_inst_i_1 
       (.I0(o_CRC_OBUF[11]),
        .O(o_CRC_Xor_OBUF[11]));
  OBUF \o_CRC_Xor_OBUF[12]_inst 
       (.I(o_CRC_Xor_OBUF[12]),
        .O(o_CRC_Xor[12]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[12]_inst_i_1 
       (.I0(o_CRC_OBUF[12]),
        .O(o_CRC_Xor_OBUF[12]));
  OBUF \o_CRC_Xor_OBUF[13]_inst 
       (.I(o_CRC_Xor_OBUF[13]),
        .O(o_CRC_Xor[13]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[13]_inst_i_1 
       (.I0(o_CRC_OBUF[13]),
        .O(o_CRC_Xor_OBUF[13]));
  OBUF \o_CRC_Xor_OBUF[14]_inst 
       (.I(o_CRC_Xor_OBUF[14]),
        .O(o_CRC_Xor[14]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[14]_inst_i_1 
       (.I0(o_CRC_OBUF[14]),
        .O(o_CRC_Xor_OBUF[14]));
  OBUF \o_CRC_Xor_OBUF[15]_inst 
       (.I(o_CRC_Xor_OBUF[15]),
        .O(o_CRC_Xor[15]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[15]_inst_i_1 
       (.I0(o_CRC_OBUF[15]),
        .O(o_CRC_Xor_OBUF[15]));
  OBUF \o_CRC_Xor_OBUF[1]_inst 
       (.I(o_CRC_Xor_OBUF[1]),
        .O(o_CRC_Xor[1]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[1]_inst_i_1 
       (.I0(o_CRC_OBUF[1]),
        .O(o_CRC_Xor_OBUF[1]));
  OBUF \o_CRC_Xor_OBUF[2]_inst 
       (.I(o_CRC_Xor_OBUF[2]),
        .O(o_CRC_Xor[2]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[2]_inst_i_1 
       (.I0(o_CRC_OBUF[2]),
        .O(o_CRC_Xor_OBUF[2]));
  OBUF \o_CRC_Xor_OBUF[3]_inst 
       (.I(o_CRC_Xor_OBUF[3]),
        .O(o_CRC_Xor[3]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[3]_inst_i_1 
       (.I0(o_CRC_OBUF[3]),
        .O(o_CRC_Xor_OBUF[3]));
  OBUF \o_CRC_Xor_OBUF[4]_inst 
       (.I(o_CRC_Xor_OBUF[4]),
        .O(o_CRC_Xor[4]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[4]_inst_i_1 
       (.I0(o_CRC_OBUF[4]),
        .O(o_CRC_Xor_OBUF[4]));
  OBUF \o_CRC_Xor_OBUF[5]_inst 
       (.I(o_CRC_Xor_OBUF[5]),
        .O(o_CRC_Xor[5]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[5]_inst_i_1 
       (.I0(o_CRC_OBUF[5]),
        .O(o_CRC_Xor_OBUF[5]));
  OBUF \o_CRC_Xor_OBUF[6]_inst 
       (.I(o_CRC_Xor_OBUF[6]),
        .O(o_CRC_Xor[6]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[6]_inst_i_1 
       (.I0(o_CRC_OBUF[6]),
        .O(o_CRC_Xor_OBUF[6]));
  OBUF \o_CRC_Xor_OBUF[7]_inst 
       (.I(o_CRC_Xor_OBUF[7]),
        .O(o_CRC_Xor[7]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[7]_inst_i_1 
       (.I0(o_CRC_OBUF[7]),
        .O(o_CRC_Xor_OBUF[7]));
  OBUF \o_CRC_Xor_OBUF[8]_inst 
       (.I(o_CRC_Xor_OBUF[8]),
        .O(o_CRC_Xor[8]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[8]_inst_i_1 
       (.I0(o_CRC_OBUF[8]),
        .O(o_CRC_Xor_OBUF[8]));
  OBUF \o_CRC_Xor_OBUF[9]_inst 
       (.I(o_CRC_Xor_OBUF[9]),
        .O(o_CRC_Xor[9]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_OBUF[9]_inst_i_1 
       (.I0(o_CRC_OBUF[9]),
        .O(o_CRC_Xor_OBUF[9]));
  OBUF \o_CRC_Xor_Reversed_OBUF[0]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[0]),
        .O(o_CRC_Xor_Reversed[0]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[0]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[0]),
        .O(o_CRC_Xor_Reversed_OBUF[0]));
  OBUF \o_CRC_Xor_Reversed_OBUF[10]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[10]),
        .O(o_CRC_Xor_Reversed[10]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[10]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[10]),
        .O(o_CRC_Xor_Reversed_OBUF[10]));
  OBUF \o_CRC_Xor_Reversed_OBUF[11]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[11]),
        .O(o_CRC_Xor_Reversed[11]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[11]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[11]),
        .O(o_CRC_Xor_Reversed_OBUF[11]));
  OBUF \o_CRC_Xor_Reversed_OBUF[12]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[12]),
        .O(o_CRC_Xor_Reversed[12]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[12]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[12]),
        .O(o_CRC_Xor_Reversed_OBUF[12]));
  OBUF \o_CRC_Xor_Reversed_OBUF[13]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[13]),
        .O(o_CRC_Xor_Reversed[13]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[13]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[13]),
        .O(o_CRC_Xor_Reversed_OBUF[13]));
  OBUF \o_CRC_Xor_Reversed_OBUF[14]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[14]),
        .O(o_CRC_Xor_Reversed[14]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[14]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[14]),
        .O(o_CRC_Xor_Reversed_OBUF[14]));
  OBUF \o_CRC_Xor_Reversed_OBUF[15]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[15]),
        .O(o_CRC_Xor_Reversed[15]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[15]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[15]),
        .O(o_CRC_Xor_Reversed_OBUF[15]));
  OBUF \o_CRC_Xor_Reversed_OBUF[1]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[1]),
        .O(o_CRC_Xor_Reversed[1]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[1]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[1]),
        .O(o_CRC_Xor_Reversed_OBUF[1]));
  OBUF \o_CRC_Xor_Reversed_OBUF[2]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[2]),
        .O(o_CRC_Xor_Reversed[2]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[2]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[2]),
        .O(o_CRC_Xor_Reversed_OBUF[2]));
  OBUF \o_CRC_Xor_Reversed_OBUF[3]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[3]),
        .O(o_CRC_Xor_Reversed[3]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[3]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[3]),
        .O(o_CRC_Xor_Reversed_OBUF[3]));
  OBUF \o_CRC_Xor_Reversed_OBUF[4]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[4]),
        .O(o_CRC_Xor_Reversed[4]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[4]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[4]),
        .O(o_CRC_Xor_Reversed_OBUF[4]));
  OBUF \o_CRC_Xor_Reversed_OBUF[5]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[5]),
        .O(o_CRC_Xor_Reversed[5]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[5]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[5]),
        .O(o_CRC_Xor_Reversed_OBUF[5]));
  OBUF \o_CRC_Xor_Reversed_OBUF[6]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[6]),
        .O(o_CRC_Xor_Reversed[6]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[6]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[6]),
        .O(o_CRC_Xor_Reversed_OBUF[6]));
  OBUF \o_CRC_Xor_Reversed_OBUF[7]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[7]),
        .O(o_CRC_Xor_Reversed[7]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[7]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[7]),
        .O(o_CRC_Xor_Reversed_OBUF[7]));
  OBUF \o_CRC_Xor_Reversed_OBUF[8]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[8]),
        .O(o_CRC_Xor_Reversed[8]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[8]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[8]),
        .O(o_CRC_Xor_Reversed_OBUF[8]));
  OBUF \o_CRC_Xor_Reversed_OBUF[9]_inst 
       (.I(o_CRC_Xor_Reversed_OBUF[9]),
        .O(o_CRC_Xor_Reversed[9]));
  LUT1 #(
    .INIT(2'h1)) 
    \o_CRC_Xor_Reversed_OBUF[9]_inst_i_1 
       (.I0(o_CRC_Reversed_OBUF[9]),
        .O(o_CRC_Xor_Reversed_OBUF[9]));
  IBUF rstn_IBUF_inst
       (.I(rstn),
        .O(rstn_IBUF));
  (* SOFT_HLUTNM = "soft_lutpair4" *) 
  LUT3 #(
    .INIT(8'hE4)) 
    \state[0]_i_1 
       (.I0(rstn_IBUF),
        .I1(\state_reg_n_0_[0] ),
        .I2(n_state[0]),
        .O(\state[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair4" *) 
  LUT3 #(
    .INIT(8'hE4)) 
    \state[1]_i_1 
       (.I0(rstn_IBUF),
        .I1(\state_reg_n_0_[1] ),
        .I2(n_state[1]),
        .O(\state[1]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \state_reg[0] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\state[0]_i_1_n_0 ),
        .Q(\state_reg_n_0_[0] ),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \state_reg[1] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\state[1]_i_1_n_0 ),
        .Q(\state_reg_n_0_[1] ),
        .R(1'b0));
  LUT5 #(
    .INIT(32'h00003022)) 
    \table_reg[0]_i_1 
       (.I0(\table_reg_reg_n_0_[0] ),
        .I1(\table_rev_reg[0]_i_1_n_0 ),
        .I2(table_reg1),
        .I3(input_reg1),
        .I4(input_reg15_out),
        .O(\table_reg[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair7" *) 
  LUT2 #(
    .INIT(4'h6)) 
    \table_reg[12]_i_1 
       (.I0(table_reg1),
        .I1(\table_reg_reg_n_0_[11] ),
        .O(\table_reg[12]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h1114DDD7EEEB2228)) 
    \table_reg[12]_i_2 
       (.I0(\table_reg[12]_i_3_n_0 ),
        .I1(cnt_reg[2]),
        .I2(cnt_reg[1]),
        .I3(cnt_reg[0]),
        .I4(\table_reg[12]_i_4_n_0 ),
        .I5(p_0_in0_in),
        .O(table_reg1));
  LUT6 #(
    .INIT(64'hAFFCA0FCAF0CA00C)) 
    \table_reg[12]_i_3 
       (.I0(\input_reg_reg_n_0_[5] ),
        .I1(\input_reg_reg_n_0_[4] ),
        .I2(cnt_reg[1]),
        .I3(cnt_reg[0]),
        .I4(\input_reg_reg_n_0_[7] ),
        .I5(\input_reg_reg_n_0_[6] ),
        .O(\table_reg[12]_i_3_n_0 ));
  LUT6 #(
    .INIT(64'hAFFCA0FCAF0CA00C)) 
    \table_reg[12]_i_4 
       (.I0(\input_reg_reg_n_0_[1] ),
        .I1(\input_reg_reg_n_0_[0] ),
        .I2(cnt_reg[1]),
        .I3(cnt_reg[0]),
        .I4(\input_reg_reg_n_0_[3] ),
        .I5(\input_reg_reg_n_0_[2] ),
        .O(\table_reg[12]_i_4_n_0 ));
  LUT4 #(
    .INIT(16'hFF20)) 
    \table_reg[15]_i_1 
       (.I0(\state_reg_n_0_[0] ),
        .I1(\state_reg_n_0_[1] ),
        .I2(i_DV_IBUF),
        .I3(\table_rev_reg[0]_i_1_n_0 ),
        .O(\table_reg[15]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0055005600000000)) 
    \table_reg[15]_i_2 
       (.I0(cnt_reg[3]),
        .I1(cnt_reg[1]),
        .I2(cnt_reg[0]),
        .I3(cnt_reg[4]),
        .I4(cnt_reg[2]),
        .I5(p_0_in3_in),
        .O(input_reg1));
  LUT2 #(
    .INIT(4'h2)) 
    \table_reg[15]_i_3 
       (.I0(\state_reg_n_0_[1] ),
        .I1(\state_reg_n_0_[0] ),
        .O(p_0_in3_in));
  (* SOFT_HLUTNM = "soft_lutpair7" *) 
  LUT2 #(
    .INIT(4'h6)) 
    \table_reg[5]_i_1 
       (.I0(table_reg1),
        .I1(\table_reg_reg_n_0_[4] ),
        .O(\table_reg[5]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[0] 
       (.C(clk_IBUF_BUFG),
        .CE(1'b1),
        .D(\table_reg[0]_i_1_n_0 ),
        .Q(\table_reg_reg_n_0_[0] ),
        .R(1'b0));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[10] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[9] ),
        .Q(\table_reg_reg_n_0_[10] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[11] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[10] ),
        .Q(\table_reg_reg_n_0_[11] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[12] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg[12]_i_1_n_0 ),
        .Q(\table_reg_reg_n_0_[12] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[13] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[12] ),
        .Q(\table_reg_reg_n_0_[13] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[14] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[13] ),
        .Q(\table_reg_reg_n_0_[14] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[15] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[14] ),
        .Q(p_0_in0_in),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[1] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[0] ),
        .Q(\table_reg_reg_n_0_[1] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[2] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[1] ),
        .Q(\table_reg_reg_n_0_[2] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[3] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[2] ),
        .Q(\table_reg_reg_n_0_[3] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[4] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[3] ),
        .Q(\table_reg_reg_n_0_[4] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[5] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg[5]_i_1_n_0 ),
        .Q(\table_reg_reg_n_0_[5] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[6] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[5] ),
        .Q(\table_reg_reg_n_0_[6] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[7] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[6] ),
        .Q(\table_reg_reg_n_0_[7] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[8] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[7] ),
        .Q(\table_reg_reg_n_0_[8] ),
        .R(\table_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_reg_reg[9] 
       (.C(clk_IBUF_BUFG),
        .CE(input_reg1),
        .D(\table_reg_reg_n_0_[8] ),
        .Q(\table_reg_reg_n_0_[9] ),
        .R(\table_reg[15]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0000000000000010)) 
    \table_rev_reg[0]_i_1 
       (.I0(cnt_reg[4]),
        .I1(cnt_reg[1]),
        .I2(p_0_in3_in),
        .I3(cnt_reg[2]),
        .I4(cnt_reg[3]),
        .I5(cnt_reg[0]),
        .O(\table_rev_reg[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair5" *) 
  LUT3 #(
    .INIT(8'hBE)) 
    \table_rev_reg[10]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[10]),
        .I2(table_rev_reg1),
        .O(\table_rev_reg[10]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair11" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[11]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[11]),
        .O(\table_rev_reg[11]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair12" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[12]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[12]),
        .O(\table_rev_reg[12]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair12" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[13]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[13]),
        .O(\table_rev_reg[13]_i_1_n_0 ));
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[14]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[14]),
        .O(\table_rev_reg[14]_i_1_n_0 ));
  LUT3 #(
    .INIT(8'h20)) 
    \table_rev_reg[15]_i_1 
       (.I0(i_DV_IBUF),
        .I1(\state_reg_n_0_[1] ),
        .I2(\state_reg_n_0_[0] ),
        .O(\table_rev_reg[15]_i_1_n_0 ));
  LUT5 #(
    .INIT(32'hFFFFFF20)) 
    \table_rev_reg[15]_i_2 
       (.I0(\state_reg_n_0_[0] ),
        .I1(\state_reg_n_0_[1] ),
        .I2(i_DV_IBUF),
        .I3(input_reg1),
        .I4(\table_rev_reg[0]_i_1_n_0 ),
        .O(\table_rev_reg[15]_i_2_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair5" *) 
  LUT3 #(
    .INIT(8'hBE)) 
    \table_rev_reg[15]_i_3 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[15]),
        .I2(table_rev_reg1),
        .O(\table_rev_reg[15]_i_3_n_0 ));
  LUT6 #(
    .INIT(64'h1114DDD7EEEB2228)) 
    \table_rev_reg[15]_i_4 
       (.I0(\table_reg[12]_i_3_n_0 ),
        .I1(cnt_reg[2]),
        .I2(cnt_reg[1]),
        .I3(cnt_reg[0]),
        .I4(\table_reg[12]_i_4_n_0 ),
        .I5(\table_rev_reg_reg_n_0_[15] ),
        .O(table_rev_reg1));
  (* SOFT_HLUTNM = "soft_lutpair6" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[1]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[1]),
        .O(\table_rev_reg[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair8" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[2]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[2]),
        .O(\table_rev_reg[2]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair6" *) 
  LUT3 #(
    .INIT(8'hBE)) 
    \table_rev_reg[3]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[3]),
        .I2(table_rev_reg1),
        .O(\table_rev_reg[3]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair8" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[4]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[4]),
        .O(\table_rev_reg[4]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair9" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[5]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[5]),
        .O(\table_rev_reg[5]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair9" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[6]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[6]),
        .O(\table_rev_reg[6]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair10" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[7]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[7]),
        .O(\table_rev_reg[7]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair10" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[8]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[8]),
        .O(\table_rev_reg[8]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair11" *) 
  LUT2 #(
    .INIT(4'hE)) 
    \table_rev_reg[9]_i_1 
       (.I0(\table_rev_reg[0]_i_1_n_0 ),
        .I1(p_0_in[9]),
        .O(\table_rev_reg[9]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[0] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[0]_i_1_n_0 ),
        .Q(p_0_in[1]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[10] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[10]_i_1_n_0 ),
        .Q(p_0_in[11]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[11] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[11]_i_1_n_0 ),
        .Q(p_0_in[12]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[12] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[12]_i_1_n_0 ),
        .Q(p_0_in[13]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[13] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[13]_i_1_n_0 ),
        .Q(p_0_in[14]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[14] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[14]_i_1_n_0 ),
        .Q(p_0_in[15]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[15] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[15]_i_3_n_0 ),
        .Q(\table_rev_reg_reg_n_0_[15] ),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[1] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[1]_i_1_n_0 ),
        .Q(p_0_in[2]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[2] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[2]_i_1_n_0 ),
        .Q(p_0_in[3]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[3] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[3]_i_1_n_0 ),
        .Q(p_0_in[4]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[4] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[4]_i_1_n_0 ),
        .Q(p_0_in[5]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[5] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[5]_i_1_n_0 ),
        .Q(p_0_in[6]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[6] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[6]_i_1_n_0 ),
        .Q(p_0_in[7]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[7] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[7]_i_1_n_0 ),
        .Q(p_0_in[8]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[8] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[8]_i_1_n_0 ),
        .Q(p_0_in[9]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
  FDRE #(
    .INIT(1'b0)) 
    \table_rev_reg_reg[9] 
       (.C(clk_IBUF_BUFG),
        .CE(\table_rev_reg[15]_i_2_n_0 ),
        .D(\table_rev_reg[9]_i_1_n_0 ),
        .Q(p_0_in[10]),
        .R(\table_rev_reg[15]_i_1_n_0 ));
endmodule
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
