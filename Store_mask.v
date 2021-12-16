`include "Opcode.vh"

module Store_mask(
	input stype,
	input [1:0] offset,
	input [1:0] funct3_MEM, //only the lower 2-bit of funct3
	input [31:0] dataW_MEM,
	output reg [3:0] dcache_we,
	output reg [31:0] dataW
	);
	
	always@(*) begin
		dcache_we 	= 4'b0000;
		dataW 		= 32'd0;
		if(stype) begin
			case(offset) 
				2'd0: 
				begin
					case(funct3_MEM)
						2'b00:	//store byte
						begin
							dcache_we 	= 4'b0001;
							dataW 		= dataW_MEM;
						end
						2'b01:	//store halfword
						begin
							dcache_we 	= 4'b0011;
							dataW 		= dataW_MEM;
						end
						2'b10:	//store word
						begin
							dcache_we 	= 4'b1111;
							dataW 		= dataW_MEM;
						end
						default:
						begin
							dcache_we 	= 4'b0000;
							dataW 		= dataW_MEM;
						end
					endcase
				end
				2'd1:
				begin
					case(funct3_MEM)
						2'b00:	//store byte
						begin
							dcache_we = 4'b0010;
							dataW = {dataW_MEM[23:0], 8'd0};
						end
						2'b01:	//store halfword
						begin
							dcache_we = 4'b0110;
							dataW = {dataW_MEM[23:0], 8'd0};
						end
						2'b10:	//store word ???
						begin
							dcache_we = 4'b1111;
							dataW = dataW_MEM;
						end
						default:
						begin
							dcache_we = 4'b0000;
						end
					endcase
				end
				2'd2:
				begin
					case(funct3_MEM)
						2'b00:	//store byte
						begin
							dcache_we = 4'b0100;
							dataW = {dataW_MEM[15:0], 16'd0};
						end
						2'b01:	//store halfword
						begin
							dcache_we = 4'b1100;
							dataW = {dataW_MEM[15:0], 16'd0};
						end
						2'b10:	//store word 
						begin
							dcache_we = 4'b1111;
							dataW = dataW_MEM;
						end
						default:
						begin
							dcache_we = 4'b0000;
						end
					endcase
				end
				2'd3:
				begin
					case(funct3_MEM)
						2'b00:	//store byte
						begin
							dcache_we = 4'b1000;
							dataW = {dataW_MEM[7:0], 24'd0};
						end
						2'b01:	//store halfword ???
						begin
							dcache_we = 4'b1100;
							dataW = {dataW_MEM[15:0], 16'd0};
						end
						2'b10:	//store word
						begin
							dcache_we = 4'b1111;
							dataW = dataW_MEM;
						end
						default:
						begin
							dcache_we = 4'b0000;
						end
					endcase
				end
				default:
				begin
					dataW 		= 32'd0;
					dcache_we 	= 4'd0;
				end
			endcase
		end
		else begin
			dcache_we 	= 4'b0000;
			dataW 		= 32'd0;
		end
	end
endmodule

 