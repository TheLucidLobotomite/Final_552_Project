module MEMtoW(
    input wire clk,
    input wire rst,
    input wire [1:0] rd_dest_select,
    input wire [31:0] i_alu_result,
    input wire [31:0]o_immediate,
    input wire [31:0] pc_plus_4,
    input wire [31:0] i_dmem_rdata,
    output reg [31:0] o_alu_result_pipeline,
    output reg [31:0] o_immediate_pipeline,
    output reg [31:0] o_pc_plus_4_pipeline,
    output reg [31:0] o_dmem_rdata_pipeline
    output reg [1:0] o_rd_dest_select_pipeline
);

always @(posedge clk) begin
    if (rst) begin
        o_alu_result_pipeline <= 32'b0;
        o_immediate_pipeline <= 32'b0;
        o_pc_plus_4_pipeline <= 32'b0;
        o_dmem_rdata_pipeline <= 32'b0;
        o_rd_dest_select_pipeline <= 2'b00;
    end else begin
        o_alu_result_pipeline <= i_alu_result;
        o_immediate_pipeline <= o_immediate;
        o_pc_plus_4_pipeline <= pc_plus_4;
        o_dmem_rdata_pipeline <= i_dmem_rdata;
        o_rd_dest_select_pipeline <= rd_dest_select;
    end
end



endmodule