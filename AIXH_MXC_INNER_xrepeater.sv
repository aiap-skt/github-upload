//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Inner) X-Repeater
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_INNER_xrepeater
(
   input  wire                                            aixh_core_clk2x
   
  ,input  wire [IPTILE_YCELLS * IPCELL_FWD_CWIDTH   -1:0] i_fwd_cmd
  ,input  wire [IPTILE_YCELLS * IPCELL_FWD_DWIDTH   -1:0] i_fwd_dat
  ,output reg  [IPTILE_YCELLS * IPCELL_FWD_CWIDTH   -1:0] o_fwd_cmd
  ,output reg  [IPTILE_YCELLS * IPCELL_FWD_DWIDTH   -1:0] o_fwd_dat

  ,input  wire [IPTILE_YCELLS                       -1:0] i_bwd_vld
  ,input  wire [IPTILE_YCELLS * IPCELL_BWD_DWIDTH   -1:0] i_bwd_dat
  ,output reg  [IPTILE_YCELLS                       -1:0] o_bwd_vld
  ,output reg  [IPTILE_YCELLS * IPCELL_BWD_DWIDTH   -1:0] o_bwd_dat
);

always_ff @(posedge aixh_core_clk2x) begin
  o_fwd_cmd <= i_fwd_cmd;

  for (int i = 0; i < IPTILE_YCELLS; i++) begin
    if (i_fwd_cmd[(i+1)*IPCELL_FWD_CWIDTH-1]) begin
      o_fwd_dat[IPCELL_FWD_DWIDTH*i+:IPCELL_FWD_DWIDTH] <=
      i_fwd_dat[IPCELL_FWD_DWIDTH*i+:IPCELL_FWD_DWIDTH];
    end
  end
end

always_ff @(posedge aixh_core_clk2x) begin
  o_bwd_vld <= i_bwd_vld;

  for (int i = 0; i < IPTILE_YCELLS; i++) begin
    if (i_bwd_vld[i]) begin
      o_bwd_dat[IPCELL_BWD_DWIDTH*i+:IPCELL_BWD_DWIDTH] <=
      i_bwd_dat[IPCELL_BWD_DWIDTH*i+:IPCELL_BWD_DWIDTH];
    end
  end
end

endmodule
`resetall
