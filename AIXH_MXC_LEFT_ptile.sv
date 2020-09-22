//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Left) Processing-Tile
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_LEFT_ptile
#(
  TILE_INDEX = 0
) (
   input  wire                                            aixh_core_clk2x
  // LQCELL interface
  ,input  wire [IPTILE_YCELLS * LPCELL_FWI_DWIDTH   -1:0] i_lqt_dat
  ,output wire [IPTILE_YCELLS                       -1:0] o_lqt_vld
  ,output wire [IPTILE_YCELLS * LPCELL_BWO_DWIDTH   -1:0] o_lqt_dat
  // Veritical LPCELL interface
  ,input  wire [LPCELL_DWD_CWIDTH                   -1:0] i_lpt_cmd
  ,input  wire                                            i_lpt_vld
  ,input  wire [LPCELL_DWD_DWIDTH                   -1:0] i_lpt_dat
  ,output wire [LPCELL_DWD_CWIDTH                   -1:0] o_lpt_cmd
  ,output wire                                            o_lpt_vld
  ,output wire [LPCELL_DWD_DWIDTH                   -1:0] o_lpt_dat
  // Horizontal IPCELL interface
  ,input  wire [IPTILE_YCELLS                       -1:0] i_ipt_vld
  ,input  wire [IPTILE_YCELLS * IPCELL_BWD_DWIDTH   -1:0] i_ipt_dat
  ,output wire [IPTILE_YCELLS * IPCELL_FWD_CWIDTH   -1:0] o_ipt_cmd
  ,output wire [IPTILE_YCELLS * IPCELL_FWD_DWIDTH   -1:0] o_ipt_dat
);

wire [LPCELL_DWD_CWIDTH   -1:0] arr_lpc_cmd[IPTILE_YCELLS+1];
wire                            arr_lpc_vld[IPTILE_YCELLS+1];
wire [LPCELL_DWD_DWIDTH   -1:0] arr_lpc_dat[IPTILE_YCELLS+1];

assign arr_lpc_cmd[0] = i_lpt_cmd;
assign arr_lpc_vld[0] = i_lpt_vld;
assign arr_lpc_dat[0] = i_lpt_dat;
assign o_lpt_cmd = arr_lpc_cmd[IPTILE_YCELLS];
assign o_lpt_vld = arr_lpc_vld[IPTILE_YCELLS];
assign o_lpt_dat = arr_lpc_dat[IPTILE_YCELLS];

for (genvar y = 0; y < IPTILE_YCELLS; y++) begin: Y
  AIXH_MXC_LEFT_PTILE_cell #(
     .CELL_INDEX      (TILE_INDEX * IPTILE_YCELLS + y                     )
  ) u_cell(
     .aixh_core_clk2x (aixh_core_clk2x                                    )
    ,.i_lqc_dat       (i_lqt_dat[y*LPCELL_FWI_DWIDTH+:LPCELL_FWI_DWIDTH]  )
    ,.o_lqc_vld       (o_lqt_vld[y]                                       )
    ,.o_lqc_dat       (o_lqt_dat[y*LPCELL_BWO_DWIDTH+:LPCELL_BWO_DWIDTH]  )
    ,.i_lpc_cmd       (arr_lpc_cmd[y]                                     )
    ,.i_lpc_vld       (arr_lpc_vld[y]                                     )
    ,.i_lpc_dat       (arr_lpc_dat[y]                                     )
    ,.o_lpc_cmd       (arr_lpc_cmd[y+1]                                   )
    ,.o_lpc_vld       (arr_lpc_vld[y+1]                                   )
    ,.o_lpc_dat       (arr_lpc_dat[y+1]                                   )
    ,.i_ipc_vld       (i_ipt_vld[y]                                       )
    ,.i_ipc_dat       (i_ipt_dat[y*IPCELL_BWD_DWIDTH+:IPCELL_BWD_DWIDTH]  )
    ,.o_ipc_cmd       (o_ipt_cmd[y*IPCELL_FWD_CWIDTH+:IPCELL_FWD_CWIDTH]  )
    ,.o_ipc_dat       (o_ipt_dat[y*IPCELL_FWD_DWIDTH+:IPCELL_FWD_DWIDTH]  )
  );
end

endmodule

`resetall
