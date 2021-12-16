`include "Opcode.vh"
//for scratch
module Load_Ext(
	funct3,
	offset,
	d_rdata_WB,
	d_rdata_ext
	);

	input [2:0] funct3;
	input [1:0] offset;
	input [31:0] d_rdata_WB;
	output reg [31:0] d_rdata_ext;

	reg [31:0] running_rdata;

	always@(*) begin
		d_rdata_ext = 32'd0;
		
		case(funct3)
			`FNC_LB:
			begin
				case(offset)
					2'd0:	d_rdata_ext = {{24{d_rdata_WB[7]}},d_rdata_WB[7:0]};
					2'd1:	d_rdata_ext = {{24{d_rdata_WB[15]}},d_rdata_WB[15:8]};
					2'd2:	d_rdata_ext = {{24{d_rdata_WB[23]}},d_rdata_WB[23:16]};
					2'd3:	d_rdata_ext = {{24{d_rdata_WB[31]}},d_rdata_WB[31:24]};
					default:	d_rdata_ext = 32'd0;
				endcase
			end	
			`FNC_LH:
			begin
				case(offset)
					2'd0:	d_rdata_ext = {{16{d_rdata_WB[15]}},d_rdata_WB[15:0]};
					2'd1:	d_rdata_ext = {{16{d_rdata_WB[23]}},d_rdata_WB[23:8]};
					2'd2:	d_rdata_ext = {{16{d_rdata_WB[31]}},d_rdata_WB[31:16]};
					2'd3:	d_rdata_ext = {{16{d_rdata_WB[31]}},d_rdata_WB[31:16]};
					default:	d_rdata_ext = 32'd0;
				endcase
			end	
			`FNC_LW:
			begin
				d_rdata_ext = d_rdata_WB;
			end	
			`FNC_LBU:
			begin
				case(offset)
					2'd0:	d_rdata_ext = {{24{1'd0}},d_rdata_WB[7:0]};
					2'd1:	d_rdata_ext = {{24{1'd0}},d_rdata_WB[15:8]};
					2'd2:	d_rdata_ext = {{24{1'd0}},d_rdata_WB[23:16]};
					2'd3:	d_rdata_ext = {{24{1'd0}},d_rdata_WB[31:24]};
					default:	d_rdata_ext = 32'd0;
				endcase
			end	
			`FNC_LHU: 
			begin
				case(offset)
					2'd0:	d_rdata_ext = {{16{1'd0}},d_rdata_WB[15:0]};
					2'd1:	d_rdata_ext = {{16{1'd0}},d_rdata_WB[23:8]};
					2'd2:	d_rdata_ext = {{16{1'd0}},d_rdata_WB[31:16]};
					2'd3:	d_rdata_ext = {{16{1'd0}},d_rdata_WB[31:16]};
					default:	d_rdata_ext = 32'd0;
				endcase
			end	
			default:	d_rdata_ext = 32'd0;
		endcase
	end

endmodule