//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Upper) Queue-Tile
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_UPPER_qtile
#(
  TILE_INDEX = 0
) (
   input  wire                                            aixh_core_clk
  ,input  wire                                            aixh_core_clk2x
  
  // Horizontal control interface
  ,input  wire                                            i_csync
  ,output wire                                            o_csync

  // UTC interface
  ,input  wire [UQTILE_CELLS                        -1:0] i_utc_vld
  ,input  wire [UQTILE_CELLS * UQCELL_DWD_DWIDTH    -1:0] i_utc_dat
  // UPCELL interface
  ,output wire [UQTILE_CELLS * UQCELL_DWD_DWIDTH    -1:0] o_upt_dat
);

wire arr_csync[UQTILE_CELLS+1];

assign arr_csync[0] = i_csync;
assign o_csync = arr_csync[UQTILE_CELLS];

for (genvar x = 0; x < UQTILE_CELLS; x++) begin: X
  localparam SKEW_DEPTH = x + 1;
  
  reg r_csync;
  assign arr_csync[x+1] = r_csync;
  always_ff @(posedge aixh_core_clk2x) r_csync <= ~arr_csync[x];

  AIXH_MXC_UPPER_QTILE_cell #(
     .SKEW_DEPTH          (SKEW_DEPTH                                         )
  ) u_cell (
     .aixh_core_clk       (aixh_core_clk                                      )
    ,.aixh_core_clk2x     (aixh_core_clk2x                                    )
    ,.i_csync             (r_csync                                            )
    ,.i_senable           (i_utc_vld[x]                                       )
    ,.i_sdata             (i_utc_dat[x*UQCELL_DWD_DWIDTH+:UQCELL_DWD_DWIDTH]  )
    ,.o_rdata             (o_upt_dat[x*UQCELL_DWD_DWIDTH+:UQCELL_DWD_DWIDTH]  )
   );
end

endmodule
`resetall
