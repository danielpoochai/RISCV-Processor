module Forwarding_unit(
		input if_rs1_EX, if_rs2_EX, RegWEn_MEM, RegWEn_WB,
		input [1:0] memtoreg_MEM, memtoreg_WB,
		input [4:0] rs1_EX, rs2_EX, rd_MEM, rd_WB,
		output reg [2:0] A_sel, B_sel,  
		output stall
);

reg stall_A, stall_B;
assign stall = stall_A | stall_B;

//A_sel
always@(*) begin
	stall_A = 1'd0;
	A_sel 	= 3'd0;
	if(if_rs1_EX && rs1_EX != 5'd0) begin
		if((rs1_EX == rd_MEM) && RegWEn_MEM) begin
			case(memtoreg_MEM)
				2'd0: //Load Intruction
				begin
					stall_A = 1'd1; //stall for one cycle
					A_sel 	= 3'd0; 
				end
				2'd1: //write the alu_result back to reg
				begin
					stall_A = 1'd0;
					A_sel 	= 3'd1;
				end
				default: //might detect J type for debugging
				begin
					stall_A = 1'd0;
					A_sel 	= 3'd5; //for debug!
				end
			endcase
		end
		else if((rs1_EX == rd_WB) && RegWEn_WB) begin
			case(memtoreg_WB)
				2'd0:
				begin
					stall_A = 1'd0;
					A_sel = 3'd2;
				end
				2'd1:
				begin
					stall_A = 1'd0;
					A_sel = 3'd3;
				end
				2'd2:
				begin
					stall_A = 1'd0;
					A_sel = 3'd4;
				end
				default:
				begin
					stall_A = 1'd0;
					A_sel 	= 3'd6; //for debug!
				end
			endcase
		end
		else begin //no data hazard on A
			stall_A = 1'd0;
			A_sel 	= 3'd0;
		end
	end
end

//B_sel
always@(*) begin
	stall_B = 1'd0;
	B_sel 	= 3'd0;

	if(if_rs2_EX && rs2_EX != 5'd0) begin
		if((rs2_EX == rd_MEM) && RegWEn_MEM) begin
			case(memtoreg_MEM) 
				2'd0:
				begin
					stall_B = 1'd1;
					B_sel 	= 3'd0;
				end
				2'd1:
				begin
					stall_B = 1'd0;
					B_sel = 3'd1;
				end
				default:
				begin
					stall_B = 1'd0;
					B_sel 	= 3'd5; 
				end
			endcase
		end
		else if((rs2_EX == rd_WB) && RegWEn_WB) begin
			case(memtoreg_WB)
				2'd0:
				begin
					stall_B = 1'd0;
					B_sel = 3'd2;
				end
				2'd1:
				begin
					stall_B = 1'd0;
					B_sel = 3'd3;
				end
				2'd2:
				begin
					stall_B = 1'd0;
					B_sel = 3'd4;
				end
				default:
				begin
				 	stall_B = 1'd0;
				 	B_sel 	= 3'd6; 
				end
			endcase
		end
		else begin
			stall_B = 1'd0;
			B_sel 	= 3'd0;
		end
	end
end

endmodule