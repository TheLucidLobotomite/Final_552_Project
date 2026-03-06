`timescale 1ns / 1ps

module hart_tb;

    reg         clk;
    reg         rst;
    wire [31:0] imem_raddr;
    reg  [31:0] imem_rdata;
    wire [31:0] dmem_addr;
    wire        dmem_ren;
    wire        dmem_wen;
    wire [31:0] dmem_wdata;
    wire [ 3:0] dmem_mask;
    reg  [31:0] dmem_rdata;
    wire        retire_valid;
    wire [31:0] retire_inst;
    wire        retire_trap;
    wire        retire_halt;
    wire [ 4:0] retire_rs1_raddr;
    wire [ 4:0] retire_rs2_raddr;
    wire [31:0] retire_rs1_rdata;
    wire [31:0] retire_rs2_rdata;
    wire [ 4:0] retire_rd_waddr;
    wire [31:0] retire_rd_wdata;
    wire [31:0] retire_pc;
    wire [31:0] retire_next_pc;
    wire [31:0] retire_dmem_addr;
    wire        retire_dmem_ren;
    wire        retire_dmem_wen;
    wire [ 3:0] retire_dmem_mask;
    wire [31:0] retire_dmem_wdata;
    wire [31:0] retire_dmem_rdata;

    hart uut (
        .i_clk               (clk),
        .i_rst               (rst),
        .o_imem_raddr        (imem_raddr),
        .i_imem_rdata        (imem_rdata),
        .o_dmem_addr         (dmem_addr),
        .o_dmem_ren          (dmem_ren),
        .o_dmem_wen          (dmem_wen),
        .o_dmem_wdata        (dmem_wdata),
        .o_dmem_mask         (dmem_mask),
        .i_dmem_rdata        (dmem_rdata),
        .o_retire_valid      (retire_valid),
        .o_retire_inst       (retire_inst),
        .o_retire_trap       (retire_trap),
        .o_retire_halt       (retire_halt),
        .o_retire_rs1_raddr  (retire_rs1_raddr),
        .o_retire_rs2_raddr  (retire_rs2_raddr),
        .o_retire_rs1_rdata  (retire_rs1_rdata),
        .o_retire_rs2_rdata  (retire_rs2_rdata),
        .o_retire_rd_waddr   (retire_rd_waddr),
        .o_retire_rd_wdata   (retire_rd_wdata),
        .o_retire_pc         (retire_pc),
        .o_retire_next_pc    (retire_next_pc),
        .o_retire_dmem_addr  (retire_dmem_addr),
        .o_retire_dmem_ren   (retire_dmem_ren),
        .o_retire_dmem_wen   (retire_dmem_wen),
        .o_retire_dmem_mask  (retire_dmem_mask),
        .o_retire_dmem_wdata (retire_dmem_wdata),
        .o_retire_dmem_rdata (retire_dmem_rdata)
    );

    always #5 clk = ~clk;

    initial begin
        clk       = 0;
        rst       = 1;
        imem_rdata = 32'h00000013; // no clue what this is
        dmem_rdata = 32'h00000000;
        #20;
        rst = 0;
        #100;
        $display("Yahoo, this shit compiles");
        $finish;
    end

endmodule