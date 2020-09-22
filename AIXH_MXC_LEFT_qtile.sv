//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Left) Queue-Tile
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_LEFT_qtile
#(
  TILE_INDEX = 0
) (
   input  wire                                            aixh_core_clk
  ,input  wire                                            aixh_core_clk2x
  ,input  wire                                            aixh_core_rstn
  // Vertical interface
  ,input  wire                                            i_icsync
  ,input  wire                                            i_ocsync
  ,input  wire                                            i_iwenable
  ,input  wire                                            i_irenable
  ,input  wire [2                                   -1:0] i_irmode
  ,input  wire [64                                  -1:0] i_iudata
  ,input  wire [64                                  -1:0] i_ivdata
  ,output wire                                            o_icsync
  ,output wire                                            o_ocsync
  ,output wire                                            o_iwenable
  ,output wire                                            o_irenable
  ,output wire [2                                   -1:0] o_irmode
  ,output wire [64                                  -1:0] o_iudata
  ,output wire [64                                  -1:0] o_ivdata
  // LTC interface
  ,input  wire [LQTILE_CELLS                        -1:0] i_ltc_vld
  ,input  wire [LQTILE_CELLS * LQCELL_FWD_DWIDTH    -1:0] i_ltc_dat
  ,output wire [LQTILE_CELLS * LQCELL_FWD_DWIDTH    -1:0] o_ltc_dat
  // LPCELL interface
  ,input  wire [LQTILE_CELLS * 2                    -1:0] i_lpt_vld
  ,input  wire [LQTILE_CELLS * LQCELL_BWD_DWIDTH    -1:0] i_lpt_dat
  ,output wire [LQTILE_CELLS * LQCELL_FWD_DWIDTH    -1:0] o_lpt_dat
);

wire                  arr_icsync  [LQTILE_CELLS+1];
wire                  arr_ocsync  [LQTILE_CELLS+1];
wire                  arr_iwenable[LQTILE_CELLS+1];
wire                  arr_irenable[LQTILE_CELLS+1];
wire [2         -1:0] arr_irmode  [LQTILE_CELLS+1];
wire [64        -1:0] arr_iudata  [LQTILE_CELLS+1];
wire [64        -1:0] arr_ivdata  [LQTILE_CELLS+1];

assign arr_icsync  [0]            = i_icsync;
assign arr_ocsync  [0]            = i_ocsync;
assign arr_iwenable[0]            = i_iwenable;
assign arr_irenable[0]            = i_irenable;
assign arr_irmode  [0]            = i_irmode;
assign arr_iudata  [0]            = i_iudata;
assign arr_ivdata  [LQTILE_CELLS] = i_ivdata;
assign o_icsync   = arr_icsync  [LQTILE_CELLS];
assign o_ocsync   = arr_ocsync  [LQTILE_CELLS];
assign o_iwenable = arr_iwenable[LQTILE_CELLS];
assign o_irenable = arr_irenable[LQTILE_CELLS];
assign o_irmode   = arr_irmode  [LQTILE_CELLS];
assign o_iudata   = arr_iudata  [LQTILE_CELLS];
assign o_ivdata   = arr_ivdata  [0];

for (genvar y = 0; y < LQTILE_CELLS; y++) begin: Y
  localparam SKEW_DEPTH = y + 1;
  localparam DESKEW_DEPTH = LQTILE_CELLS - y;
  
  reg r_icsync;
  reg r_ocsync;
  assign arr_icsync[y+1] = r_icsync;
  assign arr_ocsync[y+1] = r_ocsync;
  always_ff @(posedge aixh_core_clk2x) r_icsync <= ~arr_icsync[y];
  always_ff @(posedge aixh_core_clk2x) r_ocsync <= ~arr_ocsync[y];

  AIXH_MXC_LEFT_QTILE_iscell #(
     .SKEW_DEPTH          (SKEW_DEPTH                                         )
  ) u_iscell (
     .aixh_core_clk       (aixh_core_clk                                      )
    ,.aixh_core_clk2x     (aixh_core_clk2x                                    )
    ,.aixh_core_rstn      (aixh_core_rstn                                     )
    ,.i_csync             (r_icsync                                           )
    ,.i_senable           (i_ltc_vld   [y]                                    )
    ,.i_wenable           (arr_iwenable[y]                                    )
    ,.i_renable           (arr_irenable[y]                                    )
    ,.i_rmode             (arr_irmode  [y]                                    )
    ,.o_wenable           (arr_iwenable[y+1]                                  )
    ,.o_renable           (arr_irenable[y+1]                                  )
    ,.o_rmode             (arr_irmode  [y+1]                                  )
    ,.i_udata             (arr_iudata  [y]                                    )
    ,.i_vdata             (arr_ivdata  [y+1]                                  )
    ,.o_udata             (arr_iudata  [y+1]                                  )
    ,.o_vdata             (arr_ivdata  [y]                                    )
    ,.i_sdata             (i_ltc_dat[y*LQCELL_FWD_DWIDTH+:LQCELL_FWD_DWIDTH]  )
    ,.o_rdata             (o_lpt_dat[y*LQCELL_FWD_DWIDTH+:LQCELL_FWD_DWIDTH]  )
  );

  AIXH_MXC_LEFT_QTILE_oscell #(
     .DESKEW_DEPTH        (DESKEW_DEPTH                                       )
  ) u_oscell (
     .aixh_core_clk       (aixh_core_clk                                      )
    ,.aixh_core_clk2x     (aixh_core_clk2x                                    )
    ,.i_csync             (r_ocsync                                           )
    ,.i_wenable           (i_lpt_vld[y*2] | i_lpt_vld[y*2+1]                  )
    ,.i_wdata             (i_lpt_dat[y*LQCELL_FWD_DWIDTH+:LQCELL_FWD_DWIDTH]  )
    ,.o_rdata             (o_ltc_dat[y*LQCELL_FWD_DWIDTH+:LQCELL_FWD_DWIDTH]  )
   );
end

endmodule
`resetall
