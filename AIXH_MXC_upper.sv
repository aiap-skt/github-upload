//==============================================================================
// AIX-H Project
//
// Module: (MxConv) Upper
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_upper
(
   input  wire                                            aixh_core_clk
  ,input  wire                                            aixh_core_clk2x

  //
  // Vertical interface
  //
  // - UTC
  ,input  wire [UTC_SLICES                          -1:0] i_utc_vld
  ,input  wire [UQTILE_COUNT * UQTILE_DWD_DWIDTH    -1:0] i_utc_dat
  // - INNER
  ,output wire [IPTILE_XCOUNT * IPTILE_XCELLS*2     -1:0] o_dwd_vld
  ,output wire [IPTILE_XCOUNT * IPTILE_DWD_DWIDTH   -1:0] o_dwd_dat

  //
  // Horizontal interface
  //
  // - CTRL
  ,input  wire                                            i_fwd_csync
  ,input  wire [UPCELL_FWD_CWIDTH                   -1:0] i_fwd_cmd
  // - LEFT
  ,output wire                                            o_bwd_vld 
  ,output wire [UPCELL_BWD_DWIDTH                   -1:0] o_bwd_dat
);

localparam XREPEATER_MASK = IPTILE_XCOUNT'(`AIXH_MXC_IPTILE_XREPEATER_MASK);

wire [`AIXH_MXC_WIDTH*64    -1:0] q2p_dwd_dat;
wire [UQTILE_COUNT+1        -1:0] arr_fwd_csync;
wire [UPCELL_FWD_CWIDTH     -1:0] arr_fwd_cmd[IPTILE_XCOUNT];
wire                              arr_bwd_vld[IPTILE_XCOUNT];
wire [UPCELL_BWD_DWIDTH     -1:0] arr_bwd_dat[IPTILE_XCOUNT];

wire [UQTILE_COUNT * UQTILE_CELLS       -1:0] t_utc_vld;

// Expand per-slice UTC rvalid signal to per-UQCELL valid signal.
for (genvar s = 0; s < UTC_SLICES; s++) begin
  localparam DUP = UQTILE_COUNT * UQTILE_CELLS / UTC_SLICES;
  assign t_utc_vld[s*DUP+:DUP] = {DUP{i_utc_vld[s]}};
end


for (genvar x = 0; x < UQTILE_COUNT; x++) begin: QX
  AIXH_MXC_UPPER_qtile #(
     .TILE_INDEX          (x                                                  )
  ) u_qtile(
     .aixh_core_clk       (aixh_core_clk                                      )
    ,.aixh_core_clk2x     (aixh_core_clk2x                                    )
    ,.i_csync             (arr_fwd_csync[x]                                   )
    ,.o_csync             (arr_fwd_csync[x+1]                                 )
    ,.i_utc_vld           (t_utc_vld[x*UQTILE_CELLS+:UQTILE_CELLS]            )
    ,.i_utc_dat           (i_utc_dat[x*UQTILE_DWD_DWIDTH+:UQTILE_DWD_DWIDTH]  )
    ,.o_upt_dat           (q2p_dwd_dat[x*UQTILE_DWD_DWIDTH+:UQTILE_DWD_DWIDTH])
   );
end

assign arr_fwd_csync[0] = i_fwd_csync;


for (genvar x = 0; x < IPTILE_XCOUNT; x++) begin: PX
  wire [UPCELL_FWD_CWIDTH     -1:0] pti_fwd_cmd;
  wire                              pti_bwd_vld;
  wire [UPCELL_BWD_DWIDTH     -1:0] pti_bwd_dat;
  wire [UPCELL_FWD_CWIDTH     -1:0] pto_fwd_cmd;
  wire                              pto_bwd_vld;
  wire [UPCELL_BWD_DWIDTH     -1:0] pto_bwd_dat;

  AIXH_MXC_UPPER_ptile
`ifndef AIXH_MXC_UPTILE_IDENTICAL
  #( .TILE_INDEX          (x                                                 ))
`endif  
  u_ptile(
     .aixh_core_clk2x     (aixh_core_clk2x                                    )
    ,.i_uqt_dat           (q2p_dwd_dat[x*UPTILE_DWI_DWIDTH+:UPTILE_DWI_DWIDTH])
    ,.o_ipt_vld           (o_dwd_vld[x*IPTILE_XCELLS*2+:IPTILE_XCELLS*2]      )
    ,.o_ipt_dat           (o_dwd_dat[x*IPTILE_DWD_DWIDTH+:IPTILE_DWD_DWIDTH]  )
    ,.i_upt_cmd           (pti_fwd_cmd                                        )
    ,.o_upt_cmd           (pto_fwd_cmd                                        )
    ,.i_upt_vld           (pti_bwd_vld                                        )
    ,.i_upt_dat           (pti_bwd_dat                                        )
    ,.o_upt_vld           (pto_bwd_vld                                        )
    ,.o_upt_dat           (pto_bwd_dat                                        )
  );

  if (!XREPEATER_MASK[x]) begin
    assign pti_fwd_cmd = arr_fwd_cmd[x];
    assign arr_bwd_vld[x] = pto_bwd_vld;
    assign arr_bwd_dat[x] = pto_bwd_dat;
  end else begin
    AIXH_MXC_UPPER_repeater u_repeater(
       .aixh_core_clk2x   (aixh_core_clk2x                                    )
      ,.i_fwd_cmd         (arr_fwd_cmd[x]                                     )
      ,.o_fwd_cmd         (pti_fwd_cmd                                        )
      ,.i_bwd_vld         (pto_bwd_vld                                        )
      ,.i_bwd_dat         (pto_bwd_dat                                        )
      ,.o_bwd_vld         (arr_bwd_vld[x]                                     )
      ,.o_bwd_dat         (arr_bwd_dat[x]                                     )
    );
  end

  if (x < IPTILE_XCOUNT-1) begin
    assign arr_fwd_cmd[x+1] = pto_fwd_cmd;
    assign pti_bwd_vld = arr_bwd_vld[x+1];
    assign pti_bwd_dat = arr_bwd_dat[x+1];
  end else begin
    assign pti_bwd_vld = 1'b0;
    assign pti_bwd_dat = UPCELL_BWD_DWIDTH'(0);
  end
end

assign arr_fwd_cmd[0] = i_fwd_cmd;
assign o_bwd_vld = arr_bwd_vld[0];
assign o_bwd_dat = arr_bwd_dat[0];

endmodule
`resetall
