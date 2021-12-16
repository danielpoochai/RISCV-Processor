module mux2_to1 #(WIDTH = 32)(
	in_a, in_b, sel, out
	);

	input [WIDTH-1:0] in_a, in_b;
	input sel;
	output [WIDTH-1:0] out;

	assign out = sel? in_b: in_a;
endmodule

module mux3_to1 #(WIDTH = 32)(
	in_a, in_b, in_c, sel, out
	);

	input [WIDTH-1:0] in_a, in_b, in_c;
	input [1:0] sel;
	output reg [WIDTH-1:0] out;

	always@(*) begin
		case(sel) 
			2'b00: out = in_a;
			2'b01: out = in_b;
			2'b10: out = in_c;
			default: out = 0;
		endcase
	end
endmodule

module mux4_to1 #(WIDTH = 128)(
	in, sel, out
	);
	input [WIDTH-1:0] in;
	input [1:0] sel;
	output reg [WIDTH/4-1:0] out;

	always@(*) begin
		case(sel)
			3'd0: out = in[WIDTH/4-1:0];
			3'd1: out = in[WIDTH/2-1:WIDTH/4];
			3'd2: out = in[3*WIDTH/4-1:WIDTH/2];
			3'd3: out = in[WIDTH-1:3*WIDTH/4];
			default: out = 0;
		endcase
	end

endmodule

module mux5_to1 #(WIDTH = 32)(
	in_a, in_b, in_c, in_d, in_e, sel, out
	);

	input [WIDTH-1:0] in_a, in_b, in_c, in_d, in_e;
	input [2:0] sel;
	output reg [WIDTH-1:0] out;

	always@(*) begin
		case(sel)
			3'd0: out = in_a;
			3'd1: out = in_b;
			3'd2: out = in_c;
			3'd3: out = in_d;
			3'd4: out = in_e;
			default: out = 0;
		endcase
	end
endmodule