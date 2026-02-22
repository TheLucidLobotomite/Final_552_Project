module execute_phase (
    // Inputs
    input wire [31:0] pc_in,
    input wire [31:0] o_rs1_rdata_in, o_rs2_rdata_in,	// From rf.v
    input wire [31:0] o_immediate,                      // From imm.v
    input wire jump,                                    // From control.v
    input wire jalr,
    input wire branch,
    input wire [2:0] branch_type,
    input wire [2:0] i_opsel,
    input wire i_sub,
    input wire i_unsigned,
    input wire i_arith,
    input wire auipc,
    input wire i_alu_src,

    // Outputs
    output wire [31:0]pc_out,
    output wire [31:0]o_result
);
    /////////////////////////////////////
    // The grind starts here gentlemen
    /////////////////////////////////////

    // Intermediate Signals
    wire [31:0]i_op1, i_op2;
    wire op_eq, op_slt, br_condition_met;

    // Pre-alu
	assign i_op1 = auipc ? pc_in : o_rs1_rdata_in;
    assign i_op2 = i_alu_src ? o_immediate : o_rs2_rdata_in;

    // ALU instantiation
    alu u_alu (
        .i_opsel(i_opsel),
        .i_sub(i_sub),
        .i_unsigned(i_unsigned),
        .i_arith(i_arith),
        .i_op1(i_op1),
        .i_op2(i_op2),
        .o_result(o_result),
        .o_eq(op_eq),
        .o_slt(op_slt)
    );



    // PC Logic
    assign br_condition_met =   (branch_type == 3'b000) ? op_eq    :
                                (branch_type == 3'b001) ? ~op_eq   :
                                (branch_type == 3'b100) ? op_slt   :
                                (branch_type == 3'b101) ? ~op_slt  :
                                (branch_type == 3'b110) ? op_slt   :
                                (branch_type == 3'b111) ? ~op_slt  :
                                1'b0;

assign pc_out = jalr                                ? {o_result[31:1], 1'b0} :
                jump | (branch & br_condition_met)  ? (pc_in + o_immediate)  :
                pc_in + 32'd4;

endmodule