module Branch_Pred(
	input clk, reset, btype_ID, branch_result_EX,
	output branch_predict
	);
	
	localparam TAKEN_STRONG 	= 	2'd0;
	localparam TAKEN_WEAK 		=	2'd1;
	localparam NOT_TAKEN_WEAK 	=	2'd2;
	localparam NOT_TAKEN_STRONG	=	2'd3;

	localparam TAKEN 	= 1'd1; 
	localparam NOT_TAKEN= 1'd0;

	reg [1:0] 	state, state_nxt;
	reg 		predict;

	//Two-bit predictor
	assign branch_predict = btype_ID? predict: NOT_TAKEN;

	//always Taken
	// assign branch_predict = btype_ID? TAKEN: NOT_TAKEN;

	//always Not Taken
	// assign branch_predict = btype_ID? NOT_TAKEN: NOT_TAKEN;

	// 1-bit predictor
	// always@(*) begin
	// 	case(state) 
	// 		TAKEN_STRONG:
	// 		begin
	// 			if(branch_predict) state_nxt = TAKEN_STRONG;
	// 			else state_nxt = NOT_TAKEN_STRONG;

	// 			predict = TAKEN;
	// 		end
	// 		NOT_TAKEN_STRONG:
	// 		begin
	// 			if(branch_predict) state_nxt = TAKEN_STRONG;
	// 			else state_nxt = NOT_TAKEN_STRONG;

	// 			predict = NOT_TAKEN;
	// 		end
	// 	endcase
	// end

	//2-bit predictor
	always@(*) begin
		case(state)
			TAKEN_STRONG:
			begin
				//state
				if(branch_result_EX) state_nxt = TAKEN_STRONG;
				else state_nxt = TAKEN_WEAK;
				//output
				predict = TAKEN;
			end
			TAKEN_WEAK:
			begin
				//state
				if(branch_result_EX) state_nxt = TAKEN_STRONG;
				else state_nxt = NOT_TAKEN_WEAK;
				//output
				predict = TAKEN;
			end
			NOT_TAKEN_WEAK:
			begin
				//state
				if(branch_result_EX) state_nxt = TAKEN_WEAK;
				else state_nxt = NOT_TAKEN_STRONG;
				//output
				predict = NOT_TAKEN;
			end
			NOT_TAKEN_STRONG:
			begin
				//state
				if(branch_result_EX) state_nxt = NOT_TAKEN_WEAK;
				else state_nxt = NOT_TAKEN_STRONG;
				//output
				predict = NOT_TAKEN;
			end
		endcase
	end

	always@(posedge clk) begin
		if(reset) state <= TAKEN_STRONG;
		else state <= state_nxt;
	end
endmodule