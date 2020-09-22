//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Left) Repeater
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_LEFT_repeater
(
   input  wire                                            aixh_core_clk2x
   
  ,input wire [LPCELL_DWD_CWIDTH                    -1:0] i_dwd_cmd 
  ,input wire                                             i_dwd_vld 
  ,input wire [LPCELL_DWD_DWIDTH                    -1:0] i_dwd_dat 
  ,output reg [LPCELL_DWD_CWIDTH                    -1:0] o_dwd_cmd 
  ,output reg                                             o_dwd_vld 
  ,output reg [LPCELL_DWD_DWIDTH                    -1:0] o_dwd_dat 
);

always_ff @(posedge aixh_core_clk2x) begin
  o_dwd_cmd <= i_dwd_cmd;
  o_dwd_vld <= i_dwd_vld;

  if (i_dwd_vld) begin
    o_dwd_dat <= i_dwd_dat;
  end
end

endmodule
`resetall
