//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Upper) Processing-Tile
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_UPPER_ptile
#(
  TILE_INDEX = 0
) (
   input  wire                                            aixh_core_clk2x
  // UQCELL interface
  ,input  wire [IPTILE_XCELLS * UPCELL_DWI_DWIDTH   -1:0] i_uqt_dat
  // Vertical IPCELL interface
  ,output wire [IPTILE_XCELLS * 2                   -1:0] o_ipt_vld
  ,output wire [IPTILE_XCELLS * IPCELL_DWD_DWIDTH   -1:0] o_ipt_dat
  // Horizontal UPCELL interface
  ,input  wire [UPCELL_FWD_CWIDTH                   -1:0] i_upt_cmd
  ,output wire [UPCELL_FWD_CWIDTH                   -1:0] o_upt_cmd

  ,input  wire                                            i_upt_vld
  ,input  wire [UPCELL_BWD_DWIDTH                   -1:0] i_upt_dat
  ,output wire                                            o_upt_vld
  ,output wire [UPCELL_BWD_DWIDTH                   -1:0] o_upt_dat
);

wire [UPCELL_FWD_CWIDTH   -1:0] arr_upc_cmd[IPTILE_XCELLS+1];
wire                            arr_upc_vld[IPTILE_XCELLS+1];
wire [UPCELL_BWD_DWIDTH   -1:0] arr_upc_dat[IPTILE_XCELLS+1];

assign arr_upc_cmd[0] = i_upt_cmd;
assign arr_upc_vld[IPTILE_XCELLS] = i_upt_vld;
assign arr_upc_dat[IPTILE_XCELLS] = i_upt_dat;
assign o_upt_cmd = arr_upc_cmd[IPTILE_XCELLS];
assign o_upt_vld = arr_upc_vld[0];
assign o_upt_dat = arr_upc_dat[0];

for (genvar x = 0; x < IPTILE_XCELLS; x++) begin: X
  AIXH_MXC_UPPER_PTILE_cell #(
     .CELL_INDEX      (TILE_INDEX * IPTILE_XCELLS + x                     )
  ) u_cell(
     .aixh_core_clk2x (aixh_core_clk2x                                    )
    ,.i_uqc_dat       (i_uqt_dat[x*UPCELL_DWI_DWIDTH+:UPCELL_DWI_DWIDTH]  )
    ,.o_ipc_vld       (o_ipt_vld[x*2+:2]                                  )
    ,.o_ipc_dat       (o_ipt_dat[x*IPCELL_DWD_DWIDTH+:IPCELL_DWD_DWIDTH]  )
    ,.i_upc_cmd       (arr_upc_cmd[x]                                     )
    ,.o_upc_cmd       (arr_upc_cmd[x+1]                                   )
    ,.i_upc_vld       (arr_upc_vld[x+1]                                   )
    ,.i_upc_dat       (arr_upc_dat[x+1]                                   )
    ,.o_upc_vld       (arr_upc_vld[x]                                     )
    ,.o_upc_dat       (arr_upc_dat[x]                                     )
  );
end

endmodule
`resetall
