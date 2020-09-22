//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Left / Processing-Tile) Cell 2x2
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

`ifdef AIXH_TARGET_ASIC
`ifdef AIXH_MXC_IPCELL_2X2
import AIXH_MXC_pkg::*;
module AIXH_MXC_LEFT_PTILE_cell
#(
   CELL_INDEX = 0
) (
   input  wire                              aixh_core_clk2x
  // LQCELL interface
  ,input  wire [LPCELL_FWI_DWIDTH     -1:0] i_lqc_dat
  ,output wire                              o_lqc_vld
  ,output wire [LPCELL_BWO_DWIDTH     -1:0] o_lqc_dat
  // Veritical LPCELL interface
  ,input  wire [LPCELL_DWD_CWIDTH     -1:0] i_lpc_cmd
  ,input  wire                              i_lpc_vld
  ,input  wire [LPCELL_DWD_DWIDTH     -1:0] i_lpc_dat
  ,output reg  [LPCELL_DWD_CWIDTH     -1:0] o_lpc_cmd
  ,output reg                               o_lpc_vld
  ,output reg  [LPCELL_DWD_DWIDTH     -1:0] o_lpc_dat
  // Horizontal IPCELL interface
  ,input  wire                              i_ipc_vld
  ,input  wire [IPCELL_BWD_DWIDTH     -1:0] i_ipc_dat
  ,output wire [IPCELL_FWD_CWIDTH     -1:0] o_ipc_cmd
  ,output wire [IPCELL_FWD_DWIDTH     -1:0] o_ipc_dat
);

function int SkewDepth(int idx);
  // Odd cell requires additional skew FF
  SkewDepth = idx[0] ? 1:0;
endfunction

localparam DRAIN_LATENCY = `AIXH_MXC_IPE_STAGES
                         + `AIXH_MXC_LOSPE_STAGES
                         + 3 + 3 + 2;

function int DeskewDepth(int idx);
  // Odd latency requires additional skew FF
  DeskewDepth = DRAIN_LATENCY[0] ? 1 : 0;
  // Even cell requires additional skew FF
  if (!idx[0]) DeskewDepth++;
endfunction

localparam SKEW_DEPTH = SkewDepth(CELL_INDEX);
localparam LAT_PIPES = DeskewDepth(CELL_INDEX);

localparam IPE_STAGES  = `AIXH_MXC_IPE_STAGES;
localparam ISPE_STAGES = `AIXH_MXC_LISPE_STAGES;
localparam OSPE_STAGES = `AIXH_MXC_LOSPE_STAGES;
// Pipeline stages from 'i_ipc_cmd' 
localparam OC_STAGES0 = IPE_STAGES + 3;           // IPCELL output
localparam OC_STAGES1 = OC_STAGES0 + 3;           // OSPE input
localparam OC_STAGES2 = OC_STAGES1 + OSPE_STAGES; // OSPE output
localparam OC_STAGES3 = OC_STAGES2 + LAT_PIPES;   // latency-matching pipe output
localparam OC_STAGES4 = OC_STAGES3 + 2;           // final output
// Pipeline stages from 'i_ipc_cmd.out*' 
localparam OM_STAGES1 = OC_STAGES1 - 6; 
localparam OM_STAGES2 = OC_STAGES2 - 6; 
localparam OM_STAGES3 = OC_STAGES3 - 6; 
localparam OM_STAGES4 = OC_STAGES4 - 6; 
// Pipeline stages from 'i_ipc_vld' 
localparam OV_STAGES1 = OC_STAGES1 - OC_STAGES0;
localparam OV_STAGES2 = OC_STAGES2 - OC_STAGES0;
localparam OV_STAGES3 = OC_STAGES3 - OC_STAGES0;
localparam OV_STAGES4 = OC_STAGES4 - OC_STAGES0;

localparam POOL_MEM_DEPTH = `AIXH_MXC_WIDTH;
localparam POOL_MEM_AWIDTH = $clog2(POOL_MEM_DEPTH);

LPCELL_Command                        i_cmd;
LPCELL_Command                        r_cmd;
IPCELL_Command                        ipc_cmd;

logic [8                        -1:0] cluster_ofs0;
logic [8                        -1:0] cluster_ofs0_p1;
logic [8                        -1:0] cluster_ofs1;
logic [8                        -1:0] cluster_ofs1_p1;
logic [8                        -1:0] cluster_ofs2;

logic                                 mac_knop0;
logic                                 mac_knop1;
logic [ISPE_STAGES              -1:0] mac_enable0_sr;
logic [ISPE_STAGES              -1:0] mac_enable1_sr;
logic [ISPE_STAGES-1            -1:0] mac_afresh_sr;
logic [5                        -1:0] mul_mode_sr[1];
logic [2                        -1:0] acc_mode_sr[ISPE_STAGES];
logic [OC_STAGES3               -1:0] oc_drain_req_sr;
logic [OC_STAGES1-1             -1:0] oc_start_blk0_sr;
logic [OC_STAGES1-1             -1:0] oc_start_blk1_sr;
logic [OC_STAGES3               -1:0] oc_nullify0_sr;
logic [OC_STAGES3               -1:0] oc_nullify1_sr;
logic [2                        -1:0] om_prec_mode_sr[OM_STAGES4-1];
logic                                 om_uint_mode_sr[OM_STAGES2-1];
logic [2                        -1:0] om_pool_mode_sr[OM_STAGES4-2];
logic                                 om_pack_done_sr[OM_STAGES4];
logic [OV_STAGES4-2             -1:0] ov_enable_sr;

logic                                 ispe_cvt_en0;
logic                                 ispe_cvt_en1;
logic                                 ispe_zpad_en0;
logic                                 ispe_zpad_en1;
logic                                 ispe_mul_enable0;
logic                                 ispe_mul_enable1;
logic                                 ispe_acc_enable0;
logic                                 ispe_acc_enable1;
logic                                 ispe_acc_afresh;
logic [3                        -1:0] ispe_mul_mode;
logic [2                        -1:0] ispe_acc_mode;
logic [64                       -1:0] ispe_ixdata0;
logic [64                       -1:0] ispe_ixdata1;
logic [32                       -1:0] ispe_oxdata0;
logic [32                       -1:0] ispe_oxdata1;
logic [ACCUM_BITS               -1:0] ispe_ozdata0;
logic [ACCUM_BITS               -1:0] ispe_ozdata1;
logic [ACCUM_BITS               -1:0] ispe_dzdata0;
logic [ACCUM_BITS               -1:0] ispe_dzdata1;

logic [ACCUM_BITS               -1:0] vi_mdata;
logic [SCALE_BITS               -1:0] vi_sdata;
logic [ACCUM_BITS               -1:0] vi_bdata;
logic [SCALE_BITS               -1:0] vo_sdata;
logic [ACCUM_BITS               -1:0] vo_bdata;

logic                                 mg_vsel0;
logic                                 mg_vsel1;
logic [ACCUM_BITS               -1:0] mg_vin0;
logic [ACCUM_BITS               -1:0] mg_vin1;
logic [ACCUM_BITS               -1:0] mg_hin0;
logic [ACCUM_BITS               -1:0] mg_hin1;
logic [ACCUM_BITS               -1:0] mg_hsum0;
logic [ACCUM_BITS               -1:0] mg_hsum1;
logic [ACCUM_BITS               -1:0] mg_hvsum0;
logic [ACCUM_BITS               -1:0] mg_hvsum1;
logic [ACCUM_BITS               -1:0] mg_hvsum0_nx;
logic [ACCUM_BITS               -1:0] mg_hvsum1_nx;

logic                                 ospe_enable;
logic                                 ospe_nullify0;
logic                                 ospe_nullify1;
logic [2                        -1:0] ospe_prec_mode;
logic                                 ospe_uint_mode;
logic [16                       -1:0] ospe_owdata0;
logic [16                       -1:0] ospe_owdata1;

logic                                 pool_rinit;
logic                                 pool_winit;
logic                                 pool_renable;
logic                                 pool_senable;
logic                                 pool_sbypass;
logic                                 pool_wenable;
logic [16*2                     -1:0] pool_mem[POOL_MEM_DEPTH];
logic [POOL_MEM_AWIDTH          -1:0] pool_raddr;
logic [POOL_MEM_AWIDTH          -1:0] pool_waddr;
logic                                 pool_scmp0;
logic                                 pool_scmp1;
logic [16                       -1:0] pool_idata0;
logic [16                       -1:0] pool_idata1;
logic                                 pool_inull0;
logic                                 pool_inull1;
logic                                 pool_mnull0;
logic                                 pool_mnull1;
logic [16                       -1:0] pool_rdata0;
logic [16                       -1:0] pool_rdata1;
logic [16                       -1:0] pool_sdata0;
logic [16                       -1:0] pool_sdata1;

logic                                 pack_enable;
logic                                 pack_valid;
logic [2                        -1:0] pack_prec;
logic [64                       -1:0] pack_data0;
logic [64                       -1:0] pack_data1;

// Inter-LPC pipeline
assign i_cmd = i_lpc_cmd;
assign o_lpc_cmd = r_cmd;

assign {vi_mdata, vi_sdata, vi_bdata} = i_lpc_dat;
assign o_lpc_dat = {mg_hvsum1, vo_sdata, vo_bdata};

assign cluster_ofs0 = i_cmd.cluster_ofs;
assign cluster_ofs0_p1 = cluster_ofs0 + 8'd1;
assign cluster_ofs1_p1 = cluster_ofs1 + 8'd1;

always_comb begin
  if (cluster_ofs0 == i_cmd.cluster_size)
       cluster_ofs1 = 8'd1;
  else cluster_ofs1 = cluster_ofs0_p1;

  if (cluster_ofs1 == i_cmd.cluster_size)
       cluster_ofs2 = 8'd1;
  else cluster_ofs2 = cluster_ofs1_p1;
end

always_ff @(posedge aixh_core_clk2x) begin 
  r_cmd <= i_cmd;
  r_cmd.cluster_ofs <= cluster_ofs2;
end


always_ff @(posedge aixh_core_clk2x) begin 
  o_lpc_vld <= i_lpc_vld;
  if (i_lpc_vld) begin
    vo_sdata <= vi_sdata;
    vo_bdata <= vi_bdata;
  end
end

// MAC enable gating
assign mac_knop0 = cluster_ofs0 <  i_cmd.cluster_blks ? ~i_cmd.fc_mode
                 : cluster_ofs0 == i_cmd.cluster_blks ? 1'b1 : 1'b0;
assign mac_knop1 = cluster_ofs1 <  i_cmd.cluster_blks ? ~i_cmd.fc_mode
                 : cluster_ofs1 == i_cmd.cluster_blks ? 1'b1 : 1'b0;

// Control pipeline
always_ff @(posedge aixh_core_clk2x) begin 
  mac_enable0_sr [0] <= i_cmd.mac_enable & mac_knop0;
  mac_enable1_sr [0] <= i_cmd.mac_enable & mac_knop1;
  mac_afresh_sr  [0] <= i_cmd.mac_afresh;
  mul_mode_sr    [0] <= i_cmd.mac_mode[6:2];
  acc_mode_sr    [0] <= i_cmd.mac_mode[1:0];
  oc_drain_req_sr[0] <= i_cmd.drain_req;
  om_prec_mode_sr[0] <= i_cmd.out_prec_mode;
  om_uint_mode_sr[0] <= i_cmd.out_uint_mode;
  om_pool_mode_sr[0] <= i_cmd.out_pool_mode;
  om_pack_done_sr[0] <= i_cmd.out_pack_done;
  ov_enable_sr   [0] <= i_ipc_vld;
  
  if (i_cmd.drain_req) begin
    oc_start_blk0_sr[0] <= cluster_ofs0 == 8'd1 || !i_cmd.fc_mode;
    oc_start_blk1_sr[0] <= cluster_ofs1 == 8'd1 || !i_cmd.fc_mode;
    oc_nullify0_sr  [0] <= ~mac_knop0;
    oc_nullify1_sr  [0] <= ~mac_knop1;
  end

`define __MOVE_SHIFT_REG(sr) \
  for (int i = 1; i < $size(sr); i++) sr[i] <= sr[i-1];
  `__MOVE_SHIFT_REG(mac_enable0_sr)
  `__MOVE_SHIFT_REG(mac_enable1_sr)
  `__MOVE_SHIFT_REG(mac_afresh_sr)
  `__MOVE_SHIFT_REG(mul_mode_sr)
  `__MOVE_SHIFT_REG(acc_mode_sr)
  `__MOVE_SHIFT_REG(oc_drain_req_sr)
  `__MOVE_SHIFT_REG(oc_start_blk0_sr)
  `__MOVE_SHIFT_REG(oc_start_blk1_sr)
  `__MOVE_SHIFT_REG(oc_nullify0_sr)
  `__MOVE_SHIFT_REG(oc_nullify1_sr)
  `__MOVE_SHIFT_REG(om_prec_mode_sr)
  `__MOVE_SHIFT_REG(om_uint_mode_sr)
  `__MOVE_SHIFT_REG(om_pool_mode_sr)
  `__MOVE_SHIFT_REG(om_pack_done_sr)
  `__MOVE_SHIFT_REG(ov_enable_sr)
`undef __MOVE_SHIFT_REG
end

// Skew LQC data if required
if (SKEW_DEPTH > 0) begin: g_skew
  localparam DEPTH = SKEW_DEPTH > 0 ? SKEW_DEPTH : 1;
  logic [LPCELL_FWI_DWIDTH    -1:0] pipe[DEPTH];

  always_ff @(posedge aixh_core_clk2x) begin
    pipe[0] <= i_lqc_dat;
    for (int i = 1; i < DEPTH; i++) begin
      pipe[i] <= pipe[i-1];
    end
  end

  assign {ispe_ixdata1, ispe_ixdata0} = pipe[DEPTH-1];
end else begin
  assign {ispe_ixdata1, ispe_ixdata0} = i_lqc_dat;
end

// Zero-padding control
always_ff @(posedge aixh_core_clk2x) begin
  case (i_cmd.in_zpad_mode)
    ZPAD_ABLK : ispe_zpad_en0 <= 1'b1;
    ZPAD_FBLK : ispe_zpad_en0 <= cluster_ofs0    == 8'd1;
    ZPAD_LBLK1: ispe_zpad_en0 <= cluster_ofs0    >= i_cmd.cluster_blks;
    ZPAD_LBLK2: ispe_zpad_en0 <= cluster_ofs0_p1 >= i_cmd.cluster_blks;
    default   : ispe_zpad_en0 <= 1'b0;
  endcase
  
  case (i_cmd.in_zpad_mode)
    ZPAD_ABLK : ispe_zpad_en1 <= 1'b1;
    ZPAD_FBLK : ispe_zpad_en1 <= cluster_ofs1    == 8'd1;
    ZPAD_LBLK1: ispe_zpad_en1 <= cluster_ofs1    >= i_cmd.cluster_blks;
    ZPAD_LBLK2: ispe_zpad_en1 <= cluster_ofs1_p1 >= i_cmd.cluster_blks;
    default   : ispe_zpad_en1 <= 1'b0;
  endcase
end

// IPE and ISPE control
assign ispe_cvt_en0 = mac_enable0_sr[0];
assign ispe_cvt_en1 = mac_enable1_sr[0];

always_ff @(posedge aixh_core_clk2x) begin
  ipc_cmd.mul_enable <={|mac_enable1_sr [IPE_STAGES-2:0]
                       ,|mac_enable0_sr [IPE_STAGES-2:0]};
  ipc_cmd.acc_enable <={ mac_enable1_sr [IPE_STAGES-1]
                       , mac_enable0_sr [IPE_STAGES-1]};
  ipc_cmd.acc_afresh <=  mac_afresh_sr  [IPE_STAGES-2];
  ipc_cmd.mul_mode   <=  mul_mode_sr    [0];
  ipc_cmd.acc_mode   <=  acc_mode_sr    [IPE_STAGES-1];
  ipc_cmd.drain_req0 <=  oc_drain_req_sr[IPE_STAGES-1];
  ipc_cmd.drain_req1 <=  oc_drain_req_sr[IPE_STAGES-1]
                        |oc_drain_req_sr[IPE_STAGES  ];
 
  ispe_mul_enable0 <= |mac_enable0_sr[ISPE_STAGES-2:0];
  ispe_mul_enable1 <= |mac_enable1_sr[ISPE_STAGES-2:0];
  ispe_acc_enable0 <=  mac_enable0_sr[ISPE_STAGES-1];
  ispe_acc_enable1 <=  mac_enable1_sr[ISPE_STAGES-1];
  ispe_acc_afresh  <=  mac_afresh_sr [ISPE_STAGES-2];
  ispe_mul_mode    <=  mul_mode_sr   [0][2:0];
  ispe_acc_mode    <=  acc_mode_sr   [ISPE_STAGES-1];
end

// ISPE instances
AIXH_MXC_LEFT_PTILE_CELL_ispe u_ispe0(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.cvt_enable          (ispe_cvt_en0         )
  ,.relu_enable         (r_cmd.in_relu_en     )
  ,.zpad_enable         (ispe_zpad_en0        )
  ,.half_sel            (r_cmd.in_half_sel    )
  ,.cvt_mode            (r_cmd.in_cvt_mode    )
  ,.uint_mode           (r_cmd.in_uint_mode   )

  ,.mul_enable          (ispe_mul_enable0     )
  ,.acc_enable          (ispe_acc_enable0     )
  ,.acc_afresh          (ispe_acc_afresh      )
  ,.mul_mode            (ispe_mul_mode        )
  ,.acc_mode            (ispe_acc_mode        )
  ,.ixdata              (ispe_ixdata0         )
  ,.oxdata              (ispe_oxdata0         )
  ,.ozdata              (ispe_ozdata0         )
);

AIXH_MXC_LEFT_PTILE_CELL_ispe u_ispe1(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.cvt_enable          (ispe_cvt_en1         )
  ,.relu_enable         (r_cmd.in_relu_en     )
  ,.zpad_enable         (ispe_zpad_en1        )
  ,.half_sel            (r_cmd.in_half_sel    )
  ,.cvt_mode            (r_cmd.in_cvt_mode    )
  ,.uint_mode           (r_cmd.in_uint_mode   )

  ,.mul_enable          (ispe_mul_enable1     )
  ,.acc_enable          (ispe_acc_enable1     )
  ,.acc_afresh          (ispe_acc_afresh      )
  ,.mul_mode            (ispe_mul_mode        )
  ,.acc_mode            (ispe_acc_mode        )
  ,.ixdata              (ispe_ixdata1         )
  ,.oxdata              (ispe_oxdata1         )
  ,.ozdata              (ispe_ozdata1         )
);


// Output to IPCELL
assign o_ipc_dat = {ispe_oxdata1, ispe_oxdata0};
assign o_ipc_cmd = ipc_cmd;

// ISPE drain
always_ff @(posedge aixh_core_clk2x)
  if (ipc_cmd.drain_req0) begin
    ispe_dzdata0 <= ispe_ozdata0;
    ispe_dzdata1 <= ispe_ozdata1;
  end

// Merge accumualtors
assign mg_vsel0 = oc_start_blk0_sr[OC_STAGES1-2];
assign mg_vsel1 = oc_start_blk1_sr[OC_STAGES1-2];
assign mg_vin0  = mg_vsel0 ? vi_bdata : vi_mdata;
assign mg_vin1  = mg_vsel1 ? vi_bdata : mg_hvsum0_nx;
    
assign mg_hvsum0_nx = mg_hsum0 + mg_vin0;
assign mg_hvsum1_nx = mg_hsum1 + mg_vin1;

always_ff @(posedge aixh_core_clk2x) begin
  if (i_ipc_vld) begin
    {mg_hin1, mg_hin0} <= i_ipc_dat;
  end
  if (ov_enable_sr[0] ) begin
    mg_hsum0 <= mg_hin0 - ispe_dzdata0;
    mg_hsum1 <= mg_hin1 - ispe_dzdata1;
  end
  if (ov_enable_sr[1] ) begin
    mg_hvsum0 <= mg_hvsum0_nx;
    mg_hvsum1 <= mg_hvsum1_nx;
  end
end

// OSPE control
assign ospe_nullify0  = oc_nullify0_sr [OC_STAGES1-1];
assign ospe_nullify1  = oc_nullify1_sr [OC_STAGES1-1];
assign ospe_prec_mode = om_prec_mode_sr[OM_STAGES2-2];
assign ospe_uint_mode = om_uint_mode_sr[OM_STAGES2-2];

always_ff @(posedge aixh_core_clk2x) begin
  ospe_enable <= |ov_enable_sr[1+:OSPE_STAGES];
end

// OSPE instance
AIXH_MXC_LEFT_PTILE_CELL_ospe u_ospe0(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.enable              (ospe_enable          )
  ,.nullify             (ospe_nullify0        )
  ,.prec_mode           (ospe_prec_mode       )
  ,.uint_mode           (ospe_uint_mode       )
  ,.isdata              (vo_sdata             )
  ,.imdata              (mg_hvsum0            )
  ,.owdata              (ospe_owdata0         )
);

AIXH_MXC_LEFT_PTILE_CELL_ospe u_ospe1(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.enable              (ospe_enable          )
  ,.nullify             (ospe_nullify1        )
  ,.prec_mode           (ospe_prec_mode       )
  ,.uint_mode           (ospe_uint_mode       )
  ,.isdata              (vo_sdata             )
  ,.imdata              (mg_hvsum1            )
  ,.owdata              (ospe_owdata1         )
);

//
// Latency matching pipeline
//
if (LAT_PIPES == 0) begin
  assign {pool_idata1, pool_idata0} = {ospe_owdata1, ospe_owdata0};
end else begin: LAT_PIPE
  localparam PIPES = LAT_PIPES > 0 ? LAT_PIPES : 1;
  logic [16*2   -1:0] pipe[PIPES];
  
  assign {pool_idata1, pool_idata0} = pipe[PIPES-1];

  always_ff @(posedge aixh_core_clk2x) begin
    pipe[0] <= {ospe_owdata1, ospe_owdata0};
    for (int i = 1; i < PIPES; i++) begin
      pipe[i] <= pipe[i-1];
    end
  end
end

//
// Pooling
//
assign pool_rinit   = oc_drain_req_sr[OC_STAGES3-3];
assign pool_winit   = oc_drain_req_sr[OC_STAGES3-1];
assign pool_senable = ov_enable_sr   [OV_STAGES3-1];
assign pool_inull0  = oc_nullify0_sr [OC_STAGES3-1];
assign pool_inull1  = oc_nullify1_sr [OC_STAGES3-1];

always @(posedge aixh_core_clk2x) begin
  case (om_pool_mode_sr[OM_STAGES3-3])
    POOL_INNER,
    POOL_LAST : pool_renable <= ov_enable_sr[OV_STAGES3-3];
    default   : pool_renable <= 1'b0;
  endcase

  case (om_pool_mode_sr[OM_STAGES3-2])
    POOL_BYPASS,
    POOL_FIRST : pool_sbypass <= 1'b1;
    default    : pool_sbypass <= 1'b0;
  endcase

  case (om_pool_mode_sr[OM_STAGES3-1])
    POOL_FIRST,
    POOL_INNER: pool_wenable <= ov_enable_sr[OV_STAGES3-1];
    default   : pool_wenable <= 1'b0;
  endcase
end


// Memory address generation
always @(posedge aixh_core_clk2x) begin
  if      (pool_rinit  ) pool_raddr <=              POOL_MEM_AWIDTH'(0);
  else if (pool_renable) pool_raddr <= pool_raddr + POOL_MEM_AWIDTH'(1);
  
  if      (pool_winit  ) pool_waddr <=              POOL_MEM_AWIDTH'(0);
  else if (pool_wenable) pool_waddr <= pool_waddr + POOL_MEM_AWIDTH'(1);
end

// Memory access
always @(posedge aixh_core_clk2x) begin
  if (pool_renable) begin
    {pool_rdata1, pool_rdata0} <= pool_mem[pool_raddr];
  end
  
  if (pool_wenable) begin
    pool_mem[pool_waddr] <= {pool_sdata1, pool_sdata0};
  end
end

// Compute
assign pool_scmp0 = $signed(pool_rdata0) < $signed(pool_idata0);
assign pool_scmp1 = $signed(pool_rdata1) < $signed(pool_idata1);

always @(posedge aixh_core_clk2x)
  if (pool_senable) begin
    if ((pool_scmp0 && !pool_inull0) || pool_mnull0 || pool_sbypass) begin
      pool_mnull0 <= pool_inull0;
      pool_sdata0 <= pool_idata0;
    end else begin
      pool_sdata0 <= pool_rdata0;
    end
    
    if ((pool_scmp1 && !pool_inull1) || pool_mnull1 || pool_sbypass) begin
      pool_mnull1 <= pool_inull1;
      pool_sdata1 <= pool_idata1;
    end else begin
      pool_sdata1 <= pool_rdata1;
    end
  end

//
// Packing
//
assign pack_prec = om_prec_mode_sr[OM_STAGES4-2];

always @(posedge aixh_core_clk2x) begin
  case (om_pool_mode_sr[OM_STAGES4-3])
    POOL_BYPASS,
    POOL_LAST  : pack_enable <= ov_enable_sr[OV_STAGES4-3];
    default    : pack_enable <= 1'b0;
  endcase

  pack_valid <= pack_enable & om_pack_done_sr[OM_STAGES4-1];
end

always_ff @(posedge aixh_core_clk2x)
  if (pack_enable) begin
    case (pack_prec)
      2'b00: pack_data0 <= {pool_sdata0[0+: 4], pack_data0[63: 4]};
      2'b01: pack_data0 <= {pool_sdata0[0+: 8], pack_data0[63: 8]};
      2'b10: pack_data0 <= {pool_sdata0[0+:16], pack_data0[63:16]};
    endcase
    case (pack_prec)
      2'b00: pack_data1 <= {pool_sdata1[0+: 4], pack_data1[63: 4]};
      2'b01: pack_data1 <= {pool_sdata1[0+: 8], pack_data1[63: 8]};
      2'b10: pack_data1 <= {pool_sdata1[0+:16], pack_data1[63:16]};
    endcase
  end

assign o_lqc_vld = pack_valid;
assign o_lqc_dat = {pack_data1, pack_data0};

endmodule
`endif // AIXH_MXC_IPCELL_1X2
`endif // AIXH_TARGET_ASIC
`resetall
