module decode #(
        parameter BYPASS_EN = 0
) (
    input wire clk,
    input wire rst,
    input wire [31:0] i_imem_rdata,
    input wire [31:0] writeback_mux_out,
    output reg [31:0] o_rs1_data_in,
    output reg [31:0] o_rs2_data_in,
    output reg [31:0] o_immediate,
    output reg jump,
    output reg jalr,
    output reg branch,
    output reg [2:0] branch_type,
    output reg [1:0] rd_dest_select,
    output reg [2:0] store_sel,
    output reg [2:0] load_sel,
    output reg o_dmem_ren,
    output reg o_dmem_wen,
    output reg [2:0] i_opsel,
    output reg i_arith,
    output reg i_unsigned,
    output reg i_sub,
    output reg auipc,
    output reg i_alu_src,
    output reg i_rd_wen,
    output reg [5:0] i_format
);
  
    // Instantiate the imm module
    imm imm_inst (
        .i_inst(i_imem_rdata),
        .o_immediate(o_immediate),
        .i_format(i_format)
    );

    // Instantiate the control module
    control control_inst (
        .i_imem_rdata(i_imem_rdata),
        .jump(jump),
        .jalr(jalr),
        .branch(branch),
        .branch_type(branch_type),
        .rd_dest_select(rd_dest_select),
        .store_sel(store_sel),
        .load_sel(load_sel),
        .o_dmem_ren(o_dmem_ren),
        .o_dmem_wen(o_dmem_wen),
        .i_opsel(i_opsel),
        .i_arith(i_arith),
        .i_unsigned(i_unsigned),
        .i_sub(i_sub),
        .auipc(auipc),
        .i_alu_src(i_alu_src),
        .i_rd_wen(i_rd_wen),
        .i_format(i_format)
    );

    // Instantiate the register file
    regfile regfile_inst (
        .clk(clk),
        .rst(rst),
        .i_rs1_addr(i_imem_rdata[19:15]),
        .i_rs2_addr(i_imem_rdata[24:20]),
        .i_rd_addr(i_imem_rdata[11:7]),
        .i_rd_data(writeback_mux_out),
        .i_rd_wen(i_rd_wen),
        .o_rs1_data(o_rs1_data_in),
        .o_rs2_data(o_rs2_data_in)
    );

endmodule