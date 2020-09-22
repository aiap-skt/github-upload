//==============================================================================
// AIX-H Project
//
// Module: (MxConv) Left
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_left
(
   input  wire                                            aixh_core_clk
  ,input  wire                                            aixh_core_clk2x
  ,input  wire                                            aixh_core_rstn
  
  //
  // Vertical interface
  //
  // - CTRL
  ,input  wire                                            i_dwd_icsync 
  ,input  wire                                            i_dwd_ocsync 
  ,input  wire                                            i_dwd_wenable
  ,input  wire                                            i_dwd_renable
  ,input  wire [2                                   -1:0] i_dwd_rmode  
  ,input  wire [LPCELL_DWD_CWIDTH                   -1:0] i_dwd_cmd
  // - UPPER
  ,input  wire                                            i_dwd_vld
  ,input  wire [UPCELL_BWD_DWIDTH                   -1:0] i_dwd_dat

  //
  // Horizontal interface
  //
  // - LTC
  ,input  wire [LTC_SLICES                          -1:0] i_ltc_vld
  ,input  wire [LQTILE_COUNT * LQTILE_FWD_DWIDTH    -1:0] i_ltc_dat
  ,output wire [LQTILE_COUNT * LQTILE_FWD_DWIDTH    -1:0] o_ltc_dat
  // - INNER
  ,input  wire [IPTILE_YCOUNT * IPTILE_YCELLS       -1:0] i_bwd_vld
  ,input  wire [IPTILE_YCOUNT * IPTILE_BWD_DWIDTH   -1:0] i_bwd_dat
  ,output wire [IPTILE_YCOUNT * IPTILE_FWD_CWIDTH   -1:0] o_fwd_cmd
  ,output wire [IPTILE_YCOUNT * IPTILE_FWD_DWIDTH   -1:0] o_fwd_dat
);

localparam YREPEATER_MASK = IPTILE_YCOUNT'(`AIXH_MXC_IPTILE_YREPEATER_MASK);

wire                              arr_dwd_icsync [LQTILE_COUNT+1];
wire                              arr_dwd_ocsync [LQTILE_COUNT+1];
wire                              arr_dwd_wenable[LQTILE_COUNT+1];
wire                              arr_dwd_renable[LQTILE_COUNT+1];
wire [2                     -1:0] arr_dwd_rmode  [LQTILE_COUNT+1];
wire [64                    -1:0] arr_dwd_udata  [LQTILE_COUNT+1];
wire [64                    -1:0] arr_uwd_vdata  [LQTILE_COUNT+1];

wire [LPCELL_DWD_CWIDTH     -1:0] arr_dwd_cmd[IPTILE_YCOUNT+1];
wire                              arr_dwd_vld[IPTILE_YCOUNT+1];
wire [LPCELL_DWD_DWIDTH     -1:0] arr_dwd_dat[IPTILE_YCOUNT+1];

wire [IPTILE_YCOUNT * IPTILE_YCELLS     -1:0] p2q_bwd_vld;
wire [IPTILE_YCOUNT * LPTILE_BWO_DWIDTH -1:0] p2q_bwd_dat;
wire [IPTILE_YCOUNT * LPTILE_FWI_DWIDTH -1:0] q2p_fwd_dat;

wire [LQTILE_COUNT * LQTILE_CELLS       -1:0] t_ltc_vld;

// Expand per-slice LTC rvalid signal to per-LQCELL valid signal.
for (genvar s = 0; s < LTC_SLICES; s++) begin
  localparam DUP = LQTILE_COUNT * LQTILE_CELLS / LTC_SLICES;
  assign t_ltc_vld[s*DUP+:DUP] = {DUP{i_ltc_vld[s]}};
end

//
// Queue-Tiles
//

assign arr_dwd_icsync [0] = i_dwd_icsync;
assign arr_dwd_ocsync [0] = i_dwd_ocsync;
assign arr_dwd_wenable[0] = i_dwd_wenable;
assign arr_dwd_renable[0] = i_dwd_renable;
assign arr_dwd_rmode  [0] = i_dwd_rmode;
assign arr_dwd_udata  [0] = 64'd0;
assign arr_uwd_vdata  [LQTILE_COUNT] = 64'd0;

for (genvar y = 0; y < LQTILE_COUNT; y++) begin: QY
  AIXH_MXC_LEFT_qtile u_qtile(
     .aixh_core_clk       (aixh_core_clk                                      )
    ,.aixh_core_clk2x     (aixh_core_clk2x                                    )
    ,.aixh_core_rstn      (aixh_core_rstn                                     )

    ,.i_icsync            (arr_dwd_icsync[y]                                  )
    ,.i_ocsync            (arr_dwd_ocsync[y]                                  )
    ,.i_iwenable          (arr_dwd_wenable[y]                                 )
    ,.i_irenable          (arr_dwd_renable[y]                                 )
    ,.i_irmode            (arr_dwd_rmode[y]                                   )
    ,.i_iudata            (arr_dwd_udata[y]                                   )
    ,.i_ivdata            (arr_uwd_vdata[y+1]                                 )
    ,.o_icsync            (arr_dwd_icsync[y+1]                                )
    ,.o_ocsync            (arr_dwd_ocsync[y+1]                                )
    ,.o_iwenable          (arr_dwd_wenable[y+1]                               )
    ,.o_irenable          (arr_dwd_renable[y+1]                               )
    ,.o_irmode            (arr_dwd_rmode[y+1]                                 )
    ,.o_iudata            (arr_dwd_udata[y+1]                                 )
    ,.o_ivdata            (arr_uwd_vdata[y]                                   )

    ,.i_ltc_vld           (t_ltc_vld[y*LQTILE_CELLS+:LQTILE_CELLS]            )
    ,.i_ltc_dat           (i_ltc_dat[y*LQTILE_FWD_DWIDTH+:LQTILE_FWD_DWIDTH]  )
    ,.o_ltc_dat           (o_ltc_dat[y*LQTILE_BWD_DWIDTH+:LQTILE_BWD_DWIDTH]  )

    ,.i_lpt_vld           (p2q_bwd_vld[y*LQTILE_CELLS*2+:LQTILE_CELLS*2]      )
    ,.i_lpt_dat           (p2q_bwd_dat[y*LQTILE_FWD_DWIDTH+:LQTILE_FWD_DWIDTH])
    ,.o_lpt_dat           (q2p_fwd_dat[y*LQTILE_FWD_DWIDTH+:LQTILE_FWD_DWIDTH])
  );
end

//
// Processing-Tiles
//

assign arr_dwd_cmd[0] = i_dwd_cmd;
assign arr_dwd_vld[0] = i_dwd_vld;
assign arr_dwd_dat[0] = i_dwd_dat;

for (genvar y = 0; y < IPTILE_YCOUNT; y++) begin: PY
  wire [LPCELL_DWD_CWIDTH     -1:0] pti_dwd_cmd;
  wire                              pti_dwd_vld;
  wire [LPCELL_DWD_DWIDTH     -1:0] pti_dwd_dat;

  AIXH_MXC_LEFT_ptile
`ifndef AIXH_MXC_LPTILE_IDENTICAL
  #( .TILE_INDEX          (y                                                 ))
`endif  
  u_ptile(
     .aixh_core_clk2x     (aixh_core_clk2x                                    )

    ,.i_lqt_dat           (q2p_fwd_dat[y*LPTILE_FWI_DWIDTH+:LPTILE_FWI_DWIDTH])
    ,.o_lqt_vld           (p2q_bwd_vld[y*IPTILE_YCELLS+:IPTILE_YCELLS]        )
    ,.o_lqt_dat           (p2q_bwd_dat[y*LPTILE_BWO_DWIDTH+:LPTILE_BWO_DWIDTH])

    ,.i_lpt_cmd           (pti_dwd_cmd                                        )
    ,.i_lpt_vld           (pti_dwd_vld                                        )
    ,.i_lpt_dat           (pti_dwd_dat                                        )
    ,.o_lpt_cmd           (arr_dwd_cmd[y+1]                                   )
    ,.o_lpt_vld           (arr_dwd_vld[y+1]                                   )
    ,.o_lpt_dat           (arr_dwd_dat[y+1]                                   )

    ,.i_ipt_vld           (i_bwd_vld[y*IPTILE_YCELLS+:IPTILE_YCELLS]          )
    ,.i_ipt_dat           (i_bwd_dat[y*IPTILE_BWD_DWIDTH+:IPTILE_BWD_DWIDTH]  )
    ,.o_ipt_cmd           (o_fwd_cmd[y*IPTILE_FWD_CWIDTH+:IPTILE_FWD_CWIDTH]  )
    ,.o_ipt_dat           (o_fwd_dat[y*IPTILE_FWD_DWIDTH+:IPTILE_FWD_DWIDTH]  )
  );

  if (!YREPEATER_MASK[y]) begin
    assign pti_dwd_cmd = arr_dwd_cmd[y];
    assign pti_dwd_vld = arr_dwd_vld[y];
    assign pti_dwd_dat = arr_dwd_dat[y];
  end else begin
    AIXH_MXC_LEFT_repeater u_repeater(
       .aixh_core_clk2x   (aixh_core_clk2x                                    )
      ,.i_dwd_cmd         (arr_dwd_cmd[y]                                     )
      ,.i_dwd_vld         (arr_dwd_vld[y]                                     )
      ,.i_dwd_dat         (arr_dwd_dat[y]                                     )
      ,.o_dwd_cmd         (pti_dwd_cmd                                        )
      ,.o_dwd_vld         (pti_dwd_vld                                        )
      ,.o_dwd_dat         (pti_dwd_dat                                        )
    );
  end
end

endmodule
`resetall
