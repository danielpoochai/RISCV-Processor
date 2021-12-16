`include "const.vh"

module Memory151 #
( 
  parameter CACHE_CONFIG  = `DIRECT_MAPPED
)
( 
  input clk,
  input reset,

  // Cache <=> CPU interface
  input  [31:0] dcache_addr,
  input  [31:0] icache_addr,
  input  [3:0]  dcache_we,
  input         dcache_re,
  input         icache_re,
  input  [31:0] dcache_din,
  output [31:0] dcache_dout,
  // output        dcache_dout_valid,
  output [31:0] icache_dout,
  // output        icache_dout_valid,
  output        stall,

  // Arbiter <=> Main memory interface
  output                       mem_req_valid,
  input                        mem_req_ready,
  output                       mem_req_rw,
  output [`MEM_ADDR_BITS-1:0]  mem_req_addr,
  output [`MEM_TAG_BITS-1:0]   mem_req_tag,

  output                       mem_req_data_valid,
  input                        mem_req_data_ready,
  output [`MEM_DATA_BITS-1:0]  mem_req_data_bits,
  output [(`MEM_DATA_BITS/8)-1:0]  mem_req_data_mask,

  input                        mem_resp_valid,
  input [`MEM_DATA_BITS-1:0]   mem_resp_data,
  input [`MEM_TAG_BITS-1:0]    mem_resp_tag

);

wire dcahce_cpu_req_valid;
wire i_stall_n;
wire d_stall_n;

wire ic_mem_req_valid;
wire ic_mem_req_ready;
wire [`MEM_ADDR_BITS-1:0]  ic_mem_req_addr;
wire ic_mem_resp_valid;

wire dc_mem_req_valid;
wire dc_mem_req_ready;
wire dc_mem_req_rw;
wire [`MEM_ADDR_BITS-1:0]  dc_mem_req_addr;
wire dc_mem_resp_valid;

wire [(`MEM_DATA_BITS/8)-1:0]  dc_mem_req_mask;

assign dcahce_cpu_req_valid = ((| dcache_we) || dcache_re);

`ifdef no_cache_mem
no_cache_mem icache (
  .clk(clk),
  .reset(reset),
  .cpu_req_valid(icache_re),
  .cpu_req_ready(i_stall_n),
  .cpu_req_addr(icache_addr[31:2]),
  .cpu_req_data(), // core does not write to icache
  .cpu_req_write(4'b0), // never write
  .cpu_resp_valid(),
  .cpu_resp_data(icache_dout)
);

no_cache_mem dcache (
  .clk(clk),
  .reset(reset),
  .cpu_req_valid(dcahce_cpu_req_valid),
  .cpu_req_ready(d_stall_n),
  .cpu_req_addr(dcache_addr[31:2]),
  // .cpu_req_addr(dcache_addr[29:0]),
  .cpu_req_data(dcache_din),
  .cpu_req_write(dcache_we),
  .cpu_resp_valid(),
  .cpu_resp_data(dcache_dout)
);
assign stall =  ~i_stall_n || ~d_stall_n;

`else 
// generate Cache
generate 
  case(CACHE_CONFIG)
    `DIRECT_MAPPED:
    begin
      Cache_DM_read_only icache (
        .clk(clk),
        .reset(reset),
        .cpu_req_valid(icache_re),
        .cpu_req_ready(i_stall_n),
        .cpu_req_addr(icache_addr[31:2]),
        .cpu_resp_valid(),
        .cpu_resp_data(icache_dout),
        .mem_req_valid(ic_mem_req_valid),
        .mem_req_ready(ic_mem_req_ready),
        .mem_req_addr(ic_mem_req_addr),
        .mem_req_data_valid(),
        .mem_req_data_bits(),
        .mem_req_data_mask(),
        .mem_req_data_ready(),
        .mem_req_rw(),
        .mem_resp_valid(ic_mem_resp_valid),
        .mem_resp_data(mem_resp_data)
      );
      Cache_DM dcache(
        .clk(clk),
        .reset(reset),
        .cpu_req_valid(dcahce_cpu_req_valid),
        .cpu_req_ready(d_stall_n),
        .cpu_req_addr(dcache_addr[31:2]),
        .cpu_req_data(dcache_din),
        .cpu_req_write(dcache_we),
        .cpu_resp_valid(),
        .cpu_resp_data(dcache_dout),
        .mem_req_valid(dc_mem_req_valid),
        .mem_req_ready(dc_mem_req_ready),
        .mem_req_addr(dc_mem_req_addr),
        .mem_req_rw(dc_mem_req_rw),
        .mem_req_data_valid(mem_req_data_valid),
        .mem_req_data_bits(mem_req_data_bits),
        .mem_req_data_mask(mem_req_data_mask),
        .mem_req_data_ready(mem_req_data_ready),
        .mem_resp_valid(dc_mem_resp_valid),
        .mem_resp_data(mem_resp_data)
      );
    end
    `TWO_WAY_ASSOCIATIVE:
    begin
      Cache_2WAY_read_only icache (
        .clk(clk),
        .reset(reset),
        .cpu_req_valid(icache_re),
        .cpu_req_ready(i_stall_n),
        .cpu_req_addr(icache_addr[31:2]),
        .cpu_resp_valid(),
        .cpu_resp_data(icache_dout),
        .mem_req_valid(ic_mem_req_valid),
        .mem_req_ready(ic_mem_req_ready),
        .mem_req_addr(ic_mem_req_addr),
        .mem_req_data_valid(),
        .mem_req_data_bits(),
        .mem_req_data_mask(),
        .mem_req_data_ready(),
        .mem_req_rw(),
        .mem_resp_valid(ic_mem_resp_valid),
        .mem_resp_data(mem_resp_data)
      );

      Cache_2WAY dcache (
        .clk(clk),
        .reset(reset),
        .cpu_req_valid(dcahce_cpu_req_valid),
        .cpu_req_ready(d_stall_n),
        .cpu_req_addr(dcache_addr[31:2]),
        .cpu_req_data(dcache_din),
        .cpu_req_write(dcache_we),
        .cpu_resp_valid(),
        .cpu_resp_data(dcache_dout),
        .mem_req_valid(dc_mem_req_valid),
        .mem_req_ready(dc_mem_req_ready),
        .mem_req_addr(dc_mem_req_addr),
        .mem_req_rw(dc_mem_req_rw),
        .mem_req_data_valid(mem_req_data_valid),
        .mem_req_data_bits(mem_req_data_bits),
        .mem_req_data_mask(mem_req_data_mask),
        .mem_req_data_ready(mem_req_data_ready),
        .mem_resp_valid(dc_mem_resp_valid),
        .mem_resp_data(mem_resp_data)
      );
    end
  endcase
endgenerate

assign stall =  ~i_stall_n || ~d_stall_n;

//                           ICache 
//                         /        \
//   Riscv151 --- Memory151          Arbiter <--> ExtMemModel
//                         \        /
//                           DCache 

riscv_arbiter arbiter (
  .clk(clk),
  .reset(reset),
  .ic_mem_req_valid(ic_mem_req_valid),
  .ic_mem_req_ready(ic_mem_req_ready),
  .ic_mem_req_addr(ic_mem_req_addr),
  .ic_mem_resp_valid(ic_mem_resp_valid),

  .dc_mem_req_valid(dc_mem_req_valid),
  .dc_mem_req_ready(dc_mem_req_ready),
  .dc_mem_req_rw(dc_mem_req_rw),
  .dc_mem_req_addr(dc_mem_req_addr),
  .dc_mem_resp_valid(dc_mem_resp_valid),

  .mem_req_valid(mem_req_valid),
  .mem_req_ready(mem_req_ready),
  .mem_req_rw(mem_req_rw),
  .mem_req_addr(mem_req_addr),
  .mem_req_tag(mem_req_tag),
  .mem_resp_valid(mem_resp_valid),
  .mem_resp_tag(mem_resp_tag)
);


`endif

endmodule
