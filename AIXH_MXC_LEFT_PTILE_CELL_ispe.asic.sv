//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Left / Processing-Tile / Cell) Input-Side PE
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

`ifdef AIXH_TARGET_ASIC
import AIXH_MXC_pkg::*;
module AIXH_MXC_LEFT_PTILE_CELL_ispe
(
   input  wire                    aixh_core_clk2x

   // Convert stage control
  ,input  wire                    cvt_enable
  ,input  wire                    relu_enable
  ,input  wire                    zpad_enable
  ,input  wire                    half_sel
  ,input  wire [2           -1:0] cvt_mode
  ,input  wire                    uint_mode

  // MAC stage control
  ,input  wire                    mul_enable
  ,input  wire                    acc_enable
  ,input  wire                    acc_afresh
  ,input  wire [3           -1:0] mul_mode
  ,input  wire [2           -1:0] acc_mode

  ,input  wire [64          -1:0] ixdata
  ,output reg  [32          -1:0] oxdata
  ,output wire [ACCUM_BITS  -1:0] ozdata
);
// synopsys dc_tcl_script_begin
// set_optimize_registers -check_design -print_critical_loop
// synopsys dc_tcl_script_end

localparam MSTAGES = `AIXH_MXC_LISPE_STAGES - 1;

//------------------------------------------------------------------------------
// Convert inputs
//------------------------------------------------------------------------------
wire [4       -1:0] ixqbit00 = ixdata[ 0*4+:4];
wire [4       -1:0] ixqbit01 = ixdata[ 1*4+:4];
wire [4       -1:0] ixqbit02 = ixdata[ 2*4+:4];
wire [4       -1:0] ixqbit03 = ixdata[ 3*4+:4];
wire [4       -1:0] ixqbit04 = ixdata[ 4*4+:4];
wire [4       -1:0] ixqbit05 = ixdata[ 5*4+:4];
wire [4       -1:0] ixqbit06 = ixdata[ 6*4+:4];
wire [4       -1:0] ixqbit07 = ixdata[ 7*4+:4];
wire [4       -1:0] ixqbit08 = ixdata[ 8*4+:4];
wire [4       -1:0] ixqbit09 = ixdata[ 9*4+:4];
wire [4       -1:0] ixqbit10 = ixdata[10*4+:4];
wire [4       -1:0] ixqbit11 = ixdata[11*4+:4];
wire [4       -1:0] ixqbit12 = ixdata[12*4+:4];
wire [4       -1:0] ixqbit13 = ixdata[13*4+:4];
wire [4       -1:0] ixqbit14 = ixdata[14*4+:4];
wire [4       -1:0] ixqbit15 = ixdata[15*4+:4];
wire [8       -1:0] ixbyte0  = ixdata[ 0*8+:8];
wire [8       -1:0] ixbyte1  = ixdata[ 1*8+:8];
wire [8       -1:0] ixbyte2  = ixdata[ 2*8+:8];
wire [8       -1:0] ixbyte3  = ixdata[ 3*8+:8];
wire [8       -1:0] ixbyte4  = ixdata[ 4*8+:8];
wire [8       -1:0] ixbyte5  = ixdata[ 5*8+:8];
wire [8       -1:0] ixbyte6  = ixdata[ 6*8+:8];
wire [8       -1:0] ixbyte7  = ixdata[ 7*8+:8];

always_ff @(posedge aixh_core_clk2x)
  if (cvt_enable) begin
    case ({cvt_mode, half_sel})
      3'b00_0: begin // INT4 A
        if (zpad_enable | (relu_enable & ixqbit00[3]))
             oxdata[0*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[0*4+:4] <= {~uint_mode ^ ixqbit00[3], ixqbit00[2:0]};
        if (zpad_enable | (relu_enable & ixqbit02[3]))
             oxdata[1*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[1*4+:4] <= {~uint_mode ^ ixqbit02[3], ixqbit02[2:0]};
        if (zpad_enable| (relu_enable & ixqbit04[3]))
             oxdata[2*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[2*4+:4] <= {~uint_mode ^ ixqbit04[3], ixqbit04[2:0]};
        if (zpad_enable| (relu_enable & ixqbit06[3]))
             oxdata[3*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[3*4+:4] <= {~uint_mode ^ ixqbit06[3], ixqbit06[2:0]};
        if (zpad_enable| (relu_enable & ixqbit01[3]))
             oxdata[4*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[4*4+:4] <= {~uint_mode ^ ixqbit01[3], ixqbit01[2:0]};
        if (zpad_enable| (relu_enable & ixqbit03[3]))
             oxdata[5*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[5*4+:4] <= {~uint_mode ^ ixqbit03[3], ixqbit03[2:0]};
        if (zpad_enable| (relu_enable & ixqbit05[3]))
             oxdata[6*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[6*4+:4] <= {~uint_mode ^ ixqbit05[3], ixqbit05[2:0]};
        if (zpad_enable | (relu_enable & ixqbit07[3]))
             oxdata[7*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[7*4+:4] <= {~uint_mode ^ ixqbit07[3], ixqbit07[2:0]};
      end
      3'b00_1: begin // INT4 B
        if (zpad_enable | (relu_enable & ixqbit08[3]))
             oxdata[0*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[0*4+:4] <= {~uint_mode ^ ixqbit08[3], ixqbit08[2:0]};
        if (zpad_enable | (relu_enable & ixqbit10[3]))
             oxdata[1*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[1*4+:4] <= {~uint_mode ^ ixqbit10[3], ixqbit10[2:0]};
        if (zpad_enable| (relu_enable & ixqbit12[3]))
             oxdata[2*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[2*4+:4] <= {~uint_mode ^ ixqbit12[3], ixqbit12[2:0]};
        if (zpad_enable| (relu_enable & ixqbit14[3]))
             oxdata[3*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[3*4+:4] <= {~uint_mode ^ ixqbit14[3], ixqbit14[2:0]};
        if (zpad_enable| (relu_enable & ixqbit09[3]))
             oxdata[4*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[4*4+:4] <= {~uint_mode ^ ixqbit09[3], ixqbit09[2:0]};
        if (zpad_enable| (relu_enable & ixqbit11[3]))
             oxdata[5*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[5*4+:4] <= {~uint_mode ^ ixqbit11[3], ixqbit11[2:0]};
        if (zpad_enable| (relu_enable & ixqbit13[3]))
             oxdata[6*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[6*4+:4] <= {~uint_mode ^ ixqbit13[3], ixqbit13[2:0]};
        if (zpad_enable | (relu_enable & ixqbit15[3]))
             oxdata[7*4+:4] <= {~uint_mode, 3'b0};
        else oxdata[7*4+:4] <= {~uint_mode ^ ixqbit15[3], ixqbit15[2:0]};
      end
      3'b01_0: begin // INT8 A
        if (zpad_enable | (relu_enable & ixbyte0[7]))
             oxdata[0*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[0*8+:8] <= {~uint_mode ^ ixbyte0[7], ixbyte0[6:0]};
        if (zpad_enable | (relu_enable & ixbyte2[7]))
             oxdata[1*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[1*8+:8] <= {~uint_mode ^ ixbyte2[7], ixbyte2[6:0]};
        if (zpad_enable| (relu_enable & ixbyte1[7]))
             oxdata[2*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[2*8+:8] <= {~uint_mode ^ ixbyte1[7], ixbyte1[6:0]};
        if (zpad_enable| (relu_enable & ixbyte3[7]))
             oxdata[3*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[3*8+:8] <= {~uint_mode ^ ixbyte3[7], ixbyte3[6:0]};
      end
      3'b01_1: begin // INT8 B
        if (zpad_enable | (relu_enable & ixbyte4[7]))
             oxdata[0*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[0*8+:8] <= {~uint_mode ^ ixbyte4[7], ixbyte4[6:0]};
        if (zpad_enable | (relu_enable & ixbyte6[7]))
             oxdata[1*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[1*8+:8] <= {~uint_mode ^ ixbyte6[7], ixbyte6[6:0]};
        if (zpad_enable| (relu_enable & ixbyte5[7]))
             oxdata[2*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[2*8+:8] <= {~uint_mode ^ ixbyte5[7], ixbyte5[6:0]};
        if (zpad_enable| (relu_enable & ixbyte7[7]))
             oxdata[3*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[3*8+:8] <= {~uint_mode ^ ixbyte7[7], ixbyte7[6:0]};
      end
      3'b10_0: begin // INT16 LLLL
        if (zpad_enable | (relu_enable & ixbyte1[7]))
             oxdata[0*8+:8] <= 8'b0;
        else oxdata[0*8+:8] <= ixbyte0;
        if (zpad_enable | (relu_enable & ixbyte5[7]))
             oxdata[1*8+:8] <= 8'b0;
        else oxdata[1*8+:8] <= ixbyte4;
        if (zpad_enable | (relu_enable & ixbyte3[7]))
             oxdata[2*8+:8] <= 8'b0;
        else oxdata[2*8+:8] <= ixbyte2;
        if (zpad_enable | (relu_enable & ixbyte7[7]))
             oxdata[3*8+:8] <= 8'b0;
        else oxdata[3*8+:8] <= ixbyte6;
      end
      3'b10_1: begin // INT16 HHLL
        if (zpad_enable | (relu_enable & ixbyte1[7]))
             oxdata[0*8+:8] <= 8'b0;
        else oxdata[0*8+:8] <= ixbyte0;
        if (zpad_enable | (relu_enable & ixbyte5[7]))
             oxdata[1*8+:8] <= 8'b0;
        else oxdata[1*8+:8] <= ixbyte4;
        if (zpad_enable | (relu_enable & ixbyte3[7]))
             oxdata[2*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[2*8+:8] <= {~uint_mode ^ ixbyte3[7], ixbyte3[6:0]};
        if (zpad_enable | (relu_enable & ixbyte7[7]))
             oxdata[3*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[3*8+:8] <= {~uint_mode ^ ixbyte7[7], ixbyte7[6:0]};
      end
      3'b11_0: begin // INT16 LLHH
        if (zpad_enable| (relu_enable & ixbyte1[7]))
             oxdata[0*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[0*8+:8] <= {~uint_mode ^ ixbyte1[7], ixbyte1[6:0]};
        if (zpad_enable | (relu_enable & ixbyte5[7]))
             oxdata[1*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[1*8+:8] <= {~uint_mode ^ ixbyte5[7], ixbyte5[6:0]};
        if (zpad_enable | (relu_enable & ixbyte3[7]))
             oxdata[2*8+:8] <= 8'b0;
        else oxdata[2*8+:8] <= ixbyte2;
        if (zpad_enable | (relu_enable & ixbyte7[7]))
             oxdata[3*8+:8] <= 8'b0;
        else oxdata[3*8+:8] <= ixbyte6;
      end
      3'b11_1: begin // INT16 HHHH
        if (zpad_enable | (relu_enable & ixbyte1[7]))
             oxdata[0*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[0*8+:8] <= {~uint_mode ^ ixbyte1[7], ixbyte1[6:0]};
        if (zpad_enable | (relu_enable & ixbyte5[7]))
             oxdata[1*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[1*8+:8] <= {~uint_mode ^ ixbyte5[7], ixbyte5[6:0]};
        if (zpad_enable | (relu_enable & ixbyte3[7]))
             oxdata[2*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[2*8+:8] <= {~uint_mode ^ ixbyte3[7], ixbyte3[6:0]};
        if (zpad_enable | (relu_enable & ixbyte7[7]))
             oxdata[3*8+:8] <= {~uint_mode, 7'b0};
        else oxdata[3*8+:8] <= {~uint_mode ^ ixbyte7[7], ixbyte7[6:0]};
      end
    endcase
  end

//------------------------------------------------------------------------------
// MAC
//------------------------------------------------------------------------------
wire  [8          -1:0] udata0 = oxdata[ 0+:8];
wire  [8          -1:0] udata1 = oxdata[ 8+:8];
wire  [8          -1:0] vdata0 = oxdata[16+:8];
wire  [8          -1:0] vdata1 = oxdata[24+:8];
wire                    m_int8  = mul_mode[0];
wire                    u_cywen = mul_mode[1];
wire                    v_cywen = mul_mode[2];

logic [3          -1:0] b0_code0, b1_code0;
logic [3          -1:0] b0_code1, b1_code1;
logic [3          -1:0] b0_code2, b1_code2;
logic [3          -1:0] b0_code3, b1_code3;
logic [3          -1:0] b0_code4, b1_code4;
logic [9          -1:0] b0_idat0, b1_idat0;
logic [9          -1:0] b0_idat1, b1_idat1;
logic [10         -1:0] b0_odat0, b1_odat0;
logic [10         -1:0] b0_odat1, b1_odat1;
logic [10         -1:0] b0_odat2, b1_odat2;
logic [10         -1:0] b0_odat3, b1_odat3;
logic [10         -1:0] b0_odat4, b1_odat4;
logic                   b0_oinv0, b1_oinv0;
logic                   b0_oinv1, b1_oinv1;
logic                   b0_oinv2, b1_oinv2;
logic                   b0_oinv3, b1_oinv3;
logic                   b0_oinv4, b1_oinv4;

logic [16*8       -1:0] a0_ins;
logic [16*8       -1:0] a1_ins;
logic [16         -1:0] a0_sum;
logic [16         -1:0] a1_sum;

logic [20         -1:0] pipe[MSTAGES];
logic [20         -1:0] z_sum;
logic [20         -1:0] z_sum_r;
logic [36         -1:0] z_sft;
logic [48         -1:0] z_acc;
logic [48         -1:0] z_acc_nx;
logic                   z_update1;
logic                   z_update2;
logic                   z_update3;

always_comb begin
  casez ({m_int8, u_cywen})
    2'b0z: begin
      b0_code0 = { udata0[1], udata0[0], 1'b0     };
      b0_code1 = {~udata0[3], udata0[2], udata0[1]};
      b0_code2 = { udata0[5], udata0[4], 1'b0     }; 
      b0_code3 = {~udata0[7], udata0[6], udata0[5]};
      b0_code4 = { 1'b0     , 1'b0     , 1'b0     };
      b1_code0 = { udata1[1], udata1[0], 1'b0     };
      b1_code1 = {~udata1[3], udata1[2], udata1[1]};
      b1_code2 = { udata1[5], udata1[4], 1'b0     }; 
      b1_code3 = {~udata1[7], udata1[6], udata1[5]};
      b1_code4 = { 1'b0     , 1'b0     , 1'b0     };
    end
    2'b10: begin
      b0_code0 = { udata0[1], udata0[0], 1'b0     };
      b0_code1 = { udata0[3], udata0[2], udata0[1]};
      b0_code2 = { udata0[5], udata0[4], udata0[3]}; 
      b0_code3 = {~udata0[7], udata0[6], udata0[5]};
      b0_code4 = { 1'b0     , 1'b0     , 1'b0     };
      b1_code0 = { udata1[1], udata1[0], 1'b0     };
      b1_code1 = { udata1[3], udata1[2], udata1[1]};
      b1_code2 = { udata1[5], udata1[4], udata1[3]}; 
      b1_code3 = {~udata1[7], udata1[6], udata1[5]};
      b1_code4 = { 1'b0     , 1'b0     , 1'b0     };
    end
    2'b11: begin
      b0_code0 = { udata0[1], udata0[0], 1'b0     };
      b0_code1 = { udata0[3], udata0[2], udata0[1]};
      b0_code2 = { udata0[5], udata0[4], udata0[3]}; 
      b0_code3 = { udata0[7], udata0[6], udata0[5]};
      b0_code4 = { 1'b0     , 1'b0     , udata0[7]};
      b1_code0 = { udata1[1], udata1[0], 1'b0     };
      b1_code1 = { udata1[3], udata1[2], udata1[1]};
      b1_code2 = { udata1[5], udata1[4], udata1[3]}; 
      b1_code3 = { udata1[7], udata1[6], udata1[5]};
      b1_code4 = { 1'b0     , 1'b0     , udata1[7]};
    end
  endcase

  casez ({m_int8, v_cywen})
    2'b0z: begin
      b0_idat0 = {{6{~vdata0[3]}}, vdata0[2:0]};
      b0_idat1 = {{6{~vdata0[7]}}, vdata0[6:4]};
      b1_idat0 = {{6{~vdata1[3]}}, vdata1[2:0]};
      b1_idat1 = {{6{~vdata1[7]}}, vdata1[6:4]};
    end
    2'b10: begin
      b0_idat0 = {{2{~vdata0[7]}}, vdata0[6:0]};
      b0_idat1 = {{2{~vdata0[7]}}, vdata0[6:0]};
      b1_idat0 = {{2{~vdata1[7]}}, vdata1[6:0]};
      b1_idat1 = {{2{~vdata1[7]}}, vdata1[6:0]};
    end
    2'b11: begin
      b0_idat0 = {1'b0, vdata0[7:0]};
      b0_idat1 = {1'b0, vdata0[7:0]};
      b1_idat0 = {1'b0, vdata1[7:0]};
      b1_idat1 = {1'b0, vdata1[7:0]};
    end
  endcase
end

// BOOTH 0
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth00(
   .code            (b0_code0           )
  ,.idat            (b0_idat0           )
  ,.odat            (b0_odat0           )
  ,.oinv            (b0_oinv0           )
);
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth01(
   .code            (b0_code1           )
  ,.idat            (b0_idat0           )
  ,.odat            (b0_odat1           )
  ,.oinv            (b0_oinv1           )
);
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth02(
   .code            (b0_code2           )
  ,.idat            (b0_idat1           )
  ,.odat            (b0_odat2           )
  ,.oinv            (b0_oinv2           )
);
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth03(
   .code            (b0_code3           )
  ,.idat            (b0_idat1           )
  ,.odat            (b0_odat3           )
  ,.oinv            (b0_oinv3           )
);
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth04(
   .code            (b0_code4           )
  ,.idat            (b0_idat1           )
  ,.odat            (b0_odat4           )
  ,.oinv            (b0_oinv4           )
);

// BOOTH 1
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth10(
   .code            (b1_code0           )
  ,.idat            (b1_idat0           )
  ,.odat            (b1_odat0           )
  ,.oinv            (b1_oinv0           )
);
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth11(
   .code            (b1_code1           )
  ,.idat            (b1_idat0           )
  ,.odat            (b1_odat1           )
  ,.oinv            (b1_oinv1           )
);
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth12(
   .code            (b1_code2           )
  ,.idat            (b1_idat1           )
  ,.odat            (b1_odat2           )
  ,.oinv            (b1_oinv2           )
);
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth13(
   .code            (b1_code3           )
  ,.idat            (b1_idat1           )
  ,.odat            (b1_odat3           )
  ,.oinv            (b1_oinv3           )
);
AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth u_booth14(
   .code            (b1_code4           )
  ,.idat            (b1_idat1           )
  ,.odat            (b1_odat4           )
  ,.oinv            (b1_oinv4           )
);

assign a0_ins = {
   { 6'b0, b0_odat0}
  ,{ 4'b0, b0_odat1, 1'b0, b0_oinv0}
  ,{ 2'b0, 10'h200 , 1'b0, b0_oinv1, 2'b0}
  ,{11'b0,                 1'b0    , 4'b0}
  ,{ 6'b0, b1_odat0}
  ,{ 4'b0, b1_odat1, 1'b0, b1_oinv0}
  ,{ 2'b0, 10'h200 , 1'b0, b1_oinv1, 2'b0}
  ,{11'b0,                 1'b0    , 4'b0}
};

assign a1_ins = {
   { 6'b0, b0_odat2}
  ,{ 4'b0, b0_odat3, 1'b0, b0_oinv2}
  ,{ 2'b0, b0_odat4, 1'b0, b0_oinv3, 2'b0}
  ,{11'b0,                 b0_oinv4, 4'b0}
  ,{ 6'b0, b1_odat2}
  ,{ 4'b0, b1_odat3, 1'b0, b1_oinv2}
  ,{ 2'b0, b1_odat4, 1'b0, b1_oinv3, 2'b0}
  ,{11'b0,                 b1_oinv4, 4'b0}
};

DW02_sum #(
   .num_inputs      (8                  )
  ,.input_width     (16                 )
) u_sum0 (
   .INPUT           (a0_ins             )
  ,.SUM             (a0_sum             )
);

DW02_sum #(
   .num_inputs      (8                  )
  ,.input_width     (16                 )
) u_sum1 (
   .INPUT           (a1_ins             )
  ,.SUM             (a1_sum             )
);

assign z_sum = {4'b0, a0_sum} 
  + (m_int8  ? {      a1_sum, 4'b0}
             : {4'b0, a1_sum      });

assign z_sum_r = pipe[MSTAGES-1];

always_ff @(posedge aixh_core_clk2x)
  if (mul_enable) begin
    pipe[0] <= z_sum;
    for (int i = 1; i < MSTAGES; i++) begin
      pipe[i] <= pipe[i-1];
    end
  end

assign z_sft = acc_mode == 2'b00 ? {16'd0, z_sum_r       }
             : acc_mode == 2'b01 ? { 8'd0, z_sum_r,  8'd0}
             :                     {       z_sum_r, 16'd0};

assign z_acc_nx = z_acc + z_sft;
assign z_update1 = acc_mode == 2'b00 ? (z_acc[20]) : 1'b1;
assign z_update2 = acc_mode == 2'b00 ? (z_acc[28] & z_acc[20])
                 : acc_mode == 2'b01 ? (z_acc[28]) : 1'b1;
assign z_update3 = acc_mode == 2'b00 ? (z_acc[36] & z_acc[28] & z_acc[20])
                 : acc_mode == 2'b01 ? (z_acc[36] & z_acc[28])
                                     : (z_acc[36]);

always_ff @(posedge aixh_core_clk2x)
  if (acc_afresh) begin
    z_acc <= 48'd0;
  end else if (acc_enable) begin
                   z_acc[20:00] <= z_acc_nx[20:00];
    if (z_update1) z_acc[28:21] <= z_acc_nx[28:21];
    if (z_update2) z_acc[36:29] <= z_acc_nx[36:29];
    if (z_update3) z_acc[47:37] <= z_acc_nx[47:37];
  end

assign ozdata = z_acc;

endmodule

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

module AIXH_MXC_LEFT_PTILE_CELL_ISPE_booth
(
   input  wire [3           -1:0] code
  ,input  wire [9           -1:0] idat
  ,output wire [10          -1:0] odat
  ,output wire                    oinv
);
  
logic [10         -1:0] tdat;

assign odat = code[2] ? ~tdat : tdat;
assign oinv = code[2];

always_comb
  case (code)
    3'b000, 3'b111: tdat = {1'b1    ,  9'd0           }; // 0
    3'b001, 3'b010,
    3'b101, 3'b110: tdat = {~idat[8],  idat           }; // X
    3'b011, 3'b100: tdat = {~idat[8],  idat[7:0], 1'b0}; // 2X
  endcase

endmodule



`endif // AIXH_TARGET_ASIC
`resetall
