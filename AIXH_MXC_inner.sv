//==============================================================================
// AIX-H Project
//
// Module: (MxConv) Inner
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_inner
(
   input  wire                                            aixh_core_clk2x

   // Vertical interface
  ,input  wire [IPTILE_XCOUNT * IPTILE_XCELLS*2     -1:0] i_dwd_vld
  ,input  wire [IPTILE_XCOUNT * IPTILE_DWD_DWIDTH   -1:0] i_dwd_dat

  // Horizontal interface
  ,input  wire [IPTILE_YCOUNT * IPTILE_FWD_CWIDTH   -1:0] i_fwd_cmd
  ,input  wire [IPTILE_YCOUNT * IPTILE_FWD_DWIDTH   -1:0] i_fwd_dat

  ,output wire [IPTILE_YCOUNT * IPTILE_YCELLS       -1:0] o_bwd_vld
  ,output wire [IPTILE_YCOUNT * IPTILE_BWD_DWIDTH   -1:0] o_bwd_dat
);

localparam YREPEATER_MASK = IPTILE_YCOUNT'(`AIXH_MXC_IPTILE_YREPEATER_MASK);
localparam XREPEATER_MASK = IPTILE_XCOUNT'(`AIXH_MXC_IPTILE_XREPEATER_MASK);

wire [IPTILE_XCELLS*2     -1:0] arr_dwd_vld[IPTILE_YCOUNT][IPTILE_XCOUNT];
wire [IPTILE_DWD_DWIDTH   -1:0] arr_dwd_dat[IPTILE_YCOUNT][IPTILE_XCOUNT];
wire [IPTILE_FWD_CWIDTH   -1:0] arr_fwd_cmd[IPTILE_YCOUNT][IPTILE_XCOUNT];
wire [IPTILE_FWD_DWIDTH   -1:0] arr_fwd_dat[IPTILE_YCOUNT][IPTILE_XCOUNT];
wire [IPTILE_YCELLS       -1:0] arr_bwd_vld[IPTILE_YCOUNT][IPTILE_XCOUNT];
wire [IPTILE_BWD_DWIDTH   -1:0] arr_bwd_dat[IPTILE_YCOUNT][IPTILE_XCOUNT];


for (genvar y = 0; y < IPTILE_YCOUNT; y++) begin: Y
  for (genvar x = 0; x < IPTILE_XCOUNT; x++) begin: X
    wire [IPTILE_XCELLS*2     -1:0] pti_dwd_vld;
    wire [IPTILE_DWD_DWIDTH   -1:0] pti_dwd_dat;
    wire [IPTILE_XCELLS*2     -1:0] pto_dwd_vld;
    wire [IPTILE_DWD_DWIDTH   -1:0] pto_dwd_dat;

    wire [IPTILE_FWD_CWIDTH   -1:0] pti_fwd_cmd;
    wire [IPTILE_FWD_DWIDTH   -1:0] pti_fwd_dat;
    wire [IPTILE_FWD_CWIDTH   -1:0] pto_fwd_cmd;
    wire [IPTILE_FWD_DWIDTH   -1:0] pto_fwd_dat;

    wire [IPTILE_YCELLS       -1:0] pti_bwd_vld;
    wire [IPTILE_BWD_DWIDTH   -1:0] pti_bwd_dat;
    wire [IPTILE_YCELLS       -1:0] pto_bwd_vld;
    wire [IPTILE_BWD_DWIDTH   -1:0] pto_bwd_dat;

    AIXH_MXC_INNER_ptile u_ptile(
       .aixh_core_clk2x   (aixh_core_clk2x                                    )
      ,.i_dwd_vld         (pti_dwd_vld                                        )
      ,.i_dwd_dat         (pti_dwd_dat                                        )
      ,.o_dwd_vld         (pto_dwd_vld                                        )
      ,.o_dwd_dat         (pto_dwd_dat                                        )
      ,.i_fwd_cmd         (pti_fwd_cmd                                        )
      ,.i_fwd_dat         (pti_fwd_dat                                        )
      ,.o_fwd_cmd         (pto_fwd_cmd                                        )
      ,.o_fwd_dat         (pto_fwd_dat                                        )
      ,.i_bwd_vld         (pti_bwd_vld                                        )
      ,.i_bwd_dat         (pti_bwd_dat                                        )
      ,.o_bwd_vld         (pto_bwd_vld                                        )
      ,.o_bwd_dat         (pto_bwd_dat                                        )
    );

    if (!YREPEATER_MASK[y]) begin
      assign pti_dwd_vld = arr_dwd_vld[y][x];
      assign pti_dwd_dat = arr_dwd_dat[y][x];
    end else begin
      AIXH_MXC_INNER_yrepeater u_yrepeater(
         .aixh_core_clk2x   (aixh_core_clk2x                                  )
        ,.i_dwd_vld         (arr_dwd_vld[y][x]                                )
        ,.i_dwd_dat         (arr_dwd_dat[y][x]                                )
        ,.o_dwd_vld         (pti_dwd_vld                                      )
        ,.o_dwd_dat         (pti_dwd_dat                                      )
      );
    end

    if (!XREPEATER_MASK[x]) begin
      assign pti_fwd_cmd = arr_fwd_cmd[y][x];
      assign pti_fwd_dat = arr_fwd_dat[y][x];
      assign arr_bwd_vld[y][x] = pto_bwd_vld;
      assign arr_bwd_dat[y][x] = pto_bwd_dat;
    end else begin
      AIXH_MXC_INNER_xrepeater u_xrepeater(
         .aixh_core_clk2x   (aixh_core_clk2x                                  )
        ,.i_fwd_cmd         (arr_fwd_cmd[y][x]                                )
        ,.i_fwd_dat         (arr_fwd_dat[y][x]                                )
        ,.o_fwd_cmd         (pti_fwd_cmd                                      )
        ,.o_fwd_dat         (pti_fwd_dat                                      )
        ,.i_bwd_vld         (pto_bwd_vld                                      )
        ,.i_bwd_dat         (pto_bwd_dat                                      )
        ,.o_bwd_vld         (arr_bwd_vld[y][x]                                )
        ,.o_bwd_dat         (arr_bwd_dat[y][x]                                )
      );
    end
    
    if (y < IPTILE_YCOUNT-1) begin
      assign arr_dwd_vld[y+1][x] = pto_dwd_vld;
      assign arr_dwd_dat[y+1][x] = pto_dwd_dat;
    end
    
    if (x < IPTILE_XCOUNT-1) begin
      assign arr_fwd_cmd[y][x+1] = pto_fwd_cmd;
      assign arr_fwd_dat[y][x+1] = pto_fwd_dat;
      assign pti_bwd_vld = arr_bwd_vld[y][x+1];
      assign pti_bwd_dat = arr_bwd_dat[y][x+1];
    end else begin
      assign pti_bwd_vld = IPTILE_YCELLS'(0);
      assign pti_bwd_dat = IPTILE_BWD_DWIDTH'(0);
    end

    if (y == 0) begin
      assign arr_dwd_vld[0][x] = i_dwd_vld[IPTILE_XCELLS*2  *x+:IPTILE_XCELLS*2  ];
      assign arr_dwd_dat[0][x] = i_dwd_dat[IPTILE_DWD_DWIDTH*x+:IPTILE_DWD_DWIDTH];
    end

    if (x == 0) begin
      assign arr_fwd_cmd[y][0] = i_fwd_cmd[IPTILE_FWD_CWIDTH*y+:IPTILE_FWD_CWIDTH];
      assign arr_fwd_dat[y][0] = i_fwd_dat[IPTILE_FWD_DWIDTH*y+:IPTILE_FWD_DWIDTH];
      assign o_bwd_vld[IPTILE_YCELLS    *y+:IPTILE_YCELLS    ] = arr_bwd_vld[y][0];
      assign o_bwd_dat[IPTILE_BWD_DWIDTH*y+:IPTILE_BWD_DWIDTH] = arr_bwd_dat[y][0];
    end
  end // y
end // x

endmodule
`resetall
