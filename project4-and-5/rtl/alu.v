`default_nettype none

// The arithmetic logic unit (ALU) is responsible for performing the core
// calculations of the processor. It takes two 32-bit operands and outputs
// a 32 bit result based on the selection operation - addition, comparison,
// shift, or logical operation. This ALU is a purely combinational block, so
// you should not attempt to add any registers or pipeline it.
module alu (
    // NOTE: Both 3'b010 and 3'b011 are used for set less than operations and
    // your implementation should output the same result for both codes. The
    // reason for this will become clear in project 3.
    //
    // Major operation selection.
    // 3'b000: addition/subtraction if `i_sub` asserted
    // 3'b001: shift left logical
    // 3'b010,
    // 3'b011: set less than/unsigned if `i_unsigned` asserted
    // 3'b100: exclusive or
    // 3'b101: shift right logical/arithmetic if `i_arith` asserted
    // 3'b110: or
    // 3'b111: and
	
    input  wire [ 2:0] i_opsel,
	
    // When asserted, addition operations should subtract instead.
    // This is only used for `i_opsel == 3'b000` (addition/subtraction).
    input  wire        i_sub,
	
    // When asserted, comparison operations should be treated as unsigned.
    // This is used for branch comparisons and set less than unsigned. For
    // b ranch operations, the ALU result is not used, only the comparison
    // results.
    input  wire        i_unsigned,
	
    // When asserted, right shifts should be treated as arithmetic instead of
    // logical. This is only used for `i_opsel == 3'b101` (shift right).
    input  wire        i_arith,
	
    // First 32-bit input operand.
    input  wire [31:0] i_op1,
	
    // Second 32-bit input operand.
    input  wire [31:0] i_op2,
	
    // 32-bit output result. Any carry out should be ignored.
    output wire [31:0] o_result,
	
    // Equality result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_eq,
	
    // Set less than result. This is used externally to determine if a branch
    // should be taken.
    output wire        o_slt
);	
	// Comparison logic
	wire op1_sign = i_op1[31];
	wire op2_sign = i_op2[31];
	wire signs_differ = op1_sign ^ op2_sign;
	wire unsigned_less = (i_op1 < i_op2);
	wire signed_less = signs_differ ? op1_sign : unsigned_less;

	// Shift logic - barrel shifter implementation
	wire [4:0] shift_amt = i_op2[4:0];
	wire [31:0] sll_stage0, sll_stage1, sll_stage2, sll_stage3, sll_stage4;
	wire [31:0] srl_stage0, srl_stage1, srl_stage2, srl_stage3, srl_stage4;
	wire fill_bit = i_arith & i_op1[31];

	// Shift left barrel shifter (5 stages for 32-bit)
	assign sll_stage0 = shift_amt[0] ? {i_op1[30:0], 1'b0} : i_op1;
	assign sll_stage1 = shift_amt[1] ? {sll_stage0[29:0], 2'b0} : sll_stage0;
	assign sll_stage2 = shift_amt[2] ? {sll_stage1[27:0], 4'b0} : sll_stage1;
	assign sll_stage3 = shift_amt[3] ? {sll_stage2[23:0], 8'b0} : sll_stage2;
	assign sll_stage4 = shift_amt[4] ? {sll_stage3[15:0], 16'b0} : sll_stage3;

	// Shift right barrel shifter (5 stages for 32-bit)
	assign srl_stage0 = shift_amt[0] ? {{1{fill_bit}}, i_op1[31:1]} : i_op1;
	assign srl_stage1 = shift_amt[1] ? {{2{fill_bit}}, srl_stage0[31:2]} : srl_stage0;
	assign srl_stage2 = shift_amt[2] ? {{4{fill_bit}}, srl_stage1[31:4]} : srl_stage1;
	assign srl_stage3 = shift_amt[3] ? {{8{fill_bit}}, srl_stage2[31:8]} : srl_stage2;
	assign srl_stage4 = shift_amt[4] ? {{16{fill_bit}}, srl_stage3[31:16]} : srl_stage3;

	// Setting information
	assign o_slt = i_unsigned ? unsigned_less : signed_less;
	assign o_eq = (i_op1 == i_op2);

	// Figure out which main mode we are in
	assign o_result =   (i_opsel == 3'b001) ? sll_stage4 :
				        (i_opsel == 3'b010) ? {31'b0, (i_unsigned ? unsigned_less : signed_less)} :
				        (i_opsel == 3'b011) ? {31'b0, (i_unsigned ? unsigned_less : signed_less)} :
				        (i_opsel == 3'b100) ? (i_op1 ^ i_op2) :
				        (i_opsel == 3'b101) ? srl_stage4 :
				        (i_opsel == 3'b110) ? (i_op1 | i_op2) :
                        (i_opsel == 3'b111) ? (i_op1 & i_op2) :
                        i_sub ? (i_op1 - i_op2) : (i_op1 + i_op2);
endmodule

`default_nettype wire