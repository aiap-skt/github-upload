//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Inner) Processing-Tile
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_INNER_ptile
(
   input  wire                                            aixh_core_clk2x
  
   // Vertical interface
  ,input  wire [IPTILE_XCELLS * 2                   -1:0] i_dwd_vld
  ,input  wire [IPTILE_XCELLS * IPCELL_DWD_DWIDTH   -1:0] i_dwd_dat
  ,output wire [IPTILE_XCELLS * 2                   -1:0] o_dwd_vld
  ,output wire [IPTILE_XCELLS * IPCELL_DWD_DWIDTH   -1:0] o_dwd_dat

  // Horizontal interface
  ,input  wire [IPTILE_YCELLS * IPCELL_FWD_CWIDTH   -1:0] i_fwd_cmd
  ,input  wire [IPTILE_YCELLS * IPCELL_FWD_DWIDTH   -1:0] i_fwd_dat
  ,output wire [IPTILE_YCELLS * IPCELL_FWD_CWIDTH   -1:0] o_fwd_cmd
  ,output wire [IPTILE_YCELLS * IPCELL_FWD_DWIDTH   -1:0] o_fwd_dat

  ,input  wire [IPTILE_YCELLS                       -1:0] i_bwd_vld
  ,input  wire [IPTILE_YCELLS * IPCELL_BWD_DWIDTH   -1:0] i_bwd_dat
  ,output wire [IPTILE_YCELLS                       -1:0] o_bwd_vld
  ,output wire [IPTILE_YCELLS * IPCELL_BWD_DWIDTH   -1:0] o_bwd_dat
);

wire [2                   -1:0] arr_dwd_vld[IPTILE_YCELLS+1][IPTILE_XCELLS  ];
wire [IPCELL_DWD_DWIDTH   -1:0] arr_dwd_dat[IPTILE_YCELLS+1][IPTILE_XCELLS  ];
wire [IPCELL_FWD_CWIDTH   -1:0] arr_fwd_cmd[IPTILE_YCELLS  ][IPTILE_XCELLS+1];
wire [IPCELL_FWD_DWIDTH   -1:0] arr_fwd_dat[IPTILE_YCELLS  ][IPTILE_XCELLS+1];
wire                            arr_bwd_vld[IPTILE_YCELLS  ][IPTILE_XCELLS+1];
wire [IPCELL_BWD_DWIDTH   -1:0] arr_bwd_dat[IPTILE_YCELLS  ][IPTILE_XCELLS+1];

for (genvar x = 0; x < IPTILE_XCELLS; x++) begin: X
  assign arr_dwd_vld[0][x] = i_dwd_vld[x*2+:2                                ];
  assign arr_dwd_dat[0][x] = i_dwd_dat[x*IPCELL_DWD_DWIDTH+:IPCELL_DWD_DWIDTH];

  assign o_dwd_vld[x*2+:2                                ] = arr_dwd_vld[IPTILE_YCELLS][x];
  assign o_dwd_dat[x*IPCELL_DWD_DWIDTH+:IPCELL_DWD_DWIDTH] = arr_dwd_dat[IPTILE_YCELLS][x];
end

for (genvar y = 0; y < IPTILE_YCELLS; y++) begin: Y
  assign arr_fwd_cmd[y][0] = i_fwd_cmd[y*IPCELL_FWD_CWIDTH+:IPCELL_FWD_CWIDTH];
  assign arr_fwd_dat[y][0] = i_fwd_dat[y*IPCELL_FWD_DWIDTH+:IPCELL_FWD_DWIDTH];
  assign arr_bwd_vld[y][IPTILE_XCELLS] = i_bwd_vld[y];
  assign arr_bwd_dat[y][IPTILE_XCELLS] = i_bwd_dat[y*IPCELL_BWD_DWIDTH+:IPCELL_BWD_DWIDTH];

  assign o_fwd_cmd[y*IPCELL_FWD_CWIDTH+:IPCELL_FWD_CWIDTH] = arr_fwd_cmd[y][IPTILE_XCELLS];
  assign o_fwd_dat[y*IPCELL_FWD_DWIDTH+:IPCELL_FWD_DWIDTH] = arr_fwd_dat[y][IPTILE_XCELLS];
  assign o_bwd_vld[y                                     ] = arr_bwd_vld[y][0];
  assign o_bwd_dat[y*IPCELL_BWD_DWIDTH+:IPCELL_BWD_DWIDTH] = arr_bwd_dat[y][0];

  for (genvar x = 0; x < IPTILE_XCELLS; x++) begin: X
    AIXH_MXC_INNER_PTILE_cell u_cell(
       .aixh_core_clk2x (aixh_core_clk2x        )
      ,.i_dwd_vld       (arr_dwd_vld[y  ][x  ]  )
      ,.i_dwd_dat       (arr_dwd_dat[y  ][x  ]  )
      ,.o_dwd_vld       (arr_dwd_vld[y+1][x  ]  )
      ,.o_dwd_dat       (arr_dwd_dat[y+1][x  ]  )
      ,.i_fwd_cmd       (arr_fwd_cmd[y  ][x  ]  )
      ,.i_fwd_dat       (arr_fwd_dat[y  ][x  ]  )
      ,.o_fwd_cmd       (arr_fwd_cmd[y  ][x+1]  )
      ,.o_fwd_dat       (arr_fwd_dat[y  ][x+1]  )
      ,.i_bwd_vld       (arr_bwd_vld[y  ][x+1]  )
      ,.i_bwd_dat       (arr_bwd_dat[y  ][x+1]  )
      ,.o_bwd_vld       (arr_bwd_vld[y  ][x  ]  )
      ,.o_bwd_dat       (arr_bwd_dat[y  ][x  ]  )
    );
  end
end

endmodule

`resetall
