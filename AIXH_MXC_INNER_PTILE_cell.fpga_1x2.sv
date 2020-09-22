//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Inner / Processing-Tile) Cell for FPGA 1x2
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

`ifdef AIXH_TARGET_FPGA
`ifdef AIXH_MXC_IPCELL_1X2
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

localparam PE_STAGES = `AIXH_MXC_IPE_STAGES;

IPCELL_Command            i_cmd_raw;
IPCELL_Command            i_cmd_gated;
IPCELL_Command            r_cmd;


assign i_cmd_raw = i_fwd_cmd;
assign r_cmd     = o_fwd_cmd;

// Gate command signals
always_comb begin
  i_cmd_gated.mul_enable = i_cmd_raw.mul_enable & i_dwd_vld[0];
  i_cmd_gated.acc_enable = i_cmd_raw.acc_enable & i_dwd_vld[0];
  i_cmd_gated.acc_afresh = i_cmd_raw.acc_afresh & i_dwd_vld[0];
  i_cmd_gated.drain_req0 = i_cmd_raw.drain_req0 & i_dwd_vld[1];
  i_cmd_gated.drain_req1 = i_cmd_raw.drain_req1 & i_dwd_vld[1];
  i_cmd_gated.int8_mode  = 1'b0;
end

// Inter-CELL pipeline
always_ff @(posedge aixh_core_clk2x) begin
  o_dwd_vld <= i_dwd_vld;
  o_fwd_cmd <= i_cmd_gated;

  if (i_dwd_vld[0]) begin
`ifdef AIXH_MXC_DISABLE_INT16
    o_dwd_dat[0*8+:8] <= i_dwd_dat[0*8+:8];
    o_dwd_dat[2*8+:8] <= i_dwd_dat[2*8+:8];
    o_dwd_dat[4*8+:8] <= i_dwd_dat[4*8+:8];
    o_dwd_dat[6*8+:8] <= i_dwd_dat[6*8+:8];
    o_fwd_dat[0*8+:8] <= i_fwd_dat[0*8+:8];
    o_fwd_dat[2*8+:8] <= i_fwd_dat[2*8+:8];
`else
    o_dwd_dat <= i_dwd_dat;
    o_fwd_dat <= i_fwd_dat;
`endif
  end
end


//------------------------------------------------------------------------------
// MACs
//------------------------------------------------------------------------------
`ifdef AIXH_MXC_POWER_OPT
localparam ACCUM_SHIFT = 16;
`else
localparam ACCUM_SHIFT = 0;
`endif

`ifndef AIXH_MXC_EXPLICIT_DSP //------------------------------------------------
wire  signed [8   -1:0] s1_xelem0 = $signed(o_fwd_dat[ 7: 0]);
wire  signed [8   -1:0] s1_xelem1 = $signed(o_fwd_dat[23:16]);
wire  signed [8   -1:0] s1_yelem0 = $signed(o_dwd_dat[ 7: 0]);
wire  signed [8   -1:0] s1_yelem1 = $signed(o_dwd_dat[23:16]);
wire  signed [8   -1:0] s1_yelem2 = $signed(o_dwd_dat[39:32]);
wire  signed [8   -1:0] s1_yelem3 = $signed(o_dwd_dat[55:48]);

logic                                      move_p;

logic signed [9                      -1:0] s2_usum0;
logic signed [9                      -1:0] s2_usum1;
logic signed [8+ACCUM_SHIFT          -1:0] s2_vsum_inx;
logic signed [8+ACCUM_SHIFT          -1:0] s2_vsum_iny0;
logic signed [8+ACCUM_SHIFT          -1:0] s2_vsum_iny1;

logic signed [9                      -1:0] s3_usum0;
logic signed [9                      -1:0] s3_usum1;
logic signed [9+ACCUM_SHIFT          -1:0] s3_vsum0;
logic signed [9+ACCUM_SHIFT          -1:0] s3_vsum1;

logic signed [ACCUM_BITS+ACCUM_SHIFT -1:0] s4_uvprod0;
logic signed [ACCUM_BITS+ACCUM_SHIFT -1:0] s4_uvprod1;

logic signed [ACCUM_BITS+ACCUM_SHIFT -1:0] dsp0_p;
logic signed [ACCUM_BITS+ACCUM_SHIFT -1:0] dsp1_p;
    
always_ff @(posedge aixh_core_clk2x)
  move_p <= i_cmd_raw.drain_req0;
    
always_ff @(posedge aixh_core_clk2x)
  if (r_cmd.mul_enable) begin
    s2_usum0     <= s1_xelem0 + s1_yelem1;
    s2_usum1     <= s1_xelem0 + s1_yelem3;
    s2_vsum_inx  <= s1_xelem1 << ACCUM_SHIFT;
    s2_vsum_iny0 <= s1_yelem0 << ACCUM_SHIFT;
    s2_vsum_iny1 <= s1_yelem2 << ACCUM_SHIFT;

    s3_usum0 <= s2_usum0;
    s3_usum1 <= s2_usum1;
    s3_vsum0 <= s2_vsum_inx + s2_vsum_iny0;
    s3_vsum1 <= s2_vsum_inx + s2_vsum_iny1;
    
    s4_uvprod0 <= s3_usum0 * s3_vsum0;
    s4_uvprod1 <= s3_usum1 * s3_vsum1;
  end

// DSP P reg stage
always_ff @(posedge aixh_core_clk2x)
  if (r_cmd.acc_afresh) begin
    dsp0_p <= (ACCUM_BITS+ACCUM_SHIFT)'(0);
  end else
  if (r_cmd.acc_enable) begin
    if (move_p)
         dsp0_p <= dsp1_p;
    else dsp0_p <= dsp0_p + s4_uvprod0;
  end

always_ff @(posedge aixh_core_clk2x)
  if (r_cmd.acc_afresh) begin
    dsp1_p <= (ACCUM_BITS+ACCUM_SHIFT)'(0);
  end else
  if (r_cmd.acc_enable) begin
    dsp1_p <= dsp1_p + s4_uvprod1;
  end

`else // !AIXH_MXC_EXPLICIT_DSP ------------------------------------------------
wire [8   -1:0] s1_xelem0 = o_fwd_dat[ 7: 0];
wire [8   -1:0] s1_xelem1 = o_fwd_dat[23:16];
wire [8   -1:0] s1_yelem0 = o_dwd_dat[ 7: 0];
wire [8   -1:0] s1_yelem1 = o_dwd_dat[23:16];
wire [8   -1:0] s1_yelem2 = o_dwd_dat[39:32];
wire [8   -1:0] s1_yelem3 = o_dwd_dat[55:48];

wire [8   -1:0] pa0_cy0_o;
wire [8   -1:0] pa0_cy0_co;
wire [8   -1:0] pa0_cy1_o;
wire [8   -1:0] pa1_cy0_o;
wire [8   -1:0] pa1_cy0_co;
wire [8   -1:0] pa1_cy1_o;

wire [30  -1:0] dsp0_a;
wire [18  -1:0] dsp0_b;
wire [48  -1:0] dsp0_c;
wire [27  -1:0] dsp0_d;
wire [48  -1:0] dsp0_p;
wire [9   -1:0] dsp0_opmode;
wire [30  -1:0] dsp1_a;
wire [18  -1:0] dsp1_b;
wire [48  -1:0] dsp1_c;
wire [27  -1:0] dsp1_d;
wire [48  -1:0] dsp1_pcout;
wire [30  -1:0] dsp1_acout;
wire [9   -1:0] dsp1_opmode;

CARRY8 #(
   .CARRY_TYPE("SINGLE_CY8"         )
) u_pa0_cy0 (
   .CO        (pa0_cy0_co           )
  ,.O         (pa0_cy0_o            )
  ,.CI        (1'b0                 )
  ,.CI_TOP    (                     )
  ,.DI        (s1_xelem0 ^ 8'h80    )
  ,.S         (s1_xelem0 ^ s1_yelem1)
);

CARRY8 #(
   .CARRY_TYPE("SINGLE_CY8"         )
) u_pa0_cy1 (
   .CO        (                     )
  ,.O         (pa0_cy1_o            )
  ,.CI        (pa0_cy0_co[7]        )
  ,.CI_TOP    (                     )
  ,.DI        (8'b0                 )
  ,.S         (8'b1                 )
);

CARRY8 #(
   .CARRY_TYPE("SINGLE_CY8"         )
) u_pa1_cy0 (
   .CO        (pa1_cy0_co           )
  ,.O         (pa1_cy0_o            )
  ,.CI        (1'b0                 )
  ,.CI_TOP    (                     )
  ,.DI        (s1_xelem0 ^ 8'h80    )
  ,.S         (s1_xelem0 ^ s1_yelem3)
);

CARRY8 #(
   .CARRY_TYPE("SINGLE_CY8"         )
) u_pa1_cy1 (
   .CO        (                     )
  ,.O         (pa1_cy1_o            )
  ,.CI        (pa1_cy0_co[7]        )
  ,.CI_TOP    (                     )
  ,.DI        (8'b0                 )
  ,.S         (8'b1                 )
);

assign dsp0_a = dsp1_a;
assign dsp0_b = {{18-8{pa0_cy1_o[0]}}, pa0_cy0_o};
assign dsp1_b = {{18-8{pa1_cy1_o[0]}}, pa1_cy0_o};
assign dsp1_a = {{30-ACCUM_SHIFT-8{s1_xelem1[7]}}, s1_xelem1} << ACCUM_SHIFT;
assign dsp0_d = {{27-ACCUM_SHIFT-8{s1_yelem0[7]}}, s1_yelem0} << ACCUM_SHIFT;
assign dsp1_d = {{27-ACCUM_SHIFT-8{s1_yelem2[7]}}, s1_yelem2} << ACCUM_SHIFT;
assign dsp0_opmode = i_cmd_raw.drain_req0
                   ? 9'b00_001_00_00  // 0 + PCIN + 0  + 0
                   : 9'b00_010_01_01; // 0 +    P + Mx + My
assign dsp1_opmode = 9'b00_010_01_01;

DSP48E2 #(
   .AMULTSEL                  ("AD"                 ) // Selects A input to multiplier (A, AD)
  ,.A_INPUT                   ("DIRECT"             ) // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
  ,.BMULTSEL                  ("B"                  ) // Selects B input to multiplier (AD, B)
  ,.B_INPUT                   ("DIRECT"             ) // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
  ,.PREADDINSEL               ("A"                  ) // Selects input to pre-adder (A, B)
  ,.RND                       (48'h000000000000     ) // Rounding Constant
  ,.USE_MULT                  ("MULTIPLY"           ) // Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
  ,.USE_SIMD                  ("ONE48"              ) // SIMD selection (FOUR12, ONE48, TWO24)
  ,.USE_WIDEXOR               ("FALSE"              ) // Use the Wide XOR function (FALSE, TRUE)
  ,.XORSIMD                   ("XOR24_48_96"        ) // Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
  ,.AUTORESET_PATDET          ("NO_RESET"           ) // NO_RESET, RESET_MATCH, RESET_NOT_MATCH
  ,.AUTORESET_PRIORITY        ("RESET"              ) // Priority of AUTORESET vs. CEP (CEP, RESET).
  ,.MASK                      (48'h3fffffffffff     ) // 48-bit mask value for pattern detect (1=ignore)
  ,.PATTERN                   (48'h000000000000     ) // 48-bit pattern match for pattern detect
  ,.SEL_MASK                  ("MASK"               ) // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
  ,.SEL_PATTERN               ("PATTERN"            ) // Select pattern value (C, PATTERN)
  ,.USE_PATTERN_DETECT        ("NO_PATDET"          ) // Enable pattern detect (NO_PATDET, PATDET)
  ,.IS_ALUMODE_INVERTED       (4'b0000              ) // Optional inversion for ALUMODE
  ,.IS_CARRYIN_INVERTED       (1'b0                 ) // Optional inversion for CARRYIN
  ,.IS_CLK_INVERTED           (1'b0                 ) // Optional inversion for CLK
  ,.IS_INMODE_INVERTED        (5'b00000             ) // Optional inversion for INMODE
  ,.IS_OPMODE_INVERTED        (9'b000000000         ) // Optional inversion for OPMODE
  ,.IS_RSTALLCARRYIN_INVERTED (1'b0                 ) // Optional inversion for RSTALLCARRYIN
  ,.IS_RSTALUMODE_INVERTED    (1'b0                 ) // Optional inversion for RSTALUMODE
  ,.IS_RSTA_INVERTED          (1'b0                 ) // Optional inversion for RSTA
  ,.IS_RSTB_INVERTED          (1'b0                 ) // Optional inversion for RSTB
  ,.IS_RSTCTRL_INVERTED       (1'b0                 ) // Optional inversion for RSTCTRL
  ,.IS_RSTC_INVERTED          (1'b0                 ) // Optional inversion for RSTC
  ,.IS_RSTD_INVERTED          (1'b0                 ) // Optional inversion for RSTD
  ,.IS_RSTINMODE_INVERTED     (1'b0                 ) // Optional inversion for RSTINMODE
  ,.IS_RSTM_INVERTED          (1'b0                 ) // Optional inversion for RSTM
  ,.IS_RSTP_INVERTED          (1'b0                 ) // Optional inversion for RSTP
  ,.ACASCREG                  (1                    ) // Number of pipeline stages between A/ACIN and ACOUT (0-2)
  ,.ADREG                     (1                    ) // Pipeline stages for pre-adder (0-1)
  ,.ALUMODEREG                (0                    ) // Pipeline stages for ALUMODE (0-1)
  ,.AREG                      (1                    ) // Pipeline stages for A (0-2)
  ,.BCASCREG                  (1                    ) // Number of pipeline stages between B/BCIN and BCOUT (0-2)
  ,.BREG                      (2                    ) // Pipeline stages for B (0-2)
  ,.CARRYINREG                (0                    ) // Pipeline stages for CARRYIN (0-1)
  ,.CARRYINSELREG             (0                    ) // Pipeline stages for CARRYINSEL (0-1)
  ,.CREG                      (0                    ) // Pipeline stages for C (0-1)
  ,.DREG                      (1                    ) // Pipeline stages for D (0-1)
  ,.INMODEREG                 (0                    ) // Pipeline stages for INMODE (0-1)
  ,.MREG                      (1                    ) // Multiplier pipeline stages (0-1)
  ,.OPMODEREG                 (1                    ) // Pipeline stages for OPMODE (0-1)
  ,.PREG                      (1                    ) // Number of pipeline stages for P (0-1)
) u_dsp0 (
   .ACOUT                     (/*nc*/               ) // 30-bit output: A port cascade
  ,.BCOUT                     (/*nc*/               ) // 18-bit output: B cascade
  ,.CARRYCASCOUT              (/*nc*/               ) // 1-bit output: Cascade carry
  ,.MULTSIGNOUT               (/*nc*/               ) // 1-bit output: Multiplier sign cascade
  ,.PCOUT                     (/*nc*/               ) // 48-bit output: Cascade output
  ,.OVERFLOW                  (/*nc*/               ) // 1-bit output: Overflow in add/acc
  ,.PATTERNBDETECT            (/*nc*/               ) // 1-bit output: Pattern bar detect
  ,.PATTERNDETECT             (/*nc*/               ) // 1-bit output: Pattern detect
  ,.UNDERFLOW                 (/*nc*/               ) // 1-bit output: Underflow in add/acc
  ,.CARRYOUT                  (/*nc*/               ) // 4-bit output: Carry
  ,.P                         (dsp0_p               ) // 48-bit output: Primary data
  ,.XOROUT                    (/*nc*/               ) // 8-bit output: XOR data
  ,.ACIN                      (dsp1_acout           ) // 30-bit input: A cascade data
  ,.BCIN                      (/*nc*/               ) // 18-bit input: B cascade
  ,.CARRYCASCIN               (/*nc*/               ) // 1-bit input: Cascade carry
  ,.MULTSIGNIN                (/*nc*/               ) // 1-bit input: Multiplier sign cascade
  ,.PCIN                      (dsp1_pcout           ) // 48-bit input: P cascade
  ,.ALUMODE                   (4'b0000              ) // 4-bit input: ALU control
  ,.CARRYINSEL                (3'b000               ) // 3-bit input: Carry select
  ,.CLK                       (aixh_core_clk2x      ) // 1-bit input: Clock
  ,.INMODE                    (5'b00100             ) // 5-bit input: INMODE control
  ,.OPMODE                    (dsp0_opmode          ) // 9-bit input: Operation mode
  ,.A                         (dsp0_a               ) // 30-bit input: A data
  ,.B                         (dsp0_b               ) // 18-bit input: B data
  ,.C                         (/*nc*/               ) // 48-bit input: C data
  ,.CARRYIN                   (1'b0                 ) // 1-bit input: Carry-in
  ,.D                         (dsp0_d               ) // 27-bit input: D data
  ,.CEA1                      (1'b0                 ) // 1-bit input: Clock enable for 1st stage AREG
  ,.CEA2                      (r_cmd.mul_enable     ) // 1-bit input: Clock enable for 2nd stage AREG
  ,.CEAD                      (r_cmd.mul_enable     ) // 1-bit input: Clock enable for ADREG
  ,.CEALUMODE                 (1'b0                 ) // 1-bit input: Clock enable for ALUMODE
  ,.CEB1                      (r_cmd.mul_enable     ) // 1-bit input: Clock enable for 1st stage BREG
  ,.CEB2                      (r_cmd.mul_enable     ) // 1-bit input: Clock enable for 2nd stage BREG
  ,.CEC                       (1'b0                 ) // 1-bit input: Clock enable for CREG
  ,.CECARRYIN                 (1'b0                 ) // 1-bit input: Clock enable for CARRYINREG
  ,.CECTRL                    (1'b1                 ) // 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
  ,.CED                       (r_cmd.mul_enable     ) // 1-bit input: Clock enable for DREG
  ,.CEINMODE                  (1'b0                 ) // 1-bit input: Clock enable for INMODEREG
  ,.CEM                       (r_cmd.mul_enable     ) // 1-bit input: Clock enable for MREG
  ,.CEP                       (r_cmd.acc_enable     ) // 1-bit input: Clock enable for PREG
  ,.RSTA                      (1'b0                 ) // 1-bit input: Reset for AREG
  ,.RSTALLCARRYIN             (1'b0                 ) // 1-bit input: Reset for CARRYINREG
  ,.RSTALUMODE                (1'b0                 ) // 1-bit input: Reset for ALUMODEREG
  ,.RSTB                      (1'b0                 ) // 1-bit input: Reset for BREG
  ,.RSTC                      (1'b0                 ) // 1-bit input: Reset for CREG
  ,.RSTCTRL                   (1'b0                 ) // 1-bit input: Reset for OPMODEREG and CARRYINSELREG
  ,.RSTD                      (1'b0                 ) // 1-bit input: Reset for DREG and ADREG
  ,.RSTINMODE                 (1'b0                 ) // 1-bit input: Reset for INMODEREG
  ,.RSTM                      (1'b0                 ) // 1-bit input: Reset for MREG
  ,.RSTP                      (r_cmd.acc_afresh     ) // 1-bit input: Reset for PREG
);

DSP48E2 #(
   .AMULTSEL                  ("AD"                 ) // Selects A input to multiplier (A, AD)
  ,.A_INPUT                   ("DIRECT"             ) // Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
  ,.BMULTSEL                  ("B"                  ) // Selects B input to multiplier (AD, B)
  ,.B_INPUT                   ("DIRECT"             ) // Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
  ,.PREADDINSEL               ("A"                  ) // Selects input to pre-adder (A, B)
  ,.RND                       (48'h000000000000     ) // Rounding Constant
  ,.USE_MULT                  ("MULTIPLY"           ) // Select multiplier usage (DYNAMIC, MULTIPLY, NONE)
  ,.USE_SIMD                  ("ONE48"              ) // SIMD selection (FOUR12, ONE48, TWO24)
  ,.USE_WIDEXOR               ("FALSE"              ) // Use the Wide XOR function (FALSE, TRUE)
  ,.XORSIMD                   ("XOR24_48_96"        ) // Mode of operation for the Wide XOR (XOR12, XOR24_48_96)
  ,.AUTORESET_PATDET          ("NO_RESET"           ) // NO_RESET, RESET_MATCH, RESET_NOT_MATCH
  ,.AUTORESET_PRIORITY        ("RESET"              ) // Priority of AUTORESET vs. CEP (CEP, RESET).
  ,.MASK                      (48'h3fffffffffff     ) // 48-bit mask value for pattern detect (1=ignore)
  ,.PATTERN                   (48'h000000000000     ) // 48-bit pattern match for pattern detect
  ,.SEL_MASK                  ("MASK"               ) // C, MASK, ROUNDING_MODE1, ROUNDING_MODE2
  ,.SEL_PATTERN               ("PATTERN"            ) // Select pattern value (C, PATTERN)
  ,.USE_PATTERN_DETECT        ("NO_PATDET"          ) // Enable pattern detect (NO_PATDET, PATDET)
  ,.IS_ALUMODE_INVERTED       (4'b0000              ) // Optional inversion for ALUMODE
  ,.IS_CARRYIN_INVERTED       (1'b0                 ) // Optional inversion for CARRYIN
  ,.IS_CLK_INVERTED           (1'b0                 ) // Optional inversion for CLK
  ,.IS_INMODE_INVERTED        (5'b00000             ) // Optional inversion for INMODE
  ,.IS_OPMODE_INVERTED        (9'b000000000         ) // Optional inversion for OPMODE
  ,.IS_RSTALLCARRYIN_INVERTED (1'b0                 ) // Optional inversion for RSTALLCARRYIN
  ,.IS_RSTALUMODE_INVERTED    (1'b0                 ) // Optional inversion for RSTALUMODE
  ,.IS_RSTA_INVERTED          (1'b0                 ) // Optional inversion for RSTA
  ,.IS_RSTB_INVERTED          (1'b0                 ) // Optional inversion for RSTB
  ,.IS_RSTCTRL_INVERTED       (1'b0                 ) // Optional inversion for RSTCTRL
  ,.IS_RSTC_INVERTED          (1'b0                 ) // Optional inversion for RSTC
  ,.IS_RSTD_INVERTED          (1'b0                 ) // Optional inversion for RSTD
  ,.IS_RSTINMODE_INVERTED     (1'b0                 ) // Optional inversion for RSTINMODE
  ,.IS_RSTM_INVERTED          (1'b0                 ) // Optional inversion for RSTM
  ,.IS_RSTP_INVERTED          (1'b0                 ) // Optional inversion for RSTP
  ,.ACASCREG                  (1                    ) // Number of pipeline stages between A/ACIN and ACOUT (0-2)
  ,.ADREG                     (1                    ) // Pipeline stages for pre-adder (0-1)
  ,.ALUMODEREG                (0                    ) // Pipeline stages for ALUMODE (0-1)
  ,.AREG                      (1                    ) // Pipeline stages for A (0-2)
  ,.BCASCREG                  (1                    ) // Number of pipeline stages between B/BCIN and BCOUT (0-2)
  ,.BREG                      (2                    ) // Pipeline stages for B (0-2)
  ,.CARRYINREG                (0                    ) // Pipeline stages for CARRYIN (0-1)
  ,.CARRYINSELREG             (0                    ) // Pipeline stages for CARRYINSEL (0-1)
  ,.CREG                      (0                    ) // Pipeline stages for C (0-1)
  ,.DREG                      (1                    ) // Pipeline stages for D (0-1)
  ,.INMODEREG                 (0                    ) // Pipeline stages for INMODE (0-1)
  ,.MREG                      (1                    ) // Multiplier pipeline stages (0-1)
  ,.OPMODEREG                 (0                    ) // Pipeline stages for OPMODE (0-1)
  ,.PREG                      (1                    ) // Number of pipeline stages for P (0-1)
) u_dsp1 (
   .ACOUT                     (dsp1_acout           ) // 30-bit output: A port cascade
  ,.BCOUT                     (/*nc*/               ) // 18-bit output: B cascade
  ,.CARRYCASCOUT              (/*nc*/               ) // 1-bit output: Cascade carry
  ,.MULTSIGNOUT               (/*nc*/               ) // 1-bit output: Multiplier sign cascade
  ,.PCOUT                     (dsp1_pcout           ) // 48-bit output: Cascade output
  ,.OVERFLOW                  (/*nc*/               ) // 1-bit output: Overflow in add/acc
  ,.PATTERNBDETECT            (/*nc*/               ) // 1-bit output: Pattern bar detect
  ,.PATTERNDETECT             (/*nc*/               ) // 1-bit output: Pattern detect
  ,.UNDERFLOW                 (/*nc*/               ) // 1-bit output: Underflow in add/acc
  ,.CARRYOUT                  (/*nc*/               ) // 4-bit output: Carry
  ,.P                         (/*nc*/               ) // 48-bit output: Primary data
  ,.XOROUT                    (/*nc*/               ) // 8-bit output: XOR data
  ,.ACIN                      (/*nc*/               ) // 30-bit input: A cascade data
  ,.BCIN                      (/*nc*/               ) // 18-bit input: B cascade
  ,.CARRYCASCIN               (/*nc*/               ) // 1-bit input: Cascade carry
  ,.MULTSIGNIN                (/*nc*/               ) // 1-bit input: Multiplier sign cascade
  ,.PCIN                      (/*nc*/               ) // 48-bit input: P cascade
  ,.ALUMODE                   (4'b0000              ) // 4-bit input: ALU control
  ,.CARRYINSEL                (3'b000               ) // 3-bit input: Carry select
  ,.CLK                       (aixh_core_clk2x      ) // 1-bit input: Clock
  ,.INMODE                    (5'b00100             ) // 5-bit input: INMODE control
  ,.OPMODE                    (dsp1_opmode          ) // 9-bit input: Operation mode
  ,.A                         (dsp1_a               ) // 30-bit input: A data
  ,.B                         (dsp1_b               ) // 18-bit input: B data
  ,.C                         (/*nc*/               ) // 48-bit input: C data
  ,.CARRYIN                   (1'b0                 ) // 1-bit input: Carry-in
  ,.D                         (dsp1_d               ) // 27-bit input: D data
  ,.CEA1                      (1'b0                 ) // 1-bit input: Clock enable for 1st stage AREG
  ,.CEA2                      (r_cmd.mul_enable     ) // 1-bit input: Clock enable for 2nd stage AREG
  ,.CEAD                      (r_cmd.mul_enable     ) // 1-bit input: Clock enable for ADREG
  ,.CEALUMODE                 (1'b0                 ) // 1-bit input: Clock enable for ALUMODE
  ,.CEB1                      (r_cmd.mul_enable     ) // 1-bit input: Clock enable for 1st stage BREG
  ,.CEB2                      (r_cmd.mul_enable     ) // 1-bit input: Clock enable for 2nd stage BREG
  ,.CEC                       (1'b0                 ) // 1-bit input: Clock enable for CREG
  ,.CECARRYIN                 (1'b0                 ) // 1-bit input: Clock enable for CARRYINREG
  ,.CECTRL                    (1'b0                 ) // 1-bit input: Clock enable for OPMODEREG and CARRYINSELREG
  ,.CED                       (r_cmd.mul_enable     ) // 1-bit input: Clock enable for DREG
  ,.CEINMODE                  (1'b0                 ) // 1-bit input: Clock enable for INMODEREG
  ,.CEM                       (r_cmd.mul_enable     ) // 1-bit input: Clock enable for MREG
  ,.CEP                       (r_cmd.acc_enable     ) // 1-bit input: Clock enable for PREG
  ,.RSTA                      (1'b0                 ) // 1-bit input: Reset for AREG
  ,.RSTALLCARRYIN             (1'b0                 ) // 1-bit input: Reset for CARRYINREG
  ,.RSTALUMODE                (1'b0                 ) // 1-bit input: Reset for ALUMODEREG
  ,.RSTB                      (1'b0                 ) // 1-bit input: Reset for BREG
  ,.RSTC                      (1'b0                 ) // 1-bit input: Reset for CREG
  ,.RSTCTRL                   (1'b0                 ) // 1-bit input: Reset for OPMODEREG and CARRYINSELREG
  ,.RSTD                      (1'b0                 ) // 1-bit input: Reset for DREG and ADREG
  ,.RSTINMODE                 (1'b0                 ) // 1-bit input: Reset for INMODEREG
  ,.RSTM                      (1'b0                 ) // 1-bit input: Reset for MREG
  ,.RSTP                      (r_cmd.acc_afresh     ) // 1-bit input: Reset for PREG
);
`endif // !AIXH_MXC_EXPLICIT_DSP -----------------------------------------------

//------------------------------------------------------------------------------
// Drain
//------------------------------------------------------------------------------
always_ff @(posedge aixh_core_clk2x) begin
  if (r_cmd.drain_req1 | i_bwd_vld) begin
    o_bwd_vld <= 1'b1;
    o_bwd_dat <= i_bwd_vld ? i_bwd_dat : dsp0_p[ACCUM_SHIFT+:ACCUM_BITS];
  end else begin
    o_bwd_vld <= 1'b0;
  end
end

endmodule
`endif // AIXH_MXC_IPCELL_1X2
`endif // AIXH_TARGET_FPGA
`resetall
