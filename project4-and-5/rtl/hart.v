`timescale 1ns / 1ps
`default_nettype none

module hart #(
    // After reset, the program counter (PC) should be initialized to this
    // address and start executing instructions from there.
    parameter RESET_ADDR = 32'h00000000
) (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // Instruction fetch goes through a read only instruction memory (imem)
    // port. The port accepts a 32-bit address (e.g. from the program counter)
    // per cycle and combinationally returns a 32-bit instruction word. This
    // is not representative of a realistic memory interface; it has been
    // modeled as more similar to a DFF or SRAM to simplify phase 3. In
    // later phases, you will replace this with a more realistic memory.
    //
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Instruction word fetched from memory, available on the same cycle.
    input  wire [31:0] i_imem_rdata,
    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle. Reads are combinational - values are available immediately after
    // updating the address and asserting read enable. Writes occur on (and
    // are visible at) the next clock edge.
    //
    // Read/write address for the data memory. This should be 32-bit aligned
    // (i.e. the two LSB should be zero). See `o_dmem_mask` for how to perform
    // half-word and byte accesses at unaligned addresses.
    output wire [31:0] o_dmem_addr,
    // When asserted, the memory will perform a read at the aligned address
    // specified by `i_addr` and return the 32-bit word at that address
    // immediately (i.e. combinationally). It is illegal to assert this and
    // `o_dmem_wen` on the same cycle.
    output wire        o_dmem_ren,
    // When asserted, the memory will perform a write to the aligned address
    // `o_dmem_addr`. When asserted, the memory will write the bytes in
    // `o_dmem_wdata` (specified by the mask) to memory at the specified
    // address on the next rising clock edge. It is illegal to assert this and
    // `o_dmem_ren` on the same cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    //
    // To perform a half-word read at address 0x00001002, align `o_dmem_addr`
    // to 0x00001000, assert `o_dmem_ren`, and set the mask to 0b1100 to
    // indicate that only the upper two bytes should be read. Only the upper
    // two bytes of `i_dmem_rdata` can be assumed to have valid data; to
    // calculate the final value of the `lh[u]` instruction, shift the rdata
    // word right by 16 bits and sign/zero extend as appropriate.
    //
    // To perform a byte write at address 0x00002003, align `o_dmem_addr` to
    // `0x00002000`, assert `o_dmem_wen`, and set the mask to 0b1000 to
    // indicate that only the upper byte should be written. On the next clock
    // cycle, the upper byte of `o_dmem_wdata` will be written to memory, with
    // the other three bytes of the aligned word unaffected. Remember to shift
    // the value of the `sb` instruction left by 24 bits to place it in the
    // appropriate byte lane.
    output wire [ 3:0] o_dmem_mask,
    // The 32-bit word read from data memory. When `o_dmem_ren` is asserted,
    // this will immediately reflect the contents of memory at the specified
    // address, for the bytes enabled by the mask. When read enable is not
    // asserted, or for bytes not set in the mask, the value is undefined.
    input  wire [31:0] i_dmem_rdata,
	// The output `retire` interface is used to signal to the testbench that
    // the CPU has completed and retired an instruction. A single cycle
    // implementation will assert this every cycle; however, a pipelined
    // implementation that needs to stall (due to internal hazards or waiting
    // on memory accesses) will not assert the signal on cycles where the
    // instruction in the writeback stage is not retiring.
    //
    // Asserted when an instruction is being retired this cycle. If this is
    // not asserted, the other retire signals are ignored and may be left invalid.
    output wire        o_retire_valid,
    // The 32 bit instruction word of the instrution being retired. This
    // should be the unmodified instruction word fetched from instruction
    // memory.
    output wire [31:0] o_retire_inst,
    // Asserted if the instruction produced a trap, due to an illegal
    // instruction, unaligned data memory access, or unaligned instruction
    // address on a taken branch or jump.
    output wire        o_retire_trap,
    // Asserted if the instruction is an `ebreak` instruction used to halt the
    // processor. This is used for debugging and testing purposes to end
    // a program.
    output wire        o_retire_halt,
    // The first register address read by the instruction being retired. If
    // the instruction does not read from a register (like `lui`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs1_raddr,
    // The second register address read by the instruction being retired. If
    // the instruction does not read from a second register (like `addi`), this
    // should be 5'd0.
    output wire [ 4:0] o_retire_rs2_raddr,
    // The first source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs1 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs1_rdata,
    // The second source register data read from the register file (in the
    // decode stage) for the instruction being retired. If rs2 is 5'd0, this
    // should also be 32'd0.
    output wire [31:0] o_retire_rs2_rdata,
    // The destination register address written by the instruction being
    // retired. If the instruction does not write to a register (like `sw`),
    // this should be 5'd0.
    output wire [ 4:0] o_retire_rd_waddr,
    // The destination register data written to the register file in the
    // writeback stage by this instruction. If rd is 5'd0, this field is
    // ignored and can be treated as a don't care.
    output wire [31:0] o_retire_rd_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc,
    output wire [31:0] o_retire_dmem_addr,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire [31:0] o_retire_dmem_wdata,
    output wire [31:0] o_retire_dmem_rdata

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);
    /////////////////////////////////////
    // PC/Instruction Fetch Phase
    /////////////////////////////////////


    wire stall;
    reg  [31:0] pc_reg;
    wire [31:0] pc_next;
    wire [31:0] pc_plus_4 = pc_reg + 32'd4;

    assign o_imem_raddr = pc_reg;

    always @(posedge i_clk) begin
        if (i_rst)
            pc_reg <= RESET_ADDR;
        else if (!stall)
            pc_reg <= pc_next;
        else
            pc_reg <= pc_reg;
    end

    /////////////////////////////////////
    // Fetch-Decode Pipeline
    /////////////////////////////////////
    wire [31:0] if_id_pc_reg_in       = pc_reg;
    wire [31:0] if_id_pc_plus_4_in    = pc_plus_4;
    wire [31:0] if_id_i_imem_rdata_in = i_imem_rdata;

    reg  [31:0] if_id_pc_reg_out;
    reg  [31:0] if_id_pc_plus_4_out;
    reg  [31:0] if_id_i_imem_rdata_out;
    reg if_id_valid_out;

    wire [6:0] if_id_opcode;
    assign if_id_opcode = if_id_i_imem_rdata_out[6:0];

    wire if_id_is_jal;

    assign if_id_is_jal  = (if_id_opcode == 7'b1101111);

    always @(posedge i_clk) begin
        if (i_rst) begin
            if_id_pc_reg_out       <= 32'b0;
            if_id_pc_plus_4_out    <= 32'b0;
            if_id_i_imem_rdata_out <= 32'b0;
            if_id_valid_out        <= 1'b0;
        end else if (if_id_valid_out & if_id_is_jal) begin
            if_id_pc_reg_out       <= 32'b0;
            if_id_pc_plus_4_out    <= 32'b0;
            if_id_i_imem_rdata_out <= 32'b0;
            if_id_valid_out        <= 1'b0;
        end else if (!stall) begin
            if_id_pc_reg_out       <= if_id_pc_reg_in;
            if_id_pc_plus_4_out    <= if_id_pc_plus_4_in;
            if_id_i_imem_rdata_out <= if_id_i_imem_rdata_in;
            if_id_valid_out        <= 1'b1;
        end
    end


    /////////////////////////////////////
    // Decode Phase
    /////////////////////////////////////
    // WB -> decode feedback wires (driven from WB stage)
    wire [ 4:0] wb_rd_waddr;
    wire [31:0] wb_rd_wdata;
    wire        wb_rd_wen;

    wire [31:0] o_rs1_rdata;
    wire [31:0] o_rs2_rdata;
    wire [31:0] o_immediate;
    wire        jump, jalr, branch;
    wire [ 2:0] branch_type;
    wire [ 1:0] rd_dest_select;
    wire [ 2:0] store_sel;
    wire [ 2:0] load_sel;
    wire        dmem_ren, dmem_wen;
    wire [ 2:0] i_opsel;
    wire        i_arith, i_unsigned, i_sub;
    wire        auipc, i_alu_src, i_rd_wen;
    wire [ 5:0] i_format;
    wire [31:0] writeback_mux_out;

    decode #(.BYPASS_EN(1)) iDUT_decode (
        .clk            (i_clk),
        .rst            (i_rst),
        .i_imem_rdata   (if_id_i_imem_rdata_out),
        .i_wb_rd_waddr  (wb_rd_waddr),
        .i_wb_rd_wdata  (wb_rd_wdata),
        .i_wb_rd_wen    (wb_rd_wen),
        .o_rs1_data_in  (o_rs1_rdata),
        .o_rs2_data_in  (o_rs2_rdata),
        .o_immediate    (o_immediate),
        .jump           (jump),
        .jalr           (jalr),
        .branch         (branch),
        .branch_type    (branch_type),
        .rd_dest_select (rd_dest_select),
        .store_sel      (store_sel),
        .load_sel       (load_sel),
        .o_dmem_ren     (dmem_ren),
        .o_dmem_wen     (dmem_wen),
        .i_opsel        (i_opsel),
        .i_arith        (i_arith),
        .i_unsigned     (i_unsigned),
        .i_sub          (i_sub),
        .auipc          (auipc),
        .i_alu_src      (i_alu_src),
        .i_rd_wen       (i_rd_wen),
        .i_format       (i_format)
    );

    /////////////////////////////////////
    // Decode-Execute Pipeline
    /////////////////////////////////////
    wire [31:0] id_ex_pc_reg_in          = if_id_pc_reg_out;
    wire [31:0] id_ex_pc_plus_4_in       = if_id_pc_plus_4_out;
    wire [31:0] id_ex_i_imem_rdata_in    = if_id_i_imem_rdata_out;
    wire [31:0] id_ex_o_rs1_rdata_in     = o_rs1_rdata;
    wire [31:0] id_ex_o_rs2_rdata_in     = o_rs2_rdata;
    wire [31:0] id_ex_o_immediate_in     = o_immediate;
    wire        id_ex_jump_in            = jump;
    wire        id_ex_jalr_in            = jalr;
    wire        id_ex_branch_in          = branch;
    wire [ 2:0] id_ex_branch_type_in     = branch_type;
    wire [ 1:0] id_ex_rd_dest_select_in  = rd_dest_select;
    wire [ 2:0] id_ex_store_sel_in       = store_sel;
    wire [ 2:0] id_ex_load_sel_in        = load_sel;
    wire        id_ex_dmem_ren_in        = dmem_ren;
    wire        id_ex_dmem_wen_in        = dmem_wen;
    wire [ 2:0] id_ex_i_opsel_in         = i_opsel;
    wire        id_ex_i_arith_in         = i_arith;
    wire        id_ex_i_unsigned_in      = i_unsigned;
    wire        id_ex_i_sub_in           = i_sub;
    wire        id_ex_auipc_in           = auipc;
    wire        id_ex_i_alu_src_in       = i_alu_src;
    wire        id_ex_i_rd_wen_in        = i_rd_wen;

    reg  [31:0] id_ex_pc_reg_out;
    reg  [31:0] id_ex_pc_plus_4_out;
    reg  [31:0] id_ex_i_imem_rdata_out;
    reg  [31:0] id_ex_o_rs1_rdata_out;
    reg  [31:0] id_ex_o_rs2_rdata_out;
    reg  [31:0] id_ex_o_immediate_out;
    reg         id_ex_jump_out;
    reg         id_ex_jalr_out;
    reg         id_ex_branch_out;
    reg  [ 2:0] id_ex_branch_type_out;
    reg  [ 1:0] id_ex_rd_dest_select_out;
    reg  [ 2:0] id_ex_store_sel_out;
    reg  [ 2:0] id_ex_load_sel_out;
    reg         id_ex_dmem_ren_out;
    reg         id_ex_dmem_wen_out;
    reg  [ 2:0] id_ex_i_opsel_out;
    reg         id_ex_i_arith_out;
    reg         id_ex_i_unsigned_out;
    reg         id_ex_i_sub_out;
    reg         id_ex_auipc_out;
    reg         id_ex_i_alu_src_out;
    reg         id_ex_i_rd_wen_out;
    reg         id_ex_valid_out;

    always @(posedge i_clk) begin
        if (i_rst | stall) begin
            id_ex_pc_reg_out          <= 32'b0;
            id_ex_pc_plus_4_out       <= 32'b0;
            id_ex_i_imem_rdata_out    <= 32'b0;
            id_ex_o_rs1_rdata_out     <= 32'b0;
            id_ex_o_rs2_rdata_out     <= 32'b0;
            id_ex_o_immediate_out     <= 32'b0;
            id_ex_jump_out            <= 1'b0;
            id_ex_jalr_out            <= 1'b0;
            id_ex_branch_out          <= 1'b0;
            id_ex_branch_type_out     <= 3'b0;
            id_ex_rd_dest_select_out  <= 2'b0;
            id_ex_store_sel_out       <= 3'b0;
            id_ex_load_sel_out        <= 3'b0;
            id_ex_dmem_ren_out        <= 1'b0;
            id_ex_dmem_wen_out        <= 1'b0;
            id_ex_i_opsel_out         <= 3'b0;
            id_ex_i_arith_out         <= 1'b0;
            id_ex_i_unsigned_out      <= 1'b0;
            id_ex_i_sub_out           <= 1'b0;
            id_ex_auipc_out           <= 1'b0;
            id_ex_i_alu_src_out       <= 1'b0;
            id_ex_i_rd_wen_out        <= 1'b0;
            id_ex_valid_out           <= 1'b0;
        end else begin
            id_ex_pc_reg_out          <= id_ex_pc_reg_in;
            id_ex_pc_plus_4_out       <= id_ex_pc_plus_4_in;
            id_ex_i_imem_rdata_out    <= id_ex_i_imem_rdata_in;
            id_ex_o_rs1_rdata_out     <= id_ex_o_rs1_rdata_in;
            id_ex_o_rs2_rdata_out     <= id_ex_o_rs2_rdata_in;
            id_ex_o_immediate_out     <= id_ex_o_immediate_in;
            id_ex_jump_out            <= id_ex_jump_in;
            id_ex_jalr_out            <= id_ex_jalr_in;
            id_ex_branch_out          <= id_ex_branch_in;
            id_ex_branch_type_out     <= id_ex_branch_type_in;
            id_ex_rd_dest_select_out  <= id_ex_rd_dest_select_in;
            id_ex_store_sel_out       <= id_ex_store_sel_in;
            id_ex_load_sel_out        <= id_ex_load_sel_in;
            id_ex_dmem_ren_out        <= id_ex_dmem_ren_in;
            id_ex_dmem_wen_out        <= id_ex_dmem_wen_in;
            id_ex_i_opsel_out         <= id_ex_i_opsel_in;
            id_ex_i_arith_out         <= id_ex_i_arith_in;
            id_ex_i_unsigned_out      <= id_ex_i_unsigned_in;
            id_ex_i_sub_out           <= id_ex_i_sub_in;
            id_ex_auipc_out           <= id_ex_auipc_in;
            id_ex_i_alu_src_out       <= id_ex_i_alu_src_in;
            id_ex_i_rd_wen_out        <= id_ex_i_rd_wen_in;
            id_ex_valid_out           <= if_id_valid_out;
        end
    end

    /////////////////////////////////////
    // Execute Phase
    /////////////////////////////////////
    wire [31:0] o_result;
    wire [31:0] execute_pc_next;
    execute_phase iDUT_execute (
        .pc_in          (id_ex_pc_reg_out),
        .o_rs1_rdata_in (id_ex_o_rs1_rdata_out),
        .o_rs2_rdata_in (id_ex_o_rs2_rdata_out),
        .o_immediate    (id_ex_o_immediate_out),
        .jump           (id_ex_jump_out),
        .jalr           (id_ex_jalr_out),
        .branch         (id_ex_branch_out),
        .branch_type    (id_ex_branch_type_out),
        .i_opsel        (id_ex_i_opsel_out),
        .i_sub          (id_ex_i_sub_out),
        .i_unsigned     (id_ex_i_unsigned_out),
        .i_arith        (id_ex_i_arith_out),
        .auipc          (id_ex_auipc_out),
        .i_alu_src      (id_ex_i_alu_src_out),
        .pc_out         (execute_pc_next),
        .o_result       (o_result)
    );
assign pc_next = if_id_is_jal
                 ? (if_id_pc_reg_out + o_immediate)
                 : ((id_ex_valid_out & id_ex_jalr_out)
                    ? execute_pc_next
                    : pc_plus_4);

    /////////////////////////////////////
    // Execute-Memory Pipeline
    /////////////////////////////////////
    wire [31:0] ex_mem_pc_plus_4_in      = id_ex_pc_plus_4_out;
    wire [31:0] ex_mem_pc_next_in        = execute_pc_next;
    wire [31:0] ex_mem_i_imem_rdata_in   = id_ex_i_imem_rdata_out;
    wire [31:0] ex_mem_o_result_in       = o_result;
    wire [31:0] ex_mem_o_rs1_rdata_in    = id_ex_o_rs1_rdata_out;
    wire [31:0] ex_mem_o_rs2_rdata_in    = id_ex_o_rs2_rdata_out;
    wire [31:0] ex_mem_o_immediate_in    = id_ex_o_immediate_out;
    wire [ 1:0] ex_mem_rd_dest_select_in = id_ex_rd_dest_select_out;
    wire [ 2:0] ex_mem_store_sel_in      = id_ex_store_sel_out;
    wire [ 2:0] ex_mem_load_sel_in       = id_ex_load_sel_out;
    wire        ex_mem_dmem_ren_in       = id_ex_dmem_ren_out;
    wire        ex_mem_dmem_wen_in       = id_ex_dmem_wen_out;
    wire        ex_mem_i_rd_wen_in       = id_ex_i_rd_wen_out;
    wire        ex_mem_valid_in          = id_ex_valid_out;

    reg  [31:0] ex_mem_pc_plus_4_out;
    reg  [31:0] ex_mem_pc_next_out;
    reg  [31:0] ex_mem_i_imem_rdata_out;
    reg  [31:0] ex_mem_o_result_out;
    reg  [31:0] ex_mem_o_rs1_rdata_out;
    reg  [31:0] ex_mem_o_rs2_rdata_out;
    reg  [31:0] ex_mem_o_immediate_out;
    reg  [ 1:0] ex_mem_rd_dest_select_out;
    reg  [ 2:0] ex_mem_store_sel_out;
    reg  [ 2:0] ex_mem_load_sel_out;
    reg         ex_mem_dmem_ren_out;
    reg         ex_mem_dmem_wen_out;
    reg         ex_mem_i_rd_wen_out;
    reg         ex_mem_valid_out;

    always @(posedge i_clk) begin
        if (i_rst) begin
            ex_mem_pc_plus_4_out      <= 32'b0;
            ex_mem_pc_next_out        <= 32'b0;
            ex_mem_i_imem_rdata_out   <= 32'b0;
            ex_mem_o_result_out       <= 32'b0;
            ex_mem_o_rs1_rdata_out    <= 32'b0;
            ex_mem_o_rs2_rdata_out    <= 32'b0;
            ex_mem_o_immediate_out    <= 32'b0;
            ex_mem_rd_dest_select_out <= 2'b0;
            ex_mem_store_sel_out      <= 3'b0;
            ex_mem_load_sel_out       <= 3'b0;
            ex_mem_dmem_ren_out       <= 1'b0;
            ex_mem_dmem_wen_out       <= 1'b0;
            ex_mem_i_rd_wen_out       <= 1'b0;
            ex_mem_valid_out          <= 1'b0;
        end else begin
            ex_mem_pc_plus_4_out      <= ex_mem_pc_plus_4_in;
            ex_mem_pc_next_out        <= ex_mem_pc_next_in;
            ex_mem_i_imem_rdata_out   <= ex_mem_i_imem_rdata_in;
            ex_mem_o_result_out       <= ex_mem_o_result_in;
            ex_mem_o_rs1_rdata_out    <= ex_mem_o_rs1_rdata_in;
            ex_mem_o_rs2_rdata_out    <= ex_mem_o_rs2_rdata_in;
            ex_mem_o_immediate_out    <= ex_mem_o_immediate_in;
            ex_mem_rd_dest_select_out <= ex_mem_rd_dest_select_in;
            ex_mem_store_sel_out      <= ex_mem_store_sel_in;
            ex_mem_load_sel_out       <= ex_mem_load_sel_in;
            ex_mem_dmem_ren_out       <= ex_mem_dmem_ren_in;
            ex_mem_dmem_wen_out       <= ex_mem_dmem_wen_in;
            ex_mem_i_rd_wen_out       <= ex_mem_i_rd_wen_in;
            ex_mem_valid_out          <= ex_mem_valid_in;
        end
    end

    /////////////////////////////////////
    // Memory Phase
    /////////////////////////////////////
    wire [31:0] load_mux_out;

    memory_phase iDUT_memory (
        .alu_result   (ex_mem_o_result_out),
        .load_sel     (ex_mem_load_sel_out),
        .store_sel    (ex_mem_store_sel_out),
        .dmem_ren     (ex_mem_dmem_ren_out),
        .dmem_wen     (ex_mem_dmem_wen_out),
        .o_rs2_rdata  (ex_mem_o_rs2_rdata_out),
        .i_dmem_rdata (i_dmem_rdata),
        .o_dmem_addr  (o_dmem_addr),
        .o_dmem_ren   (o_dmem_ren),
        .o_dmem_wen   (o_dmem_wen),
        .o_dmem_wdata (o_dmem_wdata),
        .o_dmem_mask  (o_dmem_mask),
        .load_mux_out (load_mux_out)
    );

    /////////////////////////////////////
    // Memory-Execute Pipeline
    /////////////////////////////////////
    wire [31:0] mem_wb_pc_plus_4_in      = ex_mem_pc_plus_4_out;
    wire [31:0] mem_wb_pc_next_in        = ex_mem_pc_next_out;
    wire [31:0] mem_wb_i_imem_rdata_in   = ex_mem_i_imem_rdata_out;
    wire [31:0] mem_wb_o_result_in       = ex_mem_o_result_out;
    wire [31:0] mem_wb_load_mux_out_in   = load_mux_out;
    wire [31:0] mem_wb_dmem_addr_in  = o_dmem_addr;
    wire        mem_wb_dmem_ren_in   = o_dmem_ren;
    wire        mem_wb_dmem_wen_in   = o_dmem_wen;
    wire [ 3:0] mem_wb_dmem_mask_in  = o_dmem_mask;
    wire [31:0] mem_wb_dmem_wdata_in = o_dmem_wdata;
    wire [31:0] mem_wb_dmem_rdata_in = i_dmem_rdata;
    wire [31:0] mem_wb_o_immediate_in    = ex_mem_o_immediate_out;
    wire [31:0] mem_wb_o_rs1_rdata_in    = ex_mem_o_rs1_rdata_out;
    wire [31:0] mem_wb_o_rs2_rdata_in    = ex_mem_o_rs2_rdata_out;
    wire [ 1:0] mem_wb_rd_dest_select_in = ex_mem_rd_dest_select_out;
    wire        mem_wb_i_rd_wen_in       = ex_mem_i_rd_wen_out;
    wire        mem_wb_valid_in          = ex_mem_valid_out;

    reg  [31:0] mem_wb_pc_plus_4_out;
    reg  [31:0] mem_wb_pc_next_out;
    reg  [31:0] mem_wb_i_imem_rdata_out;
    reg  [31:0] mem_wb_o_result_out;
    reg  [31:0] mem_wb_load_mux_out_out;
    reg  [31:0] mem_wb_o_immediate_out;
    reg  [31:0] mem_wb_o_rs1_rdata_out;
    reg  [31:0] mem_wb_o_rs2_rdata_out;
    reg  [ 1:0] mem_wb_rd_dest_select_out;
    reg         mem_wb_i_rd_wen_out;
    reg         mem_wb_valid_out;
    reg [31:0] mem_wb_dmem_addr_out;
    reg        mem_wb_dmem_ren_out;
    reg        mem_wb_dmem_wen_out;
    reg [ 3:0] mem_wb_dmem_mask_out;
    reg [31:0] mem_wb_dmem_wdata_out;
    reg [31:0] mem_wb_dmem_rdata_out;

    always @(posedge i_clk) begin
        if (i_rst) begin
            mem_wb_pc_plus_4_out      <= 32'b0;
            mem_wb_pc_next_out        <= 32'b0;
            mem_wb_i_imem_rdata_out   <= 32'b0;
            mem_wb_o_result_out       <= 32'b0;
            mem_wb_load_mux_out_out   <= 32'b0;
            mem_wb_o_immediate_out    <= 32'b0;
            mem_wb_o_rs1_rdata_out    <= 32'b0;
            mem_wb_o_rs2_rdata_out    <= 32'b0;
            mem_wb_rd_dest_select_out <= 2'b0;
            mem_wb_i_rd_wen_out       <= 1'b0;
            mem_wb_valid_out          <= 1'b0;
            mem_wb_dmem_addr_out      <= 32'b0;
            mem_wb_dmem_ren_out       <= 1'b0;
            mem_wb_dmem_wen_out       <= 1'b0;
            mem_wb_dmem_mask_out      <= 4'b0;
            mem_wb_dmem_wdata_out     <= 32'b0;
            mem_wb_dmem_rdata_out     <= 32'b0;
        end else begin
            mem_wb_pc_plus_4_out      <= mem_wb_pc_plus_4_in;
            mem_wb_pc_next_out        <= mem_wb_pc_next_in;
            mem_wb_i_imem_rdata_out   <= mem_wb_i_imem_rdata_in;
            mem_wb_o_result_out       <= mem_wb_o_result_in;
            mem_wb_load_mux_out_out   <= mem_wb_load_mux_out_in;
            mem_wb_o_immediate_out    <= mem_wb_o_immediate_in;
            mem_wb_o_rs1_rdata_out    <= mem_wb_o_rs1_rdata_in;
            mem_wb_o_rs2_rdata_out    <= mem_wb_o_rs2_rdata_in;
            mem_wb_rd_dest_select_out <= mem_wb_rd_dest_select_in;
            mem_wb_i_rd_wen_out       <= mem_wb_i_rd_wen_in;
            mem_wb_valid_out          <= mem_wb_valid_in;
            mem_wb_dmem_addr_out      <= mem_wb_dmem_addr_in;
            mem_wb_dmem_ren_out       <= mem_wb_dmem_ren_in;
            mem_wb_dmem_wen_out       <= mem_wb_dmem_wen_in;
            mem_wb_dmem_mask_out      <= mem_wb_dmem_mask_in;
            mem_wb_dmem_wdata_out     <= mem_wb_dmem_wdata_in;
            mem_wb_dmem_rdata_out     <= mem_wb_dmem_rdata_in;
        end
    end

    /////////////////////////////////////
    // Writeback Phase
    /////////////////////////////////////
    writeback_phase iDUT_writeback (
        .rd_dest_select    (mem_wb_rd_dest_select_out),
        .alu_result        (mem_wb_o_result_out),
        .pc_plus_4         (mem_wb_pc_plus_4_out),
        .o_immediate       (mem_wb_o_immediate_out),
        .load_mux_out      (mem_wb_load_mux_out_out),
        .writeback_mux_out (writeback_mux_out)
    );

    // WB -> Decode register file write port feedback
    assign wb_rd_waddr = mem_wb_i_imem_rdata_out[11:7];
    assign wb_rd_wdata = writeback_mux_out;
    assign wb_rd_wen   = mem_wb_i_rd_wen_out;

        assign o_retire_dmem_addr  = mem_wb_dmem_addr_out;
    assign o_retire_dmem_ren   = mem_wb_dmem_ren_out;
    assign o_retire_dmem_wen   = mem_wb_dmem_wen_out;
    assign o_retire_dmem_mask  = mem_wb_dmem_mask_out;
    assign o_retire_dmem_wdata = mem_wb_dmem_wdata_out;
    assign o_retire_dmem_rdata = mem_wb_dmem_rdata_out;


    ////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////
    // POST PIPELINE LOGIC THAT NEEDS ALL SIGNALS DEFINED ALREADY
    ////////////////////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////////////////////

    /////////////////////////////////////
    // Hazard Detection
    /////////////////////////////////////
    // 
    wire [6:0] id_opcode = if_id_i_imem_rdata_out[6:0];
wire [4:0] id_rs1    = if_id_i_imem_rdata_out[19:15];
wire [4:0] id_rs2    = if_id_i_imem_rdata_out[24:20];
wire [4:0] ex_rd     = id_ex_i_imem_rdata_out[11:7];

wire id_uses_rs1;
wire id_uses_rs2;

assign id_uses_rs1 =
    (id_opcode == 7'b0110011) |   // R-type
    (id_opcode == 7'b0010011) |   // I-type ALU
    (id_opcode == 7'b0000011) |   // loads
    (id_opcode == 7'b0100011) |   // stores
    (id_opcode == 7'b1100011) |   // branches
    (id_opcode == 7'b1100111);    // jalr

assign id_uses_rs2 =
    (id_opcode == 7'b0110011) |   // R-type
    (id_opcode == 7'b0100011) |   // stores
    (id_opcode == 7'b1100011);    // branches

wire ex_rd_match;
assign ex_rd_match =
    id_ex_i_rd_wen_out &
    (ex_rd != 5'd0) &
    (
        (id_uses_rs1 & (ex_rd == id_rs1)) |
        (id_uses_rs2 & (ex_rd == id_rs2))
    );
    wire mem_rd_match = ex_mem_i_rd_wen_out && (ex_mem_i_imem_rdata_out[11:7] != 5'd0) &&
                        ((ex_mem_i_imem_rdata_out[11:7] == id_rs1) || (ex_mem_i_imem_rdata_out[11:7] == id_rs2));

    assign stall = ex_rd_match | mem_rd_match;

        /////////////////////////////////////
    // Hazard Detection
    /////////////////////////////////////
    // wire [6:0] id_opcode = if_id_i_imem_rdata_out[6:0];
    // wire [4:0] id_rs1    = if_id_i_imem_rdata_out[19:15];
    // wire [4:0] id_rs2    = if_id_i_imem_rdata_out[24:20];

    // wire [4:0] ex_rd     = id_ex_i_imem_rdata_out[11:7];
    // wire [4:0] mem_rd    = ex_mem_i_imem_rdata_out[11:7];

    // wire id_uses_rs1 = (id_opcode != 7'b0110111) &   // lui
    //                    (id_opcode != 7'b0010111);    // auipc

    // wire id_uses_rs2 = (id_opcode == 7'b0110011) |   // R-type
    //                    (id_opcode == 7'b0100011);    // store

    // wire ex_rd_match  = id_ex_i_rd_wen_out  & (ex_rd  != 5'd0) &
    //                     ((id_uses_rs1 & (ex_rd  == id_rs1)) |
    //                      (id_uses_rs2 & (ex_rd  == id_rs2)));

    // wire mem_rd_match = ex_mem_i_rd_wen_out & (mem_rd != 5'd0) &
    //                     ((id_uses_rs1 & (mem_rd == id_rs1)) |
    //                      (id_uses_rs2 & (mem_rd == id_rs2)));

    // assign stall = ex_rd_match | mem_rd_match;

    /////////////////////////////////////
    // Retire Interface - hart comments
    /////////////////////////////////////
    assign o_retire_valid     = ~i_rst & mem_wb_valid_out;
    assign o_retire_inst      = mem_wb_i_imem_rdata_out;
    assign o_retire_pc        = mem_wb_pc_plus_4_out - 32'd4;
    assign o_retire_next_pc   = mem_wb_pc_next_out;

    assign o_retire_rs1_raddr = mem_wb_i_imem_rdata_out[19:15];
    assign o_retire_rs2_raddr = mem_wb_i_imem_rdata_out[24:20];
    assign o_retire_rd_waddr  = mem_wb_i_rd_wen_out ? mem_wb_i_imem_rdata_out[11:7] : 5'd0;

    assign o_retire_rs1_rdata = mem_wb_o_rs1_rdata_out;
    assign o_retire_rs2_rdata = mem_wb_o_rs2_rdata_out;
    assign o_retire_rd_wdata  = writeback_mux_out;

    // DO NOT FORGOR THIS
    assign o_retire_halt = (mem_wb_i_imem_rdata_out == 32'h00100073);

    // Trap on misaligned instruction fetch target or misaligned data access
    wire misaligned_fetch = (id_ex_jump_out | id_ex_jalr_out | id_ex_branch_out) &
                            (pc_next[1:0] != 2'b00);
    wire misaligned_dmem  = (ex_mem_dmem_wen_out & (ex_mem_store_sel_out == 3'b010) & (ex_mem_o_result_out[1:0] != 2'b00)) |
                            (ex_mem_dmem_wen_out & (ex_mem_store_sel_out == 3'b001) & (ex_mem_o_result_out[0]   != 1'b0 )) |
                            (ex_mem_dmem_ren_out & (ex_mem_load_sel_out  == 3'b010) & (ex_mem_o_result_out[1:0] != 2'b00)) |
                            (ex_mem_dmem_ren_out & (ex_mem_load_sel_out  == 3'b001) & (ex_mem_o_result_out[0]   != 1'b0 ));
    assign o_retire_trap  = misaligned_fetch | misaligned_dmem;

endmodule

`default_nettype wire