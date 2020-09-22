//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Left / Processing-Tile / Cell) Output-Side PE
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

`ifdef AIXH_TARGET_ASIC
import AIXH_MXC_pkg::*;
module AIXH_MXC_LEFT_PTILE_CELL_ospe(
   input  wire                    aixh_core_clk2x
  ,input  wire                    enable
  ,input  wire                    nullify
  ,input  wire [2           -1:0] prec_mode
  ,input  wire                    uint_mode
  ,input  wire [SCALE_BITS  -1:0] isdata
  ,input  wire [48          -1:0] imdata
  ,output wire [16          -1:0] owdata
);
// synopsys dc_tcl_script_begin
// set_optimize_registers -check_design -print_critical_loop
// synopsys dc_tcl_script_end

localparam MSTAGES = `AIXH_MXC_LOSPE_STAGES - 2 - 2;
localparam SM = `AIXH_MXC_SCALE_MANTISSA_BITS;

logic                   a0_nullify;
logic                   a0_m_sign;
logic [47         -1:0] a0_m_asbits;
logic [47         -1:0] a0_m_magnitude;
logic [7          -1:0] a0_m_leading0s;
logic [SM+5       -1:0] a0_s_negative;
logic [SM+5       -1:0] a0_s_positve;

logic                   a1_m_sign;
logic [47         -1:0] a1_m_magnitude;
logic [6          -1:0] a1_m_leading0s;
logic [47         -1:0] a1_m_aligned;
logic [25         -1:0] a1_m_rounded;
logic [SM+5       -1:0] a1_s_selected;
logic [6          -1:0] a1_s_exponent;
logic [SM-1       -1:0] a1_s_mantissa;
logic [8          -1:0] a1_w_rshamt;

logic                   a2_m_sign;
logic [25         -1:0] a2_m_mantissa;
logic [SM         -1:0] a2_s_mantissa;
logic [6          -1:0] a2_w_rshamt;

logic                   a3_w_sign_sr  [MSTAGES];
logic [6          -1:0] a3_w_rshamt_sr[MSTAGES];

logic                   b0_w_sign;
logic [6          -1:0] b0_w_rshamt;
logic [SM+25      -1:0] b0_w_mantissa;
logic [SM+40      -1:0] b0_w_rshifted;

logic [2          -1:0] b1_prec_mode;
logic                   b1_uint_mode;
logic                   b1_w_sign;
logic [16         -1:0] b1_w_rshifted;
logic [16         -1:0] b1_w_rounded;
logic                   b1_w_rsh_ovf;
logic [15         -1:0] b1_w_saturated;

logic [16         -1:0] b2_w_result;


//always_ff @(posedge aixh_core_clk2x)
//  if (enable) begin
//    {a0_m_sign, a0_m_asbits} <= imdata;
//    {a0_s_negative, a0_s_positve} <= isdata;
//    b1_prec_mode <= prec_mode;
//    b1_uint_mode <= uint_mode;
//  end
assign a0_nullify = nullify;
assign {a0_m_sign, a0_m_asbits} = imdata;
assign {a0_s_negative, a0_s_positve} = isdata;
assign b1_prec_mode = prec_mode;
assign b1_uint_mode = uint_mode;

//
// Convert the fixed point M into floating-point
//
assign a0_m_magnitude = ({47{a0_m_sign}} ^ a0_m_asbits) + {46'b0, a0_m_sign};

DW_lzd #(
   .a_width         (47                       )
) u_lzd(
   .a               (a0_m_magnitude           )
  ,.enc             (a0_m_leading0s           )
  ,.dec             (                         ) 
);

always_ff @(posedge aixh_core_clk2x) 
  if (enable) begin
    a1_m_sign      <= a0_m_sign;
    a1_m_magnitude <= a0_m_magnitude;
    a1_m_leading0s <= a0_m_leading0s[0+:6];
    if (a0_nullify) begin
      a1_s_selected  <= {SM+5{1'b0}};
    end else begin
      a1_s_selected  <= a0_m_sign ? a0_s_negative : a0_s_positve;
    end
  end

assign a1_m_aligned = a1_m_magnitude << a1_m_leading0s;
assign a1_m_rounded = { 1'b0, a1_m_aligned[46-:24]}
                    + {24'b0, a1_m_aligned[46-24]};
assign {a1_s_exponent, a1_s_mantissa} = a1_s_selected;
// W right shift amount where W=S*M
// - M_exponent = M_lzd_in_bits(=47) 
//              - M_leading0s 
//              - M_mantisa_bits(=24)
// - W_exponent = M_exponent 
//              + S_exponent
//              - M_in_bits(=48)
//              - S_mantissa_bits(=SM) + 1
// - W_exponent = S_exponent - M_leading0s - SM - 24;
// - W_pre_lshamt = W_magnitude_bits(=15) + rnd_bit(=1) = 16
// - W_rshamt = W_pre_lshamt - rnd_bit(=1) - W_exponent
//            = m_leading0s - S_exponent + SM + 39;
assign a1_w_rshamt = {2'b00, a1_m_leading0s}
                   - {2'b00, a1_s_exponent}
                   + 8'(SM + 39);

always_ff @(posedge aixh_core_clk2x) 
  if (enable) begin
    a2_m_sign     <= a1_m_sign;
    a2_m_mantissa <= a1_m_rounded;

    if (a1_w_rshamt[7]) begin
      // Max-scaling
      a2_s_mantissa <= {1'b1, a1_s_mantissa};
      a2_w_rshamt   <= 6'd0;
    end else
    if (a1_w_rshamt[6]) begin
      // Zero-scaling
      a2_s_mantissa <= 8'b0;
      a2_w_rshamt   <= 6'd0;
    end else begin
      a2_s_mantissa <= {1'b1, a1_s_mantissa};
      a2_w_rshamt   <= a1_w_rshamt[0+:6];
    end
  end

//
// Multiply
//
DW_mult_pipe #(
   .a_width         (25                       )
  ,.b_width         (SM                       )
  ,.num_stages      (MSTAGES+1                )
  ,.stall_mode      (1                        )
  ,.rst_mode        (0                        )
  ,.op_iso_mode     (1 /* none */             )
) u_mul(
   .clk             (aixh_core_clk2x          )
  ,.rst_n           (1'b1                     )
  ,.en              (enable                   )
  ,.tc              (1'b0                     )
  ,.a               (a2_m_mantissa            )
  ,.b               (a2_s_mantissa            )
  ,.product         (b0_w_mantissa            )
);

// pass-through shift registers
always_ff @(posedge aixh_core_clk2x)
  if (enable) begin
    a3_w_sign_sr[0]   <= a2_m_sign;
    a3_w_rshamt_sr[0] <= a2_w_rshamt;
    for (int i = 1; i < MSTAGES; i++) begin
      a3_w_sign_sr[i]   <= a3_w_sign_sr  [i-1];
      a3_w_rshamt_sr[i] <= a3_w_rshamt_sr[i-1];
    end
  end

assign b0_w_sign   = a3_w_sign_sr  [MSTAGES-1];
assign b0_w_rshamt = a3_w_rshamt_sr[MSTAGES-1];

//
// Convert back to fixed-point
//
assign b0_w_rshifted = {b0_w_mantissa[0+:SM+24], 16'd0} >> b0_w_rshamt;

always_ff @(posedge aixh_core_clk2x)
  if (enable) begin
    b1_w_sign     <=  b0_w_sign;
    b1_w_rshifted <=  b0_w_rshifted[   15: 0];
    b1_w_rsh_ovf  <= |b0_w_rshifted[SM+39:16];
  end

assign b1_w_rounded = { 1'b0, b1_w_rshifted[15:1]}
                    + {15'b0, b1_w_rshifted[0]};

always_comb begin
  b1_w_saturated = b1_w_rounded[14:0];
  case ({b1_prec_mode, b1_uint_mode})
    3'b00_0: // SINT4
      if (|{b1_w_rsh_ovf, b1_w_rounded[15:3]})
           b1_w_saturated = 15'h0007;
    3'b00_1: // UINT4
      if (b1_w_sign)
           b1_w_saturated = 15'h0000;
      else
      if (|{b1_w_rsh_ovf, b1_w_rounded[15:4]})
           b1_w_saturated = 15'h000F;
    3'b01_0: // SINT8
      if (|{b1_w_rsh_ovf, b1_w_rounded[15:7]})
           b1_w_saturated = 15'h007F;
    3'b01_1: // UINT8
      if (b1_w_sign)
           b1_w_saturated = 15'h0000;
      else
      if (|{b1_w_rsh_ovf, b1_w_rounded[15:8]})
           b1_w_saturated = 15'h00FF;
    default: // SINT16
      if (|{b1_w_rsh_ovf, b1_w_rounded[15]})
           b1_w_saturated = 15'h7FFF;
  endcase
end

always_ff @(posedge aixh_core_clk2x)
  if (enable) begin
    b2_w_result <= ({16{b1_w_sign}} ^ {1'b0, b1_w_saturated})
              + {15'b0, b1_w_sign};
  end

assign owdata = b2_w_result;

endmodule
`endif // AIXH_TARGET_ASIC
`resetall
