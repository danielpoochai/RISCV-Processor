`include "Opcode.vh"
//for scratch
module Control_unit(
	opcode, funct3,
	RegWEn, Asel, Bsel, dataW_sel, memRW, memtoreg,
	if_rs1, if_rs2, btype, jtype, stype, csrtype
	);

	input [6:0] opcode;
	input funct3; //only one bit funct3[2], to discern csrw/ csrwi
	output reg if_rs1, if_rs2, Asel, Bsel, RegWEn, memRW, btype, jtype, stype, csrtype;
	output reg [1:0] memtoreg, dataW_sel;

	always@(*) begin
		btype 	= 1'd0;
		jtype 	= 1'd0;
		stype 	= 1'd0;
		if_rs1 	= 1'd0;
		if_rs2 	= 1'd0;
		csrtype = 1'd0;
		RegWEn 	= 1'd0;
		Asel   	= 1'd0;
		Bsel 	= 1'd0;
		memRW 	= 1'd0;
		memtoreg 	= 1'd0;
		dataW_sel 	= 2'd0;
		case(opcode)
			`OPC_LUI:
			begin
				if_rs1 	= 1'd0;
				if_rs2 	= 1'd0;
				btype 	= 1'd0;
				jtype 	= 1'd0;
				stype 	= 1'd0;
				csrtype = 1'd0;
				RegWEn 	= 1'd1; //write to reg
				Bsel 	= 1'd1; //choose the imm. path
				memRW 	= 1'd0; //not write
				memtoreg 	= 2'd1; //choose the alu output
				//don't care
				Asel   	= 1'd0;
				dataW_sel 	= 2'd0;
			end 
			`OPC_AUIPC:
			begin
				if_rs1 	= 1'd0;
				if_rs2 	= 1'd0;
				btype 	= 1'd0;
				jtype 	= 1'd0;
				stype 	= 1'd0;
				csrtype = 1'd0;
				RegWEn 	= 1'd1; //write to reg
				Asel   	= 1'd1; //choose the PC
				Bsel 	= 1'd1; //choose the imm.
				memRW 	= 1'd0; //not write
				memtoreg 	= 2'd1;
				//don't care
				dataW_sel 	= 2'd0;
			end
			`OPC_JAL:
			begin
				if_rs1 	= 1'd0;
				if_rs2 	= 1'd0;
				btype 	= 1'd0;
				jtype 	= 1'd1;
				stype 	= 1'd0;
				csrtype = 1'd0;
				RegWEn 	= 1'd1; //write pc+4 to the reg
				Asel   	= 1'd1; //choose the PC
				Bsel 	= 1'd1; //choose the imm.
				memRW 	= 1'd0; //not write
				memtoreg 	= 2'd2;  //
				//don't care
				dataW_sel 	= 2'd0;
			end
			`OPC_JALR:
			begin
				if_rs1 	= 1'd1;
				if_rs2 	= 1'd0;
				btype 	= 1'd0;
				jtype 	= 1'd1;
				stype 	= 1'd0;
				csrtype = 1'd0;
				RegWEn 	= 1'd1; //write pc+4 to the reg
				Asel   	= 1'd0; //not deal with hazard
				Bsel 	= 1'd1; //choose the immediate
				memRW 	= 1'd0; //not write
				memtoreg 	= 2'd2;
				//don't care
				dataW_sel 	= 2'd0;
			end
			`OPC_BRANCH:
			begin
				if_rs1 	= 1'd1;
				if_rs2 	= 1'd1;
				btype 	= 1'd1;
				jtype 	= 1'd0;
				stype 	= 1'd0;
				csrtype = 1'd0;
				RegWEn 	= 1'd0; //not write
				Asel   	= 1'd0; //pc
				Bsel 	= 1'd0; //immediate
				memRW 	= 1'd0; //not write
				//don't care
				memtoreg 	= 2'd0;
				dataW_sel 	= 2'd0;
			end
			`OPC_STORE:
			begin
				if_rs1 	= 1'd1;
				if_rs2 	= 1'd1;
				btype 	= 1'd0;
				jtype 	= 1'd0;
				stype 	= 1'd1;
				csrtype = 1'd0;
				RegWEn 	= 1'd0;
				Asel   	= 1'd0; //not deal with hazard
				Bsel 	= 1'd0; //not deal with hazard
				memRW 	= 1'd0; //write to memory
				dataW_sel 	= 2'd1; //choose alu_inB
				//don't care
				memtoreg 	= 2'd0;
			end
			`OPC_LOAD:
			begin
				if_rs1 	= 1'd1;
				if_rs2 	= 1'd0;
				btype 	= 1'd0;
				jtype 	= 1'd0;
				stype 	= 1'd0;
				csrtype = 1'd0;
				RegWEn 	= 1'd1; //write to reg
				Asel   	= 1'd0; //dataA & deal with hazard
				Bsel 	= 1'd1; //choose the imm.
				memRW 	= 1'd1; //read
				memtoreg 	= 2'd0; 
				//don't care
				dataW_sel 	= 2'd0;
			end
			`OPC_ARI_RTYPE:
			begin
				if_rs1 	= 1'd1;
				if_rs2 	= 1'd1;
				btype 	= 1'd0;
				jtype 	= 1'd0;
				stype 	= 1'd0;
				csrtype = 1'd0;
				RegWEn 	= 1'd1; //write to reg
				Asel   	= 1'd0; //not deal with hazard
				Bsel 	= 1'd0; //not deal with hazard
				memRW 	= 1'd0; //not write
				memtoreg 	= 2'd1; //choose alu_out
				//don't care
				dataW_sel 	= 2'd0;
			end
			`OPC_ARI_ITYPE:
			begin
				if_rs1 	= 1'd1;
				if_rs2 	= 1'd0;
				btype 	= 1'd0;
				jtype 	= 1'd0;
				csrtype = 1'd0;
				RegWEn 	= 1'd1; //write to reg
				Asel   	= 1'd0; //not deal with hazard
				Bsel 	= 1'd1; //choose the imm.
				memRW 	= 1'd0; //not write
				memtoreg 	= 2'd1; //choose alu_out
				//don't care
				dataW_sel 	= 2'd0;
			end
			`OPC_CSR:
			begin
				if_rs1 	= 1'd1;
				if_rs2 	= 1'd0;
				btype 	= 1'd0;
				jtype 	= 1'd0;
				stype 	= 1'd0;
				csrtype = 1'd1; //write to CSR	
				RegWEn 	= 1'd0; //in this project, only write to CSR, not write back to reg
				Asel   	= 1'd0; //not deal with hazard
				memRW 	= 1'd0; 
				dataW_sel 	= funct3? 2'd2: 2'd0; //csrwi? choose imm.: choose rs1
				//don't care
				Bsel 	= 1'd0;
				memtoreg 	=  1'd0;

			end
			default:
			begin
				if_rs1 	= 1'd0;
				if_rs2 	= 1'd0;
				btype 	= 1'd0;
				jtype 	= 1'd0;
				stype 	= 1'd0;
				csrtype = 1'd0; 
				RegWEn 	= 1'd0;
				Asel   	= 1'd0;
				Bsel 	= 1'd0;
				memRW 	= 1'd0;
				memtoreg 	= 1'd0;
				dataW_sel 	= 2'd0;
			end
		endcase
	end

endmodule