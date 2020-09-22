//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Upper / Processing-Tile) Cell
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_UPPER_PTILE_cell
#(
   CELL_INDEX = 0
) (
   input  wire                              aixh_core_clk2x
  // UQCELL interface
  ,input  wire [UPCELL_DWI_DWIDTH     -1:0] i_uqc_dat
  // Vertical IPCELL interface
  ,output reg  [2                     -1:0] o_ipc_vld
  ,output wire [IPCELL_DWD_DWIDTH     -1:0] o_ipc_dat
  // Horizontal UPCELL interface
  ,input  wire [UPCELL_FWD_CWIDTH     -1:0] i_upc_cmd
  ,output reg  [UPCELL_FWD_CWIDTH     -1:0] o_upc_cmd

  ,input  wire                              i_upc_vld
  ,input  wire [UPCELL_BWD_DWIDTH     -1:0] i_upc_dat
  ,output reg                               o_upc_vld
  ,output reg  [UPCELL_BWD_DWIDTH     -1:0] o_upc_dat
);

localparam XREPEATER_MASK = `AIXH_MXC_IPTILE_XREPEATER_MASK;

function int SkewDepth(int idx);
  // Odd cell requires additional skew FF
  SkewDepth = idx[0] ? 1:0;
  for (int i = 0; i <= idx / IPTILE_XCELLS; i++) begin
    if (XREPEATER_MASK[i]) SkewDepth++; 
  end
endfunction

function automatic int ReLU(int x);
  ReLU = x > 0 ? x : 0;
endfunction

localparam SKEW_DEPTH = SkewDepth(CELL_INDEX);
localparam IPE_STAGES   = `AIXH_MXC_IPE_STAGES;
localparam UISPE_STAGES = `AIXH_MXC_UISPE_STAGES;
localparam DRAIN_LATENCY = 3 + ReLU(UISPE_STAGES-3);

UPCELL_Command                        i_cmd_raw;
UPCELL_Command                        i_cmd_gated;
UPCELL_Command                        r_cmd;

logic [UISPE_STAGES             -1:0] mac_enable_sr;
logic [UISPE_STAGES-1           -1:0] mac_afresh_sr;
logic [3                        -1:0] mul_mode_sr[1];
logic [2                        -1:0] acc_mode_sr[UISPE_STAGES];
logic [UISPE_STAGES+1           -1:0] drain_req_sr;

logic                                 pe_mul_enable;
logic                                 pe_acc_enable;
logic                                 pe_acc_afresh;
logic [3                        -1:0] pe_mul_mode;
logic [2                        -1:0] pe_acc_mode;

logic                                 drain_1st;
logic                                 drain_2nd;

logic [64                       -1:0] iydata0;
logic [64                       -1:0] iydata1;
logic [32                       -1:0] oydata0;
logic [32                       -1:0] oydata1;
logic [ACCUM_BITS               -1:0] zdata0;
logic [ACCUM_BITS               -1:0] zdata1;
logic [ACCUM_BITS               -1:0] bdata0;
logic [ACCUM_BITS               -1:0] bdata1;
logic [SCALE_BITS               -1:0] sdata0;
logic [SCALE_BITS               -1:0] sdata1;


assign i_cmd_raw = i_upc_cmd;
assign o_ipc_dat = {oydata1, oydata0};

// Gate command signals
always_comb begin
  i_cmd_gated = i_cmd_raw;
  i_cmd_gated.active_cells = i_cmd_raw.active_cells - 7'd1;
  if (i_cmd_raw.active_cells == 7'd0) begin
    i_cmd_gated.mac_enable = 1'b0;
    i_cmd_gated.drain_pre  = 1'b0;
    i_cmd_gated.drain_req  = 1'b0;
  end
end

// Control signal pipeline
always_ff @(posedge aixh_core_clk2x) begin 
  mac_enable_sr[0] <= i_cmd_gated.mac_enable;
  mac_afresh_sr[0] <= i_cmd_gated.mac_afresh;
  mul_mode_sr  [0] <= i_cmd_gated.mac_mode[4:2];
  acc_mode_sr  [0] <= i_cmd_gated.mac_mode[1:0];
  drain_req_sr [0] <= i_cmd_gated.drain_req;
  
`define __MOVE_SHIFT_REG(sr) \
  for (int i = 1; i < $size(sr); i++) sr[i] <= sr[i-1];
  `__MOVE_SHIFT_REG(mac_enable_sr)
  `__MOVE_SHIFT_REG(mac_afresh_sr)
  `__MOVE_SHIFT_REG(mul_mode_sr)
  `__MOVE_SHIFT_REG(acc_mode_sr)
  `__MOVE_SHIFT_REG(drain_req_sr)
`undef __MOVE_SHIFT_REG
end

// PE control
always_ff @(posedge aixh_core_clk2x) begin
  pe_mul_enable <= |mac_enable_sr[UISPE_STAGES-2:0];
  pe_acc_enable <=  mac_enable_sr[UISPE_STAGES-1];
  pe_acc_afresh <=  mac_afresh_sr[UISPE_STAGES-2];
  pe_mul_mode   <=  mul_mode_sr  [0];
  pe_acc_mode   <=  acc_mode_sr  [UISPE_STAGES-1];
end

// Drain control
assign drain_1st = drain_req_sr[DRAIN_LATENCY-2];
assign drain_2nd = drain_req_sr[DRAIN_LATENCY-1];

// Inter-cell command pipeline
assign o_upc_cmd = r_cmd;

always_ff @(posedge aixh_core_clk2x) begin
  r_cmd        <= i_cmd_gated;
  o_ipc_vld[0] <= |{mac_enable_sr[IPE_STAGES-1:0]
                   ,drain_req_sr [IPE_STAGES-1]};
  o_ipc_vld[1] <= | drain_req_sr [IPE_STAGES-1+:2];
end

// Skew UQC data if required
if (SKEW_DEPTH > 0) begin: g_skew
  localparam DEPTH = SKEW_DEPTH > 0 ? SKEW_DEPTH : 1;
  logic [UPCELL_DWI_DWIDTH    -1:0] pipe[DEPTH];

  always_ff @(posedge aixh_core_clk2x) begin
    pipe[0] <= i_uqc_dat;
    for (int i = 1; i < DEPTH; i++) begin
      pipe[i] <= pipe[i-1];
    end
  end

  assign {iydata1, iydata0} = pipe[DEPTH-1];
end else begin
  assign {iydata1, iydata0} = i_uqc_dat;
end

// Drain
always_ff @(posedge aixh_core_clk2x)
  if (r_cmd.drain_pre) begin
    bdata0 <= iydata0[0+:ACCUM_BITS];
    bdata1 <= iydata1[0+:ACCUM_BITS];
  end else
  if (r_cmd.drain_req) begin
    sdata0 <= iydata0[0+:SCALE_BITS];
    sdata1 <= iydata1[0+:SCALE_BITS];
  end

always_ff @(posedge aixh_core_clk2x) begin
  o_upc_vld <= drain_1st | drain_2nd | i_upc_vld;

  if (drain_1st) begin
    o_upc_dat[ACCUM_BITS-1:0] <= bdata0 + ~zdata0;
    o_upc_dat[ACCUM_BITS+:SCALE_BITS] <= sdata0;
  end else
  if (drain_2nd) begin
    o_upc_dat[ACCUM_BITS-1:0] <= bdata1 + ~zdata1;
    o_upc_dat[ACCUM_BITS+:SCALE_BITS] <= sdata1;
  end else
  if (i_upc_vld) begin
    o_upc_dat <= i_upc_dat;
  end
end

// PE instances
AIXH_MXC_UPPER_PTILE_CELL_pe u_pe0(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.cvt_enable          (r_cmd.mac_enable     )
  ,.half_sel            (r_cmd.in_half_sel    )
  ,.cvt_mode            (r_cmd.in_cvt_mode    )

  ,.mul_enable          (pe_mul_enable        )
  ,.acc_enable          (pe_acc_enable        )
  ,.acc_afresh          (pe_acc_afresh        )
  ,.mul_mode            (pe_mul_mode          )
  ,.acc_mode            (pe_acc_mode          )
  ,.iydata              (iydata0              )
  ,.oydata              (oydata0              )
  ,.ozdata              (zdata0               )
);

AIXH_MXC_UPPER_PTILE_CELL_pe u_pe1(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.cvt_enable          (r_cmd.mac_enable     )
  ,.half_sel            (r_cmd.in_half_sel    )
  ,.cvt_mode            (r_cmd.in_cvt_mode    )

  ,.mul_enable          (pe_mul_enable        )
  ,.acc_enable          (pe_acc_enable        )
  ,.acc_afresh          (pe_acc_afresh        )
  ,.mul_mode            (pe_mul_mode          )
  ,.acc_mode            (pe_acc_mode          )
  ,.iydata              (iydata1              )
  ,.oydata              (oydata1              )
  ,.ozdata              (zdata1               )
);

//==============================================================================
//==============================================================================
endmodule
`resetall
