`include "util.vh"
`include "const.vh"

module Cache_nWB #
(
  parameter LINES = 64,
  parameter CPU_WIDTH = `CPU_INST_BITS, //32
  parameter WORD_ADDR_BITS = `CPU_ADDR_BITS-`ceilLog2(`CPU_INST_BITS/8) //32-2 = 30
)
(
  input clk,
  input reset,

  input                       cpu_req_valid,
  output reg                  cpu_req_ready,
  input [WORD_ADDR_BITS-1:0]  cpu_req_addr,  //addr [31:2]
  input [CPU_WIDTH-1:0]       cpu_req_data,
  input [3:0]                 cpu_req_write,

  output                      cpu_resp_valid,
  output reg [CPU_WIDTH-1:0]  cpu_resp_data,

  output reg                  mem_req_valid,
  input                       mem_req_ready,
  output reg [WORD_ADDR_BITS-1:`ceilLog2(`MEM_DATA_BITS/CPU_WIDTH)] mem_req_addr, //[29:2]
  output reg                  mem_req_rw,
  output reg                  mem_req_data_valid,
  input                            mem_req_data_ready,
  output reg [`MEM_DATA_BITS-1:0]  mem_req_data_bits,
  // byte level masking
  output reg [(`MEM_DATA_BITS/8)-1:0] mem_req_data_mask,

  input                       mem_resp_valid,
  input [`MEM_DATA_BITS-1:0]  mem_resp_data
);

  //SRAM Cache 
  reg [4:0]     cache_index;                       //5bit index: 32 entries
  reg           web15_12, web11_8, web7_4, web3_0; //read:1 write:0
  reg [15:0]    bytemask;                          //16byte (128bit per SRAM) write:1
  reg [127:0]   i_data15_12, i_data11_8, i_data7_4, i_data3_0;
  wire[127:0]   o_data15_12, o_data11_8, o_data7_4, o_data3_0;
  wire[31:0]    cache_data;

  reg           web_tag;      //read:1 write:0
  reg           i_dirty, i_valid;
  reg [20:0]    i_tag;
  wire          o_dirty, o_valid; 
  wire[20:0]    cache_tag;
  wire[8:0]     o_none_use;

  SRAM1RW64x32    TAG            (.A({1'd0,cache_index}),.CE(clk),.WEB(web_tag),.OEB(1'd0),.CSB(1'd0),
                                .I({9'd0,i_dirty,i_valid,i_tag}),.O({o_none_use,o_dirty,o_valid,cache_tag}));

  SRAM1RW256x128  DATA15_12WORDS (.A({3'd0,cache_index}),.CE(clk),.WEB(web15_12),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask),.I(i_data15_12),.O(o_data15_12));
  SRAM1RW256x128  DATA11_8WORDS  (.A({3'd0,cache_index}),.CE(clk),.WEB(web11_8),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask),.I(i_data11_8),.O(o_data11_8));
  SRAM1RW256x128  DATA7_4WORDS   (.A({3'd0,cache_index}),.CE(clk),.WEB(web7_4),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask),.I(i_data7_4),.O(o_data7_4));
  SRAM1RW256x128  DATA3_0WORDS   (.A({3'd0,cache_index}),.CE(clk),.WEB(web3_0),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask),.I(i_data3_0),.O(o_data3_0));

  //Cache Initialization
  reg [4:0] init_cnt, init_cnt_nxt;

  //from cpu_req
  reg [20:0]  cpu_tag     ,cpu_tag_nxt;
  reg [31:0]  cpu_data    ,cpu_data_nxt;
  reg [4:0]   cpu_index   ,cpu_index_nxt;
  reg [3:0]   cpu_offset  ,cpu_offset_nxt;
  reg         cpu_valid   ,cpu_valid_nxt;
  reg [3:0]   cpu_write   ,cpu_write_nxt;
  
  localparam IDLE         = 3'd0; 
  localparam WRITE        = 3'd1;
  localparam BEFORE_READ  = 3'd2;
  localparam READ_MEM     = 3'd3;
  localparam BEFORE_WRITE = 3'd4;
  localparam WRITE_BACK   = 3'd5;
  localparam BEFORE_IDLE  = 3'd6;

  reg [2:0] state, state_nxt;
  reg [2:0] cnt,   cnt_nxt;

  //write buffer
  reg         buf_dirty, buf_dirty_nxt;
  reg [20:0]  buf_tag, buf_tag_nxt;
  reg [127:0] buf15_12, buf11_8, buf7_4, buf3_0;
  reg [127:0] buf15_12_nxt, buf11_8_nxt, buf7_4_nxt, buf3_0_nxt;

  wire hit, miss; 
  assign hit  = (cpu_valid) & o_valid & (cpu_tag == cache_tag); 
  assign miss = (cpu_valid) & ~(o_valid & (cpu_tag == cache_tag));

  //write 
  wire [127:0]  READMEM_write_data, WRITEBACK_write_data;
  wire [15:0]   write_hit_mask;
  wire [3:0]    WRITE_wen, READMEM_wen;
   
  //mem buffer
  reg         from_mem, from_mem_nxt;
  reg [127:0] data_from_mem15_12, data_from_mem15_12_nxt; 
  always@(*) begin
    state_nxt     = state;
    cnt_nxt       = cnt;
    //mem buffer
    from_mem_nxt  = from_mem;
    data_from_mem15_12_nxt = data_from_mem15_12;
    //cpu buffer
    cpu_tag_nxt   = cpu_tag;
    cpu_data_nxt  = cpu_data;
    cpu_index_nxt = cpu_index;
    cpu_offset_nxt= cpu_offset;
    cpu_valid_nxt = cpu_valid;
    cpu_write_nxt = cpu_write;
    //write buffer
    buf_dirty_nxt = buf_dirty;
    buf_tag_nxt   = buf_tag;
    {buf15_12_nxt,buf11_8_nxt,buf7_4_nxt,buf3_0_nxt}= {buf15_12,buf11_8,buf7_4,buf3_0};
    //cache interface
    if(reset) begin
      init_cnt_nxt = init_cnt + 5'd1;

      bytemask    = 16'hFFFF;   //write
      cache_index = init_cnt;   //current cpu input index
      {web15_12,web11_8,web7_4,web3_0} = 4'b0000; //Write
      {i_data15_12,i_data11_8,i_data7_4,i_data3_0}= 512'd0;
      web_tag  = 1'b0; 
      {i_dirty,i_valid,i_tag} = 23'd0;
    end
    else begin
      init_cnt_nxt = 5'd0;

      bytemask    = 16'h0000;           //no write
      cache_index = cpu_index;
      {web15_12,web11_8,web7_4,web3_0} = 4'b1111; //read
      {i_data15_12,i_data11_8,i_data7_4,i_data3_0}= {o_data15_12,o_data11_8,o_data7_4,o_data3_0};
      web_tag = 1'b1;
      {i_dirty,i_valid,i_tag}= {o_dirty,o_valid,cache_tag};
    end
    //memory interface
    mem_req_valid       = 1'd0  ;       //no mem transaction
    mem_req_addr        = 28'd0 ;
    mem_req_rw          = 1'd0  ;       //read
    mem_req_data_valid  = 1'd0  ; 
    mem_req_data_bits   = 128'd0;
    mem_req_data_mask   = 16'd0 ; 
    //cpu interface
    cpu_req_ready       = 1'd1  ;       //default not to stall
    cpu_resp_data       = cache_data; 
    case(state)
      IDLE: //3'd0
      begin
        //state
        if(miss) state_nxt = BEFORE_READ;
        else if(|(cpu_req_write)& cpu_req_valid) state_nxt = WRITE; 
        else state_nxt = IDLE;
        //mem buffer
        from_mem_nxt = 1'd0;
        //cpu buffer
        if(~miss) begin
          cpu_tag_nxt   = cpu_req_addr[29:9];
          cpu_data_nxt  = cpu_req_data;
          cpu_index_nxt = cpu_req_addr[8:4] ;
          cpu_offset_nxt= cpu_req_addr[3:0] ;
          cpu_valid_nxt = cpu_req_valid;
          cpu_write_nxt = cpu_req_write;
        end
        //cache  interface 
        if(~reset) begin
          if(miss) cache_index = cpu_index;
          else cache_index = cpu_req_addr[8:4];
        end
        //memory interface
        
        //cpu interface
        if(miss) begin
          cpu_req_ready   = 1'd0; //stall
          cpu_resp_data   = 32'd0;
        end
      end
      WRITE: //3'd1
      begin
        //state
        if(hit) state_nxt = IDLE;
        else state_nxt = BEFORE_READ; //write miss
        //cache  interface
        if(hit) begin
          bytemask    = write_hit_mask;     //write
          cache_index = cpu_index;          
          web_tag     = 1'd0;
          i_dirty     = 1'd1;
          {web15_12,web11_8,web7_4,web3_0} = WRITE_wen; //read
          {i_data15_12,i_data11_8,i_data7_4,i_data3_0}= {16{cpu_data}};
        end 
        //memory interface
        
        //cpu interface
        cpu_req_ready = 1'd0; //stall
      end
      BEFORE_READ: //3'd2
      begin
        //state
        if(mem_req_ready) begin
          state_nxt = READ_MEM;
          cnt_nxt   = 3'd0;
        end
        //cache  interface 
        if(~reset) begin
          cache_index = cpu_index;
        end
        //memory interface
        mem_req_valid       = 1'd1  ;       //Read from MEM
        mem_req_addr        = {cpu_tag,cpu_index,2'd0} ; //mem_req_addr[1:0] is useless in READMEM
        mem_req_rw          = 1'd0  ;       //read
        //cpu interface
        cpu_req_ready       = 1'd0  ; 

        //write buffer
        buf_dirty_nxt = o_dirty;
        buf_tag_nxt   = cache_tag;
        {buf15_12_nxt,buf11_8_nxt,buf7_4_nxt,buf3_0_nxt} = {o_data15_12,o_data11_8,o_data7_4,o_data3_0};
      end
      READ_MEM: //3'd3
      begin
        //state
        if(mem_req_ready & mem_resp_valid) begin
          if(buf_dirty) state_nxt = BEFORE_WRITE;
          else begin 
            state_nxt     = IDLE;
            from_mem_nxt  = 1'd1;
          end
        end
        //counter
        if(mem_resp_valid) begin
          if(mem_req_ready) cnt_nxt = 3'd0;
          else cnt_nxt = cnt + 3'd1;
        end
        //cache  interface
        if(mem_resp_valid) begin //write the mem_resp_data into SRAM
          bytemask    = 16'hFFFF;           //write
          cache_index = cpu_index;
          data_from_mem15_12_nxt = mem_resp_data; 
          {web15_12,web11_8,web7_4,web3_0} = READMEM_wen; //write by turns
          web_tag = 1'b1;
          if(cnt == cpu_offset[3:2]) begin
            {i_data15_12,i_data11_8,i_data7_4,i_data3_0} = {{4{READMEM_write_data}}};        
          end
          else begin
            {i_data15_12,i_data11_8,i_data7_4,i_data3_0} = {{4{mem_resp_data}}};
          end
          if(cnt == 3'd0) begin
            web_tag = 1'b0;
            {i_dirty,i_valid,i_tag} = {|(cpu_write),1'd1,cpu_tag};
          end
        end
        //memory  interface
        mem_req_valid       = 1'd1  ;       //Read from MEM
        mem_req_addr        = {cpu_tag,cpu_index,2'd0} ; //mem_req_addr[1:0] is useless in READMEM
        mem_req_rw          = 1'd0  ;       //read
        //cpu  interface
        cpu_req_ready       = 1'd0  ;       //stall
      end
      BEFORE_WRITE: //3'd4
      begin
        //state
        if(mem_req_ready) begin
          state_nxt = WRITE_BACK;
          // cnt_nxt   = cnt + 3'd1;
        end
        //memery interface
        mem_req_valid       = 1'd1  ;       //mem transaction
        mem_req_addr        = {buf_tag,cpu_index,cnt[1:0]};
        mem_req_rw          = 1'd1  ;       //write
        mem_req_data_valid  = 1'd1  ; 
        mem_req_data_bits   = WRITEBACK_write_data;
        mem_req_data_mask   = 16'hFFFF;
        //cpu interface
        cpu_req_ready       = 1'd0;         //stall
      end
      WRITE_BACK:  //3d'5
      begin
        //state
        if(mem_req_data_ready) begin
          if(cnt == 3'd3) state_nxt = BEFORE_IDLE;
          else state_nxt = BEFORE_WRITE;
        end
        //counter
        if(mem_req_data_ready) begin
          if(cnt == 3'd3) cnt_nxt = 3'd0;
          else cnt_nxt = cnt + 3'd1;
        end
        //cache  interface: idle...

        //memory interface
        mem_req_valid       = 1'd1  ;       //mem transaction
        mem_req_addr        = {buf_tag,cpu_index,cnt[1:0]};
        mem_req_rw          = 1'd1  ;       //write
        mem_req_data_valid  = 1'd1  ; 
        mem_req_data_bits   = WRITEBACK_write_data;
        mem_req_data_mask   = 16'hFFFF;
        //cpu interface
        cpu_req_ready       = 1'd0;         //stall
      end
      BEFORE_IDLE: //3'd6
      begin
        if(mem_req_ready) state_nxt = IDLE;
        //cpu interface
        cpu_req_ready       = 1'd0  ;       //default not to stall
      end
    endcase
  end

  always@(posedge clk) begin
    if(reset) begin
      //cache init
      if(init_cnt>=5'd0 && init_cnt<=5'd31) begin
        init_cnt <= init_cnt_nxt;
      end
      else begin
        init_cnt <= 5'd0;
      end
      //state & counter
      state <= 3'd0;
      cnt   <= 3'd0; 
      //cpu buffer
      cpu_tag   <= 21'd0;
      cpu_data  <= 32'd0;
      cpu_index <= 5'd0;
      cpu_offset<= 4'd0;
      cpu_valid <= 1'd0;
      cpu_write <= 3'd0;
      //write buffer
      buf_dirty <= 1'd0;
      buf_tag   <= 21'd0;
      {buf15_12, buf11_8, buf7_4, buf3_0} <= 512'd0;
      //mem buffer
      from_mem  <= 1'd0;
      data_from_mem15_12 <= 128'd0;
    end
    else begin
      //cache init
      init_cnt <= init_cnt_nxt;
      //state & counter
      state <= state_nxt;
      cnt   <= cnt_nxt;
      //cpu buffer
      cpu_tag     <= cpu_tag_nxt;
      cpu_data    <= cpu_data_nxt;
      cpu_index   <= cpu_index_nxt;
      cpu_offset  <= cpu_offset_nxt;
      cpu_valid   <= cpu_valid_nxt;
      cpu_write   <= cpu_write_nxt;
      //write buffer
      buf_dirty <= buf_dirty_nxt;
      buf_tag   <= buf_tag_nxt;
      {buf15_12, buf11_8, buf7_4, buf3_0} <= {buf15_12_nxt, buf11_8_nxt, buf7_4_nxt, buf3_0_nxt};
      //mem buffer
      from_mem  <= from_mem_nxt;
      data_from_mem15_12 <= data_from_mem15_12_nxt;
    end
  end

  //cache response data
  wire [31:0] o_mux15_12, o_mux11_8, o_mux7_4, o_mux3_0;
  wire [127:0] i_mux15_12;
  assign i_mux15_12 = from_mem? data_from_mem15_12: o_data15_12;
  mux4_to1 mux_data15_12(.in(i_mux15_12 ), .sel(cpu_offset[1:0]), .out(o_mux15_12)); 
  mux4_to1 mux_data11_8 (.in(o_data11_8 ), .sel(cpu_offset[1:0]), .out(o_mux11_8)); 
  mux4_to1 mux_data7_4  (.in(o_data7_4  ), .sel(cpu_offset[1:0]), .out(o_mux7_4)); 
  mux4_to1 mux_data3_0  (.in(o_data3_0  ), .sel(cpu_offset[1:0]), .out(o_mux3_0)); 
  mux4_to1 mux_cache_resp_data (.in({o_mux15_12, o_mux11_8, o_mux7_4, o_mux3_0}), 
                        .sel(cpu_offset[3:2]), .out(cache_data));
  //WRITE Cache
  Write_Mask    write_mask(.which_words(cpu_offset[1:0]), 
                        .cpu_write_mask(cpu_write), .write_mask(write_hit_mask));
  Write_Enable  write_enable_WRITE  (.which_SRAM(cpu_offset[3:2]), 
                        .write_enable_hit(WRITE_wen));
  Write_Enable  write_enable_READMEM(.which_SRAM(cnt[1:0]), 
                        .write_enable_hit(READMEM_wen));
  Write_Data    write_data(.mem_resp_data(mem_resp_data), .cpu_req_data(cpu_data), 
                        .cpu_req_write(cpu_write), 
                        .which_words(cpu_offset[1:0]), 
                        .sram_write_data(READMEM_write_data));

  //WRITE MEM
  mux4_to1 #(.WIDTH(512)) write_back_data_MUX (.in({buf15_12,buf11_8,buf7_4,buf3_0}), 
                          .sel(cnt[1:0]), .out(WRITEBACK_write_data));

 endmodule