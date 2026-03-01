module ExtoMEM(
    input wire clk,
    input wire rst,
    input wire [1:0] rd_dest_select;
    input wire [2:0] store_sel,
    input wire [2:0] load_sel,
    input wire o_dmem_ren,
    input wire o_dmem_wen,
    input wire [31:0] i_alu_result,
    input wire [31:0] o_immediate,
    input wire [31:0] pc_plus_4,
    input wire [31:0] o_rs2_data,
    output reg [1:0] o_rd_dest_select_pipeline,
    output reg [2:0] o_store_sel_pipeline,
    output reg [2:0] o_load_sel_pipeline,
    output reg o_dmem_ren_pipeline,
    output reg o_dmem_wen_pipeline,
    output reg [31:0] o_alu_result_pipeline,
    output reg [31:0] o_immediate_pipeline,
    output reg [31:0] o_pc_plus_4_pipeline,
    output reg [31:0] o_rs2_data_pipeline
    
);

always @(posedge clk) begin
    if (rst) begin
        o_rd_dest_select_pipeline <= 2'b00;
        o_store_sel_pipeline <= 3'b000;
        o_load_sel_pipeline <= 3'b000;
        o_dmem_ren_pipeline <= 1'b0;
        o_dmem_wen_pipeline <= 1'b0;
        o_alu_result_pipeline <= 32'b0;
        o_immediate_pipeline <= 32'b0;
        o_pc_plus_4_pipeline <= 32'b0;
        o_rs2_data_pipeline <= 32'b0;
    end else begin
        o_rd_dest_select_pipeline <= rd_dest_select;
        o_store_sel_pipeline <= store_sel;
        o_load_sel_pipeline <= load_sel;
        o_dmem_ren_pipeline <= o_dmem_ren;
        o_dmem_wen_pipeline <= o_dmem_wen;
        o_alu_result_pipeline <= i_alu_result;
        o_immediate_pipeline <= o_immediate;
        o_pc_plus_4_pipeline <= pc_plus_4;
        o_rs2_data_pipeline <= o_rs2_data;
    end
end

endmodule