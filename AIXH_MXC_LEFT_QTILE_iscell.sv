//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Left / Queue-Tile) Input-Side Cell
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_LEFT_QTILE_iscell
#(
   SKEW_DEPTH = 1
) (
   input  wire                              aixh_core_clk
  ,input  wire                              aixh_core_clk2x
  ,input  wire                              aixh_core_rstn

  // Vertical control interface
  ,input  wire                              i_csync
  ,input  wire                              i_senable
  ,input  wire                              i_wenable
  ,input  wire                              i_renable
  ,input  wire [2                     -1:0] i_rmode
  ,output wire                              o_wenable
  ,output wire                              o_renable
  ,output wire [2                     -1:0] o_rmode

  ,input  wire [64                    -1:0] i_udata
  ,input  wire [64                    -1:0] i_vdata
  ,output wire [64                    -1:0] o_udata
  ,output wire [64                    -1:0] o_vdata
  // Horizontal data interface
  ,input  wire [LQCELL_FWD_DWIDTH     -1:0] i_sdata
  ,output wire [LQCELL_FWD_DWIDTH     -1:0] o_rdata
);

//------------------------------------------------------------------------------
// Delay buffer for skew generation
//------------------------------------------------------------------------------
localparam DLYB_CORE_INTVL  = 8;
localparam DLYB_CORE_SLICES = (SKEW_DEPTH+DLYB_CORE_INTVL-3)/DLYB_CORE_INTVL;
localparam DLYB_ALL_SLICES  = (SKEW_DEPTH+DLYB_CORE_INTVL-2)/DLYB_CORE_INTVL+1;

logic                             dlyb_svalid[DLYB_ALL_SLICES];
logic [LQCELL_FWD_DWIDTH    -1:0] dlyb_sdata [DLYB_ALL_SLICES];
logic                             dlyb_ovalid;
logic [LQCELL_FWD_DWIDTH    -1:0] dlyb_odata ;

// Input slice
always_ff @(posedge aixh_core_clk) begin
  dlyb_svalid[0] <= i_senable;
  if (i_senable) begin
    dlyb_sdata[0] <= i_sdata;
  end
end

// Core slices
for (genvar s = 1; s <= DLYB_CORE_SLICES; s++) begin: g_dlyb_core
  localparam DEPTH0 = SKEW_DEPTH-1 - DLYB_CORE_INTVL*(s-1);
  localparam DEPTH  = DEPTH0 < DLYB_CORE_INTVL
                    ? DEPTH0 : DLYB_CORE_INTVL;
  localparam PWIDTH = $clog2(DEPTH);
  localparam EPTR   = PWIDTH'($unsigned(DEPTH-1));

  logic [LQCELL_FWD_DWIDTH    -1:0] mem[DEPTH];
  logic [PWIDTH               -1:0] ptr;
  logic [DEPTH                -1:0] vld;
  
  always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
    if (~aixh_core_rstn) begin
      ptr <= PWIDTH'(0);
    end else
    if (|{dlyb_svalid[s-1], vld[0+:DEPTH-1]}) begin
      if (ptr == EPTR) ptr <= PWIDTH'(0);
      else             ptr <= PWIDTH'(1) + ptr;
    end

  always_ff @(posedge aixh_core_clk) begin
    vld <= DEPTH'({vld, dlyb_svalid[s-1]});
    if (dlyb_svalid[s-1]) begin
      mem[ptr] <= dlyb_sdata[s-1]; 
    end
  end

  assign dlyb_svalid[s] = vld[DEPTH-1];
  assign dlyb_sdata [s] = mem[ptr];
end

// Output slice
if (DLYB_CORE_SLICES + 1 < DLYB_ALL_SLICES) begin: g_dlyb_out
  always_ff @(posedge aixh_core_clk) begin
    dlyb_svalid[DLYB_ALL_SLICES-1] <= dlyb_svalid[DLYB_ALL_SLICES-2];
    if (dlyb_svalid[DLYB_ALL_SLICES-2]) begin
      dlyb_sdata[DLYB_ALL_SLICES-1] <= dlyb_sdata[DLYB_ALL_SLICES-2];
    end
  end
end

assign dlyb_ovalid = dlyb_svalid[DLYB_ALL_SLICES-1]; 
assign dlyb_odata  = dlyb_sdata [DLYB_ALL_SLICES-1]; 

//------------------------------------------------------------------------------
// FIFO
//------------------------------------------------------------------------------
localparam FIFO_DEPTH  = $unsigned(`AIXH_LTC_MXC_RDATA_QDEPTH);
localparam FIFO_AWIDTH = $clog2(FIFO_DEPTH);
localparam FIFO_EADDR  = FIFO_AWIDTH'(FIFO_DEPTH - 1);

reg  [LQCELL_FWD_DWIDTH     -1:0] fifo_mem[FIFO_DEPTH];
reg  [LQCELL_FWD_DWIDTH     -1:0] fifo_dout;
reg  [FIFO_AWIDTH           -1:0] fifo_waddr;
wire [FIFO_AWIDTH           -1:0] fifo_waddr_nx;
reg  [FIFO_AWIDTH           -1:0] fifo_raddr;
wire [FIFO_AWIDTH           -1:0] fifo_raddr_nx;
reg                               fifo_wen;
reg                               fifo_ren;


assign o_wenable = fifo_wen;
assign o_renable = fifo_ren;

assign fifo_waddr_nx = fifo_waddr == FIFO_EADDR ? 'd0 : fifo_waddr + 'd1;
assign fifo_raddr_nx = fifo_raddr == FIFO_EADDR ? 'd0 : fifo_raddr + 'd1;

always_ff @(posedge aixh_core_clk) begin
  fifo_wen <= i_wenable;
  fifo_ren <= i_renable;
end

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if  (~aixh_core_rstn) begin
    fifo_waddr <= 'd0;
    fifo_raddr <= 'd0;
  end else begin
    if (fifo_wen) fifo_waddr <= fifo_waddr_nx;
    if (fifo_ren) fifo_raddr <= fifo_raddr_nx;
  end

always_ff @(posedge aixh_core_clk) begin
  if (fifo_wen) fifo_mem[fifo_waddr] <= dlyb_odata;
  if (fifo_ren) fifo_dout <= fifo_mem[fifo_raddr];
end

//------------------------------------------------------------------------------
// Output stages
//------------------------------------------------------------------------------
reg                               ostage0_valid;
wire [LQCELL_FWD_DWIDTH     -1:0] ostage0_rdata;

reg                               ostage1_valid;
reg  [2                     -1:0] ostage1_rmode;
reg  [LQCELL_FWD_DWIDTH     -1:0] ostage1_rdata;
wire [LQCELL_FWD_DWIDTH+128 -1:0] ostage1_mdata;

reg                               ostage2_valid;
reg  [LQCELL_FWD_DWIDTH     -1:0] ostage2_rdata;
reg  [64                    -1:0] ostage2_udata;

reg  [LQCELL_FWD_DWIDTH     -1:0] ostage3_rdata;


assign ostage0_rdata = fifo_dout;
assign ostage1_mdata = {i_vdata, ostage1_rdata, i_udata};
assign o_rmode = ostage1_rmode;
assign o_udata = ostage2_udata;
assign o_vdata = ostage0_rdata[0+:64];
assign o_rdata = ostage3_rdata;

always_ff @(posedge aixh_core_clk) begin
  ostage0_valid <= fifo_ren;
  ostage1_valid <= ostage0_valid;
  ostage1_rmode <= i_rmode;

  if (ostage0_valid) begin
    ostage1_rdata <= ostage0_rdata;
  end
end

always_ff @(posedge aixh_core_clk) begin
  ostage2_valid <= ostage1_valid;

  if (ostage1_valid) begin
    case (ostage1_rmode)
      RMODE_KEEP: begin
      end
      RMODE_STRAIGHT: begin
        ostage2_rdata <= ostage1_mdata[ 64+:LQCELL_FWD_DWIDTH];
      end
      RMODE_DN_SHIFT: begin
        ostage2_rdata <= ostage1_mdata[  0+:LQCELL_FWD_DWIDTH];
        ostage2_udata <= ostage1_mdata[LQCELL_FWD_DWIDTH+: 64];
      end
      RMODE_UP_SHIFT: begin
        ostage2_rdata <= ostage1_mdata[128+:LQCELL_FWD_DWIDTH];
      end
    endcase
  end
end

always_ff @(posedge aixh_core_clk2x)
  if (i_csync && ostage2_valid) begin
    ostage3_rdata <= ostage2_rdata;
  end

endmodule
`resetall
