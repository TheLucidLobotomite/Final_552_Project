module memory_muxes(
    input wire [31:0] pc_or_offset ,
    input wire branch,
    input wire comparison_result,
    input wire [31:0] o_immediate,
    output wire [31:0] branch_target_or_pc,
);

reg and_result;
assign pc_or_offset = pc_or_offset+4;
and(and_result, branch, comparison_result);
assign branch_target_or_pc = and_result ? o_immediate : pc_or_offset;

    
endmodule