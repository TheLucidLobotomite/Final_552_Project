`timescale 1ns / 1ps
`default_nettype none

module decode #(
        parameter BYPASS_EN = 0
) (
    input wire clk,
    input wire rst,
    input wire [31:0] i_imem_rdata,
    
    // Writeback port - driven from WB stage in hart.v
    input wire [ 4:0] i_wb_rd_waddr,
    input wire [31:0] i_wb_rd_wdata,
    input wire        i_wb_rd_wen,
    output wire [31:0] o_rs1_data_in,
    output wire [31:0] o_rs2_data_in,
    output wire [31:0] o_immediate,
    output wire jump,
    output wire jalr,
    output wire branch,
    output wire [2:0] branch_type,
    output wire [1:0] rd_dest_select,
    output wire [2:0] store_sel,
    output wire [2:0] load_sel,
    output wire o_dmem_ren,
    output wire o_dmem_wen,
    output wire [2:0] i_opsel,
    output wire i_arith,
    output wire i_unsigned,
    output wire i_sub,
    output wire auipc,
    output wire i_alu_src,
    output wire i_rd_wen,
    output wire [5:0] i_format
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
    // Read addresses come from the current decode-stage instruction.
    // Write port is driven from the writeback stage via hart.v.
    rf #(.BYPASS_EN(BYPASS_EN)) regfile_inst (
        .i_clk      (clk),
        .i_rst      (rst),
        .i_rs1_raddr(i_imem_rdata[19:15]),
        .i_rs2_raddr(i_imem_rdata[24:20]),
        .i_rd_waddr (i_wb_rd_waddr),
        .i_rd_wdata (i_wb_rd_wdata),
        .i_rd_wen   (i_wb_rd_wen),
        .o_rs1_rdata(o_rs1_data_in),
        .o_rs2_rdata(o_rs2_data_in)
    );

endmodule