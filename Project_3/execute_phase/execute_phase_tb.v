`timescale 1ns/1ps

module execute_phase_tb;

    // Inputs
    reg [31:0] pc_in;
    reg [31:0] o_rs1_rdata_in, o_rs2_rdata_in;
    reg [31:0] o_immediate;
    reg jump, jalr, branch;
    reg [2:0] branch_type;
    reg [2:0] i_opsel;
    reg i_sub, i_unsigned, i_arith, auipc, i_alu_src;

    // Outputs
    wire [31:0] pc_out;
    wire [31:0] o_result;
    wire [31:0] o_rs2_rdata_out;

    integer failed = 0;

    execute_phase uut (
        .pc_in(pc_in), .o_rs1_rdata_in(o_rs1_rdata_in),
        .o_rs2_rdata_in(o_rs2_rdata_in), .o_immediate(o_immediate),
        .jump(jump), .jalr(jalr), .branch(branch),
        .branch_type(branch_type), .i_opsel(i_opsel),
        .i_sub(i_sub), .i_unsigned(i_unsigned), .i_arith(i_arith),
        .auipc(auipc), .i_alu_src(i_alu_src),
        .pc_out(pc_out), .o_result(o_result),
        .o_rs2_rdata_out(o_rs2_rdata_out)
    );

    task check;
        input [31:0] got;
        input [31:0] expected;
        input [127:0] name;
        begin
            if (got !== expected) begin
                $display("FAIL [%s]: got=%h expected=%h", name, got, expected);
                failed = failed + 1;
            end
        end
    endtask

    initial begin
        // Default everything off
        jump=0; jalr=0; branch=0; branch_type=0;
        i_opsel=0; i_sub=0; i_unsigned=0; i_arith=0; auipc=0; i_alu_src=0;
        pc_in=0; o_rs1_rdata_in=0; o_rs2_rdata_in=0; o_immediate=0;
        #10;

        // R-TYPE: ADD, 10 + 20 = 30
        o_rs1_rdata_in=32'd10; o_rs2_rdata_in=32'd20;
        i_opsel=3'b000; i_sub=0; i_alu_src=0; pc_in=32'h1000;
        #10;
        check(o_result, 32'd30, "R-TYPE ADD");

        // I-TYPE: ADDI, 10 + 15 = 25
        o_rs1_rdata_in=32'd10; o_immediate=32'd15;
        i_opsel=3'b000; i_sub=0; i_alu_src=1;
        #10;
        check(o_result, 32'd25, "I-TYPE ADDI");

        // BRANCH: BEQ taken, PC + imm = 0x1000 + 0x10 = 0x1010
        o_rs1_rdata_in=32'd5; o_rs2_rdata_in=32'd5;
        o_immediate=32'h10; branch=1; branch_type=3'b000;
        i_opsel=3'b000; i_sub=1; i_alu_src=0; pc_in=32'h1000;
        #10;
        check(pc_out, 32'h1010, "BRANCH BEQ taken");
        branch=0;

        // JAL: PC + imm = 0x1000 + 0x20 = 0x1020
        pc_in=32'h1000; o_immediate=32'h20;
        jump=1; jalr=0; i_alu_src=1;
        #10;
        check(pc_out, 32'h1020, "JAL");
        jump=0;

        // JALR: (rs1 + imm) & ~1 = (0x1000 + 0x11) & ~1 = 0x1010
        o_rs1_rdata_in=32'h1000; o_immediate=32'h11;
        i_opsel=3'b000; i_sub=0; i_alu_src=1; jalr=1; auipc=0;
        #10;
        check(pc_out, 32'h1010, "JALR");
        jalr=0;

        // AUIPC: PC + imm = 0x1000 + 0x2000 = 0x3000
        pc_in=32'h1000; o_immediate=32'h2000;
        i_opsel=3'b000; i_sub=0; i_alu_src=1; auipc=1;
        #10;
        check(o_result, 32'h3000, "AUIPC");
        auipc=0;

        // Result
        if (failed == 0)
            $display("Yahoo!!! All tests pass.");
        else
            $display("%0d test(s) failed.", failed);

        $finish;
    end

endmodule