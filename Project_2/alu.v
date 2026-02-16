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
	// Verilog wont allow wire in always, so I need reg (they should synthesize into combinational logic though)
	reg [31:0] result_temp;
	
	// Setting information
	assign o_result = result_temp;
    assign o_slt = i_unsigned ? (i_op1 < i_op2) : ($signed(i_op1) < $signed(i_op2));
	assign o_eq = (i_op1 == i_op2);
	
	// Figure out which main mode we are in
	// Also my friend told me to use ternary over case statements bc they can act weird later in the course... my guess is weird synthesis
	always @(*) begin
    result_temp = (i_opsel == 3'b001) ? (i_op1 << i_op2) :
                  (i_opsel == 3'b010 || i_opsel == 3'b011) ? {31'b0, (i_unsigned ? (i_op1 < i_op2) : ($signed(i_op1) < $signed(i_op2)))} :
                  (i_opsel == 3'b100) ? (i_op1 ^ i_op2) :
                  (i_opsel == 3'b101) ? (i_arith ? $unsigned($signed(i_op1) >>> i_op2[4:0]) : (i_op1 >> i_op2[4:0])) :
                  (i_opsel == 3'b110) ? (i_op1 | i_op2) :
                  (i_opsel == 3'b111) ? (i_op1 & i_op2) :
                  i_sub ? (i_op1 - i_op2) : (i_op1 + i_op2);
end
	
endmodule

`default_nettype wire