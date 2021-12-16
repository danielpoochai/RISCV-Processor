module Flush_unit(
	input btype_EX, jtype_EX, 
	input branch_predict_EX, branch_result_EX,
	output flush_EX, predict_correct
	);

	// assign flush_EX = jtype_EX | (btype_EX & branch_result_EX);

	//with branch prediction
	localparam PREDICTED_TAKEN 		= 1'd1; 
	localparam PREDICTED_NOT_TAKEN	= 1'd0;

	reg btype_flush_EX;
	
	//output assignment
	assign predict_correct = (branch_predict_EX == branch_result_EX);	
	assign flush_EX = jtype_EX | (btype_EX & btype_flush_EX);

	always@(*) begin
		btype_flush_EX = 1'd0;
		case(branch_predict_EX)
			PREDICTED_TAKEN:
			begin
				btype_flush_EX = 1'd0;
			end
			PREDICTED_NOT_TAKEN:
			begin
				if(branch_result_EX) btype_flush_EX = 1'd1;
				else btype_flush_EX = 1'd0;
			end
		endcase
	end

endmodule