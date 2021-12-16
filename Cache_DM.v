`include "util.vh"
`include "const.vh"

module Cache_DM #
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

  output reg                  cpu_resp_valid,
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

  reg cache_valid[0:31], cache_valid_nxt[0:31];
  reg o_valid_reg, o_valid_reg_nxt;

  reg cache_dirty[0:31], cache_dirty_nxt[0:31];
  reg o_dirty_reg, o_dirty_reg_nxt;

  reg [20:0] cache_tag_mem[0:31], cache_tag_mem_nxt[0:31];
  reg [20:0] cache_tag_reg, cache_tag_reg_nxt;


  SRAM1RW256x128  DATA15_12WORDS (.A({3'd0,cache_index}),.CE(clk),.WEB(web15_12),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask),.I(i_data15_12),.O(o_data15_12));
  SRAM1RW256x128  DATA11_8WORDS  (.A({3'd0,cache_index}),.CE(clk),.WEB(web11_8),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask),.I(i_data11_8),.O(o_data11_8));
  SRAM1RW256x128  DATA7_4WORDS   (.A({3'd0,cache_index}),.CE(clk),.WEB(web7_4),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask),.I(i_data7_4),.O(o_data7_4));
  SRAM1RW256x128  DATA3_0WORDS   (.A({3'd0,cache_index}),.CE(clk),.WEB(web3_0),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask),.I(i_data3_0),.O(o_data3_0));

  //from cpu_req
  reg [20:0]  cpu_tag     ,cpu_tag_nxt;
  reg [31:0]  cpu_data    ,cpu_data_nxt;
  reg [4:0]   cpu_index   ,cpu_index_nxt;
  reg [3:0]   cpu_offset  ,cpu_offset_nxt;
  reg         cpu_valid   ,cpu_valid_nxt;
  reg [3:0]   cpu_write   ,cpu_write_nxt;
  
  localparam IDLE         = 2'd0; 
  localparam WRITE        = 2'd1;
  localparam BEFORE_READ  = 2'd2;
  localparam READ_MEM     = 2'd3; 

  localparam BEFORE_WRITE = 2'd1;
  localparam WRITE_BACK   = 2'd2;
  localparam BEFORE_IDLE  = 2'd3;

  reg [1:0] state, state_nxt;
  reg [1:0] wb_state, wb_state_nxt;
  reg [2:0] cnt,   cnt_nxt;
  reg [2:0] wb_cnt, wb_cnt_nxt;

  //write buffer
  reg         buf_dirty, buf_dirty_nxt;
  reg [4:0]   buf_index, buf_index_nxt;
  reg [20:0]  buf_tag, buf_tag_nxt;
  reg [127:0] buf15_12, buf11_8, buf7_4, buf3_0;
  reg [127:0] buf15_12_nxt, buf11_8_nxt, buf7_4_nxt, buf3_0_nxt;

  wire hit, miss; 
  assign hit  = (cpu_valid) & o_valid_reg & (cpu_tag == cache_tag_reg); 
  assign miss = (cpu_valid) & (~(o_valid_reg) || (cpu_tag != cache_tag_reg)); 

  //write 
  wire [127:0]  READMEM_write_data, WRITEBACK_write_data;
  wire [15:0]   write_hit_mask;
  wire [3:0]    WRITE_wen, READMEM_wen;
   
  //mem buffer
  reg         from_mem, from_mem_nxt;
  reg [127:0] data_from_mem15_12, data_from_mem15_12_nxt; 

  integer i;
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
    //cache interface
    bytemask    = 16'h0000;           //no write
    cache_index = cpu_index;
    {web15_12,web11_8,web7_4,web3_0} = 4'b1111; //read
    {i_data15_12,i_data11_8,i_data7_4,i_data3_0}= {o_data15_12,o_data11_8,o_data7_4,o_data3_0};
    
    for(i=0; i<32; i=i+1) begin
      cache_valid_nxt[i] = cache_valid[i];
      cache_dirty_nxt[i] = cache_dirty[i];
      cache_tag_mem_nxt[i] = cache_tag_mem[i]; 
    end
    o_valid_reg_nxt = cache_valid[cache_index];
    o_dirty_reg_nxt = cache_dirty[cache_index];
    cache_tag_reg_nxt = cache_tag_mem[cache_index];

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
    cpu_resp_valid      = 1'd1  ;       //default resp valid
    case(state)
      IDLE: //2'd0
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
        if(miss) begin
          cache_index = cpu_index;
          o_valid_reg_nxt = cache_valid[cpu_index];
          o_dirty_reg_nxt = cache_dirty[cpu_index];
          cache_tag_reg_nxt = cache_tag_mem[cpu_index];
        end
        else begin
          cache_index = cpu_req_addr[8:4];
          o_valid_reg_nxt = cache_valid[cpu_req_addr[8:4]];
          o_dirty_reg_nxt = cache_valid[cpu_req_addr[8:4]];
          cache_tag_reg_nxt = cache_tag_mem[cpu_req_addr[8:4]];
        end
        //memory interface
        
        //cpu interface
        if(miss) begin
          cpu_req_ready   = 1'd0; //stall
          cpu_resp_data   = 32'd0;
        end
        else begin
          cpu_req_ready   = 1'd1; //not stall
          cpu_resp_data   = cache_data;
        end

        // if(cpu_valid) cpu_resp_valid = 1'd1;
        // else cpu_resp_valid = 1'd0;
      end
      WRITE: //2'd1
      begin
        //state
        if(hit) state_nxt = IDLE;
        else state_nxt = BEFORE_READ; //write miss
    
        //cache  interface
        if(hit) begin
          bytemask    = write_hit_mask;     //write
          cache_index = cpu_index;          
          {web15_12,web11_8,web7_4,web3_0} = WRITE_wen; //read
          {i_data15_12,i_data11_8,i_data7_4,i_data3_0}= {16{cpu_data}};

          cache_dirty_nxt[cache_index] = 1'd1;
        end 
        //memory interface
        
        //cpu interface
        cpu_req_ready = 1'd0; //stall
        cpu_resp_data = 32'd0;
      end
      BEFORE_READ: //2'd2
      begin
        //state
        if(mem_req_ready & wb_state == IDLE) begin
        // if(mem_req_ready) begin
          state_nxt = READ_MEM;
          cnt_nxt   = 3'd0;
        end
        //cache  interface 
        cache_index = cpu_index;
        //memory interface
        if(mem_req_ready & wb_state == IDLE) begin
        // if(mem_req_ready) begin
          mem_req_valid       = 1'd1  ;       //Read from MEM
          mem_req_addr        = {cpu_tag,cpu_index,2'd0} ; //mem_req_addr[1:0] is useless in READMEM
          mem_req_rw          = 1'd0  ;       //read
        end
        //cpu interface
        cpu_req_ready       = 1'd0  ; 
        cpu_resp_data       = 32'd0 ;
      end
      READ_MEM: //2'd3
      begin
        //state
        if(mem_req_ready & mem_resp_valid) begin
            state_nxt     = IDLE;
            from_mem_nxt  = 1'd1;
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
          // web_tag = 1'b1;
          if(cnt == cpu_offset[3:2]) begin
            {i_data15_12,i_data11_8,i_data7_4,i_data3_0} = {{4{READMEM_write_data}}};        
          end
          else begin
            {i_data15_12,i_data11_8,i_data7_4,i_data3_0} = {{4{mem_resp_data}}};
          end
          if(cnt == 3'd0) begin
            cache_valid_nxt[cache_index] = 1'd1;
            cache_dirty_nxt[cache_index] = |(cpu_write);
            cache_tag_mem_nxt[cache_index] = cpu_tag;
          end
        end

        //memory  interface
        mem_req_valid       = 1'd1  ;       //Read from MEM
        mem_req_addr        = {cpu_tag,cpu_index,2'd0} ; //mem_req_addr[1:0] is useless in READMEM
        mem_req_rw          = 1'd0  ;       //read
        //cpu  interface
        cpu_req_ready       = 1'd0  ;       //stall
        cpu_resp_data       = 32'd0;
      end
      default:
      begin
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
        //cache interface
        bytemask    = 16'h0000;           //no write
        cache_index = cpu_index;
        {web15_12,web11_8,web7_4,web3_0} = 4'b1111; //read
        {i_data15_12,i_data11_8,i_data7_4,i_data3_0}= {o_data15_12,o_data11_8,o_data7_4,o_data3_0};
        
        for(i=0; i<32; i=i+1) begin
          cache_valid_nxt[i] = cache_valid[i];
          cache_dirty_nxt[i] = cache_dirty[i];
          cache_tag_mem_nxt[i] = cache_tag_mem[i]; 
        end
        o_valid_reg_nxt = cache_valid[cache_index];
        o_dirty_reg_nxt = cache_dirty[cache_index];
        cache_tag_reg_nxt = cache_tag_mem[cache_index];

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
        // cpu_resp_valid      = 1'd1;
      end
    endcase

    //Write Back State
    wb_state_nxt  = wb_state;
    wb_cnt_nxt    = wb_cnt;
    //write buffer
    buf_dirty_nxt = buf_dirty;
    buf_index_nxt = buf_index;
    buf_tag_nxt   = buf_tag;
    {buf15_12_nxt,buf11_8_nxt,buf7_4_nxt,buf3_0_nxt}= {buf15_12,buf11_8,buf7_4,buf3_0};

    case(wb_state) 
      IDLE:
      begin
        //state
        if(state == READ_MEM) begin
          if(mem_req_ready & mem_resp_valid & buf_dirty) wb_state_nxt = BEFORE_WRITE;
        end
        //write buffer
        if(state == BEFORE_READ) begin
          buf_dirty_nxt = o_dirty_reg;
          buf_index_nxt = cpu_index;
          buf_tag_nxt   = cache_tag_reg;
          {buf15_12_nxt,buf11_8_nxt,buf7_4_nxt,buf3_0_nxt} = {o_data15_12,o_data11_8,o_data7_4,o_data3_0};
        end
      end
      BEFORE_WRITE: //2'd1
      begin
        //state
        if(mem_req_ready) begin
          wb_state_nxt = WRITE_BACK;
        end
        //memery interface
        mem_req_valid       = 1'd1  ;       //mem transaction
        mem_req_addr        = {buf_tag,buf_index,wb_cnt[1:0]};
        mem_req_rw          = 1'd1  ;       //write
        mem_req_data_valid  = 1'd1  ; 
        mem_req_data_bits   = WRITEBACK_write_data;
        mem_req_data_mask   = 16'hFFFF;
      end
      WRITE_BACK:  //2'd2
      begin
        //state
        if(mem_req_data_ready) begin
          if(wb_cnt == 3'd3) wb_state_nxt = BEFORE_IDLE;
          else wb_state_nxt = BEFORE_WRITE;
        end
        //counter
        if(mem_req_data_ready) begin
          if(wb_cnt == 3'd3) wb_cnt_nxt = 3'd0;
          else wb_cnt_nxt = wb_cnt + 3'd1;
        end
        //memory interface
        mem_req_valid       = 1'd1  ;       //mem transaction
        mem_req_addr        = {buf_tag,buf_index,wb_cnt[1:0]};
        mem_req_rw          = 1'd1  ;       //write
        mem_req_data_valid  = 1'd1  ; 
        mem_req_data_bits   = WRITEBACK_write_data;
        mem_req_data_mask   = 16'hFFFF;
      end
      BEFORE_IDLE: //2'd3
      begin
        if(mem_req_ready) wb_state_nxt = IDLE;
      end
      default:
      begin
        wb_state_nxt  = wb_state;
        wb_cnt_nxt    = wb_cnt;
        //write buffer
        buf_dirty_nxt = buf_dirty;
        buf_index_nxt = buf_index;
        buf_tag_nxt   = buf_tag;
        {buf15_12_nxt,buf11_8_nxt,buf7_4_nxt,buf3_0_nxt}= {buf15_12,buf11_8,buf7_4,buf3_0};
      end
    endcase
  end

  integer j;
  always@(posedge clk) begin
    if(reset) begin
      //cache init
      for(j=0; j<32; j=j+1) begin
        cache_valid[j] <= 1'd0;
        cache_dirty[j] <= 1'd0;
        cache_tag_mem[j] <= 21'd0;
      end
      o_valid_reg   <= 1'd0;
      o_dirty_reg   <= 1'd0;
      cache_tag_reg <= 21'd0;
      //state & counter
      state     <= 2'd0;
      cnt       <= 3'd0; 
      wb_state  <= 2'd0;
      wb_cnt    <= 3'd0;
      //cpu buffer
      cpu_tag   <= 21'd0;
      cpu_data  <= 32'd0;
      cpu_index <= 5'd0;
      cpu_offset<= 4'd0;
      cpu_valid <= 1'd0;
      cpu_write <= 3'd0;
      //write buffer
      buf_dirty <= 1'd0;
      buf_index <= 5'd0;
      buf_tag   <= 21'd0;
      {buf15_12, buf11_8, buf7_4, buf3_0} <= 512'd0;
      //mem buffer
      from_mem  <= 1'd0;
      data_from_mem15_12 <= 128'd0;
    end
    else begin
      //cache init
      for(j=0; j<32; j=j+1) begin
        cache_valid[j]  <= cache_valid_nxt[j];
        cache_dirty[j]  <= cache_dirty_nxt[j];
        cache_tag_mem[j]<= cache_tag_mem_nxt[j];
      end
      o_valid_reg   <= o_valid_reg_nxt;
      o_dirty_reg   <= o_dirty_reg_nxt;
      cache_tag_reg <= cache_tag_reg_nxt;
      //state & counter
      state     <= state_nxt;
      cnt       <= cnt_nxt;
      wb_state  <= wb_state_nxt;
      wb_cnt    <= wb_cnt_nxt;
      //cpu buffer
      cpu_tag     <= cpu_tag_nxt;
      cpu_data    <= cpu_data_nxt;
      cpu_index   <= cpu_index_nxt;
      cpu_offset  <= cpu_offset_nxt;
      cpu_valid   <= cpu_valid_nxt;
      cpu_write   <= cpu_write_nxt;
      //write buffer
      buf_dirty <= buf_dirty_nxt;
      buf_index <= buf_index_nxt;
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
                          .sel(wb_cnt[1:0]), .out(WRITEBACK_write_data));

 endmodule