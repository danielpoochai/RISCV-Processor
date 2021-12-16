`include "Opcode.vh"
//for scratch
module Branch_Comp(
	branch_inA, branch_inB, funct3,
	branch_result
	);
	
	input [31:0] branch_inA, branch_inB;
	input [2:0] funct3;
	output reg branch_result;

	wire beq, blt, bltu;
	assign beq 	= $signed(branch_inA) == $signed(branch_inB);
	assign blt 	= $signed(branch_inA) < $signed(branch_inB);
	assign bltu = branch_inA < branch_inB;

	always@(*) begin
		branch_result = 1'b0;
		case(funct3)
			`FNC_BEQ: 	branch_result = beq;
			`FNC_BNE: 	branch_result = ~(beq);
			`FNC_BLT: 	branch_result = blt;
			`FNC_BGE: 	branch_result = ~(blt);
			`FNC_BLTU: 	branch_result = bltu;
			`FNC_BGEU: 	branch_result = ~(bltu);
			default:	branch_result = 1'b0;
		endcase
	end

endmodule