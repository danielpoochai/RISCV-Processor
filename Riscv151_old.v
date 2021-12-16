`include "const.vh"

module Riscv151(
    input clk,
    input reset,

    // Memory system ports
    output [31:0] dcache_addr,
    output [31:0] icache_addr,
    output [3:0] dcache_we,
    output dcache_re,
    output icache_re,
    output [31:0] dcache_din,

    input [31:0] dcache_dout,
    input [31:0] icache_dout,
    input stall,
    output reg [31:0] csr

);

//global signal
wire  flush_EX, forward_stall, predict_correct;
reg   flush_MEM;

//branch prediction
wire branch_predict_ID;
reg branch_predict_EX;

//IF stage
wire  [31:0] pc, pc_tmp, pc_predict, pc_add4_nxt; 
reg   [31:0] pc_add4;

always@(posedge clk) begin
  if(reset) begin
    pc_add4 <= `PC_RESET;
  end
  else if(~(stall || forward_stall)) begin
      pc_add4 <= pc_add4_nxt;
  end
end

//ID stage
wire  [31:0] instr;
reg   [31:0] instr_buf;
reg   [31:0] pc_ID;
wire  [31:0] pc_branch_ID, pc_add4_ID;
wire  [31:0] dataA_ID, dataB_ID, imm_ID;
  //ID control signals
wire  if_rs1_ID, if_rs2_ID, Asel_ID, Bsel_ID, RegWEn_ID, memRW_ID, btype_ID, jtype_ID, stype_ID, csrtype_ID;
wire  [1:0] memtoreg_ID, dataW_sel_ID;
  //ID alu_dec signal
wire  [3:0] ALUop_ID;

assign instr = (stall||forward_stall)? instr_buf:((branch_predict_EX||flush_EX||flush_MEM) ? 32'd0: icache_dout);

//register IF/ID
always@(posedge clk) begin
  if(reset) begin
    pc_ID     <= 32'd0;
    instr_buf <= 32'd0;
  end
  else if(~(forward_stall||stall)) begin
    pc_ID     <= pc;
    if(flush_EX||flush_MEM) instr_buf <= 32'd0;
    else instr_buf <= icache_dout;
  end
end

//EX stage
reg   [31:0]  pc_EX;
reg   [31:0]  pc_branch_EX, pc_add4_EX;
reg   [2:0]   funct3_EX;
reg   [4:0]   instr_csr_EX, rs1_EX, rs2_EX, rd_EX;
reg   [31:0]  dataA_EX, dataB_EX, imm_EX;

wire  branch_result_EX;
wire  [31:0] orig_A, orig_B, alu_inA, alu_inB, alu_out, branch_inA, branch_inB;
wire  [31:0] csr_imm, dataW_EX;

assign csr_imm = {27'd0,instr_csr_EX[4:0]};
  //EX control signals
wire  alu_inB_sel;
reg   if_rs1_EX, if_rs2_EX, RegWEn_EX, memRW_EX, btype_EX, jtype_EX, stype_EX, csrtype_EX;
reg   [1:0] memtoreg_EX, dataW_sel_EX;
wire  [2:0] A_sel_EX, B_sel_EX;
  //EX alu_dec signal
reg   [3:0] ALUop_EX;

assign alu_inB_sel = btype_EX | stype_EX;

//register ID/EX
always@(posedge clk) begin
  if(reset) begin
    //stage
    funct3_EX     <= 3'd0;
    instr_csr_EX  <= 5'd0;
    rs1_EX        <= 5'd0;
    rs2_EX        <= 5'd0;   
    rd_EX         <= 5'd0;
    pc_EX         <= 32'd0;
    pc_branch_EX  <= 32'd0;
    pc_add4_EX    <= 32'd0;
    dataA_EX      <= 32'd0;
    dataB_EX      <= 32'd0; 
    imm_EX        <= 32'd0;
    //control signals
    if_rs1_EX     <= 1'd0;
    if_rs2_EX     <= 1'd0;
    RegWEn_EX     <= 1'd0;
    memRW_EX      <= 1'd0;
    btype_EX      <= 1'd0;
    jtype_EX      <= 1'd0;
    stype_EX      <= 1'd0;
    csrtype_EX    <= 1'd0;     
    ALUop_EX      <= 4'd0;
    memtoreg_EX   <= 2'd0;
    dataW_sel_EX  <= 2'd0; 
    //branch prediction
    branch_predict_EX <= 1'd0;
  end
  else if(~(stall)) begin
    if(forward_stall) begin
      if_rs1_EX     <= if_rs1_EX;
      if_rs2_EX     <= if_rs2_EX;
      RegWEn_EX     <= RegWEn_EX;
      memRW_EX      <= memRW_EX;
      btype_EX      <= btype_EX;
      jtype_EX      <= jtype_EX;
      stype_EX      <= stype_EX;
      csrtype_EX    <= csrtype_EX;
      ALUop_EX      <= ALUop_EX;
      memtoreg_EX   <= memtoreg_EX;
      dataW_sel_EX  <= dataW_sel_EX;
      //stage
      funct3_EX     <= funct3_EX ;
      instr_csr_EX  <= instr_csr_EX;
      rd_EX         <= rd_EX;
      rs1_EX        <= rs1_EX;
      rs2_EX        <= rs2_EX; 
      pc_EX         <= pc_EX;
      pc_branch_EX  <= pc_branch_EX;
      pc_add4_EX    <= pc_add4_EX;
      dataA_EX      <= branch_inA;
      dataB_EX      <= branch_inB; 
      imm_EX        <= imm_EX;
      //branch_prediction
      branch_predict_EX <= branch_predict_EX; 
    end
    else if(flush_EX||flush_MEM) begin
      //stage
      funct3_EX     <= 3'd0;
      instr_csr_EX  <= 5'd0;
      rs1_EX        <= 5'd0;
      rs2_EX        <= 5'd0;   
      rd_EX         <= 5'd0;
      pc_EX         <= 32'd0;
      pc_branch_EX  <= 32'd0;
      pc_add4_EX    <= 32'd0;
      dataA_EX      <= 32'd0;
      dataB_EX      <= 32'd0; 
      imm_EX        <= 32'd0;
      //control signals
      if_rs1_EX     <= 1'd0;
      if_rs2_EX     <= 1'd0;
      RegWEn_EX     <= 1'd0;
      memRW_EX      <= 1'd0;
      btype_EX      <= 1'd0;
      jtype_EX      <= 1'd0;
      stype_EX      <= 1'd0;
      csrtype_EX    <= 1'd0;     
      ALUop_EX      <= 4'd0;
      memtoreg_EX   <= 2'd0;
      dataW_sel_EX  <= 2'd0; 
      //branch prediction
      branch_predict_EX <= 1'd0;
    end
    else begin
      //control signals
      if_rs1_EX     <= if_rs1_ID;
      if_rs2_EX     <= if_rs2_ID;
      RegWEn_EX     <= RegWEn_ID;
      memRW_EX      <= memRW_ID;
      btype_EX      <= btype_ID;
      jtype_EX      <= jtype_ID;
      stype_EX      <= stype_ID;
      csrtype_EX    <= csrtype_ID;
      ALUop_EX      <= ALUop_ID;
      memtoreg_EX   <= memtoreg_ID;
      dataW_sel_EX  <= dataW_sel_ID;
      //stage
      funct3_EX     <= instr[14:12];
      instr_csr_EX  <= instr[19:15];
      rd_EX         <= instr[11:7];
      rs1_EX        <= instr[19:15];
      rs2_EX        <= instr[24:20]; 
      pc_EX         <= pc_ID;
      pc_branch_EX  <= pc_branch_ID;
      pc_add4_EX    <= pc_add4_ID;
      dataA_EX      <= orig_A;
      dataB_EX      <= orig_B; 
      imm_EX        <= imm_ID; 
      //branch prediction
      branch_predict_EX <= branch_predict_ID;
    end
  end
end

//MEM stage
reg   stype_MEM, csrtype_MEM;
reg   [2:0] funct3_MEM;
reg   [4:0] rd_MEM;
reg   [31:0] pc_MEM, alu_out_MEM, dataW_MEM;
reg   [31:0] dcache_addr_buf, dataW_buf;

wire  [31:0] pc_add4_MEM, dataW; 
  //MEM control signals
wire  [3:0] dcache_we_wire;
reg   RegWEn_MEM, memRW_MEM;
reg   [1:0] memtoreg_MEM;

//CSR
wire  [31:0] csr_nxt;
assign csr_nxt = csrtype_MEM? dataW_MEM: csr;
//CSR
always@(posedge clk) begin
  if(reset) begin
    csr <= 32'd0;
  end
  // else begin
  //   csr <= csr_nxt;
  // end
  else if(~(stall))begin
    if(forward_stall) csr <= csr;
    else csr <= csr_nxt;
  end
end

//register EX/MEM
always@(posedge clk) begin
  if(reset) begin
    //stage
    stype_MEM         <= 1'd0;
    csrtype_MEM       <= 1'd0;
    funct3_MEM        <= 3'd0;
    rd_MEM            <= 5'd0;
    pc_MEM            <= 32'd0;
    alu_out_MEM       <= 32'd0;
    dataW_MEM         <= 32'd0;
    //control signals
    RegWEn_MEM        <= 1'd0;
    memRW_MEM         <= 1'd0;
    memtoreg_MEM      <= 2'd0;
    //flush signal
    flush_MEM         <= 1'd0; 
    //dcache_addr buf
    dcache_addr_buf   <= 32'd0;
    dataW_buf         <= 32'd0; 
  end
  else if(~(stall)) begin
    if(forward_stall) begin
      //stage
      stype_MEM         <= 1'd0;
      csrtype_MEM       <= 1'd0;
      funct3_MEM        <= 3'd0;
      rd_MEM            <= 5'd0;
      pc_MEM            <= 32'd0;
      alu_out_MEM       <= 32'd0;
      dataW_MEM         <= 32'd0;
      //control signals
      RegWEn_MEM        <= 1'd0;
      memRW_MEM         <= 1'd0;
      memtoreg_MEM      <= 2'd0;
      //flush signal
      flush_MEM         <= 1'd0;
      //dcache_addr buf
      dcache_addr_buf   <= 32'd0;
      dataW_buf         <= 32'd0;
    end
    else begin
      //stage
      stype_MEM         <= stype_EX;
      csrtype_MEM       <= csrtype_EX;
      funct3_MEM        <= funct3_EX;
      rd_MEM            <= rd_EX;
      pc_MEM            <= pc_EX;
      alu_out_MEM       <= alu_out;
      dataW_MEM         <= dataW_EX;
      //control signals
      RegWEn_MEM        <= RegWEn_EX;
      memRW_MEM         <= memRW_EX;
      memtoreg_MEM      <= memtoreg_EX;
      //flush signal 
      flush_MEM         <= flush_EX;
      //dcache_addr buf
      dcache_addr_buf   <= alu_out_MEM;
      dataW_buf         <= dataW;
    end
  end
end

//WB stage
reg   [4:0] rd_WB;
reg   [31:0] pc_add4_WB, alu_out_WB;
reg   [2:0] funct3_WB;
wire  [31:0] d_rdata_ext, rdata_WB;
wire  [31:0] d_rdata_WB;
reg   [31:0] dcache_dout_buf;

  //WB control signals
reg   RegWEn_WB;
reg   [1:0] memtoreg_WB;

//assignment
assign d_rdata_WB = (stall)? dcache_dout_buf: dcache_dout;

//register MEM/WB
always@(posedge clk) begin
  if(reset) begin
    //stage
    pc_add4_WB  <= 32'd0;
    alu_out_WB  <= 32'd0;
    rd_WB       <= 5'd0;
    funct3_WB   <= 3'd0;
    //control signal
    RegWEn_WB   <= 1'd0;
    memtoreg_WB <= 2'd0;
    //dcache_out buf
    dcache_dout_buf <= 32'd0;

  end
  else if(~(stall)) begin
    //stage
    pc_add4_WB  <= pc_add4_MEM;
    alu_out_WB  <= alu_out_MEM;
    rd_WB       <= rd_MEM;
    funct3_WB   <= funct3_MEM;
    //control signal
    RegWEn_WB   <= RegWEn_MEM;
    memtoreg_WB <= memtoreg_MEM;
    //dcache_out buf
    dcache_dout_buf <= d_rdata_WB;
  end
  
end

//output assignment
assign icache_addr= (stall||forward_stall)? pc_ID: pc;
assign icache_re  = (stall||forward_stall||flush_EX||branch_predict_ID)? 1'd0: 1'd1;

assign dcache_addr= (stall)? dcache_addr_buf: alu_out_MEM;
assign dcache_din = (stall)? dataW_buf: dataW;
assign dcache_re  = (stall)? 1'd0: memRW_MEM;
assign dcache_we  = (stall)? 4'd0: dcache_we_wire;

//adder
adder  pc_adder_branch(.in_a(pc_ID), .in_b(imm_ID), .out(pc_branch_ID));
adder4 pc_adder_ID    (.in_a(pc_ID), .out(pc_add4_ID));
adder4 pc_adder_IF    (.in_a(pc), .out(pc_add4_nxt));
adder4 pc_adder_MEM   (.in_a(pc_MEM), .out(pc_add4_MEM));

//submodule instantiation
mux2_to1 mux_pc_tmp     (.in_a(pc_add4),    .in_b(alu_out_MEM),   .sel(flush_MEM),          .out(pc_tmp));
mux2_to1 mux_pc_predict (.in_a(pc_add4_EX), .in_b(pc_branch_EX),  .sel(predict_correct),    .out(pc_predict));
mux2_to1 mux_pc         (.in_a(pc_tmp),     .in_b(pc_predict),    .sel(branch_predict_EX),  .out(pc));
Control_unit control_unit(.clk(clk), .reset(reset), .opcode(instr[6:0]), .funct3(instr[14]),
                          .RegWEn(RegWEn_ID), .Asel(Asel_ID), .Bsel(Bsel_ID), .dataW_sel(dataW_sel_ID), .memRW(memRW_ID), 
                          .memtoreg(memtoreg_ID), .btype(btype_ID), .jtype(jtype_ID), .stype(stype_ID), .csrtype(csrtype_ID),
                          .if_rs1(if_rs1_ID), .if_rs2(if_rs2_ID));
Registers rf(.clk(clk), .reset(reset), .RegWEn(RegWEn_WB), .rs1(instr[19:15]), .rs2(instr[24:20]), .rd(rd_WB), 
                    .rd_data(rdata_WB), .rs1_data(dataA_ID), .rs2_data(dataB_ID));
Imm_Gen imm_gen(.instr(instr), .imm(imm_ID));
Forwarding_unit forwarding_unit(.if_rs1_EX(if_rs1_EX), .if_rs2_EX(if_rs2_EX), .RegWEn_MEM(RegWEn_MEM), .RegWEn_WB(RegWEn_WB), 
                                .memtoreg_MEM(memtoreg_MEM), .memtoreg_WB(memtoreg_WB),
                                .rs1_EX(rs1_EX), .rs2_EX(rs2_EX), .rd_MEM(rd_MEM), .rd_WB(rd_WB),
                                .A_sel(A_sel_EX), .B_sel(B_sel_EX), .stall(forward_stall));

// Flush_unit flush_unit(.btype_EX(btype_EX), .jtype_EX(jtype_EX), .branch_result_EX(branch_result_EX), .flush_EX(flush_EX));
Flush_unit flush_unit(.btype_EX(btype_EX), .jtype_EX(jtype_EX), 
                      .branch_predict_EX(branch_predict_EX), .branch_result_EX(branch_result_EX), 
                      .flush_EX(flush_EX), .predict_correct(predict_correct));
ALUdec aludec(.opcode(instr[6:0]), .funct(instr[14:12]), .add_rshift_type(instr[30]), .ALUop(ALUop_ID));
mux2_to1 mux_preA(.in_a(dataA_ID), .in_b(pc_ID), .sel(Asel_ID), .out(orig_A));
mux2_to1 mux_preB(.in_a(dataB_ID), .in_b(imm_ID), .sel(Bsel_ID), .out(orig_B));
//might change to mux_2to1 using rdata_WB
mux5_to1 mux_branch_inA(.in_a(dataA_EX), .in_b(alu_out_MEM), .in_c(d_rdata_ext), .in_d(alu_out_WB), .in_e(pc_add4_WB), .sel(A_sel_EX), .out(branch_inA));
mux5_to1 mux_branch_inB(.in_a(dataB_EX), .in_b(alu_out_MEM), .in_c(d_rdata_ext), .in_d(alu_out_WB), .in_e(pc_add4_WB), .sel(B_sel_EX), .out(branch_inB));
mux2_to1 mux_ALU_inA(.in_a(branch_inA), .in_b(pc_EX), .sel(btype_EX), .out(alu_inA));
mux2_to1 mux_ALU_inB(.in_a(branch_inB), .in_b(imm_EX), .sel(alu_inB_sel), .out(alu_inB));
ALU alu(.A(alu_inA), .B(alu_inB), .ALUop(ALUop_EX), .Out(alu_out));
Branch_Comp branch_comp(.branch_inA(branch_inA), .branch_inB(branch_inB), .funct3(funct3_EX), .branch_result(branch_result_EX));
mux3_to1 mux_dataW(.in_a(alu_inA), .in_b(branch_inB), .in_c(csr_imm), .sel(dataW_sel_EX), .out(dataW_EX));
Store_mask store_mask(.stype(stype_MEM), .offset(alu_out_MEM[1:0]), .funct3_MEM(funct3_MEM[1:0]),  
                      .dataW_MEM(dataW_MEM), .dcache_we(dcache_we_wire), .dataW(dataW));
Load_Ext load_ext(.funct3(funct3_WB), .offset(alu_out_WB[1:0]), .d_rdata_WB(d_rdata_WB), .d_rdata_ext(d_rdata_ext));
mux3_to1 mux_rdata_WB(.in_a(d_rdata_ext), .in_b(alu_out_WB), .in_c(pc_add4_WB), .sel(memtoreg_WB), .out(rdata_WB));
//Branch Prediction
Branch_Pred branch_pred(.clk(clk), .reset(reset), .btype_ID(btype_ID), .branch_result_EX(branch_result_EX), .branch_predict(branch_predict_ID));
endmodule
