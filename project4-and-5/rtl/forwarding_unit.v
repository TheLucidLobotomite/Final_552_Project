// fwd_rsX_sel encoding:
//   2'b00 = use register-file value from decode stage
//   2'b01 = EX->EX forward  (ALU result in EX/MEM pipeline reg)
//   2'b10 = MEM->EX forward (writeback value in MEM/WB pipeline reg)
//
// Priority: EX->EX (exmem) takes precedence over MEM->EX (memwb)
`timescale 1ns / 1ps
`default_nettype none

module forwarding_unit (
    // Source register addresses of the instruction currently in EX
    input  wire [4:0] ex_rs1,
    input  wire [4:0] ex_rs2,

    // EX/MEM pipeline register destination (instruction that just left EX)
    input  wire [4:0] exmem_rd,
    input  wire       exmem_rd_wen,

    // MEM/WB pipeline register destination (instruction that just left MEM)
    input  wire [4:0] memwb_rd,
    input  wire       memwb_rd_wen,

    // Mux selects for the two ALU input forwarding muxes
    output wire [1:0] fwd_rs1_sel,
    output wire [1:0] fwd_rs2_sel
);

    // EX->EX match (higher priority)
    wire exmem_rs1_match = exmem_rd_wen & (exmem_rd != 5'd0) & (exmem_rd == ex_rs1);
    wire exmem_rs2_match = exmem_rd_wen & (exmem_rd != 5'd0) & (exmem_rd == ex_rs2);

    // MEM->EX match (lower priority)
    wire memwb_rs1_match = memwb_rd_wen & (memwb_rd != 5'd0) & (memwb_rd == ex_rs1);
    wire memwb_rs2_match = memwb_rd_wen & (memwb_rd != 5'd0) & (memwb_rd == ex_rs2);

    // EX->EX wins if both match; otherwise MEM->EX; otherwise no forward
    assign fwd_rs1_sel = exmem_rs1_match ? 2'b01 : memwb_rs1_match ? 2'b10 : 2'b00;

    assign fwd_rs2_sel = exmem_rs2_match ? 2'b01 : memwb_rs2_match ? 2'b10 : 2'b00;

endmodule

`default_nettype wire