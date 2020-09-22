//==============================================================================
// AIX-H Project
//
// Module: MxConv
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_mxc
(
   input  wire                                        aixh_core_clk2x
`ifdef AIXH_DEVICE_FPGA
  ,input  wire                                        aixh_core_clk
`endif
  ,input  wire                                        aixh_core_div_rstn
  ,input  wire                                        aixh_core_rstn
  
  // Command interface (DCS)
  ,input  wire                                        cmdw_en
  ,input  wire                                        cmdw_last
  ,input  wire [64                              -1:0] cmdw_data
  ,input  wire                                        cmdx_req
  ,output wire                                        cmdx_done
  
  // LTC interface
  ,input  wire [LTC_SLICES                      -1:0] ltc_arupdate
  ,output wire [LTC_SLICES                      -1:0] ltc_arvalid
  ,output wire [LTC_SLICES * LTC_SLICE_AWIDTH   -1:0] ltc_araddr
  ,output wire [LTC_SLICES                      -1:0] ltc_rupdate
  ,input  wire [LTC_SLICES                      -1:0] ltc_rvalid
  ,input  wire [LTC_SLICES * LTC_SLICE_DWIDTH   -1:0] ltc_rdata
  
  ,input  wire [LTC_SLICES                      -1:0] ltc_awupdate
  ,output wire [LTC_SLICES                      -1:0] ltc_awvalid
  ,output wire [LTC_SLICES * LTC_SLICE_AWIDTH   -1:0] ltc_awaddr
  ,input  wire [LTC_SLICES                      -1:0] ltc_wupdate
  ,output wire [LTC_SLICES                      -1:0] ltc_wvalid
  ,output wire [LTC_SLICES * LTC_SLICE_DWIDTH   -1:0] ltc_wdata

  // UTC interface
  ,output wire [UTC_SLICES                      -1:0] utc_arvalid
  ,output wire [UTC_SLICES * UTC_SLICE_AWIDTH   -1:0] utc_araddr
  ,input  wire [UTC_SLICES * UTC_SLICE_DWIDTH   -1:0] utc_rdata
  
  // Debug
  ,output wire [32                              -1:0] dbg_out
);

localparam HEIGHT = `AIXH_MXC_HEIGHT;
localparam WIDTH  = `AIXH_MXC_WIDTH;
localparam YCELLS = HEIGHT / IPCELL_HEIGHT;
localparam XCELLS = WIDTH  / IPCELL_WIDTH;

wire [UTC_SLICES                          -1:0] utc_rvalid;

wire                                            upper_fwd_csync; 
wire [UPCELL_FWD_CWIDTH                   -1:0] upper_fwd_cmd;
wire                                            upper_bwd_vld;
wire [UPCELL_BWD_DWIDTH                   -1:0] upper_bwd_dat;

wire                                            left_dwd_icsync;
wire                                            left_dwd_ocsync;
wire                                            left_dwd_wenable;
wire                                            left_dwd_renable;
wire [2                                   -1:0] left_dwd_rmode;
wire [LPCELL_DWD_CWIDTH                   -1:0] left_dwd_cmd;
wire                                            left_dwd_vld;
wire [UPCELL_BWD_DWIDTH                   -1:0] left_dwd_dat;

wire [IPTILE_YCOUNT * IPTILE_FWD_CWIDTH   -1:0] inner_fwd_cmd;
wire [IPTILE_YCOUNT * IPTILE_FWD_DWIDTH   -1:0] inner_fwd_dat;
wire [IPTILE_YCOUNT * IPTILE_YCELLS       -1:0] inner_bwd_vld;
wire [IPTILE_YCOUNT * IPTILE_BWD_DWIDTH   -1:0] inner_bwd_dat;
wire [IPTILE_XCOUNT * IPTILE_XCELLS*2     -1:0] inner_dwd_vld;
wire [IPTILE_XCOUNT * IPTILE_DWD_DWIDTH   -1:0] inner_dwd_dat;


assign ltc_wvalid = ltc_awvalid;

`ifdef AIXH_DEVICE_ASIC
//
// Clock divider
//
wire                                            aixh_core_clk; 

AIXH_MXC_clkdiv2 u_clkdiv2(
   .i_clk                 (aixh_core_clk2x                                    )
  ,.i_rstn                (aixh_core_div_rstn                                 )
  ,.o_clkdiv2             (aixh_core_clk                                      )
);
`endif // AIXH_DEVICE_ASIC


//
// Controller
//
(* keep_hierarchy = "yes" *)
AIXH_MXC_ctrl u_ctrl(
   .aixh_core_clk         (aixh_core_clk                                      )
  ,.aixh_core_clk2x       (aixh_core_clk2x                                    )
  ,.aixh_core_rstn        (aixh_core_rstn                                     )
  ,.aixh_core_div_rstn    (aixh_core_div_rstn                                 )

  ,.cmdw_en               (cmdw_en                                            )
  ,.cmdw_last             (cmdw_last                                          )
  ,.cmdw_data             (cmdw_data                                          )
  ,.cmdx_req              (cmdx_req                                           )
  ,.cmdx_done             (cmdx_done                                          )

  ,.ltc_arupdate          (ltc_arupdate                                       )
  ,.ltc_arvalid           (ltc_arvalid                                        )
  ,.ltc_araddr            (ltc_araddr                                         )
  ,.ltc_rupdate           (ltc_rupdate                                        )
  ,.ltc_rvalid            (ltc_rvalid                                         )
  ,.ltc_awupdate          (ltc_awupdate                                       )
  ,.ltc_awvalid           (ltc_awvalid                                        )
  ,.ltc_awaddr            (ltc_awaddr                                         )

  ,.utc_arvalid           (utc_arvalid                                        )
  ,.utc_araddr            (utc_araddr                                         )
  ,.utc_rvalid            (utc_rvalid                                         )

  ,.uqc_csync             (upper_fwd_csync                                    )
  ,.upc_cmd               (upper_fwd_cmd                                      )
  ,.upc_vld               (upper_bwd_vld                                      )
  ,.lqc_icsync            (left_dwd_icsync                                    )
  ,.lqc_ocsync            (left_dwd_ocsync                                    )
  ,.lqc_wenable           (left_dwd_wenable                                   )
  ,.lqc_renable           (left_dwd_renable                                   )
  ,.lqc_rmode             (left_dwd_rmode                                     )
  ,.lpc_cmd               (left_dwd_cmd                                       )

  ,.dbg_out               (dbg_out                                            )
);

`ifndef AIXH_DRY_MODE
//
// Upper
//
AIXH_MXC_upper u_upper(
   .aixh_core_clk         (aixh_core_clk                                      )
  ,.aixh_core_clk2x       (aixh_core_clk2x                                    )

  ,.i_utc_vld             (utc_rvalid                                         )
  ,.i_utc_dat             (utc_rdata                                          )
  ,.o_dwd_vld             (inner_dwd_vld                                      )
  ,.o_dwd_dat             (inner_dwd_dat                                      )

  ,.i_fwd_csync           (upper_fwd_csync                                    )
  ,.i_fwd_cmd             (upper_fwd_cmd                                      )
  ,.o_bwd_vld             (upper_bwd_vld                                      )
  ,.o_bwd_dat             (upper_bwd_dat                                      )
);

//
// Corner (Upper to Left)
//
AIXH_MXC_corner u_corner(
   .aixh_core_clk2x       (aixh_core_clk2x                                    )

  ,.i_upper_cmd           (upper_fwd_cmd                                      )
  ,.i_upper_vld           (upper_bwd_vld                                      )
  ,.i_upper_dat           (upper_bwd_dat                                      )

  ,.o_left_vld            (left_dwd_vld                                       )
  ,.o_left_dat            (left_dwd_dat                                       )
);


//
// Left
//
AIXH_MXC_left u_left(
   .aixh_core_clk         (aixh_core_clk                                      )
  ,.aixh_core_clk2x       (aixh_core_clk2x                                    )
  ,.aixh_core_rstn        (aixh_core_rstn                                     )

  ,.i_dwd_icsync          (left_dwd_icsync                                    )
  ,.i_dwd_ocsync          (left_dwd_ocsync                                    )
  ,.i_dwd_wenable         (left_dwd_wenable                                   )
  ,.i_dwd_renable         (left_dwd_renable                                   )
  ,.i_dwd_rmode           (left_dwd_rmode                                     )
  ,.i_dwd_cmd             (left_dwd_cmd                                       )
  ,.i_dwd_vld             (left_dwd_vld                                       )
  ,.i_dwd_dat             (left_dwd_dat                                       )

  ,.i_ltc_vld             (ltc_rvalid                                         )
  ,.i_ltc_dat             (ltc_rdata                                          )
  ,.o_ltc_dat             (ltc_wdata                                          )
  ,.i_bwd_vld             (inner_bwd_vld                                      )
  ,.i_bwd_dat             (inner_bwd_dat                                      )
  ,.o_fwd_cmd             (inner_fwd_cmd                                      )
  ,.o_fwd_dat             (inner_fwd_dat                                      )
);

//
// Inner
//
AIXH_MXC_inner u_inner(
   .aixh_core_clk2x       (aixh_core_clk2x                                    )

  ,.i_dwd_vld             (inner_dwd_vld                                      )
  ,.i_dwd_dat             (inner_dwd_dat                                      )

  ,.i_fwd_cmd             (inner_fwd_cmd                                      ) 
  ,.i_fwd_dat             (inner_fwd_dat                                      )
  ,.o_bwd_vld             (inner_bwd_vld                                      )
  ,.o_bwd_dat             (inner_bwd_dat                                      )
);
`endif // !AIXH_DRY_MODE

endmodule

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

module AIXH_MXC_corner
(
   input  wire                                        aixh_core_clk2x

  ,input  wire [UPCELL_FWD_CWIDTH               -1:0] i_upper_cmd
  ,input  wire                                        i_upper_vld
  ,input  wire [UPCELL_BWD_DWIDTH               -1:0] i_upper_dat
  ,output wire                                        o_left_vld
  ,output wire [UPCELL_BWD_DWIDTH               -1:0] o_left_dat
);

function automatic int ReLU(int x);
  ReLU = x > 0 ? x : 0;
endfunction

localparam IPE_STAGES   = `AIXH_MXC_IPE_STAGES;
localparam UISPE_STAGES = `AIXH_MXC_UISPE_STAGES;
localparam UPPER_LATENCY = 3 + ReLU(UISPE_STAGES-3);
localparam U2L_PIPES = (IPE_STAGES + 5) - UPPER_LATENCY;

localparam LPE_INT4_BIAS = 48'h00000A800;
localparam LPE_INT8_BIAS = 48'h000059400;
localparam UPE_INT4_BIAS = 48'h00000A800;
localparam UPE_INT8_BIAS = 48'h000059400;
localparam IPE_INT4_BIAS = 48'h000024C00;
localparam IPE_INT8_BIAS = 48'h000024800;
localparam CPE_INT4_BIAS = LPE_INT4_BIAS + UPE_INT4_BIAS - IPE_INT4_BIAS;
localparam CPE_INT8_BIAS = LPE_INT8_BIAS + UPE_INT8_BIAS - IPE_INT8_BIAS;

UPCELL_Command                        i_cmd;

logic [UPPER_LATENCY-2          -1:0] mac_afresh_sr;
logic [UPPER_LATENCY-1          -1:0] mac_enable_sr;
logic [3                        -1:0] mac_mode_sr[UPPER_LATENCY-1];
logic [UPPER_LATENCY-1          -1:0] drain_req_sr;

logic                                 mac_enable;
logic                                 mac_afresh;
logic [3                        -1:0] mac_mode;
logic                                 drain_req;

logic [ACCUM_BITS               -1:0] acc_prev;
logic [ACCUM_BITS               -1:0] acc_curr;

logic [ACCUM_BITS               -1:0] bdata_in;
logic [ACCUM_BITS               -1:0] bdata_adj;
logic [SCALE_BITS               -1:0] sdata;

logic                                 u2l_vpipe[U2L_PIPES];
logic [UPCELL_BWD_DWIDTH        -1:0] u2l_dpipe[U2L_PIPES];


assign i_cmd = i_upper_cmd;

// Control signal pipeline
always_ff @(posedge aixh_core_clk2x) begin 
  mac_enable_sr[0] <= i_cmd.mac_enable;
  mac_afresh_sr[0] <= i_cmd.mac_afresh;
  mac_mode_sr  [0] <= i_cmd.mac_mode[2:0];
  drain_req_sr [0] <= i_cmd.drain_req;
  
`define __MOVE_SHIFT_REG(sr) \
  for (int i = 1; i < $size(sr); i++) sr[i] <= sr[i-1];
  `__MOVE_SHIFT_REG(mac_enable_sr)
  `__MOVE_SHIFT_REG(mac_afresh_sr)
  `__MOVE_SHIFT_REG(mac_mode_sr)
  `__MOVE_SHIFT_REG(drain_req_sr)
`undef __MOVE_SHIFT_REG
end

assign mac_afresh = mac_afresh_sr[UPPER_LATENCY-3];
assign mac_enable = mac_enable_sr[UPPER_LATENCY-2];
assign mac_mode   = mac_mode_sr  [UPPER_LATENCY-2];
assign drain_req  = drain_req_sr [UPPER_LATENCY-2];

// Accumulate MAC offsets
always_ff @(posedge aixh_core_clk2x)
  if (mac_afresh) begin
    acc_curr <= 48'd1;
  end else
  if (mac_enable) begin
    case (mac_mode)
      3'b0_00: acc_curr <= acc_curr + 48'(CPE_INT4_BIAS <<  0);
      3'b0_01: acc_curr <= acc_curr + 48'(CPE_INT4_BIAS <<  8);
      3'b0_10: acc_curr <= acc_curr + 48'(CPE_INT4_BIAS << 16);
      3'b1_00: acc_curr <= acc_curr + 48'(CPE_INT8_BIAS <<  0);
      3'b1_01: acc_curr <= acc_curr + 48'(CPE_INT8_BIAS <<  8);
      3'b1_10: acc_curr <= acc_curr + 48'(CPE_INT8_BIAS << 16);
    endcase
  end

always_ff @(posedge aixh_core_clk2x)
  if (drain_req) acc_prev <= acc_curr;

// Adjust bias
assign {sdata, bdata_in} = i_upper_dat;
assign bdata_adj = bdata_in + acc_prev;

// Compensate for drain latency difference between IPTILE and UPTILE.
assign o_left_vld = u2l_vpipe[U2L_PIPES-1];
assign o_left_dat = u2l_dpipe[U2L_PIPES-1];

always_ff @(posedge aixh_core_clk2x) begin
  u2l_vpipe[0] <= i_upper_vld;
  if (i_upper_vld) begin
    u2l_dpipe[0] <= {sdata, bdata_adj};
  end
  for (int i = 1; i < U2L_PIPES; i++) begin
    u2l_vpipe[i] <= u2l_vpipe[i-1];
    if (u2l_vpipe[i-1]) begin
      u2l_dpipe[i] <= u2l_dpipe[i-1];
    end
  end
end

endmodule

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

module AIXH_MXC_clkdiv2(
   input  wire                                        i_clk
  ,input  wire                                        i_rstn
  ,output reg                                         o_clkdiv2
);

always_ff @(posedge i_clk or negedge i_rstn)
  if (~i_rstn)
       o_clkdiv2 <= 1'b0;
  else o_clkdiv2 <= ~o_clkdiv2; 

endmodule
`resetall
