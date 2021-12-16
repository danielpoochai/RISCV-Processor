// Module: ALU.v
// Desc:   32-bit ALU for the RISC-V Processor
// Inputs: 
//    A: 32-bit value
//    B: 32-bit value
//    ALUop: Selects the ALU's operation 
// 						
// Outputs:
//    Out: The chosen function mapped to A and B.

`include "Opcode.vh"
`include "ALUop.vh"

module ALU(
    input [31:0] A,B,
    input [3:0] ALUop,
    output reg [31:0] Out
);

wire [32:0] B_option, result;

assign B_option = (ALUop[0]|ALUop[1])? ~(B) + 32'd1: B;
assign result =  A + B_option;

always@(*) begin
    Out = 32'd0;
    case(ALUop)
        `ALU_ADD:    Out     = result[31:0];             //0000
        `ALU_SUB:    Out     = result[31:0];             //0001  
        `ALU_AND:    Out     = A & B;                    //0010  
        `ALU_OR:     Out     = A | B;                    //0011    
        `ALU_XOR:    Out     = A ^ B;                    //0100
        `ALU_SLT:    Out[0]  = $signed(A) < $signed(B);  //0101
        `ALU_SLTU:   Out[0]  = result[32];               //0110
        `ALU_SLL:    Out     = A << B[4:0];              //0111
        `ALU_SRA:    Out     = $signed(A) >>> B[4:0];    //1000
        `ALU_SRL:    Out     = A >> B[4:0];              //1001
        `ALU_COPY_B: Out     = B;                        //1010
        `ALU_XXX:    Out     = 32'd0;                    //1111
        default:    Out     = 32'd0;
    endcase
end

endmodule
