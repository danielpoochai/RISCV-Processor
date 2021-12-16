//for scratch

module Registers #(DEPTH=32)(
	clk, reset, RegWEn,
	rs1, rs2, rd, rd_data, 
	rs1_data, rs2_data
	);

	input clk, reset, RegWEn;
	input [4:0] rs1, rs2, rd;
	input [31:0] rd_data;

	output reg [31:0] rs1_data, rs2_data;

	//registers bank
	reg [31:0] mem[0:DEPTH-1], mem_nxt[0:DEPTH-1];

	integer j;
	always@(*) begin
		rs1_data = 32'd0;
		rs2_data = 32'd0;	
	//rs1
		if(rs1 == 5'd0) begin
			rs1_data = 32'd0;
		end
		else if((rs1 == rd) && RegWEn) begin
			rs1_data = rd_data;
		end
		else begin
			rs1_data = mem[rs1];
		end
	//rs2
		if(rs2 == 5'd0) begin
			rs2_data = 32'd0;
		end
		else if((rs2 == rd) && RegWEn) begin
			rs2_data = rd_data;
		end
		else begin
			rs2_data = mem[rs2];
		end

	//rd
		for(j=0; j< 32; j=j+1) begin
			mem_nxt[j] = mem[j];
		end
		if(RegWEn && rd != 5'd0) begin
			mem_nxt[rd] = rd_data;
		end
	end

	integer i;
	always@(posedge clk) begin
		if(reset) begin
			for(i =0; i <= 31; i = i+1) begin
				mem[i] <= 32'd0;
			end
			// rs1_data <= 32'd0;
			// rs2_data <= 32'd0;
		end
		else begin
			// if(RegWEn && rd != 5'd0) begin
			// 	mem[rd] <= rd_data;
			// end
			for(i =0; i <= 31; i = i+1) begin
				mem[i] <= mem_nxt[i];
			end
		end
	end

endmodule