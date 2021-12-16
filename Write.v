`include "const.vh"

module Write_Data(
		input [127:0]	mem_resp_data, 
		input [31:0] 	cpu_req_data,
		input [3:0]	 	cpu_req_write,
		input [1:0] 	which_words,		
		output reg [127:0] sram_write_data 
		); 
	
	wire [31:0] write_mask, write_mask_n;
	assign write_mask 	= {{8{cpu_req_write[3]}},{8{cpu_req_write[2]}},{8{cpu_req_write[1]}},{8{cpu_req_write[0]}}};
	assign write_mask_n = ~ write_mask;
           
	always@(*) begin
		sram_write_data = mem_resp_data;
		case(which_words)
			2'd0: 	sram_write_data[31:0] 	= ((write_mask_n&mem_resp_data[31:0]  )|(write_mask&cpu_req_data));
			2'd1:	sram_write_data[63:32] 	= ((write_mask_n&mem_resp_data[63:32] )|(write_mask&cpu_req_data));
			2'd2:	sram_write_data[95:64] 	= ((write_mask_n&mem_resp_data[95:64] )|(write_mask&cpu_req_data));
			2'd3:	sram_write_data[127:96] = ((write_mask_n&mem_resp_data[127:96])|(write_mask&cpu_req_data));
		endcase
	end
endmodule

module Write_Mask(
	input [1:0] 		which_words,
	input [3:0] 		cpu_write_mask,
	output reg [15:0] 	write_mask
	);
	
	always@(*) begin
		write_mask = 16'b0000_0000_0000_0000;
		case(which_words)
			2'd0: write_mask[3:0] 	= cpu_write_mask;
			2'd1: write_mask[7:4] 	= cpu_write_mask;
			2'd2: write_mask[11:8] 	= cpu_write_mask;
			2'd3: write_mask[15:12] = cpu_write_mask;
		endcase
	end

endmodule

module Write_Enable(
	input 		[1:0] 	which_SRAM,
	output reg	[3:0] 	write_enable_hit 
	);
	
	always@(*) begin 
		write_enable_hit = 4'b1111;
		// if(cpu_we != 4'd0000) begin //cpu write
		case(which_SRAM)
			2'd0: 	write_enable_hit = 4'b1110;
			2'd1:	write_enable_hit = 4'b1101;
			2'd2:	write_enable_hit = 4'b1011;
			2'd3:	write_enable_hit = 4'b0111;
		endcase
		// end
	end
		
endmodule


