//==============================================================================
// AIX-H Project
//
// Module: MxConv Package
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`include "aixh_config.vh"

package AIXH_MXC_pkg;
`ifdef AIXH_MXC_IPCELL_1X2
  localparam IPCELL_HEIGHT = 1;
  localparam IPCELL_WIDTH  = 2;
  localparam IPCELL_DRAINS = 1;
`elsif AIXH_MXC_IPCELL_2X2
  localparam IPCELL_HEIGHT = 2;
  localparam IPCELL_WIDTH  = 2;
  localparam IPCELL_DRAINS = 2;
`else
  `error "Invalid MXC Cell Size"
`endif

  localparam MXC_HEIGHT = `AIXH_MXC_HEIGHT;
  localparam MXC_WIDTH  = `AIXH_MXC_WIDTH;

  localparam IPTILE_HEIGHT = `AIXH_MXC_IPTILE_HEIGHT;
  localparam IPTILE_WIDTH  = `AIXH_MXC_IPTILE_WIDTH;
  localparam IPTILE_DRAINS = IPTILE_HEIGHT * IPCELL_DRAINS;
  localparam IPTILE_YCELLS = IPTILE_HEIGHT / IPCELL_HEIGHT;
  localparam IPTILE_XCELLS = IPTILE_WIDTH  / IPCELL_WIDTH;
  localparam IPTILE_YCOUNT = MXC_HEIGHT / IPTILE_HEIGHT; 
  localparam IPTILE_XCOUNT = MXC_WIDTH  / IPTILE_WIDTH; 

  // In the current architecture, there is no tiling in the left queue
  // regardless of LTC slicing. This is different from the upper one.
  localparam LQCELL_HEIGHT = IPCELL_HEIGHT * 2;
  localparam LQTILE_COUNT  = 1;
  localparam LQTILE_HEIGHT = MXC_HEIGHT / LQTILE_COUNT;
  localparam LQTILE_CELLS  = LQTILE_HEIGHT / LQCELL_HEIGHT;

  localparam UQCELL_WIDTH  = IPCELL_WIDTH * 2;
  localparam UQTILE_COUNT  = `AIXH_UTC_SLICES;
  localparam UQTILE_WIDTH  = MXC_WIDTH / UQTILE_COUNT;
  localparam UQTILE_CELLS  = UQTILE_WIDTH / UQCELL_WIDTH;
  
  localparam ACCUM_BITS = `AIXH_MXC_ACCUMULATOR_BITS;
  localparam SCALE_BITS = 2*(`AIXH_MXC_SCALE_MANTISSA_BITS-1+6);

  //----------------------------------------------------------------------------
  // Opcodes
  //----------------------------------------------------------------------------
  // Precision
  localparam PREC_INT4  = 2'b00,
             PREC_INT8  = 2'b01,
             PREC_INT16 = 2'b10,
             PREC_MIX48 = 2'b11;

  // read modes
  localparam RMODE_KEEP      = 2'b00,
             RMODE_STRAIGHT  = 2'b01,
             RMODE_UP_SHIFT  = 2'b10,
             RMODE_DN_SHIFT  = 2'b11;
  
  // Pooling mode
  localparam POOL_BYPASS = 2'b00,
             POOL_FIRST  = 2'b01,
             POOL_INNER  = 2'b10,
             POOL_LAST   = 2'b11;

  localparam ZPAD_NONE  = 3'd0,
             ZPAD_ABLK  = 3'd1, // all blocks
             ZPAD_FBLK  = 3'd2, // first block
             ZPAD_LBLK1 = 3'd3, // last block
             ZPAD_LBLK2 = 3'd4; // last two blocks

  //----------------------------------------------------------------------------
  // LEFT-PE related types
  //----------------------------------------------------------------------------  
  typedef struct packed {
    logic                                 mac_enable;
    logic                                 mac_afresh;
    logic [7                        -1:0] mac_mode;
    logic                                 drain_req;
    logic                                 fc_mode;
    logic [8                        -1:0] cluster_size;
    logic [8                        -1:0] cluster_blks;
    logic [8                        -1:0] cluster_ofs;
    logic                                 in_half_sel;
    logic [2                        -1:0] in_cvt_mode;
    logic                                 in_uint_mode;
    logic                                 in_relu_en;
    logic [3                        -1:0] in_zpad_mode;
    logic [2                        -1:0] out_prec_mode;
    logic                                 out_uint_mode;
    logic [2                        -1:0] out_pool_mode;
    logic                                 out_pack_done;
  } LPCELL_Command;
  
  //----------------------------------------------------------------------------
  // UPPER-PE related types
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic                                 mac_enable;
    logic                                 mac_afresh;
    logic [5                        -1:0] mac_mode;
    logic                                 drain_pre;
    logic                                 drain_req;
    logic [7                        -1:0] active_cells;
    logic                                 in_half_sel;
    logic [2                        -1:0] in_cvt_mode;
  } UPCELL_Command;

  //----------------------------------------------------------------------------
  // INNER-PE related types
  //----------------------------------------------------------------------------
  typedef struct packed {
    logic [IPCELL_HEIGHT            -1:0] mul_enable;
    logic [IPCELL_HEIGHT            -1:0] acc_enable;
    logic                                 acc_afresh;
    logic [5                        -1:0] mul_mode;
    logic [2                        -1:0] acc_mode;
    logic                                 drain_req0;
    logic                                 drain_req1;
  } IPCELL_Command;
 
  //----------------------------------------------------------------------------
  // Controller raw command format
  //----------------------------------------------------------------------------  
  typedef struct packed {
    logic [16                       -1:0] filter_address; 
    logic [16                       -1:0] out_mixp_precs; 
    logic [16                       -1:0] out_dx_astride; 
    logic [16                       -1:0] out_dy_astride; 
  } CTRL_RawCommand5;

  typedef struct packed {
    logic [16                       -1:0] out_sx_astride; 
    logic [16                       -1:0] out_sy_astride; 
    logic [16                       -1:0] out_address   ; 
    logic [16                       -1:0] out_width     ; 
  } CTRL_RawCommand4;

  typedef struct packed {
    logic [16                       -1:0] out_blk_height; 
    logic [16                       -1:0] in_dx_astride ; 
    logic [16                       -1:0] in_dy_astride ; 
    logic [16                       -1:0] in_address1   ; 
  } CTRL_RawCommand3;

  typedef struct packed {
    logic [16                       -1:0] in_address0   ; 
    logic [16                       -1:0] in_width1     ; 
    logic [16                       -1:0] in_width0     ; 
    logic [16                       -1:0] in_blk_height1; 
  } CTRL_RawCommand2;

  typedef struct packed {
    logic [16                       -1:0] in_blk_height0; 
    logic [16                       -1:0] in_cwords     ; 
    logic [8                        -1:0] in_xoffset    ; 
    logic [8                        -1:0] in_yoffset    ; 
    logic [8                        -1:0] cluster_blks  ; 
    logic [8                        -1:0] cluster_size  ; 
  } CTRL_RawCommand1;
  
  typedef struct packed {
    logic [4                        -1:0] slide_xstride ;
    logic [4                        -1:0] slide_ystride ;
    logic [8                        -1:0] filter_count  ;
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
    logic [1                        -1:0] __reserved0__ ;
    logic [1                        -1:0] hyper_cluster ;
    logic [1                        -1:0] fc_last       ;
    logic [1                        -1:0] fc_first      ;
    logic [1                        -1:0] fc_mode       ;
  } CTRL_RawCommand0;

  localparam UQCELL_DWD_DWIDTH = IPCELL_WIDTH*64*2;
  localparam UPCELL_DWI_DWIDTH = UQCELL_DWD_DWIDTH/2;
  localparam UPCELL_FWD_CWIDTH = $bits(UPCELL_Command);
  localparam UPCELL_BWD_DWIDTH = ACCUM_BITS+SCALE_BITS;

  localparam LQCELL_FWD_DWIDTH = IPCELL_HEIGHT*64*2;
  localparam LQCELL_BWD_DWIDTH = IPCELL_HEIGHT*64*2;
  localparam LPCELL_FWI_DWIDTH = LQCELL_FWD_DWIDTH/2;
  localparam LPCELL_BWO_DWIDTH = LQCELL_BWD_DWIDTH/2;
  localparam LPCELL_DWD_CWIDTH = $bits(LPCELL_Command);
  localparam LPCELL_DWD_DWIDTH = UPCELL_BWD_DWIDTH+ACCUM_BITS;

  localparam IPCELL_FWD_CWIDTH = $bits(IPCELL_Command);
  localparam IPCELL_FWD_DWIDTH = IPCELL_HEIGHT*32;
  localparam IPCELL_BWD_DWIDTH = IPCELL_DRAINS * ACCUM_BITS;
  localparam IPCELL_DWD_DWIDTH = IPCELL_WIDTH*32;

  localparam UQTILE_DWD_DWIDTH = UQTILE_CELLS  * UQCELL_DWD_DWIDTH;
  localparam UPTILE_DWI_DWIDTH = IPTILE_XCELLS * UPCELL_DWI_DWIDTH;

  localparam LQTILE_FWD_DWIDTH = LQTILE_CELLS  * LQCELL_FWD_DWIDTH;
  localparam LQTILE_BWD_DWIDTH = LQTILE_CELLS  * LQCELL_BWD_DWIDTH;
  localparam LPTILE_FWI_DWIDTH = IPTILE_YCELLS * LPCELL_FWI_DWIDTH; 
  localparam LPTILE_BWO_DWIDTH = IPTILE_YCELLS * LPCELL_BWO_DWIDTH; 

  localparam IPTILE_FWD_CWIDTH = IPTILE_YCELLS * IPCELL_FWD_CWIDTH;
  localparam IPTILE_FWD_DWIDTH = IPTILE_YCELLS * IPCELL_FWD_DWIDTH;
  localparam IPTILE_BWD_DWIDTH = IPTILE_YCELLS * IPCELL_BWD_DWIDTH;
  localparam IPTILE_DWD_DWIDTH = IPTILE_XCELLS * IPCELL_DWD_DWIDTH;
  
  //----------------------------------------------------------------------------
  // Tensor Cache related
  //---------------------------------------------------------------------------- 
  localparam UTC_SLICES       = `AIXH_UTC_SLICES;
  localparam UTC_SLICE_AWIDTH = `AIXH_UTC_SLICE_AWIDTH;
  localparam UTC_SLICE_DWIDTH = `AIXH_UTC_SLICE_DWIDTH;

  localparam LTC_SLICES       = `AIXH_LTC_SLICES;
  localparam LTC_SLICE_AWIDTH = `AIXH_LTC_SLICE_AWIDTH;
  localparam LTC_SLICE_DWIDTH = `AIXH_LTC_SLICE_DWIDTH;
endpackage
