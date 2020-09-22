//==============================================================================
// AIX-H Project
//
// Module: (MxConv) Controller
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

import AIXH_MXC_pkg::*;
module AIXH_MXC_ctrl 
(
   input  wire                                        aixh_core_clk
  ,input  wire                                        aixh_core_clk2x
  ,input  wire                                        aixh_core_rstn
  ,input  wire                                        aixh_core_div_rstn

  // Command interface (DCS)
  ,input  wire                                        cmdw_en
  ,input  wire                                        cmdw_last
  ,input  wire [64                              -1:0] cmdw_data
  ,input  wire                                        cmdx_req
  ,output reg                                         cmdx_done
  
  // LTC interface
  ,input  wire [LTC_SLICES                      -1:0] ltc_arupdate
  ,output wire [LTC_SLICES                      -1:0] ltc_arvalid
  ,output wire [LTC_SLICES * LTC_SLICE_AWIDTH   -1:0] ltc_araddr
  ,output wire [LTC_SLICES                      -1:0] ltc_rupdate
  ,input  wire [LTC_SLICES                      -1:0] ltc_rvalid
  
  ,input  wire [LTC_SLICES                      -1:0] ltc_awupdate
  ,output wire [LTC_SLICES                      -1:0] ltc_awvalid
  ,output wire [LTC_SLICES * LTC_SLICE_AWIDTH   -1:0] ltc_awaddr

  // UTC interface
  ,output wire [UTC_SLICES                      -1:0] utc_arvalid
  ,output wire [UTC_SLICES * UTC_SLICE_AWIDTH   -1:0] utc_araddr
  ,output wire [UTC_SLICES                      -1:0] utc_rvalid

  // Internal interface
  ,output wire                                        uqc_csync
  ,output wire [UPCELL_FWD_CWIDTH               -1:0] upc_cmd
  ,input  wire                                        upc_vld
  ,output wire                                        lqc_icsync
  ,output wire                                        lqc_ocsync
  ,output wire                                        lqc_wenable
  ,output wire                                        lqc_renable
  ,output wire [2                               -1:0] lqc_rmode
  ,output wire [LPCELL_DWD_CWIDTH               -1:0] lpc_cmd

  ,output reg  [32                              -1:0] dbg_out
);

localparam DCS_CMDW_PIPES = `AIXH_MXC_DCS_CMDW_PIPES;
localparam DCS_CMDX_PIPES = `AIXH_MXC_DCS_CMDX_PIPES;

localparam LTC_ARCREDITS = $unsigned(`AIXH_LTC_MXC_ARADDR_QDEPTH);
localparam LTC_ARCWIDTH  = $clog2(LTC_ARCREDITS + 1);
localparam LTC_RCREDITS  = $unsigned(`AIXH_LTC_MXC_RDATA_QDEPTH);
localparam LTC_RCWIDTH   = $clog2(LTC_RCREDITS + 1);
localparam LTC_AWCREDITS = $unsigned(`AIXH_LTC_MXC_AWADDR_QDEPTH);
localparam LTC_AWCWIDTH  = $clog2(LTC_AWCREDITS + 1);

localparam LTC_ARADDR_PIPES   = `AIXH_MXC_LTC_ARADDR_PIPES;
localparam LTC_ARUPDATE_PIPES = `AIXH_MXC_LTC_ARUPDATE_PIPES;
localparam LTC_RUPDATE_PIPES  = `AIXH_MXC_LTC_RUPDATE_PIPES;
localparam LTC_AWADDR_PIPES   = `AIXH_MXC_LTC_AWADDR_PIPES;
localparam LTC_AWUPDATE_PIPES = `AIXH_MXC_LTC_AWUPDATE_PIPES;
localparam UTC_ARADDR_PIPES   = `AIXH_MXC_UTC_ARADDR_PIPES;

localparam UTC_DEPTH     = $unsigned(`AIXH_UTC_DEPTH);
localparam UTC_SLICE_EADDR  = UTC_SLICE_AWIDTH'(UTC_DEPTH - 1);
localparam UTC_INTLV_STRIDE = UTC_SLICE_AWIDTH'(MXC_HEIGHT / MXC_WIDTH);
localparam UTC_INTLV_GADDR  = UTC_SLICE_AWIDTH'(UTC_DEPTH - UTC_INTLV_STRIDE);

localparam XREPEATER_MASK = IPTILE_XCOUNT'(`AIXH_MXC_IPTILE_XREPEATER_MASK);
localparam YREPEATER_MASK = IPTILE_YCOUNT'(`AIXH_MXC_IPTILE_YREPEATER_MASK);

// Raw command queue
localparam CMDQ_DEPTH  = $unsigned(`AIXH_DCS_MXC_CMD_QDEPTH);
localparam CMDQ_AWIDTH = $clog2(CMDQ_DEPTH);
localparam CMDQ_EADDR  = CMDQ_AWIDTH'(CMDQ_DEPTH - 1);

// Middle-end command queue
localparam MCMDQ_DEPTH  = $unsigned(`AIXH_LTC_MXC_ARADDR_QDEPTH);
localparam MCMDQ_AWIDTH = $clog2(MCMDQ_DEPTH);
localparam MCMDQ_EADDR  = MCMDQ_AWIDTH'(MCMDQ_DEPTH - 1);

// Backend command pipeline
localparam REQ2LPC_LATENCY = 5;
localparam REQ2UPC_LATENCY = `AIXH_UTC_MXC_ARADDR_PIPES
                           + `AIXH_UTC_MXC_READ_LATENCY
                           + `AIXH_UTC_MXC_RDATA_PIPES
                           + 1;

localparam BCMD_PIPES = REQ2LPC_LATENCY-2 > REQ2UPC_LATENCY-2+UTC_ARADDR_PIPES
                      ? REQ2LPC_LATENCY-2 : REQ2UPC_LATENCY-2+UTC_ARADDR_PIPES;

localparam LQC_REQ_PIPES = BCMD_PIPES - (REQ2LPC_LATENCY-2);
localparam UTC_REQ_PIPES = BCMD_PIPES - (REQ2UPC_LATENCY-2);
localparam DCG_REQ_PIPES = 2 + (XREPEATER_MASK[0] ? 1 : 0);

localparam UTC_SLICE_SKEWS = `AIXH_UTC_SLICE_BLOCKS / IPCELL_WIDTH / 2;
localparam LTC_FULL_SKEWS  = `AIXH_LTC_BLOCKS / IPCELL_HEIGHT / 2;

localparam DCG2LTC_PIPES = Dag2LtcPipes();

// Startup delay cycles
localparam SDLY_CYCLES = `AIXH_MXC_HEIGHT / IPCELL_HEIGHT / 2
                       + `AIXH_MXC_WIDTH  / IPCELL_WIDTH
                       + Dag2LtcPipes() 
                       + DipExtraCycle();
localparam SDLY_CWIDTH = $clog2(SDLY_CYCLES);

// Write-address tracking queue
localparam WATQ_DEPTH = `AIXH_MXC_WATQ_DEPTH;
localparam WATQ_AWIDTH = $clog2(WATQ_DEPTH);
localparam WATQ_EADDR  = WATQ_AWIDTH'(WATQ_DEPTH - 1);


function automatic int Dag2LtcPipes();
  int drain_latency = 0;
  drain_latency = `AIXH_MXC_IPE_STAGES
                + `AIXH_MXC_LOSPE_STAGES
                + 3 + 3 + 2;
  for (int i = 1; i < IPTILE_YCOUNT; i++) begin
    if (YREPEATER_MASK[i]) drain_latency++;
  end
  
  Dag2LtcPipes = (drain_latency+1)/2
               - 2
               + (LTC_FULL_SKEWS);
endfunction

function int DipExtraCycle();
  DipExtraCycle = 0;
  for (int i = 1; i < IPTILE_XCOUNT; i++) begin
    if (XREPEATER_MASK[i]) DipExtraCycle++; 
  end
endfunction

// Frontend State
typedef enum logic [2:0] {
  FE_WAIT      = 3'd0,
  FE_FETCH     = 3'd1,
  FE_SETUP     = 3'd2,
  FE_KLOOP     = 3'd3,
  FE_DRAIN_PRE = 3'd4,
  FE_DRAIN_REQ = 3'd5,
  FE_FINISH    = 3'd6
} FeState;

// Frontend Command
typedef struct packed {
  logic [LTC_SLICE_AWIDTH         -1:0] filter_address; 
  logic [16                       -1:0] out_mixp_precs; 
  logic [LTC_SLICE_AWIDTH         -1:0] out_dx_astride; 
  logic [LTC_SLICE_AWIDTH         -1:0] out_dy_astride; 
  logic [LTC_SLICE_AWIDTH         -1:0] out_sx_astride; 
  logic [LTC_SLICE_AWIDTH         -1:0] out_sy_astride; 
  logic [LTC_SLICE_AWIDTH         -1:0] out_address   ; 
  logic [16                       -1:0] out_width     ; 
  logic [16                       -1:0] out_blk_height; 
  logic [LTC_SLICE_AWIDTH         -1:0] in_dx_astride ; 
  logic [LTC_SLICE_AWIDTH         -1:0] in_dy_astride ; 
  logic [LTC_SLICE_AWIDTH         -1:0] in_address1   ; 
  logic [LTC_SLICE_AWIDTH         -1:0] in_address0   ; 
  logic [16                       -1:0] in_width1     ; 
  logic [16                       -1:0] in_width0     ; 
  logic [16                       -1:0] in_blk_height1; 
  logic [16                       -1:0] in_blk_height0; 
  logic [16                       -1:0] in_cwords     ; 
  logic [8                        -1:0] in_xoffset    ; 
  logic [8                        -1:0] in_yoffset    ; 
  logic [8                        -1:0] cluster_blks  ; 
  logic [8                        -1:0] cluster_size  ; 
  logic [7                        -1:0] active_upcells;
  logic [4                        -1:0] slide_xstride ;
  logic [4                        -1:0] slide_ystride ;
  logic [4                        -1:0] filter_xdilate;
  logic [4                        -1:0] filter_ydilate;
  logic [4                        -1:0] filter_width  ;
  logic [4                        -1:0] filter_height ;
  logic [1                        -1:0] filter_intlv  ;
  logic [6                        -1:0] out_cwords    ;
  logic [4                        -1:0] out_xsampling ;
  logic [4                        -1:0] out_ysampling ;
  logic [1                        -1:0] out_maxpool   ;
  logic [1                        -1:0] out_unsigned  ;
  logic [2                        -1:0] out_precision ;
  logic [1                        -1:0] in_mixp_blend ;
  logic [1                        -1:0] in_relu       ;
  logic [1                        -1:0] in_packed     ;
  logic [1                        -1:0] in_indirect   ;
  logic [1                        -1:0] in_unsigned   ;
  logic [2                        -1:0] in_precision  ;
  logic [1                        -1:0] in_padding_off;
  logic [1                        -1:0] hyper_cluster ;
  logic [1                        -1:0] fc_last       ;
  logic [1                        -1:0] fc_first      ;
  logic [1                        -1:0] fc_mode       ;
  //-------------------
  // Dervied parameters
  //-------------------
  // # of input channel-word processing phases
  logic [1                        -1:0] in_phases;
} FeCommand;

// Output address generation code
typedef enum logic [2:0] {
  OAG_KEEP   = 3'd0,
  OAG_INIT   = 3'd1,
  OAG_SX_INC = 3'd2,
  OAG_SY_INC = 3'd3,
  OAG_DX_INC = 3'd4,
  OAG_DY_INC = 3'd5
} OagCode;

typedef struct packed {
  logic                                 mac_enable;
  logic                                 mac_afresh;
  logic [14                       -1:0] mac_mode;
  logic                                 drain_pre;
  logic                                 drain_req;
  logic                                 drain_last;
  logic                                 drain_fake;
  logic                                 fc_mode;
  logic [8                        -1:0] cluster_size;
  logic [8                        -1:0] cluster_blks;
  logic [7                        -1:0] active_upcells;
  logic [2                        -1:0] in_cvt_mode;
  logic [UTC_SLICE_AWIDTH         -1:0] ui_address;
  logic                                 ui_read_en;
  logic                                 li_read_en;
  logic [2                        -1:0] li_read_mode;
  logic                                 li_uint_mode;
  logic                                 li_half_ofs;
  logic                                 li_relu_en;
  logic [3                        -1:0] li_zpad_mode;
  logic [6                        -1:0] lo_write_len;
  logic [LTC_SLICE_AWIDTH         -1:0] lo_address;
  logic [2                        -1:0] lo_prec_mode;
  logic [16                       -1:0] lo_mixp_precs;
  logic                                 lo_uint_mode;
  logic [2                        -1:0] lo_pool_mode;
} MeCommand;

typedef struct packed {
  logic                                 mac_enable;
  logic                                 mac_afresh;
  logic [14                       -1:0] mac_mode;
  logic                                 drain_pre;
  logic                                 drain_req;
  logic                                 drain_last;
  logic                                 drain_fake;
  logic                                 fc_mode;
  logic [8                        -1:0] cluster_size;
  logic [8                        -1:0] cluster_blks;
  logic [7                        -1:0] active_upcells;
  logic [2                        -1:0] in_cvt_mode;
  logic                                 li_half_ofs;
  logic                                 li_uint_mode;
  logic                                 li_relu_en;
  logic [3                        -1:0] li_zpad_mode;
  logic [LTC_SLICE_AWIDTH         -1:0] lo_address;
  logic [2                        -1:0] lo_prec_mode;
  logic [16                       -1:0] lo_mixp_precs;
  logic                                 lo_uint_mode;
  logic [2                        -1:0] lo_pool_mode;
} BeCommand;

typedef struct packed {
  logic                                 mac_enable;
  logic                                 mac_afresh;
  logic [14                       -1:0] mac_mode;
  logic                                 drain_pre;
  logic                                 drain_req;
  logic                                 drain_last;
  logic                                 fc_mode;
  logic [8                        -1:0] cluster_size;
  logic [8                        -1:0] cluster_blks;
  logic [7                        -1:0] active_upcells;
  logic [2                        -1:0] in_cvt_mode;
  logic                                 li_half_ofs;
  logic                                 li_uint_mode;
  logic                                 li_relu_en;
  logic [3                        -1:0] li_zpad_mode;
  logic [2                        -1:0] lo_prec_mode;
  logic                                 lo_uint_mode;
  logic [2                        -1:0] lo_pool_mode;
  logic                                 lo_pack_done;
} PostCommand;

typedef struct packed {
  logic                                 last;
  logic                                 fake;
  logic [7                        -1:0] count;
  logic [2                        -1:0] prec_mode;
  logic [16                       -1:0] mixp_precs;
  logic                                 uint_mode;
  logic [2                        -1:0] pool_mode;
  logic [LTC_SLICE_AWIDTH         -1:0] address;
} DcgRequest;

logic                                 clk2x_phase_si;
logic [4                        -1:0] clk2x_phase_sr;
logic                                 clk2x_phase;
  
logic                                 cmdw_en_so;
logic                                 cmdw_last_so;
logic [64                       -1:0] cmdw_data_so;
logic                                 cmdx_req_so;
logic                                 cmdx_done_si;

logic                                 fstall;
FeState                               fstate;
FeState                               fstate_nx;
FeCommand                             fcmd;

CTRL_RawCommand0                      rcmd0;
CTRL_RawCommand1                      rcmd1;
CTRL_RawCommand2                      rcmd2;
CTRL_RawCommand3                      rcmd3;
CTRL_RawCommand4                      rcmd4;
CTRL_RawCommand5                      rcmd5;

logic                                 fetch_start;
logic [8                        -1:0] fetch_step;
logic                                 finish_start;
logic [4                        -1:0] finish_step;
logic [2                        -1:0] ready_cmds;

logic                                 sdly_active;
logic [SDLY_CWIDTH              -1:0] sdly_count;

logic [64                       -1:0] cmdq_mem[CMDQ_DEPTH];
logic [64                       -1:0] cmdq_rdata;
logic [64                       -1:0] cmdq_odata;
logic [CMDQ_AWIDTH              -1:0] cmdq_wptr;
logic [CMDQ_AWIDTH              -1:0] cmdq_wptr_p1;
logic [CMDQ_AWIDTH              -1:0] cmdq_rptr;
logic [CMDQ_AWIDTH              -1:0] cmdq_rptr_p1;
logic [CMDQ_AWIDTH              -1:0] cmdq_sptr;
logic [CMDQ_AWIDTH              -1:0] cmdq_nptr_mem[2];
logic                                 cmdq_nptr_widx;
logic                                 cmdq_nptr_ridx;

logic [16                       -1:0] pg_oxr;
logic [16                       -1:0] pg_oyr;
logic [4                        -1:0] pg_sx;
logic [4                        -1:0] pg_sy;
logic [16                       -1:0] pg_kw;
logic [16                       -1:0] pg_kh;
logic [16                       -1:0] pg_kxr;
logic [16                       -1:0] pg_kyr;
logic                                 pg_ip;
logic [16                       -1:0] pg_ic;
logic [16                       -1:0] pg_icr;
logic [16+1                     -1:0] pg_ix0;
logic [16+1                     -1:0] pg_iy0;
logic [16+1                     -1:0] pg_ix1;
logic [16+1                     -1:0] pg_iy1;
logic [16+1                     -1:0] pg_ix2;
logic [16+1                     -1:0] pg_iy2;
logic [16+1                     -1:0] pg_ix3;
logic [16+1                     -1:0] pg_iy3;
logic                                 pg_ip_end;
logic                                 pg_ic_end;
logic                                 pg_kx_end;
logic                                 pg_ky_end;
logic                                 pg_k_end;
logic                                 pg_sx_end;
logic                                 pg_sy_end;
logic                                 pg_ox_end;
logic                                 pg_oy_end;
logic                                 pg_all_end;

logic                                 cg0_enable;
logic                                 cg0_valid;
logic                                 cg0_mac_afresh;
OagCode                               cg0_lo_ag_code;
logic [2                        -1:0] cg0_lo_pool_mode;

logic                                 cg1_enable;
logic                                 cg1_valid;
logic                                 cg1_cluster_full;
logic                                 cg1_mac_enable;
logic                                 cg1_mac_afresh;
logic                                 cg1_drain_pre;
logic                                 cg1_drain_req;
logic                                 cg1_drain_last;
logic                                 cg1_drain_fake;
logic                                 cg1_in_phase;
logic [LTC_SLICE_AWIDTH         -1:0] cg1_in_cpos;
logic                                 cg1_ui_read_en;
logic                                 cg1_li_read_en;
logic [2                        -1:0] cg1_li_read_mode;
logic                                 cg1_li_avalid;
logic                                 cg1_li_aselect;
logic [LTC_SLICE_AWIDTH         -1:0] cg1_li_xpos;
logic [LTC_SLICE_AWIDTH         -1:0] cg1_li_ypos;
logic [LTC_SLICE_AWIDTH         -1:0] cg1_li_yofs;
logic                                 cg1_li_zpad_fblk;
logic                                 cg1_li_zpad_lblk1;
logic                                 cg1_li_zpad_lblk2;
OagCode                               cg1_lo_ag_code;
logic [2                        -1:0] cg1_lo_pool_mode;

logic                                 cg2_enable;
logic                                 cg2_valid;
logic                                 cg2_cluster_full;
logic                                 cg2_mac_enable;
logic                                 cg2_mac_afresh;
logic                                 cg2_drain_pre;
logic                                 cg2_drain_req;
logic                                 cg2_drain_last;
logic                                 cg2_drain_fake;
logic                                 cg2_in_phase;
logic [LTC_SLICE_AWIDTH         -1:0] cg2_in_cpos;
logic                                 cg2_ui_read_en;
logic                                 cg2_li_read_en;
logic [2                        -1:0] cg2_li_read_mode;
logic                                 cg2_li_half_ofs;
logic                                 cg2_li_avalid;
logic                                 cg2_li_aselect;
logic [LTC_SLICE_AWIDTH         -1:0] cg2_li_xofs;
logic [LTC_SLICE_AWIDTH         -1:0] cg2_li_yofs;
logic                                 cg2_li_zpad_fblk;
logic                                 cg2_li_zpad_lblk1;
logic                                 cg2_li_zpad_lblk2;
OagCode                               cg2_lo_ag_code;
logic [2                        -1:0] cg2_lo_pool_mode;

logic                                 cg3_enable;
logic                                 cg3_valid;
logic [8                        -1:0] cg3_cluster_blks;
logic                                 cg3_mac_enable;
logic                                 cg3_mac_afresh;
logic                                 cg3_drain_pre;
logic                                 cg3_drain_req;
logic                                 cg3_drain_last;
logic                                 cg3_drain_fake;
logic                                 cg3_in_phase;
logic [8                        -1:0] cg3_in_prec_modes;
logic [3                        -1:0] cg3_in_prec_msel;
logic                                 cg3_in_prec_mode;
logic                                 cg3_ui_read_en;
logic                                 cg3_li_read_en;
logic [2                        -1:0] cg3_li_read_mode;
logic                                 cg3_li_half_ofs;
logic                                 cg3_li_avalid;
logic [LTC_SLICE_AWIDTH         -1:0] cg3_li_abase;
logic [LTC_SLICE_AWIDTH         -1:0] cg3_li_caoffset;
logic [LTC_SLICE_AWIDTH         -1:0] cg3_li_xaoffset;
logic [LTC_SLICE_AWIDTH         -1:0] cg3_li_yaoffset;
logic                                 cg3_li_zpad_fblk;
logic                                 cg3_li_zpad_lblk1;
logic                                 cg3_li_zpad_lblk2;
OagCode                               cg3_lo_ag_code;
logic [2                        -1:0] cg3_lo_pool_mode;

logic                                 cg4_enable;
logic                                 cg4_valid;
logic [8                        -1:0] cg4_cluster_blks;
logic                                 cg4_mac_enable;
logic                                 cg4_mac_afresh;
logic [14                       -1:0] cg4_mac_mode;
logic                                 cg4_drain_pre;
logic                                 cg4_drain_req;
logic                                 cg4_drain_last;
logic                                 cg4_drain_fake;
logic [2                        -1:0] cg4_in_cvt_mode;
logic [UTC_SLICE_AWIDTH         -1:0] cg4_ui_address;
logic [UTC_SLICE_AWIDTH         -1:0] cg4_ui_address_nx;
logic                                 cg4_ui_read_en;
logic [LTC_SLICE_AWIDTH         -1:0] cg4_li_address;
logic                                 cg4_li_read_en;
logic [2                        -1:0] cg4_li_read_mode;
logic                                 cg4_li_half_ofs;
logic [3                        -1:0] cg4_li_zpad_mode;
logic                                 cg4_lo_write_en;
logic [6                        -1:0] cg4_lo_write_len;
logic [LTC_SLICE_AWIDTH         -1:0] cg4_lo_address0;
logic [LTC_SLICE_AWIDTH         -1:0] cg4_lo_address1;
logic [LTC_SLICE_AWIDTH         -1:0] cg4_lo_address2;
logic [LTC_SLICE_AWIDTH         -1:0] cg4_lo_address3;
logic [2                        -1:0] cg4_lo_pool_mode;
logic                                 cg4_lo_nullify_lblk1;
logic                                 cg4_lo_nullify_lblk2;

logic [WATQ_DEPTH               -1:0] watq_valids;
logic [LTC_SLICE_AWIDTH         -1:0] watq_saddrs[WATQ_DEPTH];
logic [LTC_SLICE_AWIDTH         -1:0] watq_eaddrs[WATQ_DEPTH];
logic [WATQ_DEPTH               -1:0] watq_evictables;
logic [WATQ_DEPTH               -1:0] watq_conflicts;
logic [WATQ_AWIDTH              -1:0] watq_head_ptr;
logic [WATQ_AWIDTH              -1:0] watq_tail_ptr;
logic                                 watq_head_tag;
logic                                 watq_tail_tag;
logic                                 watq_full;
logic                                 watq_wreq;
logic                                 watq_push;
logic                                 watq_pop;
logic                                 watq_stall;

MeCommand                             mcmdq_wdata;
MeCommand                             mcmdq_rdata;
MeCommand                             mcmdq_mem[MCMDQ_DEPTH];
logic                                 mcmdq_wenable;
logic                                 mcmdq_renable;
logic                                 mcmdq_rready;
logic                                 mcmdq_rvalid;
logic                                 mcmdq_wtag;
logic [MCMDQ_AWIDTH             -1:0] mcmdq_wptr;
logic                                 mcmdq_rtag;
logic [MCMDQ_AWIDTH             -1:0] mcmdq_rptr;
logic                                 mcmdq_full;
logic                                 mcmdq_empty;

logic                                 dip_active;
logic [7                        -1:0] dip_count;

logic                                 ltc_rupdate_si;
logic                                 ltc_arupdate_so;
logic                                 ltc_arvalid_si;
logic [LTC_SLICE_AWIDTH         -1:0] ltc_araddr_si;
logic [LTC_ARCWIDTH             -1:0] ltc_arcredits;
logic                                 ltc_arfull;
logic [LTC_RCWIDTH              -1:0] ltc_rqlevel;
logic                                 ltc_rqempty;

logic                                 utc_arvalid_si;
logic [UTC_SLICE_AWIDTH         -1:0] utc_araddr_si;
logic                                 utc_arvalid_so;
logic [UTC_SLICE_AWIDTH         -1:0] utc_araddr_so;

logic                                 lqc_renable_si;
logic [2                        -1:0] lqc_rmode_si;
logic                                 lqc_renable_so;
logic [2                        -1:0] lqc_rmode_so;
logic [2                        -1:0] lqc_rmode_dly[2];

logic [BCMD_PIPES               -1:0] bcmd_vpipe;
logic                                 bcmd_vin;
logic                                 bcmd_vout;
BeCommand                             bcmd_dpipe[BCMD_PIPES];
BeCommand                             bcmd_din;
BeCommand                             bcmd_dout;
PostCommand                           pcmd_clk2x;

LPCELL_Command                        lpc_cmd_out;
UPCELL_Command                        upc_cmd_out;

logic                                 dcg_req_vin;
logic [DCG_REQ_PIPES            -1:0] dcg_req_vpipe; 
logic                                 dcg_req_vout;
DcgRequest                            dcg_req_din;
DcgRequest                            dcg_req_dpipe[DCG_REQ_PIPES];
DcgRequest                            dcg_req_dout;

logic                                 dcg_active;
logic                                 dcg_advance;
logic                                 dcg_last;
logic                                 dcg_fake;
logic [2                        -1:0] dcg_prec_mode;
logic [16                       -1:0] dcg_mixp_precs;
logic                                 dcg_mixp_prec;
logic                                 dcg_uint_mode;
logic [2                        -1:0] dcg_pool_mode;
logic [3                        -1:0] dcg_cw_step;
logic                                 dcg_cw_done;
logic [4                        -1:0] dcg_cw_idx;
logic [7                        -1:0] dcg_cw_cnt;
logic                                 dcg_cw_last;
logic [2                        -1:0] dcg_cw_prec;
logic [LTC_SLICE_AWIDTH         -1:0] dcg_awaddr;
logic                                 dcg_awvalid;
logic                                 dcg_awlast;

logic                                 ltc_awupdate_so;
logic                                 ltc_awvalid_si;
logic [LTC_SLICE_AWIDTH         -1:0] ltc_awaddr_si;
logic [LTC_AWCWIDTH             -1:0] ltc_awcredits;
logic [6                        -1:0] ltc_awlength;
logic                                 ltc_awready;

logic [10                       -1:0] wcnt_issue;
logic [10                       -1:0] wcnt_compl;
logic [10                       -1:0] wcntq_mem[2];
logic                                 wcntq_enq;
logic                                 wcntq_deq;
logic                                 wcntq_wptr;
logic                                 wcntq_rptr;
logic [2                        -1:0] wcntq_level;


//------------------------------------------------------------------------------
// CLK to CLK2X sync
//------------------------------------------------------------------------------
always_ff @(posedge aixh_core_clk2x or negedge aixh_core_div_rstn)
  if (~aixh_core_div_rstn) begin
`ifdef AIXH_DEVICE_ASIC
    clk2x_phase_si <= 1'b1;
`else // AIXH_DEVICE_FPGA
    clk2x_phase_si <= 1'b0;
`endif // AIXH_DEVICE_FPGA
  end else begin
    clk2x_phase_si <= ~clk2x_phase_si;
  end

// Shift register for better placement
assign clk2x_phase = clk2x_phase_sr[0];
always_ff @(posedge aixh_core_clk2x) begin
  clk2x_phase_sr <= {clk2x_phase_si, clk2x_phase_sr[3:1]};
end

assign uqc_csync  = clk2x_phase;
assign lqc_icsync = clk2x_phase;
assign lqc_ocsync = clk2x_phase;

//------------------------------------------------------------------------------
// Frontend state machine
//------------------------------------------------------------------------------
assign fstall = ltc_arfull | mcmdq_full | watq_stall;

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) fstate <= FE_WAIT;
  else if (~fstall)    fstate <= fstate_nx;

always_comb begin
  fstate_nx = fstate;
  case (fstate)
    FE_WAIT:
      if (ready_cmds != 2'd0 && !sdly_active)
        fstate_nx = FE_FETCH;
    FE_FETCH:
      if (fetch_step[6])
        fstate_nx = FE_SETUP;
    FE_SETUP:
      fstate_nx = FE_KLOOP;
    FE_KLOOP:
      if (pg_k_end)
        fstate_nx = FE_DRAIN_PRE;
    FE_DRAIN_PRE:
      fstate_nx = FE_DRAIN_REQ;
    FE_DRAIN_REQ:
      if (pg_all_end)
           fstate_nx = FE_FINISH;
      else fstate_nx = FE_KLOOP;
    FE_FINISH:
      if (finish_step[3])
        fstate_nx = FE_WAIT;
    default:
      fstate_nx = FE_WAIT;
  endcase
end

// Sub-states
assign fetch_start  = fstate    == FE_WAIT &&
                      fstate_nx == FE_FETCH;
assign finish_start = fstate    != FE_FINISH &&
                      fstate_nx == FE_FINISH;

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    fetch_step  <= 8'b0;
    finish_step <= 4'b0;
  end else
  if (~fstall) begin
    fetch_step  <= {fetch_step [0+:7], fetch_start};
    finish_step <= {finish_step[0+:3], finish_start};
  end

// Startup delay
always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    sdly_active <= 1'b1;
    sdly_count  <= SDLY_CWIDTH'($unsigned(SDLY_CYCLES-1));
  end else
  if (sdly_active) begin
    sdly_active <= |sdly_count;
    sdly_count  <= sdly_count - SDLY_CWIDTH'(1);
  end


//------------------------------------------------------------------------------
// CMDX interface
//------------------------------------------------------------------------------
// Count ready commands
always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    ready_cmds <= 2'd0;
  end else begin
    case ({cmdx_req_so, finish_step[0] & ~fstall})
      2'b10:   ready_cmds <= ready_cmds + 2'd1;
      2'b01:   ready_cmds <= ready_cmds - 2'd1;
      default: ready_cmds <= ready_cmds;
    endcase
  end

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) 
       cmdx_done_si <= 1'b0;
  else cmdx_done_si <= wcntq_deq;

//------------------------------------------------------------------------------
// Raw Command queue
//------------------------------------------------------------------------------
assign cmdq_wptr_p1 = CMDQ_EADDR == cmdq_wptr
                    ? CMDQ_AWIDTH'(0)
                    : CMDQ_AWIDTH'(1) + cmdq_wptr;
assign cmdq_rptr_p1 = CMDQ_EADDR == cmdq_rptr
                    ? CMDQ_AWIDTH'(0)
                    : CMDQ_AWIDTH'(1) + cmdq_rptr;

// memory write
always @(posedge aixh_core_clk)
  if (cmdw_en_so) cmdq_mem[cmdq_wptr] <= cmdw_data_so;

// memory read                    
always @(posedge aixh_core_clk)
  if (~fstall) begin
    cmdq_rdata <= cmdq_mem[cmdq_rptr];
    cmdq_odata <= cmdq_rdata;
  end

// update write pointer
always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) cmdq_wptr <= CMDQ_AWIDTH'(0);
  else if (cmdw_en_so)    cmdq_wptr <= cmdq_wptr_p1;

// update read pointer
always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    cmdq_rptr      <= CMDQ_AWIDTH'(0);
    cmdq_nptr_ridx <= 1'b0;
  end else 
  if (~fstall) begin
    if (fstate == FE_FETCH) begin
      cmdq_rptr <= cmdq_rptr_p1;
    end else
    if (fstate == FE_SETUP) begin
      cmdq_rptr <= cmdq_sptr;
    end else
    if (fstate == FE_KLOOP) begin
      if (pg_ip_end) begin
        if (pg_ic_end)
          cmdq_rptr <= cmdq_sptr;
        else if ( fcmd.in_indirect && pg_ic[1:0] == 3'd3)
          cmdq_rptr <= cmdq_rptr_p1;
        else if (!fcmd.in_indirect && pg_ic[5:0] == 6'd63)
          cmdq_rptr <= cmdq_rptr_p1;
      end
    end else
    if (finish_step[0]) begin
      cmdq_rptr <= cmdq_nptr_mem[cmdq_nptr_ridx];
      cmdq_nptr_ridx <= ~cmdq_nptr_ridx;
    end
  end

// store the start pointer of indirection table
always_ff @(posedge aixh_core_clk)
  if (fetch_step[6]) begin
    cmdq_sptr <= cmdq_rptr;
  end

// enqueue the next-read pointer
always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn)                 cmdq_nptr_widx <= 1'b0;
  else if (cmdw_en_so && cmdw_last_so) cmdq_nptr_widx <= ~cmdq_nptr_widx;

always_ff @(posedge aixh_core_clk)
  if (cmdw_en_so && cmdw_last_so) cmdq_nptr_mem[cmdq_nptr_widx] <= cmdq_wptr_p1;


// Command fetch
assign rcmd0 = cmdq_odata;
assign rcmd1 = cmdq_odata;
assign rcmd2 = cmdq_odata;
assign rcmd3 = cmdq_odata;
assign rcmd4 = cmdq_odata;
assign rcmd5 = cmdq_odata;

always_ff @(posedge aixh_core_clk) begin
  if (fetch_step[7]) begin
    fcmd.filter_address <= rcmd5.filter_address; 
    fcmd.out_mixp_precs <= rcmd5.out_mixp_precs; 
    fcmd.out_dx_astride <= rcmd5.out_dx_astride; 
    fcmd.out_dy_astride <= rcmd5.out_dy_astride; 
  end
  if (fetch_step[6]) begin
    fcmd.out_sx_astride <= rcmd4.out_sx_astride; 
    fcmd.out_sy_astride <= rcmd4.out_sy_astride; 
    fcmd.out_address    <= rcmd4.out_address; 
    fcmd.out_width      <= rcmd4.out_width; 
  end
  if (fetch_step[5]) begin
    fcmd.out_blk_height <= rcmd3.out_blk_height; 
    fcmd.in_dx_astride  <= rcmd3.in_dx_astride; 
    fcmd.in_dy_astride  <= rcmd3.in_dy_astride; 
    fcmd.in_address1    <= rcmd3.in_address1; 
  end
  if (fetch_step[4]) begin
    fcmd.in_address0    <= rcmd2.in_address0; 
    fcmd.in_width1      <= rcmd2.in_width1; 
    fcmd.in_width0      <= rcmd2.in_width0; 
    fcmd.in_blk_height1 <= rcmd2.in_blk_height1; 
  end
  if (fetch_step[3]) begin
    fcmd.in_blk_height0 <= rcmd1.in_blk_height0; 
    fcmd.in_cwords      <= rcmd1.in_cwords; 
    fcmd.in_xoffset     <= rcmd1.in_xoffset; 
    fcmd.in_yoffset     <= rcmd1.in_yoffset; 
    fcmd.cluster_blks   <= rcmd1.cluster_blks; 
    fcmd.cluster_size   <= rcmd1.cluster_size; 
  end
  if (fetch_step[2]) begin
    fcmd.slide_xstride  <= rcmd0.slide_xstride;
    fcmd.slide_ystride  <= rcmd0.slide_ystride;
    fcmd.active_upcells <= rcmd0.filter_count[1+:7];
    fcmd.filter_xdilate <= rcmd0.filter_xdilate;
    fcmd.filter_ydilate <= rcmd0.filter_ydilate;
    fcmd.filter_width   <= rcmd0.filter_width;
    fcmd.filter_height  <= rcmd0.filter_height;
    fcmd.filter_intlv   <= rcmd0.filter_intlv;
    fcmd.out_cwords     <= rcmd0.out_cwords;
    fcmd.out_xsampling  <= rcmd0.out_xsampling;
    fcmd.out_ysampling  <= rcmd0.out_ysampling;
    fcmd.out_maxpool    <= rcmd0.out_maxpool;
    fcmd.out_unsigned   <= rcmd0.out_unsigned;
    fcmd.out_precision  <= rcmd0.out_precision;
    fcmd.in_mixp_blend  <= rcmd0.in_mixp_blend;
    fcmd.in_relu        <= rcmd0.in_relu;
    fcmd.in_packed      <= rcmd0.in_packed;
    fcmd.in_indirect    <= rcmd0.in_indirect;
    fcmd.in_unsigned    <= rcmd0.in_unsigned;
    fcmd.in_precision   <= rcmd0.in_precision;
    fcmd.in_padding_off <= rcmd0.in_padding_off;
    fcmd.hyper_cluster  <= rcmd0.hyper_cluster;
    fcmd.fc_last        <= rcmd0.fc_last;
    fcmd.fc_first       <= rcmd0.fc_first;
    fcmd.fc_mode        <= rcmd0.fc_mode;

    `ifdef AIXH_TARGET_ASIC
    fcmd.in_phases <= rcmd0.in_precision == PREC_INT16 ? 1'b1 : 1'b0;
    `endif
  end
end

//------------------------------------------------------------------------------
// Position generation
//------------------------------------------------------------------------------
assign pg_ix0 = {{9{fcmd.in_xoffset[7]}}, fcmd.in_xoffset};
assign pg_iy0 = {{9{fcmd.in_yoffset[7]}}, fcmd.in_yoffset};

assign pg_ip_end = pg_ip  == fcmd.in_phases;
assign pg_ic_end = pg_icr == 16'd1;
assign pg_kx_end = pg_kxr == 16'd1;
assign pg_ky_end = pg_kyr == 16'd1;
assign pg_k_end = pg_ip_end & pg_ic_end & pg_kx_end & pg_ky_end;

assign pg_sx_end = pg_sx == fcmd.out_xsampling;
assign pg_sy_end = pg_sy == fcmd.out_ysampling;
assign pg_ox_end = pg_oxr == 16'd1;
assign pg_oy_end = pg_oyr == 16'd1;
assign pg_all_end = pg_sx_end & pg_sy_end & pg_ox_end & pg_oy_end;

always_comb
  if (fcmd.fc_mode) begin
    pg_kw = fcmd.in_width0 + fcmd.in_width1;
    pg_kh = fcmd.fc_last ? fcmd.in_blk_height1
                         : fcmd.in_blk_height0;
  end else begin
    pg_kw = fcmd.filter_width;
    pg_kh = fcmd.filter_height;
  end

always_ff @(posedge aixh_core_clk)
  if (~fstall) begin
    case (fstate)
      FE_SETUP: begin
        pg_ip  <=  1'd0;
        pg_ic  <= 16'd0;
        pg_icr <= fcmd.in_cwords;
        pg_kxr <= pg_kw;
        pg_kyr <= pg_kh;
        pg_sx  <=  4'd1;
        pg_sy  <=  4'd1;
        pg_oxr <= fcmd.out_width;
        pg_oyr <= fcmd.out_blk_height;
        pg_ix1 <= pg_ix0;
        pg_iy1 <= pg_iy0;
        pg_ix2 <= pg_ix0;
        pg_iy2 <= pg_iy0;
        pg_ix3 <= pg_ix0;
        pg_iy3 <= pg_iy0;
      end
      FE_KLOOP: begin
        casez({pg_ky_end, pg_kx_end, pg_ic_end, pg_ip_end})
          4'b???0: begin // ip++
            pg_ip  <= ~pg_ip;
          end
          4'b??01: begin // ic++
            pg_ip  <= 1'd0;
            pg_ic  <= pg_ic  + 16'd1;
            pg_icr <= pg_icr - 16'd1;
          end
          4'b?011: begin // kx++
            pg_ip  <=  1'd0;
            pg_ic  <= 16'd0;
            pg_icr <= fcmd.in_cwords;
            pg_kxr <= pg_kxr - 16'd1;
            pg_ix3 <= pg_ix3 + 17'(fcmd.filter_xdilate);
          end
          4'b0111: begin // ky++
            pg_ip  <=  1'd0;
            pg_ic  <= 16'd0;
            pg_icr <= fcmd.in_cwords;
            pg_kxr <= pg_kw;
            pg_kyr <= pg_kyr - 16'd1;
            pg_ix3 <= pg_ix2;
            pg_iy3 <= pg_iy3 + 17'(fcmd.filter_ydilate);
          end
          4'b1111: begin
            pg_ip  <=  1'd0;
            pg_ic  <= 16'd0;
            pg_icr <= fcmd.in_cwords;
            pg_kxr <= pg_kw;
            pg_kyr <= pg_kh;
          end        
        endcase
      end
      FE_DRAIN_REQ: begin
        casez({pg_ox_end, pg_sy_end, pg_sx_end})
          3'b??0: begin // sx++
            pg_sx  <= pg_sx + 4'd1;
            pg_ix2 <= pg_ix2 + 17'(fcmd.slide_xstride);
            pg_ix3 <= pg_ix2 + 17'(fcmd.slide_xstride);
            pg_iy3 <= pg_iy2;
          end
          3'b?01: begin // sy++
            pg_sx  <= 4'd1;
            pg_sy  <= pg_sy + 4'd1;
            pg_ix2 <= pg_ix1;
            pg_ix3 <= pg_ix1;
            pg_iy2 <= pg_iy2 + 17'(fcmd.slide_ystride);
            pg_iy3 <= pg_iy2 + 17'(fcmd.slide_ystride);
          end
          3'b011: begin // ox++
            pg_sx  <= 4'd1;
            pg_sy  <= 4'd1;
            pg_oxr <= pg_oxr - 16'd1;
            pg_ix1 <= pg_ix2 + 17'(fcmd.slide_xstride);
            pg_ix2 <= pg_ix2 + 17'(fcmd.slide_xstride);
            pg_ix3 <= pg_ix2 + 17'(fcmd.slide_xstride);
            pg_iy2 <= pg_iy1;
            pg_iy3 <= pg_iy1;
          end
          3'b111: begin // oy++
            pg_sx  <= 4'd1;
            pg_sy  <= 4'd1;
            pg_oxr <= fcmd.out_width;
            pg_oyr <= pg_oyr - 16'd1;
            pg_ix1 <= pg_ix0;
            pg_ix2 <= pg_ix0;
            pg_ix3 <= pg_ix0;
            pg_iy1 <= pg_iy2 + 17'(fcmd.slide_ystride);
            pg_iy2 <= pg_iy2 + 17'(fcmd.slide_ystride);
            pg_iy3 <= pg_iy2 + 17'(fcmd.slide_ystride);
          end
        endcase
      end
      default: begin
        // do nothing
      end
    endcase
  end

//------------------------------------------------------------------------------
// Control generation
//------------------------------------------------------------------------------
assign cg0_enable = ~fstall;
assign cg1_enable = ~fstall & cg0_valid;
assign cg2_enable = ~fstall & cg1_valid;
assign cg3_enable = ~fstall & cg2_valid;
assign cg4_enable = ~fstall & cg3_valid;

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    cg0_valid <= 1'b0;
    cg1_valid <= 1'b0;
    cg2_valid <= 1'b0;
    cg3_valid <= 1'b0;
    cg4_valid <= 1'b0;
  end else if (~fstall) begin
    cg0_valid <= fstate_nx == FE_KLOOP     ||
                 fstate_nx == FE_DRAIN_PRE ||
                 fstate_nx == FE_DRAIN_REQ;
    cg1_valid <= cg0_valid;
    cg2_valid <= cg1_valid;
    cg3_valid <= cg2_valid;
    cg4_valid <= cg3_valid;
  end

always_ff @(posedge aixh_core_clk) 
  if (cg0_enable) begin
    // MAC afresh at the beginning of kernel loop
    cg0_mac_afresh <= fstate    != FE_KLOOP &&
                      fstate_nx == FE_KLOOP;

    // Determine output address generation action-code
    case (fstate)
      FE_SETUP: begin
        cg0_lo_ag_code <= OAG_INIT;
      end
      FE_DRAIN_REQ: 
        casez ({pg_ox_end, pg_sy_end, pg_sx_end})
          3'b??0: cg0_lo_ag_code <= OAG_SX_INC;
          3'b?01: cg0_lo_ag_code <= OAG_SY_INC;
          3'b011: cg0_lo_ag_code <= OAG_DX_INC;
          3'b111: cg0_lo_ag_code <= OAG_DY_INC;
        endcase
      default: begin
        cg0_lo_ag_code <= OAG_KEEP;
      end
    endcase

    // Determine output pooling mode
    if (fstate == FE_SETUP) begin
      cg0_lo_pool_mode <= POOL_BYPASS;
    end
    if (fstate == FE_DRAIN_PRE) begin
      case ({fcmd.out_maxpool
           ,pg_sy == 4'd1 && pg_sx == 4'd1
           ,pg_sy_end && pg_sx_end})
        3'b100 : cg0_lo_pool_mode <= POOL_INNER;
        3'b101 : cg0_lo_pool_mode <= POOL_LAST;
        3'b110 : cg0_lo_pool_mode <= POOL_FIRST;
        default: cg0_lo_pool_mode <= POOL_BYPASS;
      endcase
    end
  end


always_ff @(posedge aixh_core_clk) 
  if (cg1_enable) begin
    cg1_mac_afresh   <= cg0_mac_afresh;
    cg1_lo_ag_code   <= cg0_lo_ag_code;
    cg1_lo_pool_mode <= cg0_lo_pool_mode;

    cg1_mac_enable <= fstate == FE_KLOOP;
    cg1_drain_pre  <= fstate == FE_DRAIN_PRE;
    cg1_drain_req  <= fstate == FE_DRAIN_REQ;
    cg1_drain_last <= fstate == FE_DRAIN_REQ &&
                      fstate_nx != FE_KLOOP;
    cg1_drain_fake <= fcmd.fc_mode & ~fcmd.fc_last;

    cg1_in_phase <= pg_ip;
    cg1_in_cpos  <= pg_ic[0+:LTC_SLICE_AWIDTH]; 
 
    // In hyper cluster mode, all the blocks are valid in clusters except for
    // the last output y-position.
    cg1_cluster_full <= fcmd.hyper_cluster & ~pg_oy_end;

    //
    // Left Input Control
    //

    // enable read only for the 1st phase.
    // the read data is reused in the 2nd phase.
    cg1_li_read_en <= fstate == FE_KLOOP && pg_ip == 1'b0;

    // a negative x-position is invalid
    cg1_li_avalid <= ~pg_ix3[16];

    // select address and calculate relative x-position
    cg1_li_xpos <= pg_ix3[0+:LTC_SLICE_AWIDTH];
    if (pg_ix3[0+:16] < fcmd.in_width0) begin
      cg1_li_aselect <= 1'b0;
    end else begin
      cg1_li_aselect <= 1'b1;
    end

  
    // determine read mode and calculate y-position
    cg1_li_ypos <= pg_iy3[0+:LTC_SLICE_AWIDTH];
    if (pg_iy3[16]) begin
      // for negative y-position, read upper block input by down-shift
      cg1_li_read_mode <= RMODE_DN_SHIFT;
    end else
    if (pg_iy3[0+:16] < fcmd.in_blk_height0) begin
      // within the base block height, read block input straightly
      cg1_li_read_mode <= RMODE_STRAIGHT;
    end else begin
      // beyond the base block height, read lower block input by up-shift
      cg1_li_read_mode <= RMODE_UP_SHIFT;
    end
  
    if (pg_iy3[16]) begin
      // zero-pad the first block for negative y-position
      cg1_li_zpad_fblk  <= 1'b1;
      cg1_li_zpad_lblk1 <= 1'b0; 
      cg1_li_zpad_lblk2 <= 1'b0;
    end else begin
      // the last two blocks are zero-padding candidates
      cg1_li_zpad_fblk  <= 1'b0;
      cg1_li_zpad_lblk1 <= pg_iy3[0+:16] >= fcmd.in_blk_height1;
      cg1_li_zpad_lblk2 <= pg_iy3 >= 17'({1'b0, fcmd.in_blk_height0}
                                        +{1'b0, fcmd.in_blk_height1});
    end

    //
    // Upper Input Control
    //
    case (fstate)
      FE_KLOOP    : cg1_ui_read_en <= pg_ip == 1'b0;
      FE_DRAIN_PRE: cg1_ui_read_en <= 1'b1;
      FE_DRAIN_REQ: cg1_ui_read_en <= 1'b1;
      default     : cg1_ui_read_en <= 1'b0;
    endcase
  end

always_comb begin
  case (cg1_li_read_mode)
    RMODE_DN_SHIFT:
      cg1_li_yofs = cg1_li_ypos + fcmd.in_blk_height0[0+:LTC_SLICE_AWIDTH];
    RMODE_UP_SHIFT:
      cg1_li_yofs = cg1_li_ypos - fcmd.in_blk_height0[0+:LTC_SLICE_AWIDTH];
    default:
      cg1_li_yofs = cg1_li_ypos;
  endcase
end

always_ff @(posedge aixh_core_clk)
  if (cg2_enable) begin
    cg2_mac_enable    <= cg1_mac_enable;
    cg2_mac_afresh    <= cg1_mac_afresh;
    cg2_cluster_full  <= cg1_cluster_full;
    cg2_drain_pre     <= cg1_drain_pre;
    cg2_drain_req     <= cg1_drain_req;
    cg2_drain_last    <= cg1_drain_last;
    cg2_drain_fake    <= cg1_drain_fake;
    cg2_in_phase      <= cg1_in_phase;
    cg2_in_cpos       <= cg1_in_cpos;
    cg2_ui_read_en    <= cg1_ui_read_en;
    cg2_li_read_en    <= cg1_li_read_en;
    cg2_li_read_mode  <= cg1_li_read_mode;
    cg2_li_avalid     <= cg1_li_avalid;
    cg2_li_aselect    <= cg1_li_aselect;
    cg2_li_zpad_fblk  <= cg1_li_zpad_fblk;
    cg2_li_zpad_lblk1 <= cg1_li_zpad_lblk1;
    cg2_li_zpad_lblk2 <= cg1_li_zpad_lblk2;
    cg2_lo_ag_code    <= cg1_lo_ag_code;
    cg2_lo_pool_mode  <= cg1_lo_pool_mode;

    //
    // Left Input Control
    //
    if (cg1_li_aselect)
         cg2_li_xofs <= cg1_li_xpos - fcmd.in_width0[0+:LTC_SLICE_AWIDTH];
    else cg2_li_xofs <= cg1_li_xpos;

    if (fcmd.in_packed && cg1_li_ypos[0])
         cg2_li_half_ofs  <= 1'd1;
    else cg2_li_half_ofs  <= 1'd0;

    if (fcmd.in_packed)
         cg2_li_yofs <= {1'b0, cg1_li_yofs[LTC_SLICE_AWIDTH-1:1]};
    else cg2_li_yofs <= cg1_li_yofs;
  end

always_ff @(posedge aixh_core_clk)
  if (cg3_enable) begin
    cg3_mac_enable    <= cg2_mac_enable;
    cg3_mac_afresh    <= cg2_mac_afresh;
    cg3_drain_pre     <= cg2_drain_pre;
    cg3_drain_req     <= cg2_drain_req;
    cg3_drain_last    <= cg2_drain_last;
    cg3_drain_fake    <= cg2_drain_fake;
    cg3_in_phase      <= cg2_in_phase;
    cg3_ui_read_en    <= cg2_ui_read_en;
    cg3_li_read_en    <= cg2_li_read_en;
    cg3_li_read_mode  <= cg2_li_read_mode;
    cg3_li_half_ofs   <= cg2_li_half_ofs;
    cg3_li_zpad_fblk  <= cg2_li_zpad_fblk;
    cg3_li_zpad_lblk1 <= cg2_li_zpad_lblk1;
    cg3_li_zpad_lblk2 <= cg2_li_zpad_lblk2;
    cg3_lo_ag_code    <= cg2_lo_ag_code;
    cg3_lo_pool_mode  <= cg2_lo_pool_mode;

    cg3_cluster_blks <= cg2_cluster_full ? fcmd.cluster_size
                                         : fcmd.cluster_blks;
    
    //
    // Left Input Control
    //
    // invalidate address for x-position beyond the input width
    cg3_li_avalid <= cg2_li_avalid 
                 & (~cg2_li_aselect | (16'(cg2_li_xofs) < fcmd.in_width1));

    cg3_li_abase <= cg2_li_aselect ? fcmd.in_address1 : fcmd.in_address0;
    cg3_li_xaoffset <= LTC_SLICE_AWIDTH'(cg2_li_xofs * fcmd.in_dx_astride);
    cg3_li_yaoffset <= LTC_SLICE_AWIDTH'(cg2_li_yofs * fcmd.in_dy_astride);

    if (fcmd.in_indirect) begin
      case (cg2_in_cpos[1:0])
        2'd0: cg3_li_caoffset <= cmdq_odata[16*0+:LTC_SLICE_AWIDTH];
        2'd1: cg3_li_caoffset <= cmdq_odata[16*1+:LTC_SLICE_AWIDTH];
        2'd2: cg3_li_caoffset <= cmdq_odata[16*2+:LTC_SLICE_AWIDTH];
        2'd3: cg3_li_caoffset <= cmdq_odata[16*3+:LTC_SLICE_AWIDTH];
      endcase
      cg3_in_prec_modes <= {cmdq_odata[63]
                           ,cmdq_odata[47]
                           ,cmdq_odata[31]
                           ,cmdq_odata[15]
                           ,cmdq_odata[63]
                           ,cmdq_odata[47]
                           ,cmdq_odata[31]
                           ,cmdq_odata[15]};
    end else begin
      case (cg2_in_cpos[5:3])
        3'd0: cg3_in_prec_modes <= cmdq_odata[0*8+:8];
        3'd1: cg3_in_prec_modes <= cmdq_odata[1*8+:8];
        3'd2: cg3_in_prec_modes <= cmdq_odata[2*8+:8];
        3'd3: cg3_in_prec_modes <= cmdq_odata[3*8+:8];
        3'd4: cg3_in_prec_modes <= cmdq_odata[4*8+:8];
        3'd5: cg3_in_prec_modes <= cmdq_odata[5*8+:8];
        3'd6: cg3_in_prec_modes <= cmdq_odata[6*8+:8];
        3'd7: cg3_in_prec_modes <= cmdq_odata[7*8+:8];
      endcase
      cg3_li_caoffset <= cg2_in_cpos;
    end
    cg3_in_prec_msel <= cg2_in_cpos[2:0];
  end

assign cg3_in_prec_mode = cg3_in_prec_modes[cg3_in_prec_msel];

always_comb begin
  if (fcmd.filter_intlv) begin
    if (cg4_ui_address >= UTC_INTLV_GADDR)
         cg4_ui_address_nx = cg4_ui_address - UTC_INTLV_GADDR;
    else cg4_ui_address_nx = cg4_ui_address + UTC_INTLV_STRIDE;
  end else begin
    if (cg4_ui_address >= UTC_SLICE_EADDR)
         cg4_ui_address_nx = cg4_ui_address - UTC_SLICE_EADDR;
    else cg4_ui_address_nx = cg4_ui_address + UTC_SLICE_AWIDTH'(1);
  end
end


always_ff @(posedge aixh_core_clk)
  if (cg4_enable) begin
    cg4_mac_enable   <= cg3_mac_enable;
    cg4_mac_afresh   <= cg3_mac_afresh;
    cg4_drain_pre    <= cg3_drain_pre;
    cg4_drain_req    <= cg3_drain_req;
    cg4_drain_last   <= cg3_drain_last;
    cg4_drain_fake   <= cg3_drain_fake;
    cg4_ui_read_en   <= cg3_ui_read_en;
    cg4_li_read_mode <= cg3_li_read_mode;
    cg4_li_half_ofs  <= cg3_li_half_ofs;
    cg4_lo_pool_mode <= cg3_lo_pool_mode;
    
    // Read mode for both left and upper inputs
    casez (fcmd.in_precision)
      PREC_INT4: begin
        cg4_in_cvt_mode <= 2'b00;
        //                       /--- V-carry use
        //                       |/-- U-carry use
        //                       || /-- V-carry save
        //                       || |/- U-carry save
        //                       || || /-- INT8
        //                       || || |  //-- shift amount
        cg4_mac_mode      <= {7'b00_00_0__00, 7'b00_00_0__00};
      end
      PREC_INT8: begin
        cg4_in_cvt_mode   <= 2'b01;
        cg4_mac_mode      <= {7'b00_00_1__00, 7'b00_00_1__00};
      end
      PREC_INT16: begin
        if (cg3_in_phase == 1'b0) begin
          cg4_in_cvt_mode <= 2'b10;
          cg4_mac_mode    <= {7'b10_01_1__01, 7'b00_11_1__00};
        end else begin                                     
          cg4_in_cvt_mode <= 2'b11;                        
          cg4_mac_mode    <= {7'b11_00_1__10, 7'b01_10_1__01};
        end
      end
      PREC_MIX48: begin
        if (cg3_in_prec_mode == 1'b0) begin
          cg4_in_cvt_mode <= 2'b00;
          cg4_mac_mode    <= fcmd.in_mixp_blend 
                           ? {7'b00_00_0__01, 7'b00_00_0__01}
                           : {7'b00_00_0__00, 7'b00_00_0__00};
        end else begin                                              
          cg4_in_cvt_mode <= 2'b01;                                 
          cg4_mac_mode    <= {7'b00_00_1__00, 7'b00_00_1__00};
        end
      end
    endcase
    
    // In Fully-Connected mode, clear accumulators only at the first command.
    if (fcmd.fc_mode & ~fcmd.fc_first) begin
      cg4_mac_afresh <= 1'b0;
    end

    //------------
    // Left Input
    //------------

    // Disable read for invalid address
    cg4_li_read_en <= cg3_li_read_en & cg3_li_avalid;

    cg4_li_address <= (cg3_li_abase    + cg3_li_caoffset)
                    + (cg3_li_xaoffset + cg3_li_yaoffset);
    

    // Zero-padding control
    cg4_li_zpad_mode <= ~cg3_li_avalid     ? ZPAD_ABLK
                      :  cg3_li_zpad_fblk  ? ZPAD_FBLK
                      :  cg3_li_zpad_lblk2 ? ZPAD_LBLK2
                      :  cg3_li_zpad_lblk1 ? ZPAD_LBLK1
                      :                      ZPAD_NONE;

    //-------------
    // Left Output
    //-------------
    unique case (cg3_lo_ag_code)
      OAG_INIT: begin
        cg4_lo_address0 <= fcmd.out_address;
        cg4_lo_address1 <= fcmd.out_address;
        cg4_lo_address2 <= fcmd.out_address;
        cg4_lo_address3 <= fcmd.out_address;      
      end
      OAG_SX_INC: begin
        cg4_lo_address3 <= cg4_lo_address3 + fcmd.out_sx_astride;
      end
      OAG_SY_INC: begin
        cg4_lo_address2 <= cg4_lo_address2 + fcmd.out_sy_astride;
        cg4_lo_address3 <= cg4_lo_address2 + fcmd.out_sy_astride;
      end
      OAG_DX_INC: begin
        cg4_lo_address1 <= cg4_lo_address1 + fcmd.out_dx_astride;
        cg4_lo_address2 <= cg4_lo_address1 + fcmd.out_dx_astride;
        cg4_lo_address3 <= cg4_lo_address1 + fcmd.out_dx_astride;
      end
      OAG_DY_INC: begin
        cg4_lo_address0 <= cg4_lo_address0 + fcmd.out_dy_astride;
        cg4_lo_address1 <= cg4_lo_address0 + fcmd.out_dy_astride;
        cg4_lo_address2 <= cg4_lo_address0 + fcmd.out_dy_astride;
        cg4_lo_address3 <= cg4_lo_address0 + fcmd.out_dy_astride;
      end
      default: begin
        // invalid
      end
    endcase

    if (~cg3_drain_req
      || cg3_drain_fake
      || cg3_lo_pool_mode == POOL_FIRST
      || cg3_lo_pool_mode == POOL_INNER)
    begin
      cg4_lo_write_en  <= 1'b0;
      cg4_lo_write_len <= 6'd0;
    end else begin
      cg4_lo_write_en  <= 1'b1;
      cg4_lo_write_len <= fcmd.out_cwords;
    end

    // Adjust # of valid output cluster blocks
    cg4_cluster_blks <= cg3_cluster_blks;
    if (cg3_mac_enable) begin
      if ((cg3_li_zpad_lblk1 | ~cg3_li_avalid) ^ ~fcmd.in_padding_off)
        cg4_lo_nullify_lblk1 <=  fcmd.in_padding_off;
      else if (cg3_mac_afresh)
        cg4_lo_nullify_lblk1 <= ~fcmd.in_padding_off;

      if ((cg3_li_zpad_lblk2 | ~cg3_li_avalid) ^ ~fcmd.in_padding_off)
        cg4_lo_nullify_lblk2 <=  fcmd.in_padding_off;
      else if (cg3_mac_afresh)
        cg4_lo_nullify_lblk2 <= ~fcmd.in_padding_off;
    end else begin
      if (cg4_lo_nullify_lblk2 && cg3_cluster_blks >= 8'd2)
        cg4_cluster_blks <= cg3_cluster_blks - 8'd2;
      else if (cg4_lo_nullify_lblk1)
        cg4_cluster_blks <= cg3_cluster_blks - 8'd1;
    end

    //-------------
    // Upper Input
    //-------------
    if (cg3_mac_afresh) begin
      cg4_ui_address <= fcmd.filter_address;
    end else
    if (cg3_ui_read_en) begin
      cg4_ui_address <= cg4_ui_address_nx;
    end
  end

//------------------------------------------------------------------------------
// Write address tracking queue
//------------------------------------------------------------------------------
assign watq_full  = watq_head_tag != watq_tail_tag && 
                    watq_head_ptr == watq_tail_ptr;
assign watq_wreq  = cg4_valid & cg4_lo_write_en;
assign watq_push  = watq_wreq & ~fstall;
assign watq_pop   = ltc_awupdate_so & (|watq_evictables);
assign watq_stall = (watq_wreq & watq_full) | (|watq_conflicts);

always_comb
for (int i = 0; i < WATQ_DEPTH; i++) begin
  watq_evictables[i] = watq_head_ptr == WATQ_AWIDTH'(i) && 
                       watq_saddrs[i] == watq_eaddrs[i];
  watq_conflicts[i] = watq_valids[i] && cg4_li_read_en && cg4_valid &&
                      watq_saddrs[i] <= cg4_li_address &&
                      watq_eaddrs[i] >= cg4_li_address;
end

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if(~aixh_core_rstn) begin
    watq_head_tag <= 1'b0;
    watq_tail_tag <= 1'b0;
    watq_head_ptr <= WATQ_AWIDTH'(0);
    watq_tail_ptr <= WATQ_AWIDTH'(0);
    watq_valids   <= WATQ_DEPTH'(0);
  end else begin
    if (watq_push) begin
      if (watq_tail_ptr == WATQ_EADDR) begin
        watq_tail_tag <= ~watq_tail_tag;
        watq_tail_ptr <= WATQ_AWIDTH'(0);
      end else begin
        watq_tail_ptr <= watq_tail_ptr + WATQ_AWIDTH'(1);
      end
    end
    
    if (watq_pop) begin
      if (watq_head_ptr == WATQ_EADDR) begin
        watq_head_tag <= ~watq_head_tag;
        watq_head_ptr <= WATQ_AWIDTH'(0);
      end else begin
        watq_head_ptr <= watq_head_ptr + WATQ_AWIDTH'(1);
      end
    end

    for (int i = 0; i < WATQ_DEPTH; i++) begin
      if (watq_tail_ptr == WATQ_AWIDTH'(i) && watq_push) watq_valids[i] <= 1'b1;
      if (watq_head_ptr == WATQ_AWIDTH'(i) && watq_pop ) watq_valids[i] <= 1'b0;
    end
  end

always_ff @(posedge aixh_core_clk)
for (int i = 0; i < WATQ_DEPTH; i++) begin
  if (watq_tail_ptr == WATQ_AWIDTH'(i) && watq_push) begin
    watq_saddrs[i] <= cg4_lo_address3;
    watq_eaddrs[i] <= cg4_lo_address3
                    + LTC_SLICE_AWIDTH'(cg4_lo_write_len)
                    - LTC_SLICE_AWIDTH'(1); 
  end
  if (watq_head_ptr == WATQ_AWIDTH'(i) && ltc_awupdate_so) begin
    watq_saddrs[i] <= watq_saddrs[i] + LTC_SLICE_AWIDTH'(1);
  end
end

//------------------------------------------------------------------------------
// Middle-end command queue
//------------------------------------------------------------------------------

always_comb begin
  mcmdq_wdata.mac_enable          = cg4_mac_enable      ; 
  mcmdq_wdata.mac_afresh          = cg4_mac_afresh      ; 
  mcmdq_wdata.mac_mode            = cg4_mac_mode        ; 
  mcmdq_wdata.drain_pre           = cg4_drain_pre       ; 
  mcmdq_wdata.drain_req           = cg4_drain_req       ; 
  mcmdq_wdata.drain_last          = cg4_drain_last      ; 
  mcmdq_wdata.drain_fake          = cg4_drain_fake      ;  
  mcmdq_wdata.fc_mode             = fcmd.fc_mode        ;
  mcmdq_wdata.cluster_size        = fcmd.cluster_size   ;
  mcmdq_wdata.cluster_blks        = cg4_cluster_blks    ;
  mcmdq_wdata.active_upcells      = fcmd.active_upcells ;
  mcmdq_wdata.in_cvt_mode         = cg4_in_cvt_mode     ;
  mcmdq_wdata.ui_address          = cg4_ui_address      ;
  mcmdq_wdata.ui_read_en          = cg4_ui_read_en      ;
  mcmdq_wdata.li_read_en          = cg4_li_read_en      ;
  mcmdq_wdata.li_read_mode        = cg4_li_read_mode    ;
  mcmdq_wdata.li_uint_mode        = fcmd.in_unsigned    ;
  mcmdq_wdata.li_half_ofs         = cg4_li_half_ofs     ;
  mcmdq_wdata.li_relu_en          = fcmd.in_relu        ;
  mcmdq_wdata.li_zpad_mode        = cg4_li_zpad_mode    ;
  mcmdq_wdata.lo_address          = cg4_lo_address3     ;
  mcmdq_wdata.lo_write_len        = cg4_lo_write_len    ;
  mcmdq_wdata.lo_prec_mode        = fcmd.out_precision  ;
  mcmdq_wdata.lo_mixp_precs       = fcmd.out_mixp_precs ;
  mcmdq_wdata.lo_uint_mode        = fcmd.out_unsigned   ;
  mcmdq_wdata.lo_pool_mode        = cg4_lo_pool_mode    ;
end

// memory write
assign mcmdq_full  = mcmdq_wtag != mcmdq_rtag && mcmdq_wptr == mcmdq_rptr;
assign mcmdq_empty = mcmdq_wtag == mcmdq_rtag && mcmdq_wptr == mcmdq_rptr;

// read/write control
assign mcmdq_wenable = ~fstall & cg4_valid;
assign mcmdq_renable = ~mcmdq_empty & mcmdq_rready;

always_comb begin
  mcmdq_rready = 1'b1;
  if (mcmdq_rvalid) begin
    if (mcmdq_rdata.li_read_en & ltc_rqempty) begin
      mcmdq_rready = 1'b0;
    end
    if (mcmdq_rdata.drain_req & (dip_active | ~ltc_awready)) begin
      mcmdq_rready = 1'b0;
    end
  end
end

// memory write
always @(posedge aixh_core_clk)
  if (mcmdq_wenable) mcmdq_mem[mcmdq_wptr] <= mcmdq_wdata;

// memory read
always @(posedge aixh_core_clk)
  if (mcmdq_renable) mcmdq_rdata <= mcmdq_mem[mcmdq_rptr];

// update write pointer
always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    mcmdq_wtag <= 1'b0;
    mcmdq_wptr <= MCMDQ_AWIDTH'(0);
  end else
  if (mcmdq_wenable) begin
    if (mcmdq_wptr == MCMDQ_EADDR) begin
      mcmdq_wtag <= ~mcmdq_wtag;
      mcmdq_wptr <= MCMDQ_AWIDTH'(0);
    end else begin
      mcmdq_wptr <= mcmdq_wptr + MCMDQ_AWIDTH'(1);
    end
  end

// update read pointer
always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    mcmdq_rtag <= 1'b0;
    mcmdq_rptr <= MCMDQ_AWIDTH'(0);
  end else
  if (mcmdq_renable) begin
    if (mcmdq_rptr == MCMDQ_EADDR) begin
      mcmdq_rtag <= ~mcmdq_rtag;
      mcmdq_rptr <= MCMDQ_AWIDTH'(0);
    end else begin
      mcmdq_rptr <= mcmdq_rptr + MCMDQ_AWIDTH'(1);
    end
  end


always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn)   mcmdq_rvalid <= 1'b0;
  else if (mcmdq_rready) mcmdq_rvalid <= ~mcmdq_empty;

//------------------------------------------------------------------------------
// Drain Interval Protection
//------------------------------------------------------------------------------
always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    dip_active <= 1'b0;
  end else if (mcmdq_rvalid & mcmdq_rready & mcmdq_rdata.drain_req) begin
    dip_active <= 1'b1;
  end else if (dip_count == $unsigned(7'(1 - DipExtraCycle()))) begin
    dip_active <= 1'b0;
  end

always_ff @(posedge aixh_core_clk)
  if (mcmdq_rvalid & mcmdq_rready & mcmdq_rdata.drain_req) begin
    dip_count <= bcmd_din.active_upcells;
  end else if (dip_active) begin
    dip_count <= dip_count - 7'd1;
  end


//------------------------------------------------------------------------------
// LTC READ control
//------------------------------------------------------------------------------
assign ltc_araddr_si  = cg4_li_address;
assign ltc_arvalid_si = cg4_li_read_en & cg4_valid & ~fstall;
assign ltc_rupdate_si = lqc_renable;

assign ltc_arfull  = ~|ltc_arcredits;
assign ltc_rqempty = ~|ltc_rqlevel;

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    ltc_arcredits <= LTC_ARCWIDTH'(LTC_ARCREDITS); 
  end else begin
    case ({ltc_arupdate_so, ltc_arvalid_si})
      2'b01: ltc_arcredits <= ltc_arcredits - LTC_ARCWIDTH'(1);
      2'b10: ltc_arcredits <= ltc_arcredits + LTC_ARCWIDTH'(1);
      default: begin /* keep */ end
    endcase
  end

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    ltc_rqlevel <= LTC_RCWIDTH'(0);
  end else begin
    case ({lqc_renable_si, ltc_rvalid[0]})
      2'b01: ltc_rqlevel <= ltc_rqlevel + LTC_RCWIDTH'(1);
      2'b10: ltc_rqlevel <= ltc_rqlevel - LTC_RCWIDTH'(1);
      default: begin /* keep */ end
    endcase
  end

//------------------------------------------------------------------------------
// UTC READ control
//------------------------------------------------------------------------------
assign utc_arvalid_si = mcmdq_rvalid
                      & mcmdq_rready
                      & mcmdq_rdata.ui_read_en;
assign utc_araddr_si  = mcmdq_rdata.ui_address;
assign utc_arvalid[0]                  = utc_arvalid_so;
assign utc_araddr[0+:UTC_SLICE_AWIDTH] = utc_araddr_so;


if (UTC_REQ_PIPES == 0) begin
  assign {utc_arvalid_so, utc_araddr_so} = 
         {utc_arvalid_si , utc_araddr_si };
end else begin: UTC_REQ_PIPE
  localparam PIPES = UTC_REQ_PIPES > 0 ? UTC_REQ_PIPES : 1;
  logic [UTC_SLICE_AWIDTH+1       -1:0] pipe[PIPES];
  
  assign {utc_arvalid_so, utc_araddr_so} = pipe[PIPES-1];

  always_ff @(posedge aixh_core_clk) begin
    pipe[0] <= {utc_arvalid_si, utc_araddr_si};
    for (int i = 1; i < PIPES; i++) begin
      pipe[i] <= pipe[i-1];
    end
  end 
end

//------------------------------------------------------------------------------
// LQCELL control
//------------------------------------------------------------------------------
assign lqc_wenable = ltc_rvalid[0];
assign lqc_renable = lqc_renable_so;
assign lqc_rmode   = lqc_rmode_dly[1];
assign lqc_renable_si = mcmdq_rvalid 
                      & mcmdq_rready
                      & mcmdq_rdata.li_read_en;
assign lqc_rmode_si   = mcmdq_rdata.li_read_mode;

always_ff @(posedge aixh_core_clk) begin
  lqc_rmode_dly[0] <= lqc_rmode_so;
  lqc_rmode_dly[1] <= lqc_rmode_dly[0];
end

if (LQC_REQ_PIPES == 0) begin
  assign {lqc_renable_so, lqc_rmode_so} =
         {lqc_renable_si, lqc_rmode_si};
end else begin: LQC_REQ_PIPE
  localparam PIPES = LQC_REQ_PIPES > 0 ? LQC_REQ_PIPES : 1;
  logic [6   -1:0] pipe[PIPES];
  
  assign {lqc_renable_so, lqc_rmode_so} = pipe[PIPES-1];

  always_ff @(posedge aixh_core_clk) begin
    pipe[0] <= {lqc_renable_si, lqc_rmode_si};
    for (int i = 1; i < PIPES; i++) begin
      pipe[i] <= pipe[i-1];
    end
  end 
end

//------------------------------------------------------------------------------
// LPC and UPC control
//------------------------------------------------------------------------------
assign bcmd_dout = bcmd_dpipe[BCMD_PIPES-1];
assign bcmd_vout = bcmd_vpipe[BCMD_PIPES-1];
assign bcmd_vin  = mcmdq_rvalid & mcmdq_rready;

always_comb begin
  bcmd_din.mac_enable       = mcmdq_rdata.mac_enable    ;
  bcmd_din.mac_afresh       = mcmdq_rdata.mac_afresh    ;
  bcmd_din.mac_mode         = mcmdq_rdata.mac_mode      ;
  bcmd_din.drain_pre        = mcmdq_rdata.drain_pre     ;
  bcmd_din.drain_req        = mcmdq_rdata.drain_req     ;
  bcmd_din.drain_last       = mcmdq_rdata.drain_last    ;
  bcmd_din.drain_fake       = mcmdq_rdata.drain_fake    ;
  bcmd_din.fc_mode          = mcmdq_rdata.fc_mode       ;
  bcmd_din.cluster_size     = mcmdq_rdata.cluster_size  ;
  bcmd_din.cluster_blks     = mcmdq_rdata.cluster_blks  ;
  bcmd_din.active_upcells   = mcmdq_rdata.active_upcells;
  bcmd_din.in_cvt_mode      = mcmdq_rdata.in_cvt_mode   ;
  bcmd_din.li_half_ofs      = mcmdq_rdata.li_half_ofs   ;
  bcmd_din.li_uint_mode     = mcmdq_rdata.li_uint_mode  ;
  bcmd_din.li_relu_en       = mcmdq_rdata.li_relu_en    ;
  bcmd_din.li_zpad_mode     = mcmdq_rdata.li_zpad_mode  ;
  bcmd_din.lo_address       = mcmdq_rdata.lo_address    ;
  bcmd_din.lo_prec_mode     = mcmdq_rdata.lo_prec_mode  ;
  bcmd_din.lo_mixp_precs    = mcmdq_rdata.lo_mixp_precs ;
  bcmd_din.lo_uint_mode     = mcmdq_rdata.lo_uint_mode  ;
  bcmd_din.lo_pool_mode     = mcmdq_rdata.lo_pool_mode  ;
end

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    bcmd_vpipe <= (BCMD_PIPES)'(0);
  end else begin
    bcmd_vpipe <= {bcmd_vpipe[BCMD_PIPES-2:0], bcmd_vin};
  end


always_ff @(posedge aixh_core_clk) begin
  if (bcmd_vin) begin
    bcmd_dpipe[0] <= bcmd_din;
  end

  for (int i = 1; i < BCMD_PIPES; i++) begin
    if (bcmd_vpipe[i-1]) begin
      bcmd_dpipe[i] <= bcmd_dpipe[i-1];
    end
  end
end


always_ff @(posedge aixh_core_clk2x)
  if (clk2x_phase == 'b1) begin
    pcmd_clk2x <= 'd0;

    if (bcmd_vout) begin
      pcmd_clk2x.mac_enable      <= bcmd_dout.mac_enable;
      pcmd_clk2x.mac_afresh      <= bcmd_dout.mac_afresh;
      pcmd_clk2x.mac_mode        <= bcmd_dout.mac_mode;
      pcmd_clk2x.drain_pre       <= bcmd_dout.drain_pre;
      pcmd_clk2x.drain_req       <= bcmd_dout.drain_req;
      pcmd_clk2x.drain_last      <= bcmd_dout.drain_last
                                  &~bcmd_dout.drain_fake;
      pcmd_clk2x.fc_mode         <= bcmd_dout.fc_mode;
      pcmd_clk2x.cluster_size    <= bcmd_dout.cluster_size;
      pcmd_clk2x.cluster_blks    <= bcmd_dout.cluster_blks;
      pcmd_clk2x.active_upcells  <= bcmd_dout.active_upcells;
      pcmd_clk2x.in_cvt_mode     <= bcmd_dout.in_cvt_mode;
      pcmd_clk2x.li_half_ofs     <= bcmd_dout.li_half_ofs;
      pcmd_clk2x.li_uint_mode    <= bcmd_dout.li_uint_mode;
      pcmd_clk2x.li_relu_en      <= bcmd_dout.li_relu_en;
      pcmd_clk2x.li_zpad_mode    <= bcmd_dout.li_zpad_mode;
    end

    if (dcg_active) begin
      pcmd_clk2x.lo_prec_mode <= dcg_cw_prec; 
      pcmd_clk2x.lo_uint_mode <= dcg_uint_mode; 
      pcmd_clk2x.lo_pool_mode <= dcg_pool_mode; 
      pcmd_clk2x.lo_pack_done <= dcg_cw_done & dcg_advance;
    end
  end

always_ff @(posedge aixh_core_clk2x) begin
  upc_cmd_out.mac_enable      <= pcmd_clk2x.mac_enable;
  upc_cmd_out.mac_afresh      <= pcmd_clk2x.mac_afresh;
  upc_cmd_out.mac_mode        <= pcmd_clk2x.mac_mode[0+:5];
  upc_cmd_out.drain_pre       <= pcmd_clk2x.drain_pre;
  upc_cmd_out.drain_req       <= pcmd_clk2x.drain_req;
  upc_cmd_out.active_cells    <= pcmd_clk2x.active_upcells;
  upc_cmd_out.in_half_sel     <= 1'b0;
  upc_cmd_out.in_cvt_mode     <= pcmd_clk2x.in_cvt_mode;

  lpc_cmd_out.mac_enable      <= pcmd_clk2x.mac_enable;
  lpc_cmd_out.mac_afresh      <= pcmd_clk2x.mac_afresh;
  lpc_cmd_out.mac_mode        <= pcmd_clk2x.mac_mode[0+:7];
  lpc_cmd_out.drain_req       <= pcmd_clk2x.drain_req;
  lpc_cmd_out.fc_mode         <= pcmd_clk2x.fc_mode;
  lpc_cmd_out.cluster_size    <= pcmd_clk2x.cluster_size;
  lpc_cmd_out.cluster_blks    <= pcmd_clk2x.cluster_blks;
  lpc_cmd_out.in_half_sel     <= pcmd_clk2x.li_half_ofs;
  lpc_cmd_out.in_cvt_mode     <= pcmd_clk2x.in_cvt_mode;
  lpc_cmd_out.in_uint_mode    <= pcmd_clk2x.li_uint_mode;
  lpc_cmd_out.in_relu_en      <= pcmd_clk2x.li_relu_en;
  lpc_cmd_out.in_zpad_mode    <= pcmd_clk2x.li_zpad_mode;
  lpc_cmd_out.out_prec_mode   <= pcmd_clk2x.lo_prec_mode;
  lpc_cmd_out.out_uint_mode   <= pcmd_clk2x.lo_uint_mode;
  lpc_cmd_out.out_pool_mode   <= pcmd_clk2x.lo_pool_mode;
  lpc_cmd_out.out_pack_done   <= pcmd_clk2x.lo_pack_done;

  if (clk2x_phase == 1'b1) begin
    upc_cmd_out.mac_afresh    <= 1'b0;
    upc_cmd_out.mac_mode      <= pcmd_clk2x.mac_mode[7+:5];
    upc_cmd_out.drain_pre     <= 1'b0;
    upc_cmd_out.drain_req     <= 1'b0;
    upc_cmd_out.in_half_sel   <= pcmd_clk2x.mac_enable;

    lpc_cmd_out.mac_afresh    <= 1'b0;
    lpc_cmd_out.mac_mode      <= pcmd_clk2x.mac_mode[7+:7];
    lpc_cmd_out.drain_req     <= 1'b0;
    lpc_cmd_out.in_half_sel   <= pcmd_clk2x.mac_enable;
    lpc_cmd_out.out_pack_done <= 1'b0;
  end
end
  
assign lpc_cmd_out.cluster_ofs = 8'd1;

assign lpc_cmd = lpc_cmd_out;
assign upc_cmd = upc_cmd_out;

//------------------------------------------------------------------------------
// LTC WRITE control
//------------------------------------------------------------------------------

//
// drain control generation request
//
always_comb begin
  dcg_req_vin            = bcmd_vout
                         & bcmd_dout.drain_req;
  dcg_req_din.last       = bcmd_dout.drain_last;
  dcg_req_din.fake       = bcmd_dout.drain_fake;
  dcg_req_din.count      = bcmd_dout.active_upcells;
  dcg_req_din.prec_mode  = bcmd_dout.lo_prec_mode;
  dcg_req_din.mixp_precs = bcmd_dout.lo_mixp_precs;
  dcg_req_din.uint_mode  = bcmd_dout.lo_uint_mode;
  dcg_req_din.pool_mode  = bcmd_dout.lo_pool_mode;
  dcg_req_din.address    = bcmd_dout.lo_address;
end

assign dcg_req_vout = dcg_req_vpipe[DCG_REQ_PIPES-1];
assign dcg_req_dout = dcg_req_dpipe[DCG_REQ_PIPES-1];

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) 
       dcg_req_vpipe <= DCG_REQ_PIPES'(0);
  else dcg_req_vpipe <= {dcg_req_vpipe[DCG_REQ_PIPES-2:0], dcg_req_vin};

always_ff @(posedge aixh_core_clk) begin
  if (dcg_req_vin) begin
    dcg_req_dpipe[0] <= dcg_req_din;
  end

  for (int i = 1; i < DCG_REQ_PIPES; i++) begin
    if (dcg_req_vpipe[i-1]) begin
      dcg_req_dpipe[i] <= dcg_req_dpipe[i-1];
    end
  end
end



//
// drain control gerenation
//
assign dcg_advance = (~|XREPEATER_MASK) ? 1'b1 : upc_vld;
assign dcg_mixp_prec = dcg_mixp_precs[dcg_cw_idx];
assign dcg_cw_last = dcg_cw_cnt == 7'd1;
assign dcg_cw_prec = dcg_prec_mode == 2'b00 ? 2'b00
                   : dcg_prec_mode == 2'b01 ? 2'b01
                   : dcg_prec_mode == 2'b10 ? 2'b10
                   : dcg_mixp_prec == 1'b0  ? 2'b00
                                            : 2'b01;
assign dcg_cw_done = (dcg_cw_prec == 2'b00 && dcg_cw_step == 3'd7) ||
                     (dcg_cw_prec == 2'b01 && dcg_cw_step == 3'd3) ||
                     (dcg_cw_prec == 2'b10 && dcg_cw_step == 3'd1) ;

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    dcg_active <= 1'b0;
  end else if (dcg_req_vout) begin
    dcg_active <= 1'b1;
  end else if (dcg_active & dcg_advance) begin
    dcg_active <= ~(dcg_cw_done & dcg_cw_last);
  end

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    dcg_awvalid <= 1'b0;
    dcg_awlast  <= 1'b0;
  end else if (dcg_active & dcg_advance) begin
    dcg_awvalid <= dcg_cw_done && !dcg_fake &&
                  (dcg_pool_mode == POOL_BYPASS ||
                   dcg_pool_mode == POOL_LAST);
    dcg_awlast  <= dcg_cw_done & dcg_cw_last & dcg_last;
  end else begin
    dcg_awvalid <= 1'b0;
    dcg_awlast  <= 1'b0;
  end

always_ff @(posedge aixh_core_clk)
  if (dcg_req_vout) begin
    dcg_last       <= dcg_req_dout.last;
    dcg_fake       <= dcg_req_dout.fake;
    dcg_prec_mode  <= dcg_req_dout.prec_mode;
    dcg_mixp_precs <= dcg_req_dout.mixp_precs;
    dcg_uint_mode  <= dcg_req_dout.uint_mode;
    dcg_pool_mode  <= dcg_req_dout.pool_mode;
    dcg_awaddr     <= dcg_req_dout.address;
    dcg_cw_cnt     <= dcg_req_dout.count;
    dcg_cw_idx     <= 4'd0;
    dcg_cw_step    <= 3'd0;
  end else begin
    if (dcg_active & dcg_advance) begin
      dcg_cw_cnt <= dcg_cw_cnt - 7'd1;
      if (dcg_cw_done) begin
        dcg_cw_step <= 3'd0;
        dcg_cw_idx <= dcg_cw_idx + 4'd1;
      end else begin
        dcg_cw_step <= dcg_cw_step + 3'd1;
      end
    end
    
    if (dcg_awvalid) begin
      dcg_awaddr <= dcg_awaddr + LTC_SLICE_AWIDTH'(1);
    end
  end

//
// Keep track of LTC write credit count
//
assign ltc_awready = ltc_awcredits >= LTC_AWCWIDTH'(mcmdq_rdata.lo_write_len);
assign ltc_awlength = mcmdq_rready && mcmdq_rvalid
                    ? mcmdq_rdata.lo_write_len : 6'b0;

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    ltc_awcredits <= LTC_AWCWIDTH'(LTC_AWCREDITS);
  end else begin
    ltc_awcredits <= ltc_awcredits
                   - LTC_AWCWIDTH'(ltc_awlength)
                   + LTC_AWCWIDTH'(ltc_awupdate_so);
  end

//
// Check write-completion of commands
//
assign wcntq_deq = wcntq_level != 2'd0 && wcntq_mem[wcntq_rptr] == wcnt_compl;

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    wcnt_issue <= 10'd0;
    wcnt_compl <= 10'd0;
  end else begin
    if (dcg_awvalid    ) wcnt_issue <= wcnt_issue + 10'd1;
    if (ltc_awupdate_so) wcnt_compl <= wcnt_compl + 10'd1;
  end

always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
  if (~aixh_core_rstn) begin
    wcntq_enq   <= 1'b0;
    wcntq_wptr  <= 1'b0;
    wcntq_rptr  <= 1'b0;
    wcntq_level <= 2'd0;
  end else begin
    wcntq_enq  <= dcg_awlast;
    wcntq_wptr <= wcntq_wptr + wcntq_enq;
    wcntq_rptr <= wcntq_rptr + wcntq_deq;
    case ({wcntq_enq, wcntq_deq})
      2'b10: wcntq_level <= wcntq_level + 2'd1;
      2'b01: wcntq_level <= wcntq_level - 2'd1;
      default:;
    endcase
  end

always_ff @(posedge aixh_core_clk)
  if (wcntq_enq) begin
    wcntq_mem[wcntq_wptr] <= wcnt_issue;
  end

//------------------------------------------------------------------------------
// UTC slice latency matching pipelines
//------------------------------------------------------------------------------
for (genvar s = 1; s < UTC_SLICES; s++) begin: UTC_RSLICE
  AIXH_MXC_CTRL_dpipe #(
     .DEPTH           (UTC_SLICE_SKEWS                                        )
    ,.CWIDTH          (1                                                      )
    ,.DWIDTH          (UTC_SLICE_AWIDTH                                       )
    ,.STALL           (1                                                      )
  ) u_dpipe (
     .aixh_core_clk   (aixh_core_clk                                          )
    ,.aixh_core_rstn  (aixh_core_rstn                                         )
    ,.cin             (utc_arvalid[(s-1)]                                     )
    ,.din             (utc_araddr [(s-1)*UTC_SLICE_AWIDTH+:UTC_SLICE_AWIDTH]  )
    ,.cout            (utc_arvalid[(s  )]                                     )
    ,.dout            (utc_araddr [(s  )*UTC_SLICE_AWIDTH+:UTC_SLICE_AWIDTH]  )
  );
end
  
AIXH_MXC_CTRL_cpipe #(
     .DEPTH           (REQ2UPC_LATENCY-1                                      )
    ,.CWIDTH          (UTC_SLICES                                             )
  ) u_utc_rvalid_pipe (
     .aixh_core_clk   (aixh_core_clk                                          )
    ,.aixh_core_rstn  (aixh_core_rstn                                         )
    ,.cin             (utc_arvalid                                            )
    ,.cout            (utc_rvalid                                             )
  );

//------------------------------------------------------------------------------
// LTC slice control signal (replicated)
//------------------------------------------------------------------------------
for (genvar s = 0; s < LTC_SLICES; s++) begin: LTC_RSLICE
  AIXH_MXC_CTRL_dpipe #(
     .DEPTH           (LTC_ARADDR_PIPES                                       )
    ,.CWIDTH          (1                                                      )
    ,.DWIDTH          (LTC_SLICE_AWIDTH                                       )
    ,.STALL           (1                                                      )
  ) u_dpipe (
     .aixh_core_clk   (aixh_core_clk                                          )
    ,.aixh_core_rstn  (aixh_core_rstn                                         )
    ,.cin             (ltc_arvalid_si                                         )
    ,.din             (ltc_araddr_si                                          )
    ,.cout            (ltc_arvalid[s]                                         )
    ,.dout            (ltc_araddr[s*LTC_SLICE_AWIDTH+:LTC_SLICE_AWIDTH]       )
  );
  
  AIXH_MXC_CTRL_cpipe #(
     .DEPTH           (LTC_RUPDATE_PIPES                                      )
    ,.CWIDTH          (1                                                      )
  ) u_cpipe (
     .aixh_core_clk   (aixh_core_clk                                          )
    ,.aixh_core_rstn  (aixh_core_rstn                                         )
    ,.cin             (ltc_rupdate_si                                         )
    ,.cout            (ltc_rupdate[s]                                         )
  );
end

// Common AWADDR pipeline which is quite long compared to others. 
AIXH_MXC_CTRL_dpipe #(
   .DEPTH             (DCG2LTC_PIPES - LTC_AWADDR_PIPES                       )
  ,.CWIDTH            (1                                                      )
  ,.DWIDTH            (LTC_SLICE_AWIDTH                                       )
  ,.STALL             (1                                                      )
) u_awaddr_pipe (
   .aixh_core_clk     (aixh_core_clk                                          )
  ,.aixh_core_rstn    (aixh_core_rstn                                         )
  ,.cin               (dcg_awvalid                                            )
  ,.din               (dcg_awaddr                                             )
  ,.cout              (ltc_awvalid_si                                         )
  ,.dout              (ltc_awaddr_si                                          )
);

for (genvar s = 0; s < LTC_SLICES; s++) begin: LTC_WSLICE
  AIXH_MXC_CTRL_dpipe #(
     .DEPTH           (LTC_AWADDR_PIPES                                       )
    ,.CWIDTH          (1                                                      )
    ,.DWIDTH          (LTC_SLICE_AWIDTH                                       )
    ,.STALL           (1                                                      )
  ) u_dpipe (
     .aixh_core_clk   (aixh_core_clk                                          )
    ,.aixh_core_rstn  (aixh_core_rstn                                         )
    ,.cin             (ltc_awvalid_si                                         )
    ,.din             (ltc_awaddr_si                                          )
    ,.cout            (ltc_awvalid[s]                                         )
    ,.dout            (ltc_awaddr[s*LTC_SLICE_AWIDTH+:LTC_SLICE_AWIDTH]       )
  );
end
  
AIXH_MXC_CTRL_cpipe #(
   .DEPTH           (LTC_ARUPDATE_PIPES                                       )
  ,.CWIDTH          (1                                                        )
) u_arupdate_pipe (
   .aixh_core_clk   (aixh_core_clk                                            )
  ,.aixh_core_rstn  (aixh_core_rstn                                           )
  ,.cin             (ltc_arupdate[0]                                          )
  ,.cout            (ltc_arupdate_so                                          )
);

AIXH_MXC_CTRL_cpipe #(
   .DEPTH           (LTC_AWUPDATE_PIPES                                       )
  ,.CWIDTH          (1                                                        )
) u_awupdate_pipe (
   .aixh_core_clk   (aixh_core_clk                                            )
  ,.aixh_core_rstn  (aixh_core_rstn                                           )
  ,.cin             (ltc_awupdate[0]                                          )
  ,.cout            (ltc_awupdate_so                                          )
);
  
//------------------------------------------------------------------------------
// DCS interface pipelines
//------------------------------------------------------------------------------
AIXH_MXC_CTRL_dpipe #(
   .DEPTH           (DCS_CMDW_PIPES                                         )
  ,.CWIDTH          (1                                                      )
  ,.DWIDTH          (64+1                                                   )
  ,.STALL           (1                                                      )
) u_dcs_cmdw_pipe (
   .aixh_core_clk   (aixh_core_clk                                          )
  ,.aixh_core_rstn  (aixh_core_rstn                                         )
  ,.cin             (cmdw_en                                                )
  ,.din             ({cmdw_last, cmdw_data}                                 )
  ,.cout            (cmdw_en_so                                             )
  ,.dout            ({cmdw_last_so, cmdw_data_so}                           )
);

AIXH_MXC_CTRL_cpipe #(
   .DEPTH           (DCS_CMDX_PIPES                                         )
  ,.CWIDTH          (1                                                      )
) u_dcs_cmdx_req_pipe (
   .aixh_core_clk   (aixh_core_clk                                          )
  ,.aixh_core_rstn  (aixh_core_rstn                                         )
  ,.cin             (cmdx_req                                               )
  ,.cout            (cmdx_req_so                                            )
);

AIXH_MXC_CTRL_cpipe #(
   .DEPTH           (DCS_CMDX_PIPES                                         )
  ,.CWIDTH          (1                                                      )
) u_dcs_cmdx_done_pipe (
   .aixh_core_clk   (aixh_core_clk                                          )
  ,.aixh_core_rstn  (aixh_core_rstn                                         )
  ,.cin             (cmdx_done_si                                           )
  ,.cout            (cmdx_done                                              )
);

endmodule

//==============================================================================
module AIXH_MXC_CTRL_dpipe #(
   DEPTH =0
  ,CWIDTH=1 // control signal width
  ,DWIDTH=1 // data signal width
  ,STALL =0 // data stall according to control[0] or not
) (
   input  wire                                        aixh_core_clk
  ,input  wire                                        aixh_core_rstn

  ,input  wire [CWIDTH                          -1:0] cin
  ,input  wire [DWIDTH                          -1:0] din
  ,output wire [CWIDTH                          -1:0] cout
  ,output wire [DWIDTH                          -1:0] dout
);
// synopsys dc_tcl_script_begin
// foreach x [get_cells *reg* -quiet] { set_size_only $x }
// synopsys dc_tcl_script_end

if (DEPTH == 0) begin
  assign cout = cin;
  assign dout = din;
end else begin: g_pipe
  localparam PIPES = DEPTH > 0 ? DEPTH : 1;
  logic [CWIDTH*PIPES   -1:0] cpipe;
  logic [DWIDTH         -1:0] dpipe[PIPES];

  assign cout = cpipe[(PIPES-1)*CWIDTH+:CWIDTH];
  assign dout = dpipe[PIPES-1];
  
  always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
    if (!aixh_core_rstn) begin
      cpipe <= (PIPES*CWIDTH)'(0);
    end else begin
      cpipe <= (PIPES*CWIDTH)'({cpipe, cin});
    end
  
  always_ff @(posedge aixh_core_clk) begin
    if (!STALL || cin[0]) begin
      dpipe[0] <= din;
    end
    for (int i = 1; i < PIPES; i++) begin
      if (!STALL || cpipe[(i-1)*CWIDTH]) begin
        dpipe[i] <= dpipe[i-1];
      end
    end
  end  
end

endmodule

//==============================================================================
module AIXH_MXC_CTRL_cpipe #(
   DEPTH  = 0
  ,CWIDTH = 1 // control signal width
) (
   input  wire                                        aixh_core_clk
  ,input  wire                                        aixh_core_rstn

  ,input  wire [CWIDTH                          -1:0] cin
  ,output wire [CWIDTH                          -1:0] cout
);
// synopsys dc_tcl_script_begin
// foreach x [get_cells *reg* -quiet] { set_size_only $x }
// synopsys dc_tcl_script_end

if (DEPTH == 0) begin
  assign cout = cin;
end else begin: g_pipe
  localparam PIPES = DEPTH > 0 ? DEPTH : 1;
  logic [CWIDTH*PIPES   -1:0] cpipe;

  assign cout = cpipe[(PIPES-1)*CWIDTH+:CWIDTH];

  always_ff @(posedge aixh_core_clk or negedge aixh_core_rstn)
    if (!aixh_core_rstn) begin
      cpipe <= (PIPES*CWIDTH)'(0);
    end else begin
      cpipe <= (PIPES*CWIDTH)'({cpipe, cin});
    end
end

endmodule

`resetall
