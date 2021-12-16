`include "Opcode.vh"
//for scratch
module Imm_Gen(
	instr,
	imm
	);

	input [31:0] instr;
	output reg [31:0] imm;

	always@(*) begin
		imm[31:12] 	= {20{instr[31]}};
		imm[11:0] 	= instr[31:20];
		
		case(instr[6:0])
			// `OPC_LOAD:
			// begin
			// 	imm[31:14] 	= {20{instr[31]}};
			// 	imm[13:2] 	= instr[31:20];
			// 	imm[1:0] 	= 2'b00;
			// end
			`OPC_STORE:
			begin
				imm[31:12] 	= {20{instr[31]}};
				imm[11:5] 	= instr[31:25];
				imm[4:0] 	= instr[11:7];	 
			end
			`OPC_BRANCH:
			begin
				imm[31:12] 	= {20{instr[31]}};
				imm[11] 	= instr[7];
				imm[10:5] 	= instr[30:25];
				imm[4:1] 	= instr[11:8];
				imm[0] 		= 1'b0;
			end
			`OPC_JAL:
			begin
				imm[31:20] 	= {12{instr[31]}};
				imm[19:12] 	= instr[19:12]; 
				imm[11] 	= instr[20];
				imm[10:1] 	= instr[30:21];
				imm[0] 		= 1'b0;
			end
			`OPC_LUI:
			begin
				imm[31:12] 	= instr[31:12];
				imm[11:0] 	= {12{1'b0}};
			end
			`OPC_AUIPC:
			begin
				imm[31:12] 	= instr[31:12];
				imm[11:0] 	= {12{1'b0}};
			end
			default:
			begin
				imm[31:12] 	= {20{instr[31]}};
				imm[11:0] 	= instr[31:20];
			end
		endcase
	end
	 
endmodule