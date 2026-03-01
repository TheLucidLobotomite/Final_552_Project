module IDtoEX (
    input wire clk,
    input wire rst,
    input wire [31:0] i_pc_plus_4,
    input wire jalr,
    input wire jump,
    input wire branch,
    input wire [2:0] branch_type,
    input wire [1:0] rd_dest_select,
    input wire [2:0] store_sel,
    input wire [2:0] load_sel,
    input wire o_dmem_ren,
    input wire o_dmem_wen,
    input wire [2:0] i_opsel,
    input wire i_arith,
    input wire i_unsigned,
    input wire i_sub,
    input wire auipc,
    input wire i_alu_src,
    input wire [31:0] o_immediate,
    input wire [31:0] o_rs1_data,
    input wire [31:0] o_rs2_data,
    output reg [31:0] o_pc_plus_4_pipeline,
    output reg jalr_pipeline,
    output reg jump_pipeline,
    output reg branch_pipeline,
    output reg [2:0] branch_type_pipeline,
    output reg [1:0] rd_dest_select_pipeline,
    output reg [2:0] store_sel_pipeline,
    output reg [2:0] load_sel_pipeline,
    output reg o_dmem_ren_pipeline,
    output reg o_dmem_wen_pipeline,
    output reg [2:0] i_opsel_pipeline,
    output reg i_arith_pipeline,
    output reg i_unsigned_pipeline,
    output reg i_sub_pipeline,
    output reg auipc_pipeline,
    output reg i_alu_src_pipeline,
    output reg [31:0] o_immediate_pipeline,
    output reg [31:0] o_rs1_data_pipeline,
    output reg [31:0] o_rs2_data_pipeline

);

always @(posedge clk) begin
    if (rst) begin
        o_pc_plus_4_pipeline <= 32'b0;
        jalr_pipeline <= 1'b0;
        jump_pipeline <= 1'b0;
        branch_pipeline <= 1'b0;
        branch_type_pipeline <= 3'b000;
        rd_dest_select_pipeline <= 2'b00;
        store_sel_pipeline <= 3'b000;
        load_sel_pipeline <= 3'b000;
        o_dmem_ren_pipeline <= 1'b0;
        o_dmem_wen_pipeline <= 1'b0;
        i_opsel_pipeline <= 3'b000;
        i_arith_pipeline <= 1'b0;
        i_unsigned_pipeline <= 1'b0;
        i_sub_pipeline <= 1'b0;
        auipc_pipeline <= 1'b0;
        i_alu_src_pipeline <= 1'b0;
        o_immediate_pipeline <= 32'b0;
        o_rs1_data_pipeline <= 32'b0;
        o_rs2_data_pipeline <= 32'b0;
    end else begin
        o_pc_plus_4_pipeline <= i_pc_plus_4;
        jalr_pipeline <= jalr;
        jump_pipeline <= jump;
        branch_pipeline <= branch;
        branch_type_pipeline <= branch_type;
        rd_dest_select_pipeline <= rd_dest_select;
        store_sel_pipeline <= store_sel;
        load_sel_pipeline <= load_sel;
        o_dmem_ren_pipeline <= o_dmem_ren;
        o_dmem_wen_pipeline <= o_dmem_wen;
        i_opsel_pipeline <= i_opsel;
        i_arith_pipeline <= i_arith;
        i_unsigned_pipeline <= i_unsigned;
        i_sub_pipeline <= i_sub;
        auipc_pipeline <= auipc;
        i_alu_src_pipeline <= i_alu_src;
        o_immediate_pipeline <= o_immediate;
        o_rs1_data_pipeline <= o_rs1_data;
        o_rs2_data_pipeline <= o_rs2_data;

    end
end

endmodule