`include "util.vh"
`include "const.vh"

module Cache_2WAY_read_only #
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

  //SRAM Cache0
  reg [4:0]     cache_index;                       //5bit index: 32 entries
  reg           web0_15_12, web0_11_8, web0_7_4, web0_3_0; //read:1 write:0
  reg [15:0]    bytemask0;                          //16byte (128bit per SRAM) write:1
  reg [127:0]   i_data0_15_12, i_data0_11_8, i_data0_7_4, i_data0_3_0;
  wire[127:0]   o_data0_15_12, o_data0_11_8, o_data0_7_4, o_data0_3_0;
  wire[31:0]    cache_data0;

  reg cache_lru0[0:31], cache_lru0_nxt[0:31];
  reg o_lru0_reg, o_lru0_reg_nxt; 

  reg cache_valid0[0:31], cache_valid0_nxt[0:31];
  reg o_valid0_reg, o_valid0_reg_nxt;

  reg [20:0] cache_tag0_mem[0:31], cache_tag0_mem_nxt[0:31];
  reg [20:0] cache_tag0_reg, cache_tag0_reg_nxt;

  SRAM1RW256x128  DATA0_15_12WORDS (.A({3'd0,cache_index}),.CE(clk),.WEB(web0_15_12),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask0),.I(i_data0_15_12),.O(o_data0_15_12));
  SRAM1RW256x128  DATA0_11_8WORDS  (.A({3'd0,cache_index}),.CE(clk),.WEB(web0_11_8),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask0),.I(i_data0_11_8),.O(o_data0_11_8));
  SRAM1RW256x128  DATA0_7_4WORDS   (.A({3'd0,cache_index}),.CE(clk),.WEB(web0_7_4),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask0),.I(i_data0_7_4),.O(o_data0_7_4));
  SRAM1RW256x128  DATA0_3_0WORDS   (.A({3'd0,cache_index}),.CE(clk),.WEB(web0_3_0),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask0),.I(i_data0_3_0),.O(o_data0_3_0));
  //SRAM Cache1
  reg           web1_15_12, web1_11_8, web1_7_4, web1_3_0; //read:1 write:0
  reg [15:0]    bytemask1;                          //16byte (128bit per SRAM) write:1
  reg [127:0]   i_data1_15_12, i_data1_11_8, i_data1_7_4, i_data1_3_0;
  wire[127:0]   o_data1_15_12, o_data1_11_8, o_data1_7_4, o_data1_3_0;
  wire[31:0]    cache_data1;

  reg cache_valid1[0:31], cache_valid1_nxt[0:31];
  reg o_valid1_reg, o_valid1_reg_nxt;

  reg [20:0] cache_tag1_mem[0:31], cache_tag1_mem_nxt[0:31];
  reg [20:0] cache_tag1_reg, cache_tag1_reg_nxt;


  SRAM1RW256x128  DATA1_15_12WORDS (.A({3'd0,cache_index}),.CE(clk),.WEB(web1_15_12),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask1),.I(i_data1_15_12),.O(o_data1_15_12));
  SRAM1RW256x128  DATA1_11_8WORDS  (.A({3'd0,cache_index}),.CE(clk),.WEB(web1_11_8),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask1),.I(i_data1_11_8),.O(o_data1_11_8));
  SRAM1RW256x128  DATA1_7_4WORDS   (.A({3'd0,cache_index}),.CE(clk),.WEB(web1_7_4),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask1),.I(i_data1_7_4),.O(o_data1_7_4));
  SRAM1RW256x128  DATA1_3_0WORDS   (.A({3'd0,cache_index}),.CE(clk),.WEB(web1_3_0),.OEB(1'd0),.CSB(1'd0),
                                .BYTEMASK(bytemask1),.I(i_data1_3_0),.O(o_data1_3_0));

  //Cache Initialization
  reg [5:0]   init_cnt, init_cnt_nxt;
  //from cpu_req
  reg [20:0]  cpu_tag     ,cpu_tag_nxt;
  reg [4:0]   cpu_index   ,cpu_index_nxt;
  reg [3:0]   cpu_offset  ,cpu_offset_nxt;
  reg         cpu_valid   ,cpu_valid_nxt;
  //cpu resp data 
  reg hit0_record;
  
  //state parameters
  localparam IDLE         = 3'd0; 
  localparam BEFORE_READ  = 3'd1;
  localparam READ_MEM0    = 3'd2;
  localparam READ_MEM1    = 3'd3;
  localparam INIT         = 3'd4;

  reg [2:0] state, state_nxt;
  reg [2:0] cnt,   cnt_nxt;

  wire hit0, hit1, miss0, miss1; 
  assign hit0       = (cpu_valid) & o_valid0_reg & (cpu_tag == cache_tag0_reg); 
  assign hit1       = (cpu_valid) & o_valid1_reg & (cpu_tag == cache_tag1_reg);
  assign miss0      = (cpu_valid) & (~(o_valid0_reg) || (cpu_tag != cache_tag0_reg)); 
  assign miss1      = (cpu_valid) & (~(o_valid1_reg) || (cpu_tag != cache_tag1_reg));

  //write 
  wire [3:0]    READMEM_wen;
   
  //mem buffer
  reg         from_mem, from_mem_nxt;
  reg [127:0] data_from_mem15_12, data_from_mem15_12_nxt; 

  integer i;
  always@(*) begin
    state_nxt     = state;
    init_cnt_nxt  = init_cnt;
    cnt_nxt       = cnt;
    //mem buffer
    from_mem_nxt  = from_mem;
    data_from_mem15_12_nxt = data_from_mem15_12;
    //cpu buffer
    cpu_tag_nxt   = cpu_tag;
    cpu_index_nxt = cpu_index;
    cpu_offset_nxt= cpu_offset;
    cpu_valid_nxt = cpu_valid;

    //cache interface
    cache_index = cpu_index;
    //cache0 interface
    bytemask0   = 16'h0000;           //no write
    {web0_15_12,web0_11_8,web0_7_4,web0_3_0} = 4'b1111; //read
    {i_data0_15_12,i_data0_11_8,i_data0_7_4,i_data0_3_0}  = {o_data0_15_12,o_data0_11_8,o_data0_7_4,o_data0_3_0};
    //cache1 interface
    bytemask1   = 16'h0000;           //no write
    {web1_15_12,web1_11_8,web1_7_4,web1_3_0} = 4'b1111; //read
    {i_data1_15_12,i_data1_11_8,i_data1_7_4,i_data1_3_0}  = {o_data1_15_12,o_data1_11_8,o_data1_7_4,o_data1_3_0};

    for(i=0; i<32; i=i+1) begin
      //lru
      cache_lru0_nxt[i] = cache_lru0[i];
      //valid
      cache_valid0_nxt[i] = cache_valid0[i];
      cache_valid1_nxt[i] = cache_valid1[i];
      //tag
      cache_tag0_mem_nxt[i] = cache_tag0_mem[i];
      cache_tag1_mem_nxt[i] = cache_tag1_mem[i];
    end
    //lru
    o_lru0_reg_nxt = cache_lru0[cache_index];
    //valid
    o_valid0_reg_nxt = cache_valid0[cache_index];
    o_valid1_reg_nxt = cache_valid1[cache_index];
    //tag
    cache_tag0_reg_nxt = cache_tag0_mem[cache_index];
    cache_tag1_reg_nxt = cache_tag1_mem[cache_index];

    //memory interface
    mem_req_valid       = 1'd0  ;       //no mem transaction
    mem_req_addr        = 28'd0 ;
    mem_req_rw          = 1'd0  ;       //read
    mem_req_data_valid  = 1'd0  ; 
    mem_req_data_bits   = 128'd0;
    mem_req_data_mask   = 16'd0 ; 
    //cpu interface
    cpu_req_ready       = 1'd1  ;       //default not to stall

    if(cpu_valid) begin
      if(hit0) cpu_resp_data = cache_data0 ;
      else cpu_resp_data  = cache_data1 ;
    end
    else begin
      if(hit0_record) cpu_resp_data = cache_data0 ;
      else cpu_resp_data  = cache_data1 ;
    end
   
    case(state)
      INIT:
      begin
        if(init_cnt == 6'd32) begin
          state_nxt = IDLE;
          init_cnt_nxt = 6'd0;
        end
        else begin
          state_nxt = INIT;
          init_cnt_nxt = init_cnt + 6'd1;
        end
        //cache interface
        if(init_cnt == 6'd32) begin
          cache_index = 5'd0;
          //cache0
          bytemask0   = 16'h0000;           //no write
          {web0_15_12,web0_11_8,web0_7_4,web0_3_0} = 4'b1111; //read
          {i_data0_15_12,i_data0_11_8,i_data0_7_4,i_data0_3_0}  = 512'd0;
          //cache1
          bytemask1   = 16'h0000;           //no write
          {web1_15_12,web1_11_8,web1_7_4,web1_3_0} = 4'b1111; //read
          {i_data1_15_12,i_data1_11_8,i_data1_7_4,i_data1_3_0}  = 512'd0;
        end
        else begin
          cache_index = init_cnt[4:0];
          //cache0
          bytemask0   = 16'hFFFF;           //write
          {web0_15_12,web0_11_8,web0_7_4,web0_3_0} = 4'b0000; //write
          {i_data0_15_12,i_data0_11_8,i_data0_7_4,i_data0_3_0}  = 512'd0;
          //cache1
          bytemask1   = 16'hFFFF;           //write
          {web1_15_12,web1_11_8,web1_7_4,web1_3_0} = 4'b0000; //write
          {i_data1_15_12,i_data1_11_8,i_data1_7_4,i_data1_3_0}  = 512'd0;
        end
        //cpu interface
        cpu_req_ready = 1'd0;  //stall
        cpu_resp_data = 32'd0;
      end
      IDLE: //2'd0
      begin
        //state
        if(miss0 & miss1) state_nxt = BEFORE_READ;
        else state_nxt = IDLE;

        //mem buffer
        from_mem_nxt = 1'd0;
        //cpu buffer
        if(~(miss0 & miss1)) begin
          cpu_tag_nxt   = cpu_req_addr[29:9];
          cpu_index_nxt = cpu_req_addr[8:4] ;
          cpu_offset_nxt= cpu_req_addr[3:0] ;
          cpu_valid_nxt = cpu_req_valid;
        end

        //cache  interface 
        if(miss0 & miss1) begin
          cache_index       = cpu_index;
          //lru
          o_lru0_reg_nxt    = cache_lru0[cpu_index];
          //valid
          o_valid0_reg_nxt  = cache_valid0[cpu_index];
          o_valid1_reg_nxt  = cache_valid1[cpu_index];
          //tag
          cache_tag0_reg_nxt= cache_tag0_mem[cpu_index];
          cache_tag1_reg_nxt= cache_tag1_mem[cpu_index];
        end
        else begin
          cache_index       = cpu_req_addr[8:4];
          //lru
          o_lru0_reg_nxt    = cache_lru0[cpu_req_addr[8:4]];
          //valid
          if(hit0) begin
            o_lru0_reg_nxt    = 1'd0;
          //valid
          end
          else begin
            o_lru0_reg_nxt    = 1'd1;
          end
          o_valid0_reg_nxt  = cache_valid0[cpu_req_addr[8:4]];
          o_valid1_reg_nxt  = cache_valid1[cpu_req_addr[8:4]];
          //tag
          cache_tag0_reg_nxt= cache_tag0_mem[cpu_req_addr[8:4]];
          cache_tag1_reg_nxt= cache_tag1_mem[cpu_req_addr[8:4]];
        end

        //memory interface
        
        //cpu interface
        if(miss0 & miss1) begin
          cpu_req_ready   = 1'd0; //stall
          cpu_resp_data   = 32'd0;
        end
        else begin
          cpu_req_ready       = 1'd1  ;       //default not to stall
          if(cpu_valid) begin
            if(hit0) cpu_resp_data = cache_data0 ;
            else cpu_resp_data  = cache_data1 ;
          end
          else begin
            if(hit0_record) cpu_resp_data = cache_data0 ;
            else cpu_resp_data  = cache_data1 ;
          end
        end
      end
      BEFORE_READ: //2'd1
      begin
        //state
        if(mem_req_ready) begin
          if(o_lru0_reg == 1'd1) state_nxt = READ_MEM0; //update block0
          else state_nxt = READ_MEM1; //update block1
          cnt_nxt   = 3'd0;
        end
        //cache  interface 
        cache_index = cpu_index;

        //memory interface
        if(mem_req_ready) begin
          mem_req_valid       = 1'd1  ;       //Read from MEM
          mem_req_addr        = {cpu_tag,cpu_index,2'd0} ; //mem_req_addr[1:0] is useless in READMEM
          mem_req_rw          = 1'd0  ;       //read
        end
        //cpu interface
        cpu_req_ready       = 1'd0 ; 
        cpu_resp_data       = 32'd0; 
      end
      READ_MEM0: //2'd2 //update block 0
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
          bytemask0   = 16'hFFFF;           //write
          cache_index = cpu_index;
          data_from_mem15_12_nxt = mem_resp_data; 
          {web0_15_12,web0_11_8,web0_7_4,web0_3_0}= READMEM_wen; //write by turns
          {i_data0_15_12,i_data0_11_8,i_data0_7_4,i_data0_3_0} = {{4{mem_resp_data}}};

          if(cnt == 3'd0) begin
            cache_lru0_nxt[cache_index]   = 1'd0;
            cache_valid0_nxt[cache_index] = 1'd1;
            cache_tag0_mem_nxt[cache_index]= cpu_tag;
          end
        end

        //memory  interface
        mem_req_valid       = 1'd1  ;       //Read from MEM
        mem_req_addr        = {cpu_tag,cpu_index,2'd0} ; //mem_req_addr[1:0] is useless in READMEM
        mem_req_rw          = 1'd0  ;       //read
        //cpu  interface
        cpu_req_ready       = 1'd0  ;       //stall
        cpu_resp_data       = 32'd0 ;
      end
      READ_MEM1: //2'd3 //update block 1
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
          bytemask1   = 16'hFFFF;           //write
          cache_index = cpu_index;
          data_from_mem15_12_nxt = mem_resp_data; 
          {web1_15_12,web1_11_8,web1_7_4,web1_3_0} = READMEM_wen; //write by turns
          {i_data1_15_12,i_data1_11_8,i_data1_7_4,i_data1_3_0} = {{4{mem_resp_data}}};

          if(cnt == 3'd0) begin
            cache_lru0_nxt[cache_index]     = 1'd1;
            cache_valid1_nxt[cache_index]   = 1'd1;
            cache_tag1_mem_nxt[cache_index] = cpu_tag;
          end
        end

        //memory  interface
        mem_req_valid       = 1'd1  ;       //Read from MEM
        mem_req_addr        = {cpu_tag,cpu_index,2'd0} ; //mem_req_addr[1:0] is useless in READMEM
        mem_req_rw          = 1'd0  ;       //read
        //cpu  interface
        cpu_req_ready       = 1'd0  ;       //stall
        cpu_resp_data       = 32'd0 ; 
      end
      default:
      begin
        state_nxt     = state;
        init_cnt_nxt  = init_cnt;
        cnt_nxt       = cnt;
        //mem buffer
        from_mem_nxt  = from_mem;
        data_from_mem15_12_nxt = data_from_mem15_12;
        //cpu buffer
        cpu_tag_nxt   = cpu_tag;
        cpu_index_nxt = cpu_index;
        cpu_offset_nxt= cpu_offset;
        cpu_valid_nxt = cpu_valid;

        //cache interface
        cache_index = cpu_index;
        //cache0 interface
        bytemask0   = 16'h0000;           //no write
        {web0_15_12,web0_11_8,web0_7_4,web0_3_0} = 4'b1111; //read
        {i_data0_15_12,i_data0_11_8,i_data0_7_4,i_data0_3_0}  = {o_data0_15_12,o_data0_11_8,o_data0_7_4,o_data0_3_0};
        //cache1 interface
        bytemask1   = 16'h0000;           //no write
        {web1_15_12,web1_11_8,web1_7_4,web1_3_0} = 4'b1111; //read
        {i_data1_15_12,i_data1_11_8,i_data1_7_4,i_data1_3_0}  = {o_data1_15_12,o_data1_11_8,o_data1_7_4,o_data1_3_0};

        for(i=0; i<32; i=i+1) begin
          //lru
          cache_lru0_nxt[i] = cache_lru0[i];
          //valid
          cache_valid0_nxt[i] = cache_valid0[i];
          cache_valid1_nxt[i] = cache_valid1[i];
          //tag
          cache_tag0_mem_nxt[i] = cache_tag0_mem[i];
          cache_tag1_mem_nxt[i] = cache_tag1_mem[i];
        end
        //lru
        o_lru0_reg_nxt = cache_lru0[cache_index];
        //valid
        o_valid0_reg_nxt = cache_valid0[cache_index];
        o_valid1_reg_nxt = cache_valid1[cache_index];
        //tag
        cache_tag0_reg_nxt = cache_tag0_mem[cache_index];
        cache_tag1_reg_nxt = cache_tag1_mem[cache_index];

        //memory interface
        mem_req_valid       = 1'd0  ;       //no mem transaction
        mem_req_addr        = 28'd0 ;
        mem_req_rw          = 1'd0  ;       //read
        mem_req_data_valid  = 1'd0  ; 
        mem_req_data_bits   = 128'd0;
        mem_req_data_mask   = 16'd0 ; 
        //cpu interface
        cpu_req_ready       = 1'd1  ;       //default not to stall

        if(cpu_valid) begin
          if(hit0) cpu_resp_data = cache_data0 ;
          else cpu_resp_data  = cache_data1 ;
        end
        else begin
          if(hit0_record) cpu_resp_data = cache_data0 ;
          else cpu_resp_data  = cache_data1 ;
        end
      end
    endcase
  end

  always@(posedge clk) begin
    if(reset) hit0_record <= 1'd0;
    else if(cpu_valid) hit0_record <= hit0;
  end

  integer j;
  always@(posedge clk) begin
    if(reset) begin
      //cache init
      for(j=0; j<32; j=j+1) begin
        //lru
        cache_lru0[j] <= 1'd0;
        //valid
        cache_valid0[j] <= 1'd0;
        cache_valid1[j] <= 1'd0;
        //tag
        cache_tag0_mem[j] <= 21'd0;
        cache_tag1_mem[j] <= 21'd0;
      end
      //lru
      o_lru0_reg <= 1'd0;

      //valid
      o_valid0_reg <= 1'd0;
      o_valid1_reg <= 1'd0;
      //tag
      cache_tag0_reg <= 21'd0;
      cache_tag1_reg <= 21'd0;

      //state & counter
      state     <= INIT;
      init_cnt  <= 6'd0;
      cnt       <= 3'd0; 
      //cpu buffer
      cpu_tag   <= 21'd0;
      cpu_index <= 5'd0;
      cpu_offset<= 4'd0;
      cpu_valid <= 1'd0;
      //mem buffer
      from_mem  <= 1'd0;
      data_from_mem15_12 <= 128'd0;
    end
    else begin
      //cache init
      //cache init
      for(j=0; j<32; j=j+1) begin
        //lru
        cache_lru0[j] <= cache_lru0_nxt[j];
        //valid
        cache_valid0[j] <= cache_valid0_nxt[j];
        cache_valid1[j] <= cache_valid1_nxt[j];
        //tag
        cache_tag0_mem[j] <= cache_tag0_mem_nxt[j];
        cache_tag1_mem[j] <= cache_tag1_mem_nxt[j];
      end
      //lru
      o_lru0_reg <= o_lru0_reg_nxt;

      //valid
      o_valid0_reg <= o_valid0_reg_nxt;
      o_valid1_reg <= o_valid1_reg_nxt;
      //tag
      cache_tag0_reg <= cache_tag0_reg_nxt;
      cache_tag1_reg <= cache_tag1_reg_nxt;

      //state & counter
      state     <= state_nxt;
      init_cnt  <= init_cnt_nxt;
      cnt       <= cnt_nxt;
      //cpu buffer
      cpu_tag     <= cpu_tag_nxt;
      cpu_index   <= cpu_index_nxt;
      cpu_offset  <= cpu_offset_nxt;
      cpu_valid   <= cpu_valid_nxt;
      //mem buffer
      from_mem  <= from_mem_nxt;
      data_from_mem15_12 <= data_from_mem15_12_nxt;
    end
  end

  //cache0 response data
  wire [31:0] o_mux0_15_12, o_mux0_11_8, o_mux0_7_4, o_mux0_3_0;
  wire [127:0] i_mux0_15_12;
  assign i_mux0_15_12 = from_mem? data_from_mem15_12: o_data0_15_12;
  mux4_to1 mux0_data15_12(.in(i_mux0_15_12 ), .sel(cpu_offset[1:0]), .out(o_mux0_15_12)); 
  mux4_to1 mux0_data11_8 (.in(o_data0_11_8 ), .sel(cpu_offset[1:0]), .out(o_mux0_11_8)); 
  mux4_to1 mux0_data7_4  (.in(o_data0_7_4  ), .sel(cpu_offset[1:0]), .out(o_mux0_7_4)); 
  mux4_to1 mux0_data3_0  (.in(o_data0_3_0  ), .sel(cpu_offset[1:0]), .out(o_mux0_3_0)); 
  mux4_to1 mux0_cache_resp_data (.in({o_mux0_15_12, o_mux0_11_8, o_mux0_7_4, o_mux0_3_0}), 
                        .sel(cpu_offset[3:2]), .out(cache_data0));

  //cache1 response data
  wire [31:0] o_mux1_15_12, o_mux1_11_8, o_mux1_7_4, o_mux1_3_0;
  wire [127:0] i_mux1_15_12;
  assign i_mux1_15_12 = from_mem? data_from_mem15_12: o_data1_15_12;
  mux4_to1 mux1_data15_12(.in(i_mux1_15_12 ), .sel(cpu_offset[1:0]), .out(o_mux1_15_12)); 
  mux4_to1 mux1_data11_8 (.in(o_data1_11_8 ), .sel(cpu_offset[1:0]), .out(o_mux1_11_8)); 
  mux4_to1 mux1_data7_4  (.in(o_data1_7_4  ), .sel(cpu_offset[1:0]), .out(o_mux1_7_4)); 
  mux4_to1 mux1_data3_0  (.in(o_data1_3_0  ), .sel(cpu_offset[1:0]), .out(o_mux1_3_0)); 
  mux4_to1 mux1_cache_resp_data (.in({o_mux1_15_12, o_mux1_11_8, o_mux1_7_4, o_mux1_3_0}), 
                        .sel(cpu_offset[3:2]), .out(cache_data1));

  //WRITE Cache
  Write_Enable  write_enable_READMEM(.which_SRAM(cnt[1:0]), 
                        .write_enable_hit(READMEM_wen));

 endmodule