// Module: ALUdecoder
// Desc:   Sets the ALU operation
// Inputs: opcode: the top 6 bits of the instruction
//         funct: the funct, in the case of r-type instructions
//         add_rshift_type: selects whether an ADD vs SUB, or an SRA vs SRL
// Outputs: ALUop: Selects the ALU's operation
//

`include "Opcode.vh"
`include "ALUop.vh"

module ALUdec(
  input [6:0]       opcode,
  input [2:0]       funct, //funct3[2:0]
  input             add_rshift_type, //funct7[6] 
  output reg [3:0]  ALUop
);

always@(*) begin
  ALUop = `ALU_XXX;
  case(opcode)
    `OPC_ARI_RTYPE:
    begin
      case(funct)
        `FNC_ADD_SUB: ALUop = add_rshift_type? `ALU_SUB: `ALU_ADD;
        `FNC_SLL:   ALUop = `ALU_SLL;
        `FNC_SLT:   ALUop = `ALU_SLT;
        `FNC_SLTU:  ALUop = `ALU_SLTU;
        `FNC_XOR:   ALUop = `ALU_XOR;
        `FNC_OR:    ALUop = `ALU_OR;
        `FNC_AND:   ALUop = `ALU_AND;
        `FNC_SRL_SRA: ALUop = add_rshift_type? `ALU_SRA: `ALU_SRL;
        default:    ALUop = `ALU_XXX;
      endcase
    end
    `OPC_ARI_ITYPE:
    begin
      case(funct)
        `FNC_ADD_SUB: ALUop = `ALU_ADD; //I type only ADD (SUB with signed imm.)
        `FNC_SLL:   ALUop = `ALU_SLL;
        `FNC_SLT:   ALUop = `ALU_SLT;
        `FNC_SLTU:  ALUop = `ALU_SLTU; 
        `FNC_XOR:   ALUop = `ALU_XOR;
        `FNC_OR:    ALUop = `ALU_OR;
        `FNC_AND:   ALUop = `ALU_AND;
        `FNC_SRL_SRA: ALUop = add_rshift_type? `ALU_SRA: `ALU_SRL;
        default:    ALUop = `ALU_XXX; 
      endcase
    end
    `OPC_BRANCH: //not doing anything in ALU, there
    begin
      ALUop = `ALU_ADD;
    end
    `OPC_STORE: //rs1(base addr) + imm.
    begin
      ALUop = `ALU_ADD;
    end
    `OPC_LOAD:  //rs1(base addr) + imm.
    begin   
      ALUop = `ALU_ADD;
    end
    `OPC_JAL: 
    begin
      ALUop = `ALU_ADD;
    end
    `OPC_JALR:
    begin
      ALUop = `ALU_ADD;
    end
    `OPC_LUI:
    begin
      ALUop = `ALU_COPY_B;
    end
    `OPC_AUIPC:
    begin
      ALUop = `ALU_ADD;
    end
    `OPC_CSR:
    begin
      ALUop = `ALU_COPY_B; //imm[11:0] as the addr of CSR?
    end
    `OPC_NOOP:
    begin
      ALUop = `ALU_ADD;
    end
    default:
    begin
      ALUop = `ALU_XXX;
    end
  endcase
end

endmodule
