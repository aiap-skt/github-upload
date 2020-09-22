//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Left / Queue-Tile) Output-Side Cell
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_LEFT_QTILE_oscell
#(
   DESKEW_DEPTH = 1
) (
   input  wire                              aixh_core_clk
  ,input  wire                              aixh_core_clk2x
  
  // Vertical interface
  ,input  wire                              i_csync
  // Horizontal data interface
  ,input  wire                              i_wenable
  ,input  wire [LQCELL_BWD_DWIDTH     -1:0] i_wdata
  ,output wire [LQCELL_BWD_DWIDTH     -1:0] o_rdata
);

logic                           deskew_vin;
logic [LQCELL_BWD_DWIDTH  -1:0] deskew_din;

// CLK2X input register
always_ff @(posedge aixh_core_clk2x) begin
  if (i_csync) deskew_vin <= 
    `ifndef SYNTHESIS
    #0.1 
    `endif
    i_wenable;

  if (i_csync & i_wenable) deskew_din <= 
    `ifndef SYNTHESIS
    #0.1 
    `endif
    i_wdata;
end

// CLK1X skewing stage
if (DESKEW_DEPTH == 1) begin
  assign o_rdata = deskew_din;
end else begin: g_deskew
  localparam DEPTH = DESKEW_DEPTH > 1 ? DESKEW_DEPTH : 2;
  logic [DEPTH-2            -1:0] deskew_vffs;
  logic [LQCELL_BWD_DWIDTH  -1:0] deskew_dffs[DEPTH-1];
  assign o_rdata = deskew_dffs[DEPTH-2];

  always_ff @(posedge aixh_core_clk) begin
    deskew_vffs <= (DEPTH-1)'({deskew_vffs, deskew_vin});
    if (deskew_vin) deskew_dffs[0] <= deskew_din;

    for (int i = 1; i < DEPTH-1; i++) begin
      if (deskew_vffs[i-1]) deskew_dffs[i] <= deskew_dffs[i-1];
    end
  end
end

endmodule
`resetall
