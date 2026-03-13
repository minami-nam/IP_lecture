/*
 Copyright (C) 2025  Altera Corporation. All rights reserved.
 Your use of Altera Corporation's design tools, logic functions 
 and other software and tools, and any partner logic 
 functions, and any output files from any of the foregoing 
 (including device programming or simulation files), and any 
 associated documentation or information are expressly subject 
 to the terms and conditions of the Altera Program License 
 Subscription Agreement, the Altera Quartus Prime License Agreement,
 the Altera IP License Agreement, or other applicable license
 agreement, including, without limitation, that your use is for
 the sole purpose of programming logic devices manufactured by
 Altera and sold by Altera or its authorized distributors.  Please
 refer to the Altera Software License Subscription Agreements 
 on the Quartus Prime software download page.
*/
MODEL
/*MODEL HEADER*/
/*
 This file contains Slow Corner delays for the design using part 5CGXFC7C7F23C8
 with speed grade 8_H7, core voltage 1.1V, and temperature 0 Celsius

*/
MODEL_VERSION "1.0";
DESIGN "DRAMInterface";
DATE "02/12/2026 13:15:02";
PROGRAM "Quartus Prime";



INPUT ck_t;
INPUT a[16];
INPUT csn;
INPUT actn;
INPUT a[15];
INPUT a[14];
INPUT a[1];
INPUT burst;
INPUT a[2];
INPUT a[0];
INPUT a[3];
INPUT burst_count[2];
INPUT burst_count[3];
INOUT dqs_t;
INOUT dqs_c;
INPUT burst_count[1];
INPUT burst_count[0];
INPUT a[5];
INPUT a[6];
INPUT a[7];
INPUT a[4];
INOUT dq[0];
INOUT dq[1];
INOUT dq[2];
INOUT dq[3];
INOUT dq[4];
INOUT dq[5];
INOUT dq[6];
INOUT dq[7];
INPUT ck_c;
INPUT cke;
INPUT bg[0];
INPUT ba[0];
INPUT a[8];
INPUT a[9];
INPUT a[10];
INPUT a[11];
INPUT a[12];
INPUT a[13];
INPUT a[17];

/*Arc definitions start here*/
pos_a[0]__ck_t__setup:		SETUP (POSEDGE) a[0] ck_t ;
pos_a[1]__ck_t__setup:		SETUP (POSEDGE) a[1] ck_t ;
pos_a[2]__ck_t__setup:		SETUP (POSEDGE) a[2] ck_t ;
pos_a[3]__ck_t__setup:		SETUP (POSEDGE) a[3] ck_t ;
pos_a[4]__ck_t__setup:		SETUP (POSEDGE) a[4] ck_t ;
pos_a[5]__ck_t__setup:		SETUP (POSEDGE) a[5] ck_t ;
pos_a[6]__ck_t__setup:		SETUP (POSEDGE) a[6] ck_t ;
pos_a[7]__ck_t__setup:		SETUP (POSEDGE) a[7] ck_t ;
pos_a[14]__ck_t__setup:		SETUP (POSEDGE) a[14] ck_t ;
pos_a[15]__ck_t__setup:		SETUP (POSEDGE) a[15] ck_t ;
pos_a[16]__ck_t__setup:		SETUP (POSEDGE) a[16] ck_t ;
pos_actn__ck_t__setup:		SETUP (POSEDGE) actn ck_t ;
pos_burst__ck_t__setup:		SETUP (POSEDGE) burst ck_t ;
pos_burst_count[0]__ck_t__setup:		SETUP (POSEDGE) burst_count[0] ck_t ;
pos_burst_count[1]__ck_t__setup:		SETUP (POSEDGE) burst_count[1] ck_t ;
pos_burst_count[2]__ck_t__setup:		SETUP (POSEDGE) burst_count[2] ck_t ;
pos_burst_count[3]__ck_t__setup:		SETUP (POSEDGE) burst_count[3] ck_t ;
pos_csn__ck_t__setup:		SETUP (POSEDGE) csn ck_t ;
pos_dq[0]__ck_t__setup:		SETUP (POSEDGE) dq[0] ck_t ;
pos_dq[1]__ck_t__setup:		SETUP (POSEDGE) dq[1] ck_t ;
pos_dq[2]__ck_t__setup:		SETUP (POSEDGE) dq[2] ck_t ;
pos_dq[3]__ck_t__setup:		SETUP (POSEDGE) dq[3] ck_t ;
pos_dq[4]__ck_t__setup:		SETUP (POSEDGE) dq[4] ck_t ;
pos_dq[5]__ck_t__setup:		SETUP (POSEDGE) dq[5] ck_t ;
pos_dq[6]__ck_t__setup:		SETUP (POSEDGE) dq[6] ck_t ;
pos_dq[7]__ck_t__setup:		SETUP (POSEDGE) dq[7] ck_t ;
pos_dqs_c__ck_t__setup:		SETUP (POSEDGE) dqs_c ck_t ;
pos_dqs_t__ck_t__setup:		SETUP (POSEDGE) dqs_t ck_t ;
pos_a[0]__ck_t__hold:		HOLD (POSEDGE) a[0] ck_t ;
pos_a[1]__ck_t__hold:		HOLD (POSEDGE) a[1] ck_t ;
pos_a[2]__ck_t__hold:		HOLD (POSEDGE) a[2] ck_t ;
pos_a[3]__ck_t__hold:		HOLD (POSEDGE) a[3] ck_t ;
pos_a[4]__ck_t__hold:		HOLD (POSEDGE) a[4] ck_t ;
pos_a[5]__ck_t__hold:		HOLD (POSEDGE) a[5] ck_t ;
pos_a[6]__ck_t__hold:		HOLD (POSEDGE) a[6] ck_t ;
pos_a[7]__ck_t__hold:		HOLD (POSEDGE) a[7] ck_t ;
pos_a[14]__ck_t__hold:		HOLD (POSEDGE) a[14] ck_t ;
pos_a[15]__ck_t__hold:		HOLD (POSEDGE) a[15] ck_t ;
pos_a[16]__ck_t__hold:		HOLD (POSEDGE) a[16] ck_t ;
pos_actn__ck_t__hold:		HOLD (POSEDGE) actn ck_t ;
pos_burst__ck_t__hold:		HOLD (POSEDGE) burst ck_t ;
pos_burst_count[0]__ck_t__hold:		HOLD (POSEDGE) burst_count[0] ck_t ;
pos_burst_count[1]__ck_t__hold:		HOLD (POSEDGE) burst_count[1] ck_t ;
pos_burst_count[2]__ck_t__hold:		HOLD (POSEDGE) burst_count[2] ck_t ;
pos_burst_count[3]__ck_t__hold:		HOLD (POSEDGE) burst_count[3] ck_t ;
pos_csn__ck_t__hold:		HOLD (POSEDGE) csn ck_t ;
pos_dq[0]__ck_t__hold:		HOLD (POSEDGE) dq[0] ck_t ;
pos_dq[1]__ck_t__hold:		HOLD (POSEDGE) dq[1] ck_t ;
pos_dq[2]__ck_t__hold:		HOLD (POSEDGE) dq[2] ck_t ;
pos_dq[3]__ck_t__hold:		HOLD (POSEDGE) dq[3] ck_t ;
pos_dq[4]__ck_t__hold:		HOLD (POSEDGE) dq[4] ck_t ;
pos_dq[5]__ck_t__hold:		HOLD (POSEDGE) dq[5] ck_t ;
pos_dq[6]__ck_t__hold:		HOLD (POSEDGE) dq[6] ck_t ;
pos_dq[7]__ck_t__hold:		HOLD (POSEDGE) dq[7] ck_t ;
pos_dqs_c__ck_t__hold:		HOLD (POSEDGE) dqs_c ck_t ;
pos_dqs_t__ck_t__hold:		HOLD (POSEDGE) dqs_t ck_t ;
pos_ck_t__dq[0]__delay:		DELAY (POSEDGE) ck_t dq[0] ;
pos_ck_t__dq[1]__delay:		DELAY (POSEDGE) ck_t dq[1] ;
pos_ck_t__dq[2]__delay:		DELAY (POSEDGE) ck_t dq[2] ;
pos_ck_t__dq[3]__delay:		DELAY (POSEDGE) ck_t dq[3] ;
pos_ck_t__dq[4]__delay:		DELAY (POSEDGE) ck_t dq[4] ;
pos_ck_t__dq[5]__delay:		DELAY (POSEDGE) ck_t dq[5] ;
pos_ck_t__dq[6]__delay:		DELAY (POSEDGE) ck_t dq[6] ;
pos_ck_t__dq[7]__delay:		DELAY (POSEDGE) ck_t dq[7] ;
pos_ck_t__dqs_t__delay:		DELAY (POSEDGE) ck_t dqs_t ;
pos_ck_t__dqs_t__delay:		DELAY (POSEDGE) ck_t dqs_t ;
___11.918__delay:		DELAY  11.918 ;

ENDMODEL
