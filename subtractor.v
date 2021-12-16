module subtractor4 #(WIDTH = 32) (
	in_a, out
	);

	input [WIDTH-1:0] in_a;
	output [WIDTH-1:0] out;

	parameter FOUR = {{WIDTH-3{1'd0}}, 3'b100};

	assign out = in_a - FOUR;

endmodule