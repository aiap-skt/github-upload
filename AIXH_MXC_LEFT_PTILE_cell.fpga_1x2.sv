//==============================================================================
// AIX-H Project
//
// Module: (MxConv / Left / Processing-Tile) Cell 1x2
// Arthor: Seok Joong Hwang (nzthing@sk.com)
//==============================================================================
`default_nettype none
`include "aixh_config.vh"

`ifdef AIXH_TARGET_FPGA
`ifdef AIXH_MXC_IPCELL_1X2
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
  localparam MASK = `AIXH_MXC_IPTILE_YREPEATER_MASK;
  // Odd cell requires additional skew FF
  SkewDepth = idx[0] ? 1:0;
  for (int i = 0; i <= idx/IPTILE_YCELLS; i++) begin
    if (MASK[i]) SkewDepth++; 
  end
endfunction

function int DeskewDepth(int idx);
  localparam MASK = `AIXH_MXC_IPTILE_YREPEATER_MASK;
  automatic int drain_latency = 0;
  // Align clk2x-to-clk transfer timing
  drain_latency = `AIXH_MXC_IPE_STAGES+1 // IPE drain
                + `AIXH_MXC_LOSPE_STAGES+2; // LOSPE-pool-packing
  for (int i = 0; i < IPTILE_YCOUNT; i++) begin
    if (MASK[i]) drain_latency++;
  end
  DeskewDepth = drain_latency[0] ? 0:1;

  // Even cell requires additional skew FF
  if (!idx[0]) DeskewDepth++;

  for (int i = idx/IPTILE_YCELLS+1; i < IPTILE_YCOUNT; i++) begin
    if (MASK[i]) DeskewDepth++;
  end
endfunction

localparam IPE_STAGES  = `AIXH_MXC_IPE_STAGES;
localparam ISPE_STAGES = `AIXH_MXC_LISPE_STAGES;
localparam OSPE_STAGES = `AIXH_MXC_LOSPE_STAGES;
localparam PE_STAGES = 1            // ISPE-to-IPE latency
                     + IPE_STAGES+1 // IPE drain latency
                     + OSPE_STAGES;

localparam SKEW_DEPTH = SkewDepth(CELL_INDEX);
localparam LAT_PIPES = DeskewDepth(CELL_INDEX);

localparam POOL_MEM_DEPTH = `AIXH_MXC_WIDTH;
localparam POOL_MEM_AWIDTH = $clog2(POOL_MEM_DEPTH);
`ifdef AIXH_MXC_DISABLE_INT16
localparam POOL_DWIDTH = 8+1; // one more bit for UINT8
`else
localparam POOL_DWIDTH = 16;
`endif

LPCELL_Command                        i_cmd;
LPCELL_Command                        r_cmd;
IPCELL_Command                        ipc_cmd;

logic [LPCELL_FWI_DWIDTH        -1:0] lqc_idat;

logic [IPE_STAGES               -1:0] mac_enable_sreg;
logic [IPE_STAGES-1             -1:0] mac_afresh_sreg;
logic [PE_STAGES+LAT_PIPES+1    -1:0] drain_req_sreg; 
logic [PE_STAGES+LAT_PIPES+2    -1:0] out_int8_mode_sreg;
logic [ISPE_STAGES+1            -1:0] out_uint_mode_sreg;
logic [2                        -1:0] out_pool_mode_sreg[PE_STAGES+LAT_PIPES+2];

logic                                 ispe_drain_req;

logic                                 ispe_zpad_enable;
logic [32                       -1:0] ispe_ixdata;
logic [32                       -1:0] ispe_oxdata;
logic [ACCUM_BITS               -1:0] ispe_ozdata;

logic [OSPE_STAGES+LAT_PIPES+1  -1:0] ospe_stage;
logic                                 ospe_int8_mode;
logic                                 ospe_uint_mode;
logic [28                       -1:0] ospe_isdata;
logic [ACCUM_BITS               -1:0] ospe_ixdata;
logic [ACCUM_BITS               -1:0] ospe_iydata;
logic [ACCUM_BITS               -1:0] ospe_izdata;
logic [16                       -1:0] ospe_owdata;

logic [POOL_DWIDTH              -1:0] lat_pipe_out;

logic                                 pool_rinit;
logic                                 pool_winit;
logic                                 pool_renable;
logic                                 pool_oenable;
logic                                 pool_obypass;
logic                                 pool_wenable;
logic                                 pool_wint8;
(* ram_style = "distributed" *)
logic [POOL_DWIDTH              -1:0] pool_mem[POOL_MEM_DEPTH];
logic [POOL_MEM_AWIDTH          -1:0] pool_raddr;
logic [POOL_DWIDTH              -1:0] pool_rdata;
logic [POOL_DWIDTH              -1:0] pool_odata;
logic [POOL_MEM_AWIDTH          -1:0] pool_waddr;

logic                                 pack_enable;
logic                                 pack_valid;
logic [3                        -1:0] pack_phase;
logic [64                       -1:0] pack_data;

// Inter-LPC pipeline
assign i_cmd = i_lpc_cmd;
assign o_lpc_cmd = r_cmd;

always_ff @(posedge aixh_core_clk2x) begin 
  r_cmd <= i_cmd;
  if (i_cmd.cluster_offset == i_cmd.cluster_size)
       r_cmd.cluster_offset <= 8'd1;
  else r_cmd.cluster_offset <= i_cmd.cluster_offset + 8'd1;
end

always_ff @(posedge aixh_core_clk2x) begin 
  o_lpc_vld <= i_lpc_vld;
  if (i_lpc_vld) begin
    o_lpc_dat <= i_lpc_dat;
  end
end

// Command pipeline
always_ff @(posedge aixh_core_clk2x) begin 
  mac_enable_sreg <= {mac_enable_sreg[0+:IPE_STAGES-1], i_cmd.mac_enable};
  mac_afresh_sreg <= {mac_afresh_sreg[0+:IPE_STAGES-2], i_cmd.mac_afresh};
  drain_req_sreg  <= {drain_req_sreg [0+:PE_STAGES+LAT_PIPES], i_cmd.drain_req};

  if (i_cmd.drain_req) begin
`ifndef AIXH_MXC_DISABLE_INT16
    out_int8_mode_sreg[0] <= i_cmd.out_int8_mode;
`endif
    out_uint_mode_sreg[0] <= i_cmd.out_uint_mode;
    out_pool_mode_sreg[0] <= i_cmd.out_pool_mode;
  end
  for (int i = 1; i < PE_STAGES+LAT_PIPES+2; i++) begin
`ifndef AIXH_MXC_DISABLE_INT16
    out_int8_mode_sreg[i] <= out_int8_mode_sreg[i-1];
`endif    
    out_pool_mode_sreg[i] <= out_pool_mode_sreg[i-1];
  end
  for (int i = 1; i < ISPE_STAGES+1; i++) begin
    out_uint_mode_sreg[i] <= out_uint_mode_sreg[i-1];
  end
end

`ifdef AIXH_MXC_DISABLE_INT16
assign out_int8_mode_sreg = {$bits(out_int8_mode_sreg){1'b1}};
`endif

// Generate ISPE control signal
assign ispe_drain_req = drain_req_sreg[ISPE_STAGES];

// Skew LQC data if required
if (SKEW_DEPTH > 0) begin: g_skew
  logic [LPCELL_FWI_DWIDTH    -1:0] pipe[SKEW_DEPTH];

  always_ff @(posedge aixh_core_clk2x) begin
    pipe[0] <= i_lqc_dat;
    for (int i = 1; i < SKEW_DEPTH; i++) begin
      pipe[i] <= pipe[i-1];
    end
  end

  assign lqc_idat = pipe[SKEW_DEPTH-1];
end else begin
  assign lqc_idat = i_lqc_dat;
end

// Select 32b halfs from input 64b words
always_ff @(posedge aixh_core_clk2x)
  if (i_cmd.in_half_sel) begin
    ispe_ixdata <= lqc_idat[1*32+:32];
  end else begin
    ispe_ixdata <= lqc_idat[0*32+:32];
  end

// Zero-padding control
always_ff @(posedge aixh_core_clk2x) begin
  ispe_zpad_enable <= (i_cmd.in_zpad_sblk  && i_cmd.cluster_offset == 8'd1) ||
                      (i_cmd.in_zpad_offset < i_cmd.cluster_offset);
end

// ISPE drain
always_ff @(posedge aixh_core_clk2x)
  if (ispe_drain_req) begin
    ospe_iydata <= ispe_ozdata;
  end

// Output to IPCELL
assign o_ipc_dat = ispe_oxdata;
assign o_ipc_cmd = ipc_cmd;

always_ff @(posedge aixh_core_clk2x) begin
  ipc_cmd.mul_enable <= |mac_enable_sreg[IPE_STAGES-2:0];
  ipc_cmd.acc_enable <=  mac_enable_sreg[IPE_STAGES-1]
                        | drain_req_sreg[IPE_STAGES-1];
  ipc_cmd.acc_afresh <=  mac_afresh_sreg[IPE_STAGES-2];
  ipc_cmd.drain_req0 <=  drain_req_sreg[IPE_STAGES-1];
  ipc_cmd.drain_req1 <= |drain_req_sreg[IPE_STAGES-1+:2];
  ipc_cmd.int8_mode  <= 1'b0;
end

// Input-side PE instances
AIXH_MXC_LEFT_PTILE_CELL_ispe u_ispe(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.mac_enable          (r_cmd.mac_enable     )
  ,.mac_afresh          (r_cmd.mac_afresh     )
  ,.relu_enable         (r_cmd.in_relu_enable )
  ,.zpad_enable         (ispe_zpad_enable     )
  ,.data_mode           (r_cmd.in_data_mode   )
  ,.uint_mode           (r_cmd.in_uint_mode    )
  ,.ixdata              (ispe_ixdata          )
  ,.oxdata              (ispe_oxdata          )
  ,.ozdata              (ispe_ozdata          )
);

// Generate OSPE input signal
always @(posedge aixh_core_clk2x) begin
  ospe_stage <= {ospe_stage[0+:OSPE_STAGES+LAT_PIPES], i_ipc_vld};
end

assign ospe_int8_mode = out_int8_mode_sreg[ISPE_STAGES];
assign ospe_uint_mode = out_uint_mode_sreg[ISPE_STAGES];

assign ospe_izdata = i_ipc_dat;
assign {ospe_isdata, ospe_ixdata} = o_lpc_dat;

// Output-side PE instances
AIXH_MXC_LEFT_PTILE_CELL_ospe u_ospe(
   .aixh_core_clk2x     (aixh_core_clk2x      )
  ,.ivalid              (i_ipc_vld            )
  ,.int8_mode           (ospe_int8_mode       )
  ,.uint_mode           (ospe_uint_mode       )
  ,.isdata              (ospe_isdata          )
  ,.ixdata              (ospe_ixdata          )
  ,.iydata              (ospe_iydata          )
  ,.izdata              (ospe_izdata          )
  ,.owdata              (ospe_owdata          )
);

//
// Latency matching pipeline
//
if (LAT_PIPES == 0) begin
  assign lat_pipe_out = ospe_owdata[0+:POOL_DWIDTH];
end else begin: LAT_PIPE
  logic [POOL_DWIDTH  -1:0] pipe[LAT_PIPES];
  
  assign lat_pipe_out = pipe[LAT_PIPES-1];

  always_ff @(posedge aixh_core_clk2x) begin
    pipe[0] <= ospe_owdata[0+:POOL_DWIDTH];
    for (int i = 1; i < LAT_PIPES; i++) begin
      pipe[i] <= pipe[i-1];
    end
  end
end


//
// Pooling
//
assign pool_rinit   = drain_req_sreg    [  PE_STAGES+LAT_PIPES-2];
assign pool_winit   = drain_req_sreg    [  PE_STAGES+LAT_PIPES  ];
assign pool_wint8   = out_int8_mode_sreg[  PE_STAGES+LAT_PIPES+1];
assign pool_renable = ospe_stage        [OSPE_STAGES+LAT_PIPES-2];
assign pool_oenable = ospe_stage        [OSPE_STAGES+LAT_PIPES-1];

always @(posedge aixh_core_clk2x) begin
  
  case (out_pool_mode_sreg[PE_STAGES+LAT_PIPES-1])
    PMODE_NO_POOL   ,
    PMODE_POOL_FIRST: pool_obypass <= 1'b1;
    default         : pool_obypass <= 1'b0;
  endcase

  case (out_pool_mode_sreg[PE_STAGES+LAT_PIPES])
    PMODE_POOL_FIRST,
    PMODE_POOL_INNER: pool_wenable <= ospe_stage[OSPE_STAGES+LAT_PIPES-1];
    default         : pool_wenable <= 1'b0;
  endcase
  
  case (out_pool_mode_sreg[PE_STAGES+LAT_PIPES])
    PMODE_NO_POOL,
    PMODE_POOL_LAST: pack_enable <= ospe_stage[OSPE_STAGES+LAT_PIPES-1];
    default        : pack_enable <= 1'b0;
  endcase
              
end


// Memory address generation
always @(posedge aixh_core_clk2x) begin
  if (pool_rinit) begin
    pool_raddr <= POOL_MEM_AWIDTH'(0);
  end
  else if (pool_renable) begin
    pool_raddr <= pool_raddr + POOL_MEM_AWIDTH'(1);
  end
  
  if (pool_winit) begin
    pool_waddr <= POOL_MEM_AWIDTH'(0);
  end
  else if (pool_wenable) begin
    pool_waddr <= pool_waddr + POOL_MEM_AWIDTH'(1);
  end
end

// Memory access
always @(posedge aixh_core_clk2x) begin
  if (pool_renable) begin
    pool_rdata <= pool_mem[pool_raddr];
  end
  
  if (pool_wenable) begin
    pool_mem[pool_waddr] <= pool_odata;
  end
end

// Compute
always @(posedge aixh_core_clk2x)
  if (pool_oenable) begin
    if ($signed(pool_rdata) < $signed(lat_pipe_out) || pool_obypass)
         pool_odata <= lat_pipe_out;
    else pool_odata <= pool_rdata;
  end


//
// Packing
//
always_ff @(posedge aixh_core_clk2x) begin
  pack_valid <= 'b0;
  
  if (pool_winit) begin
    pack_phase <= 'd0;
  end else
  if (pack_enable) begin
    pack_phase <= pack_phase + 'd1;
    pack_valid <= (pack_phase[2] | ~pool_wint8) &&
                  (pack_phase[1:0] == 'b11);
  end
end

always_ff @(posedge aixh_core_clk2x)
  if (pack_enable) begin
    case ({pool_wint8, pack_phase})
`ifdef AIXH_MXC_DISABLE_INT16
      4'h0: pack_data[0*16+:16] <= pool_odata;
      4'h1: pack_data[1*16+:16] <= pool_odata;
      4'h2: pack_data[2*16+:16] <= pool_odata;
      4'h3: pack_data[3*16+:16] <= pool_odata;
`endif
      4'h8: pack_data[0* 8+: 8] <= pool_odata[0+:8];
      4'h9: pack_data[1* 8+: 8] <= pool_odata[0+:8];
      4'ha: pack_data[2* 8+: 8] <= pool_odata[0+:8];
      4'hb: pack_data[3* 8+: 8] <= pool_odata[0+:8];
      4'hc: pack_data[4* 8+: 8] <= pool_odata[0+:8];
      4'hd: pack_data[5* 8+: 8] <= pool_odata[0+:8];
      4'he: pack_data[6* 8+: 8] <= pool_odata[0+:8];
      4'hf: pack_data[7* 8+: 8] <= pool_odata[0+:8];
      default:;
    endcase
  end

assign o_lqc_vld = pack_valid;
assign o_lqc_dat = pack_data;

endmodule
`endif // AIXH_MXC_IPCELL_1X2
`endif // AIXH_TARGET_FPGA
`resetall
