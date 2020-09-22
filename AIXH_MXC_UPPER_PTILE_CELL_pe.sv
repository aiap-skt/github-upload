//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Upper / Processing-Tile/ Cell) PE
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_UPPER_PTILE_CELL_pe
(
   input  wire                    aixh_core_clk2x

  // Convert stage control
  ,input  wire                    cvt_enable
  ,input  wire                    half_sel
  ,input  wire [2           -1:0] cvt_mode

  // MAC stage control
  ,input  wire                    mul_enable
  ,input  wire                    acc_enable
  ,input  wire                    acc_afresh
  ,input  wire [3           -1:0] mul_mode
  ,input  wire [2           -1:0] acc_mode

  ,input  wire [64          -1:0] iydata
  ,output reg  [32          -1:0] oydata
  ,output wire [ACCUM_BITS  -1:0] ozdata
);
// synopsys dc_tcl_script_begin
// set_optimize_registers -check_design -print_critical_loop
// synopsys dc_tcl_script_end

localparam MSTAGES = `AIXH_MXC_UISPE_STAGES - 1;

//------------------------------------------------------------------------------
// Convert inputs
//------------------------------------------------------------------------------
always_ff @(posedge aixh_core_clk2x)
  if (cvt_enable) begin
    case ({cvt_mode, half_sel})
      3'b00_0: // INT4 A
        oydata <= {iydata[6*4+:4] ^ 4'h8
                  ,iydata[4*4+:4] ^ 4'h8
                  ,iydata[2*4+:4] ^ 4'h8
                  ,iydata[0*4+:4] ^ 4'h8
                  ,iydata[7*4+:4] ^ 4'h8
                  ,iydata[5*4+:4] ^ 4'h8
                  ,iydata[3*4+:4] ^ 4'h8
                  ,iydata[1*4+:4] ^ 4'h8};
      3'b00_1: // INT4 B
        oydata <= {iydata[6*4+32+:4] ^ 4'h8
                  ,iydata[4*4+32+:4] ^ 4'h8
                  ,iydata[2*4+32+:4] ^ 4'h8
                  ,iydata[0*4+32+:4] ^ 4'h8
                  ,iydata[7*4+32+:4] ^ 4'h8
                  ,iydata[5*4+32+:4] ^ 4'h8
                  ,iydata[3*4+32+:4] ^ 4'h8
                  ,iydata[1*4+32+:4] ^ 4'h8};
      3'b01_0: // INT8 A
        oydata <= {iydata[2*8+:8] ^ 8'h80
                  ,iydata[0*8+:8] ^ 8'h80
                  ,iydata[3*8+:8] ^ 8'h80
                  ,iydata[1*8+:8] ^ 8'h80};
      3'b01_1: // INT8 B
        oydata <= {iydata[2*8+32+:8] ^ 8'h80
                  ,iydata[0*8+32+:8] ^ 8'h80
                  ,iydata[3*8+32+:8] ^ 8'h80
                  ,iydata[1*8+32+:8] ^ 8'h80};
      3'b10_0: // INT16 LLLL
        oydata <= {iydata[4*8+:8]
                  ,iydata[0*8+:8]
                  ,iydata[6*8+:8]
                  ,iydata[2*8+:8]};
      3'b10_1: // INT16 HHLL
        oydata <= {iydata[5*8+:8] ^ 8'h80
                  ,iydata[1*8+:8] ^ 8'h80
                  ,iydata[6*8+:8]
                  ,iydata[2*8+:8]};
      3'b11_0: // INT16 LLHH
        oydata <= {iydata[4*8+:8]
                  ,iydata[0*8+:8]
                  ,iydata[7*8+:8] ^ 8'h80
                  ,iydata[3*8+:8] ^ 8'h80};
      3'b11_1: // INT16 HHHH
        oydata <= {iydata[5*8+:8] ^ 8'h80
                  ,iydata[1*8+:8] ^ 8'h80
                  ,iydata[7*8+:8] ^ 8'h80
                  ,iydata[3*8+:8] ^ 8'h80};
    endcase
  end

//------------------------------------------------------------------------------
// MAC
//------------------------------------------------------------------------------
wire  [8          -1:0] udata0 = oydata[ 0+:8];
wire  [8          -1:0] udata1 = oydata[ 8+:8];
wire  [8          -1:0] vdata0 = oydata[16+:8];
wire  [8          -1:0] vdata1 = oydata[24+:8];
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
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth00(
   .code            (b0_code0           )
  ,.idat            (b0_idat0           )
  ,.odat            (b0_odat0           )
  ,.oinv            (b0_oinv0           )
);
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth01(
   .code            (b0_code1           )
  ,.idat            (b0_idat0           )
  ,.odat            (b0_odat1           )
  ,.oinv            (b0_oinv1           )
);
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth02(
   .code            (b0_code2           )
  ,.idat            (b0_idat1           )
  ,.odat            (b0_odat2           )
  ,.oinv            (b0_oinv2           )
);
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth03(
   .code            (b0_code3           )
  ,.idat            (b0_idat1           )
  ,.odat            (b0_odat3           )
  ,.oinv            (b0_oinv3           )
);
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth04(
   .code            (b0_code4           )
  ,.idat            (b0_idat1           )
  ,.odat            (b0_odat4           )
  ,.oinv            (b0_oinv4           )
);

// BOOTH 1
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth10(
   .code            (b1_code0           )
  ,.idat            (b1_idat0           )
  ,.odat            (b1_odat0           )
  ,.oinv            (b1_oinv0           )
);
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth11(
   .code            (b1_code1           )
  ,.idat            (b1_idat0           )
  ,.odat            (b1_odat1           )
  ,.oinv            (b1_oinv1           )
);
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth12(
   .code            (b1_code2           )
  ,.idat            (b1_idat1           )
  ,.odat            (b1_odat2           )
  ,.oinv            (b1_oinv2           )
);
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth13(
   .code            (b1_code3           )
  ,.idat            (b1_idat1           )
  ,.odat            (b1_odat3           )
  ,.oinv            (b1_oinv3           )
);
AIXH_MXC_UPPER_PTILE_CELL_PE_booth u_booth14(
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

module AIXH_MXC_UPPER_PTILE_CELL_PE_booth
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

`resetall
