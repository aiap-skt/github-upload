//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Upper) Repeater
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_UPPER_repeater
(
   input  wire                                            aixh_core_clk2x
   
  ,input  wire [UPCELL_FWD_CWIDTH                   -1:0] i_fwd_cmd
  ,output reg  [UPCELL_FWD_CWIDTH                   -1:0] o_fwd_cmd

  ,input  wire                                            i_bwd_vld
  ,input  wire [UPCELL_BWD_DWIDTH                   -1:0] i_bwd_dat
  ,output reg                                             o_bwd_vld
  ,output reg  [UPCELL_BWD_DWIDTH                   -1:0] o_bwd_dat
);

always_ff @(posedge aixh_core_clk2x) begin
  o_fwd_cmd <= i_fwd_cmd;
end

always_ff @(posedge aixh_core_clk2x) begin
  o_bwd_vld <= i_bwd_vld;

  if (i_bwd_vld) begin
    o_bwd_dat <= i_bwd_dat;
  end
end

endmodule
`resetall
