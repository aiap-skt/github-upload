//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Inner) Y-Repeater
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_INNER_yrepeater
(
   input  wire                                            aixh_core_clk2x
   
  ,input  wire [IPTILE_XCELLS * 2                   -1:0] i_dwd_vld
  ,input  wire [IPTILE_XCELLS * IPCELL_DWD_DWIDTH   -1:0] i_dwd_dat
  ,output reg  [IPTILE_XCELLS * 2                   -1:0] o_dwd_vld
  ,output reg  [IPTILE_XCELLS * IPCELL_DWD_DWIDTH   -1:0] o_dwd_dat
);

always_ff @(posedge aixh_core_clk2x) begin
  o_dwd_vld <= i_dwd_vld;

  for (int i = 0; i < IPTILE_XCELLS; i++) begin
    if (i_dwd_vld[i*2]) begin
      o_dwd_dat[IPCELL_DWD_DWIDTH*i+:IPCELL_DWD_DWIDTH] <=
      i_dwd_dat[IPCELL_DWD_DWIDTH*i+:IPCELL_DWD_DWIDTH];      
    end
  end
end

endmodule
`resetall
