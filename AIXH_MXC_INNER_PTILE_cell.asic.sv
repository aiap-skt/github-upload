//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Inner-Processing-Tile) Cell for ASIC
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

`ifdef AIXH_TARGET_ASIC
import AIXH_MXC_pkg::*;
module AIXH_MXC_INNER_PTILE_cell
(
   input  wire                              aixh_core_clk2x

  // Vertical interface
  ,input  wire [2                     -1:0] i_dwd_vld
  ,input  wire [IPCELL_DWD_DWIDTH     -1:0] i_dwd_dat
  ,output reg  [2                     -1:0] o_dwd_vld
  ,output reg  [IPCELL_DWD_DWIDTH     -1:0] o_dwd_dat

  // Horizontal interface
  ,input  wire [IPCELL_FWD_CWIDTH     -1:0] i_fwd_cmd
  ,input  wire [IPCELL_FWD_DWIDTH     -1:0] i_fwd_dat
  ,output reg  [IPCELL_FWD_CWIDTH     -1:0] o_fwd_cmd
  ,output reg  [IPCELL_FWD_DWIDTH     -1:0] o_fwd_dat

  ,input  wire                              i_bwd_vld
  ,input  wire [IPCELL_BWD_DWIDTH     -1:0] i_bwd_dat
  ,output reg                               o_bwd_vld
  ,output reg  [IPCELL_BWD_DWIDTH     -1:0] o_bwd_dat
);

IPCELL_Command            i_cmd_raw;
IPCELL_Command            i_cmd_gated;
IPCELL_Command            r_cmd;


assign i_cmd_raw = i_fwd_cmd;
assign r_cmd     = o_fwd_cmd;

// Gate command signals
always_comb begin
  i_cmd_gated            = i_cmd_raw;
  i_cmd_gated.mul_enable = i_cmd_raw.mul_enable & {IPCELL_HEIGHT{i_dwd_vld[0]}};
  i_cmd_gated.acc_enable = i_cmd_raw.acc_enable & {IPCELL_HEIGHT{i_dwd_vld[0]}};
  i_cmd_gated.acc_afresh = i_cmd_raw.acc_afresh & i_dwd_vld[0];
  i_cmd_gated.drain_req0 = i_cmd_raw.drain_req0 & i_dwd_vld[1];
  i_cmd_gated.drain_req1 = i_cmd_raw.drain_req1 & i_dwd_vld[1];
end

// Inter-CELL pipeline
always_ff @(posedge aixh_core_clk2x) begin
  o_dwd_vld <= i_dwd_vld;
  o_fwd_cmd <= i_cmd_gated;

  if (i_dwd_vld[0]) begin
    o_dwd_dat <= i_dwd_dat;
    o_fwd_dat <= i_fwd_dat;
  end
end


// PE instances
logic [48         -1:0] zdata00;
logic [48         -1:0] zdata01;

AIXH_MXC_INNER_PTILE_CELL_pe u_pe00(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.mul_enable          (r_cmd.mul_enable[0]  )
  ,.acc_enable          (r_cmd.acc_enable[0]  )
  ,.acc_afresh          (r_cmd.acc_afresh     )
  ,.mul_mode            (r_cmd.mul_mode       )
  ,.acc_mode            (r_cmd.acc_mode       )
  ,.xdata               (o_fwd_dat[0*32+:32]  )
  ,.ydata               (o_dwd_dat[0*32+:32]  )
  ,.zdata               (zdata00              )
);

AIXH_MXC_INNER_PTILE_CELL_pe u_pe01(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.mul_enable          (r_cmd.mul_enable[0]  )
  ,.acc_enable          (r_cmd.acc_enable[0]  )
  ,.acc_afresh          (r_cmd.acc_afresh     )
  ,.mul_mode            (r_cmd.mul_mode       )
  ,.acc_mode            (r_cmd.acc_mode       )
  ,.xdata               (o_fwd_dat[0*32+:32]  )
  ,.ydata               (o_dwd_dat[1*32+:32]  )
  ,.zdata               (zdata01              )
);

//==============================================================================
`ifdef AIXH_MXC_IPCELL_1X2 //                                        1x2 PE Cell
//==============================================================================
// Drain
always_ff @(posedge aixh_core_clk2x)
  if (r_cmd.drain_req1 | i_bwd_vld) begin
    o_bwd_vld <= 1'b1;
    o_bwd_dat <= i_bwd_vld        ? i_bwd_dat
               : r_cmd.drain_req0 ? zdata00
               :                    zdata01;
  end else begin
    o_bwd_vld <= 1'b0;
  end
//==============================================================================
`elsif AIXH_MXC_IPCELL_2X2 //                                        2x2 PE Cell
//==============================================================================
// PE instances
logic [48         -1:0] zdata10;
logic [48         -1:0] zdata11;

AIXH_MXC_INNER_PTILE_CELL_pe u_pe10(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.mul_enable          (r_cmd.mul_enable[1]  )
  ,.acc_enable          (r_cmd.acc_enable[1]  )
  ,.acc_afresh          (r_cmd.acc_afresh     )
  ,.mul_mode            (r_cmd.mul_mode       )
  ,.acc_mode            (r_cmd.acc_mode       )
  ,.xdata               (o_fwd_dat[1*32+:32]  )
  ,.ydata               (o_dwd_dat[0*32+:32]  )
  ,.zdata               (zdata10              )
);

AIXH_MXC_INNER_PTILE_CELL_pe u_pe11(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.mul_enable          (r_cmd.mul_enable[1]  )
  ,.acc_enable          (r_cmd.acc_enable[1]  )
  ,.acc_afresh          (r_cmd.acc_afresh     )
  ,.mul_mode            (r_cmd.mul_mode       )
  ,.acc_mode            (r_cmd.acc_mode       )
  ,.xdata               (o_fwd_dat[1*32+:32]  )
  ,.ydata               (o_dwd_dat[1*32+:32]  )
  ,.zdata               (zdata11              )
);

// Drain
always_ff @(posedge aixh_core_clk2x)
  if (r_cmd.drain_req1 | i_bwd_vld) begin
    o_bwd_vld <= 1'b1;
    o_bwd_dat <= i_bwd_vld        ? i_bwd_dat
               : r_cmd.drain_req0 ? {zdata10, zdata00}
               :                    {zdata11, zdata01};
  end else begin
    o_bwd_vld <= 1'b0;
  end

//==============================================================================
`else
  `error "Invalid PE Grouping"
`endif
//==============================================================================
endmodule

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
// mul_mode[0] == 0: INT4
//             == 1: INT8
// mul_mode[1]: use saved carry for U
// mul_mode[2]: use saved carry for V
// mul_mode[3]: write carry-out for U
// mul_mode[4]: write carry-out for V
// acc_mode[1:0] == 0: << 0
//               == 1: << 8
//               == 2: << 16
module AIXH_MXC_INNER_PTILE_CELL_pe
(
   input  wire                    aixh_core_clk2x
  ,input  wire                    mul_enable
  ,input  wire                    acc_enable
  ,input  wire                    acc_afresh
  ,input  wire [5           -1:0] mul_mode
  ,input  wire [2           -1:0] acc_mode
  ,input  wire [32          -1:0] xdata
  ,input  wire [32          -1:0] ydata
  ,output wire [48          -1:0] zdata
);
// synopsys dc_tcl_script_begin
// set_optimize_registers -check_design -print_critical_loop
// synopsys dc_tcl_script_end

localparam MSTAGES = `AIXH_MXC_IPE_STAGES - 1;

logic [4          -1:0] x0;
logic [4          -1:0] x1;
logic [4          -1:0] x2;
logic [4          -1:0] x3;
logic [4          -1:0] x4;
logic [4          -1:0] x5;
logic [4          -1:0] x6;
logic [4          -1:0] x7;
logic [4          -1:0] y0;
logic [4          -1:0] y1;
logic [4          -1:0] y2;
logic [4          -1:0] y3;
logic [4          -1:0] y4;
logic [4          -1:0] y5;
logic [4          -1:0] y6;
logic [4          -1:0] y7;

logic [4          -1:0] u0l_sum;
logic [4          -1:0] u0h_sum;
logic [4          -1:0] v0l_sum;
logic [4          -1:0] v0h_sum;
logic [4          -1:0] u1l_sum;
logic [4          -1:0] u1h_sum;
logic [4          -1:0] v1l_sum;
logic [4          -1:0] v1h_sum;
logic                   u0l_ci, u0l_co;
logic                   u0h_ci, u0h_co;
logic                   v0l_ci, v0l_co;
logic                   v0h_ci, v0h_co;
logic                   u1l_ci, u1l_co;
logic                   u1h_ci, u1h_co;
logic                   v1l_ci, v1l_co;
logic                   v1h_ci, v1h_co;
logic                   u0h_co_r;
logic                   v0h_co_r;
logic                   u1h_co_r;
logic                   v1h_co_r;

logic [5          -1:0] m2_u;
logic [5          -1:0] m2_v;
logic [10         -1:0] m2_p;
logic [5          -1:0] m3_u;
logic [5          -1:0] m3_v;
logic [10         -1:0] m3_p;
logic [11         -1:0] m_psum;

logic [4          -1:0] b0_code0;
logic [4          -1:0] b0_code1;
logic [4          -1:0] b0_code2;
logic [9          -1:0] b0_idat;
logic [11         -1:0] b0_adat;
logic [11         -1:0] b0_odat0;
logic [11         -1:0] b0_odat1;
logic [11         -1:0] b0_odat2;
logic                   b0_oinv0;
logic                   b0_oinv1;
logic                   b0_oinv2;

logic [4          -1:0] b1_code0;
logic [4          -1:0] b1_code1;
logic [4          -1:0] b1_code2;
logic [9          -1:0] b1_idat;
logic [11         -1:0] b1_adat;
logic [11         -1:0] b1_odat0;
logic [11         -1:0] b1_odat1;
logic [11         -1:0] b1_odat2;
logic                   b1_oinv0;
logic                   b1_oinv1;
logic                   b1_oinv2;

logic [19         -1:0] pipe[MSTAGES];
logic [19*9       -1:0] z_ins;
logic [19         -1:0] z_sum;
logic [19         -1:0] z_sum_r;
logic [35         -1:0] z_sft;
logic [48         -1:0] z_acc;
logic [48         -1:0] z_acc_nx;
logic                   z_update1;
logic                   z_update2;
logic                   z_update3;


assign {x7, x6, x5, x4, x3, x2, x1, x0} = xdata;
assign {y7, y6, y5, y4, y3, y2, y1, y0} = ydata;

wire m_int8  = mul_mode[0];
wire u_cywen = mul_mode[1];
wire v_cywen = mul_mode[2];
wire u_cyren = mul_mode[3];
wire v_cyren = mul_mode[4];

assign u0l_ci = u_cyren & u0h_co_r;
assign v0l_ci = v_cyren & v0h_co_r;
assign u1l_ci = u_cyren & u1h_co_r;
assign v1l_ci = v_cyren & v1h_co_r;
assign u0h_ci = m_int8 & u0l_co; 
assign v0h_ci = m_int8 & v0l_co;
assign u1h_ci = m_int8 & u1l_co;
assign v1h_ci = m_int8 & v1l_co;

DW01_add #(4) u_add0(x0, y0, u0l_ci, u0l_sum, u0l_co);
DW01_add #(4) u_add1(x1, y1, u0h_ci, u0h_sum, u0h_co);
DW01_add #(4) u_add2(x2, y2, u1l_ci, u1l_sum, u1l_co);
DW01_add #(4) u_add3(x3, y3, u1h_ci, u1h_sum, u1h_co);
DW01_add #(4) u_add4(x4, y4, v0l_ci, v0l_sum, v0l_co);
DW01_add #(4) u_add5(x5, y5, v0h_ci, v0h_sum, v0h_co);
DW01_add #(4) u_add6(x6, y6, v1l_ci, v1l_sum, v1l_co);
DW01_add #(4) u_add7(x7, y7, v1h_ci, v1h_sum, v1h_co);

always_ff @(posedge aixh_core_clk2x)
  if (mul_enable) begin
    if (u_cywen) u0h_co_r <= u0h_co;    
    if (v_cywen) v0h_co_r <= v0h_co;    
    if (u_cywen) u1h_co_r <= u1h_co;    
    if (v_cywen) v1h_co_r <= v1h_co;    
  end

assign b0_code0 ={v0l_sum[2:0], 1'b0};
assign b0_code1 = ~m_int8
                ?{{2{~v0l_co}}, v0l_sum[3:2]}
                :{v0h_sum[1:0], v0l_sum[3:2]};
assign b0_code2 = ~m_int8
                ? 4'b0000
                :{~v_cywen & ~v0h_co, v0h_sum[3:1]};

assign b0_idat = ~m_int8 ? {        {5{~u0l_co}},        u0l_sum}
                         : {~u_cywen & ~u0h_co, u0h_sum, u0l_sum};
assign b0_adat = {b0_idat[8], b0_idat, 1'b0} + {{2{b0_idat[8]}}, b0_idat};

assign b1_code0 ={v1l_sum[2:0], 1'b0};
assign b1_code1 = ~m_int8
                ?{{2{~v1l_co}}, v1l_sum[3:2]}
                :{v1h_sum[1:0], v1l_sum[3:2]};
assign b1_code2 = ~m_int8
                ? 4'b0000
                :{~v_cywen & ~v1h_co, v1h_sum[3:1]};

assign b1_idat = ~m_int8 ? {        {5{~u1l_co}},        u1l_sum}
                         : {~u_cywen & ~u1h_co, u1h_sum, u1l_sum};
assign b1_adat = {b1_idat[8], b1_idat, 1'b0} + {{2{b1_idat[8]}}, b1_idat};



// BOOTH 0
AIXH_MXC_INNER_PTILE_CELL_PE_booth u_booth00(
   .code            (b0_code0           )
  ,.idat            (b0_idat            )
  ,.adat            (b0_adat            )
  ,.odat            (b0_odat0           )
  ,.oinv            (b0_oinv0           )
);
AIXH_MXC_INNER_PTILE_CELL_PE_booth u_booth01(
   .code            (b0_code1           )
  ,.idat            (b0_idat            )
  ,.adat            (b0_adat            )
  ,.odat            (b0_odat1           )
  ,.oinv            (b0_oinv1           )
);
AIXH_MXC_INNER_PTILE_CELL_PE_booth u_booth02(
   .code            (b0_code2           )
  ,.idat            (b0_idat            )
  ,.adat            (b0_adat            )
  ,.odat            (b0_odat2           )
  ,.oinv            (b0_oinv2           )
);

// BOOTH 1
AIXH_MXC_INNER_PTILE_CELL_PE_booth u_booth10(
   .code            (b1_code0           )
  ,.idat            (b1_idat            )
  ,.adat            (b1_adat            )
  ,.odat            (b1_odat0           )
  ,.oinv            (b1_oinv0           )
);
AIXH_MXC_INNER_PTILE_CELL_PE_booth u_booth11(
   .code            (b1_code1           )
  ,.idat            (b1_idat            )
  ,.adat            (b1_adat            )
  ,.odat            (b1_odat1           )
  ,.oinv            (b1_oinv1           )
);
AIXH_MXC_INNER_PTILE_CELL_PE_booth u_booth12(
   .code            (b1_code2           )
  ,.idat            (b1_idat            )
  ,.adat            (b1_adat            )
  ,.odat            (b1_odat2           )
  ,.oinv            (b1_oinv2           )
);

assign m2_u = ~m_int8 ? {~u0h_co, u0h_sum} : 5'b0;
assign m2_v = ~m_int8 ? {~v0h_co, v0h_sum} : 5'b0;
assign m3_u = ~m_int8 ? {~u1h_co, u1h_sum} : 5'b0;
assign m3_v = ~m_int8 ? {~v1h_co, v1h_sum} : 5'b0;

DW02_prod_sum #(
   .A_width         (5                  )
  ,.B_width         (5                  )
  ,.num_inputs      (2                  )
  ,.SUM_width       (11                 )
) u_psum (
   .TC              (1'b1               )
  ,.A               ({m2_u, m3_u}       )
  ,.B               ({m2_v, m3_v}       )
  ,.SUM             (m_psum             )
);

assign z_ins = {
   { 8'b0, ~m_int8 & ~m_psum[10], m_psum[9:0]}
  ,{ 8'b0, b0_odat0}
  ,{ 8'b0, b1_odat0}
  ,{ 5'b0, b0_odat1, 2'b0, b0_oinv0}
  ,{ 5'b0, b1_odat1, 2'b0, b1_oinv0}
  ,{ 2'b0, b0_odat2, 2'b0, b0_oinv1, 3'b0}
  ,{ 2'b0, b1_odat2, 2'b0, b1_oinv1, 3'b0}
  ,{12'b0,                 b0_oinv2, 6'b0}
  ,{12'b0,                 b1_oinv2, 6'b0}
};

DW02_sum #(
   .num_inputs      (9                  )
  ,.input_width     (19                 )
) u_sum (
   .INPUT           (z_ins              )
  ,.SUM             (z_sum              )
);

assign z_sum_r = pipe[MSTAGES-1];

always_ff @(posedge aixh_core_clk2x)
  if (mul_enable) begin
    pipe[0] <= z_sum;
    for (int i = 1; i < MSTAGES; i++) begin
      pipe[i] <= pipe[i-1];
    end
  end

assign z_sft = acc_mode == 2'b00 ? {16'd0, z_sum_r       }
             : acc_mode == 2'b01 ? { 8'd0, z_sum_r,  8'd0}
             :                     {       z_sum_r, 16'd0};

assign z_acc_nx = z_acc + z_sft;
assign z_update1 = acc_mode == 2'b00 ? (z_acc[19]) : 1'b1;
assign z_update2 = acc_mode == 2'b00 ? (z_acc[27] & z_acc[19])
                 : acc_mode == 2'b01 ? (z_acc[27]) : 1'b1;
assign z_update3 = acc_mode == 2'b00 ? (z_acc[35] & z_acc[27] & z_acc[19])
                 : acc_mode == 2'b01 ? (z_acc[35] & z_acc[27])
                                     : (z_acc[35]);

always_ff @(posedge aixh_core_clk2x)
  if (acc_afresh) begin
    z_acc <= 48'd0;
  end else if (acc_enable) begin
                   z_acc[19:00] <= z_acc_nx[19:00];
    if (z_update1) z_acc[27:20] <= z_acc_nx[27:20];
    if (z_update2) z_acc[35:28] <= z_acc_nx[35:28];
    if (z_update3) z_acc[47:36] <= z_acc_nx[47:36];
  end

assign zdata = z_acc;

endmodule

//------------------------------------------------------------------------------
//------------------------------------------------------------------------------
//------------------------------------------------------------------------------

module AIXH_MXC_INNER_PTILE_CELL_PE_booth
(
   input  wire [4           -1:0] code
  ,input  wire [9           -1:0] idat
  ,input  wire [11          -1:0] adat
  ,output wire [11          -1:0] odat
  ,output wire                    oinv
);
  
logic [11         -1:0] tdat;

assign odat = code[3] ? ~tdat : tdat;
assign oinv = code[3];

always_comb
  case (code)
    4'b0000, 4'b1111: tdat = {1'b1     , 10'd0              }; // 0
    4'b0001, 4'b0010,
    4'b1101, 4'b1110: tdat = {~idat[ 8], idat[8], idat      }; // X
    4'b0011, 4'b0100,
    4'b1011, 4'b1100: tdat = {~idat[ 8], idat         , 1'd0}; // 2X
    4'b0101, 4'b0110,
    4'b1001, 4'b1010: tdat = {~adat[10], adat[9:0]          }; // 3X
    4'b0111, 4'b1000: tdat = {~idat[ 8], idat[7:0]    , 2'd0}; // 4X
  endcase

endmodule
`endif // AIXH_TARGET_ASIC
`resetall
