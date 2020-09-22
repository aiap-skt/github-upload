//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Upper / Queue-Tile) Input-Side Cell
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_UPPER_QTILE_cell
#(
   SKEW_DEPTH = 1
) (
   input  wire                              aixh_core_clk  
  ,input  wire                              aixh_core_clk2x

  // Horizontal control interface
  ,input  wire                              i_csync
  // Vertical data interface
  ,input  wire                              i_senable
  ,input  wire [UQCELL_DWD_DWIDTH     -1:0] i_sdata
  ,output reg  [UQCELL_DWD_DWIDTH     -1:0] o_rdata
);

logic                           clk2x_phase;
logic                           skew_vout;
logic [UQCELL_DWD_DWIDTH  -1:0] skew_dout;

// CLK1X skewing stage
if (SKEW_DEPTH == 1) begin
  assign skew_vout = i_senable;
  assign skew_dout = i_sdata;
end else begin: g_skew
  localparam DEPTH = SKEW_DEPTH > 1 ? SKEW_DEPTH : 2;
  logic [DEPTH-1            -1:0] skew_vffs;
  logic [UQCELL_DWD_DWIDTH  -1:0] skew_dffs[DEPTH-1];
  assign skew_vout = skew_vffs[DEPTH-2];
  assign skew_dout = skew_dffs[DEPTH-2];

  always_ff @(posedge aixh_core_clk) begin
    skew_vffs <= (DEPTH-1)'({skew_vffs, i_senable});
    if (i_senable) skew_dffs[0] <= i_sdata;
    for (int i = 1; i < DEPTH-1; i++) begin
      if (skew_vffs[i-1]) skew_dffs[i] <= skew_dffs[i-1];
    end
  end
end

// CLK2X output register
always_ff @(posedge aixh_core_clk2x)
  if (i_csync & skew_vout) o_rdata <= skew_dout;

endmodule
`resetall
