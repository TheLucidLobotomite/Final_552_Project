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
    // per cycle and sequentially returns a 32-bit instruction word. For
    // projects 6 and 7, this memory has been updated to be more realistic
    // - reads are no longer combinational, and both read and write accesses
    // take multiple cycles to complete.
    //
    // The testbench memory models a fixed, multi cycle memory with partial
    // pipelining. The memory will accept a new request every N cycles by
    // asserting `mem_ready`, and if a request is made, the memory perform
    // the request (read or write) after M cycles, asserting mem_valid to
    // indicate the read data is ready (or the write is complete). Requests
    // are completed in order. The values of N and M are deterministic, but
    // may change between test cases - you must design your CPU to work
    // correctly by looking at `mem_ready` and `mem_valid` rather than
    // hardcoding a latency assumption.
    //
    // Indicates that the memory is ready to accept a new read request.
    input  wire        i_imem_ready,
    // 32-bit read address for the instruction memory. This is expected to be
    // 4 byte aligned - that is, the two LSBs should be zero.
    output wire [31:0] o_imem_raddr,
    // Issue a read request to the memory on this cycle. This should not be
    // asserted if `i_imem_ready` is not asserted.
    output wire        o_imem_ren,
    // Indicates that a valid instruction word is being returned from memory.
    input  wire        i_imem_valid,
    // Instruction word fetched from memory, available sequentially some
    // M cycles after a request (imem_ren) is issued.
    input  wire [31:0] i_imem_rdata,

    // Data memory accesses go through a separate read/write data memory (dmem)
    // that is shared between read (load) and write (stored). The port accepts
    // a 32-bit address, read or write enable, and mask (explained below) each
    // cycle.
    //
    // The timing of the dmem interface is the same as the imem interface. See
    // the documentation above.
    //
    // Indicates that the memory is ready to accept a new read or write request.
    input  wire        i_dmem_ready,
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
    // address. It is illegal to assert this and `o_dmem_ren` on the same
    // cycle.
    output wire        o_dmem_wen,
    // The 32-bit word to write to memory when `o_dmem_wen` is asserted. When
    // write enable is asserted, the byte lanes specified by the mask will be
    // written to the memory word at the aligned address at the next rising
    // clock edge. The other byte lanes of the word will be unaffected.
    output wire [31:0] o_dmem_wdata,
    // The dmem interface expects word (32 bit) aligned addresses. However,
    // the processor supports byte and half-word loads and stores at unaligned
    // and 16-bit aligned addresses, respectively. To support this, the access
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
    // Indicates that a valid data word is being returned from memory.
    input  wire        i_dmem_valid,
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
    output wire [31:0] o_retire_dmem_addr,
    output wire [ 3:0] o_retire_dmem_mask,
    output wire        o_retire_dmem_ren,
    output wire        o_retire_dmem_wen,
    output wire [31:0] o_retire_dmem_rdata,
    output wire [31:0] o_retire_dmem_wdata,
    // The current program counter of the instruction being retired - i.e.
    // the instruction memory address that the instruction was fetched from.
    output wire [31:0] o_retire_pc,
    // the next program counter after the instruction is retired. For most
    // instructions, this is `o_retire_pc + 4`, but must be the branch or jump
    // target for *taken* branches and jumps.
    output wire [31:0] o_retire_next_pc

`ifdef RISCV_FORMAL
    ,`RVFI_OUTPUTS,
`endif
);
    /////////////////////////////////////
    // PC/Instruction Fetch Phase
    /////////////////////////////////////
    wire load_use_hazard;
    //mem_stall used to stall the pipeline when there is memory access that has not yet completed
    //solves the problem of not all memory accessing taking same number of cycles
    wire mem_stall;
    //ex_flush is used to flush the pipeline when there is a branch misprediction or jump
    wire ex_flush;
    //jal_redirect is used to redirect the PC to the correct target when there is a jal instruction
    wire jal_redirect;
    wire flush;

    // Wires to connect icache <-> backing imem
    wire [31:0] icache_mem_addr;
    wire        icache_mem_ren;
    wire        icache_mem_wen;
    wire [31:0] icache_mem_wdata;
    wire [31:0] icache_mem_rdata;
    wire        icache_mem_valid;
    wire        icache_mem_ready;
    wire        icache_busy;
    wire [31:0] icache_res_rdata;

    // Wires to connect dcache <-> backing dmem
    wire [31:0] dcache_mem_addr;
    wire        dcache_mem_ren;
    wire        dcache_mem_wen;
    wire [31:0] dcache_mem_wdata;
    wire [31:0] dcache_mem_rdata;
    wire        dcache_mem_valid;
    wire        dcache_mem_ready;
    wire        dcache_busy;
    wire [31:0] dcache_res_rdata;


    reg  [31:0] pc_reg;
    wire [31:0] pc_next;
    wire [31:0] pc_plus_4 = pc_reg + 32'd4;


  // if_pending is used to track whether there is an outstanding instruction fetch request
    reg if_pending;

    //fronted hold is used to stall the instruction fetch and decode stages when there is a load-use hazard or memory stall
    // Ex. 
    // lw x1, 0(x2)
    // add x3, x1, x4 in this case x1 might not be ready when add is in decode stage, so we need to stall the pipeline until x1 is ready
    wire frontend_hold;

    //extra securr signal to deal with situation when jalr is in execution and and an available fetch slot is there,
    // we don't want to issue a fetch in this case until we know whether jalr is taken or not
    wire control_fetch_hold;
    

    wire fetch_issue;

    reg ex_mem_valid_out;

    wire [31:0] dmem_addr_raw;
    wire        dmem_ren_raw;
    wire        dmem_wen_raw;
    wire [31:0] dmem_wdata_raw;
    wire [ 3:0] dmem_mask_raw;
    wire [31:0] o_imem_addr;


    // Not really a good place, so I will just hook up the instantiations here too
    cache icache (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_req_addr     (pc_reg),
        .i_req_ren      (fetch_issue),
        .i_req_wen      (1'b0),
        .i_req_mask     (4'b1111),
        .i_req_wdata    (32'b0),
        .o_res_rdata    (icache_res_rdata),
        .o_busy         (icache_busy),
        .i_mem_ready    (icache_mem_ready),
        .i_mem_valid    (icache_mem_valid),
        .i_mem_rdata    (icache_mem_rdata),
        .o_mem_addr     (icache_mem_addr),
        .o_mem_ren      (icache_mem_ren),
        .o_mem_wen      (icache_mem_wen),
        .o_mem_wdata    (icache_mem_wdata)
    );

    cache dcache (
        .i_clk          (i_clk),
        .i_rst          (i_rst),
        .i_req_addr     (dmem_addr_raw),
        .i_req_ren      (dmem_ren_raw & ex_mem_valid_out),
        .i_req_wen      (dmem_wen_raw & ex_mem_valid_out),
        .i_req_mask     (dmem_mask_raw),
        .i_req_wdata    (dmem_wdata_raw),
        .o_res_rdata    (dcache_res_rdata),
        .o_busy         (dcache_busy),
        .i_mem_ready    (dcache_mem_ready),
        .i_mem_valid    (dcache_mem_valid),
        .i_mem_rdata    (dcache_mem_rdata),
        .o_mem_addr     (dcache_mem_addr),
        .o_mem_ren      (dcache_mem_ren),
        .o_mem_wen      (dcache_mem_wen),
        .o_mem_wdata    (dcache_mem_wdata)
    );

    // icache <-> external imem port
    assign icache_mem_ready = i_imem_ready;
    assign icache_mem_rdata = i_imem_rdata;
    assign icache_mem_valid = i_imem_valid;
    assign o_imem_addr      = icache_mem_addr;
    assign o_imem_ren       = icache_mem_ren;

    // dcache <-> external dmem port
    assign dcache_mem_ready = i_dmem_ready;
    assign dcache_mem_rdata = i_dmem_rdata;
    assign dcache_mem_valid = i_dmem_valid;
    assign o_dmem_addr      = dcache_mem_addr;
    assign o_dmem_ren       = dcache_mem_ren;
    assign o_dmem_wen       = dcache_mem_wen;
    assign o_dmem_wdata     = dcache_mem_wdata;
    assign o_dmem_mask      = dmem_mask_raw;

  

    //fetch_issue is used to determine when to issue a fetch request,
    //is used to stall a fetch when a fetch is already pending, or to avoid
    // fetching instruction when branch is in execute stage and we don't know yet if it's taken or not
    // cases when fetch_issue should be false:
    // 1. when there is already a fetch pending (if_pending is true)
    // 2. when there is a branch in execute stage and we don't know yet if it's taken or not (control_fetch_hold is true)
    // 3. when there is a load-use hazard (load_use_hazard is true)


    assign frontend_hold = load_use_hazard | mem_stall;

    //flop to determine when to issue a fetch
    always @(posedge i_clk) begin
        if (i_rst) begin
            pc_reg     <= RESET_ADDR;
            if_pending <= 1'b0;
        end else begin
            if (flush) begin
                pc_reg     <= pc_next;
                if_pending <= 1'b0;
            end else if (fetch_issue) begin
                if_pending <= 1'b1;
            end else if (~icache_busy & if_pending) begin
                pc_reg     <= pc_plus_4;
                if_pending <= 1'b0;
            end
        end
    end

    /////////////////////////////////////
    // Fetch-Decode Pipeline
    /////////////////////////////////////
    wire [6:0] if_id_opcode;
    wire if_id_is_jal;

    reg  [31:0] if_id_pc_reg_out;
    reg  [31:0] if_id_pc_plus_4_out;
    reg  [31:0] if_id_i_imem_rdata_out;
    reg if_id_valid_out;

    assign if_id_opcode = if_id_i_imem_rdata_out[6:0];

    assign if_id_is_jal  = (if_id_opcode == 7'b1101111);

    always @(posedge i_clk) begin
        if (i_rst | flush) begin
            if_id_pc_reg_out       <= 32'b0;
            if_id_pc_plus_4_out    <= 32'b0;
            if_id_i_imem_rdata_out <= 32'b0;
            if_id_valid_out        <= 1'b0;
        end else if (~icache_busy & if_pending) begin
            if_id_pc_reg_out       <= pc_reg;
            if_id_pc_plus_4_out    <= pc_plus_4;
            if_id_i_imem_rdata_out <= icache_res_rdata;
            if_id_valid_out        <= 1'b1;
        end else if(~frontend_hold) begin
            if_id_pc_reg_out <= 32'b0;
             if_id_pc_plus_4_out    <= 32'b0;
            if_id_i_imem_rdata_out <= 32'b0;
            if_id_valid_out        <= 1'b0;
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
         if (i_rst | load_use_hazard | ex_flush) begin            id_ex_pc_reg_out          <= 32'b0;
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
        end else if(mem_stall) begin
            id_ex_pc_reg_out          <= id_ex_pc_reg_out;
            id_ex_pc_plus_4_out       <= id_ex_pc_plus_4_out;
            id_ex_i_imem_rdata_out    <= id_ex_i_imem_rdata_out;
            id_ex_o_rs1_rdata_out     <= id_ex_o_rs1_rdata_out;
            id_ex_o_rs2_rdata_out     <= id_ex_o_rs2_rdata_out;
            id_ex_o_immediate_out     <= id_ex_o_immediate_out;
            id_ex_jump_out            <= id_ex_jump_out;
            id_ex_jalr_out            <= id_ex_jalr_out;
            id_ex_branch_out          <= id_ex_branch_out;
            id_ex_branch_type_out     <= id_ex_branch_type_out;
            id_ex_rd_dest_select_out  <= id_ex_rd_dest_select_out;
            id_ex_store_sel_out       <= id_ex_store_sel_out;
            id_ex_load_sel_out        <= id_ex_load_sel_out;
            id_ex_dmem_ren_out        <= id_ex_dmem_ren_out;
            id_ex_dmem_wen_out        <= id_ex_dmem_wen_out;
            id_ex_i_opsel_out         <= id_ex_i_opsel_out;
            id_ex_i_arith_out         <= id_ex_i_arith_out;
            id_ex_i_unsigned_out      <= id_ex_i_unsigned_out;
            id_ex_i_sub_out           <= id_ex_i_sub_out;
            id_ex_auipc_out           <= id_ex_auipc_out;
            id_ex_i_alu_src_out       <= id_ex_i_alu_src_out;
            id_ex_i_rd_wen_out        <= id_ex_i_rd_wen_out;
            id_ex_valid_out           <= id_ex_valid_out;
        end else begin
            id_ex_pc_reg_out          <= if_id_pc_reg_out;
            id_ex_pc_plus_4_out       <= if_id_pc_plus_4_out;
            id_ex_i_imem_rdata_out    <= if_id_i_imem_rdata_out;
            id_ex_o_rs1_rdata_out     <= o_rs1_rdata;
            id_ex_o_rs2_rdata_out     <= o_rs2_rdata;
            id_ex_o_immediate_out     <= o_immediate;
            id_ex_jump_out            <= jump;
            id_ex_jalr_out            <= jalr;
            id_ex_branch_out          <= branch;
            id_ex_branch_type_out     <= branch_type;
            id_ex_rd_dest_select_out  <= rd_dest_select;
            id_ex_store_sel_out       <= store_sel;
            id_ex_load_sel_out        <= load_sel;
            id_ex_dmem_ren_out        <= dmem_ren;
            id_ex_dmem_wen_out        <= dmem_wen;
            id_ex_i_opsel_out         <= i_opsel;
            id_ex_i_arith_out         <= i_arith;
            id_ex_i_unsigned_out      <= i_unsigned;
            id_ex_i_sub_out           <= i_sub;
            id_ex_auipc_out           <= auipc;
            id_ex_i_alu_src_out       <= i_alu_src;
            id_ex_i_rd_wen_out        <= i_rd_wen;
            id_ex_valid_out           <= if_id_valid_out;
        end
    end

    /////////////////////////////////////
    // Execute Phase
    /////////////////////////////////////
    wire [31:0] o_result;
    wire [31:0] execute_pc_next;
    wire br_condition_met;
    wire [31:0] ex_rs1_fwd, ex_rs2_fwd; // post-forwarding operand values

    // Forwarding control signals — declared here, driven after MEM/WB regs below
    wire [1:0]  fwd_alu_src_i_op1, fwd_alu_src_i_op2;
    wire [31:0] fwd_ex_val, fwd_mem_val;

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
        .fwd_alu_src_i_op1 (fwd_alu_src_i_op1),
        .fwd_alu_src_i_op2 (fwd_alu_src_i_op2),
        .fwd_ex_val     (fwd_ex_val),
        .fwd_mem_val    (fwd_mem_val),
        .pc_out           (execute_pc_next),
        .o_result         (o_result),
        .br_condition_met (br_condition_met),
        .o_rs1_fwd        (ex_rs1_fwd),
        .o_rs2_fwd        (ex_rs2_fwd)
    );
    

    assign jal_redirect = if_id_valid_out & if_id_is_jal;

    assign ex_flush = id_ex_valid_out &
                    (id_ex_jalr_out | (id_ex_branch_out & br_condition_met));

    assign flush = ex_flush | jal_redirect;

    assign pc_next = ex_flush ? execute_pc_next
                            : (if_id_pc_reg_out + o_immediate);

    assign control_fetch_hold = (if_id_valid_out & if_id_is_jal) |
                                (id_ex_valid_out & (id_ex_branch_out | id_ex_jalr_out));

    // Issue a new instruction fetch only when fetch is not blocked by reset,
    // an outstanding request, a filled IF/ID stage, pipeline stalls, control hazards,
    // and when instruction memory is ready.
    assign fetch_issue = ~i_rst &
                    ~if_pending &
                    ~if_id_valid_out &
                    ~frontend_hold &
                    ~control_fetch_hold &
                    i_imem_ready &
                    ~icache_busy;
  
    /////////////////////////////////////
    // Execute-Memory Pipeline
    /////////////////////////////////////
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
        end else if (mem_stall) begin
            // Hold EX/MEM while waiting for data memory to finish.
            ex_mem_pc_plus_4_out      <= ex_mem_pc_plus_4_out;
            ex_mem_pc_next_out        <= ex_mem_pc_next_out;
            ex_mem_i_imem_rdata_out   <= ex_mem_i_imem_rdata_out;
            ex_mem_o_result_out       <= ex_mem_o_result_out;
            ex_mem_o_rs1_rdata_out    <= ex_mem_o_rs1_rdata_out;
            ex_mem_o_rs2_rdata_out    <= ex_mem_o_rs2_rdata_out;
            ex_mem_o_immediate_out    <= ex_mem_o_immediate_out;
            ex_mem_rd_dest_select_out <= ex_mem_rd_dest_select_out;
            ex_mem_store_sel_out      <= ex_mem_store_sel_out;
            ex_mem_load_sel_out       <= ex_mem_load_sel_out;
            ex_mem_dmem_ren_out       <= ex_mem_dmem_ren_out;
            ex_mem_dmem_wen_out       <= ex_mem_dmem_wen_out;
            ex_mem_i_rd_wen_out       <= ex_mem_i_rd_wen_out;
            ex_mem_valid_out          <= ex_mem_valid_out;
        end else begin
            ex_mem_pc_plus_4_out      <= id_ex_pc_plus_4_out;
            ex_mem_pc_next_out        <= execute_pc_next;
            ex_mem_i_imem_rdata_out   <= id_ex_i_imem_rdata_out;
            ex_mem_o_result_out       <= o_result;
            ex_mem_o_rs1_rdata_out    <= ex_rs1_fwd;
            ex_mem_o_rs2_rdata_out    <= ex_rs2_fwd;
            ex_mem_o_immediate_out    <= id_ex_o_immediate_out;
            ex_mem_rd_dest_select_out <= id_ex_rd_dest_select_out;
            ex_mem_store_sel_out      <= id_ex_store_sel_out;
            ex_mem_load_sel_out       <= id_ex_load_sel_out;
            ex_mem_dmem_ren_out       <= id_ex_dmem_ren_out;
            ex_mem_dmem_wen_out       <= id_ex_dmem_wen_out;
            ex_mem_i_rd_wen_out       <= id_ex_i_rd_wen_out;
            ex_mem_valid_out          <= id_ex_valid_out;
        end
    end

    /////////////////////////////////////
    // Memory Phase
    /////////////////////////////////////
    wire [31:0] load_mux_out;

    wire ex_mem_is_mem;
    wire dmem_req_fire;
    wire dmem_rsp_fire;
    wire load_rsp_fire;
    wire store_rsp_fire;
    wire mem_wb_take;

    memory_phase iDUT_memory (
        .alu_result   (ex_mem_o_result_out),
        .load_sel     (ex_mem_load_sel_out),
        .store_sel    (ex_mem_store_sel_out),
        .dmem_ren     (ex_mem_dmem_ren_out),
        .dmem_wen     (ex_mem_dmem_wen_out),
        .o_rs2_rdata  (ex_mem_o_rs2_rdata_out),
        .i_dmem_rdata (dcache_res_rdata),
        .o_dmem_addr  (dmem_addr_raw),
        .o_dmem_ren   (dmem_ren_raw),
        .o_dmem_wen   (dmem_wen_raw),
        .o_dmem_wdata (dmem_wdata_raw),
        .o_dmem_mask  (dmem_mask_raw),
        .load_mux_out (load_mux_out)
    );

    assign ex_mem_is_mem = ex_mem_valid_out & (dmem_ren_raw | dmem_wen_raw);
    // A memory request fires when a valid memory instruction is present,
    // no prior load is still pending, and memory is ready to accept the request.
    assign dmem_req_fire = ex_mem_is_mem & ~dcache_busy;

    // A load response is considered "fired" when the load is valid,
    // the memory is returning valid data, 
    // and the load is the instruction at the head of the memory queue 
    assign load_rsp_fire  = ex_mem_valid_out & dmem_ren_raw & ~dcache_busy;

    // A store response is considered "fired" when the store is valid,
    // the store request is accepted by memory,
    // and the store is the instruction at the head of the memory queue
    //i_dmem_Valid is not necessary because when dmem_wen_raw is asserted it is considered a valid
    // store instruction and we can consider it "fired"
    assign store_rsp_fire = ex_mem_valid_out & dmem_wen_raw & ~dcache_busy;

    // The memory stage is considered to have "fired" when either a load or store response has fired,
    // since both indicate that the instruction at the head of the memory queue has completed and can be retired.
    assign dmem_rsp_fire  = load_rsp_fire | store_rsp_fire;


    assign mem_stall = ex_mem_valid_out &
                         ((dmem_ren_raw & ~load_rsp_fire) |
                          (dmem_wen_raw & ~store_rsp_fire));
    //raw registers needed to separate datapath from control logic.
    //The raw signals are not strictly required,
    // but they provide a clean intermediate representation of the intended memory operation 
    assign o_dmem_mask  = dmem_mask_raw;

    /////////////////////////////////////
    // Memory-Execute Pipeline
    /////////////////////////////////////
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


    //mem_wb_take is the signal that indicates when the MEM/WB pipeline register should latch new values from the EX/MEM stage.
    // This should only happen when the instruction in EX/MEM is valid and either:
    assign mem_wb_take = ex_mem_valid_out & ((~ex_mem_is_mem) | load_rsp_fire | store_rsp_fire);

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
        end else if (mem_wb_take) begin
            mem_wb_pc_plus_4_out      <= ex_mem_pc_plus_4_out;
            mem_wb_pc_next_out        <= ex_mem_pc_next_out;
            mem_wb_i_imem_rdata_out   <= ex_mem_i_imem_rdata_out;
            mem_wb_o_result_out       <= ex_mem_o_result_out;
            mem_wb_load_mux_out_out   <= load_mux_out;
            mem_wb_o_immediate_out    <= ex_mem_o_immediate_out;
            mem_wb_o_rs1_rdata_out    <= ex_mem_o_rs1_rdata_out;
            mem_wb_o_rs2_rdata_out    <= ex_mem_o_rs2_rdata_out;
            mem_wb_rd_dest_select_out <= ex_mem_rd_dest_select_out;
            mem_wb_i_rd_wen_out       <= ex_mem_i_rd_wen_out;
            mem_wb_valid_out          <= ex_mem_valid_out;
            mem_wb_dmem_addr_out      <= dmem_addr_raw;
            mem_wb_dmem_ren_out       <= dmem_ren_raw;
            mem_wb_dmem_wen_out       <= dmem_wen_raw;
            mem_wb_dmem_mask_out      <= dmem_mask_raw;
            mem_wb_dmem_wdata_out     <= dmem_wdata_raw;
            mem_wb_dmem_rdata_out     <= dcache_res_rdata;
        end else begin
            mem_wb_valid_out <= 1'b0;
        end
    end

    ////////////////////////////////////
    // Forwarding Unit + Value Sources
    // Placed here so all pipeline regs are declared before use
    ////////////////////////////////////

    // EX->EX: ALU result sitting in EX/MEM reg
    wire [6:0] ex_mem_opcode = ex_mem_i_imem_rdata_out[6:0];

    wire ex_mem_is_lui  = (ex_mem_opcode == 7'b0110111);
    wire ex_mem_is_jal  = (ex_mem_opcode == 7'b1101111);
    wire ex_mem_is_jalr = (ex_mem_opcode == 7'b1100111);

    assign fwd_ex_val =
        ex_mem_is_lui             ? ex_mem_o_immediate_out :
        (ex_mem_is_jal | ex_mem_is_jalr) ? ex_mem_pc_plus_4_out :
                                            ex_mem_o_result_out;
    // MEM->EX: combinational writeback mux over MEM/WB regs
    


    writeback_phase iDUT_fwd_wb (
        .rd_dest_select    (mem_wb_rd_dest_select_out),
        .alu_result        (mem_wb_o_result_out),
        .pc_plus_4         (mem_wb_pc_plus_4_out),
        .o_immediate       (mem_wb_o_immediate_out),
        .load_mux_out      (mem_wb_load_mux_out_out),
        .writeback_mux_out (fwd_mem_val)
    );

    wire [1:0] forward_a;
    wire [1:0] forward_b;

    forwarding_unit iDUT_forwarding (
        .ex_rs1       (id_ex_i_imem_rdata_out[19:15]),
        .ex_rs2       (id_ex_i_imem_rdata_out[24:20]),
        .exmem_rd     (ex_mem_i_imem_rdata_out[11:7]),
        .exmem_rd_wen (ex_mem_valid_out & ex_mem_i_rd_wen_out),
        .memwb_rd     (mem_wb_i_imem_rdata_out[11:7]),
        .memwb_rd_wen (mem_wb_valid_out & mem_wb_i_rd_wen_out),
        .fwd_rs1_sel  (forward_a),
        .fwd_rs2_sel  (forward_b)
    );

    assign fwd_alu_src_i_op1 = forward_a;
    assign fwd_alu_src_i_op2 = forward_b;

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
    assign wb_rd_wen   = mem_wb_valid_out & mem_wb_i_rd_wen_out;

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
    // With EX->EX and MEM->EX forwarding, the only remaining RAW hazard
    // that cannot be forwarded is a load-use hazard
    /////////////////////////////////////
    wire [6:0] id_opcode = if_id_i_imem_rdata_out[6:0];
    wire [4:0] id_rs1    = if_id_i_imem_rdata_out[19:15];
    wire [4:0] id_rs2    = if_id_i_imem_rdata_out[24:20];
    wire [4:0] ex_rd     = id_ex_i_imem_rdata_out[11:7];

    wire id_uses_rs1 =
        (id_opcode == 7'b0110011) |   // R-type
        (id_opcode == 7'b0010011) |   // I-type ALU
        (id_opcode == 7'b0000011) |   // loads
        (id_opcode == 7'b0100011) |   // stores
        (id_opcode == 7'b1100011) |   // branches
        (id_opcode == 7'b1100111);    // jalr

    wire id_uses_rs2 =
        (id_opcode == 7'b0110011) |   // R-type
        (id_opcode == 7'b0100011) |   // stores
        (id_opcode == 7'b1100011);    // branches

    // Load-use hazard: EX stage is a load and rd matches ID stage rs1/rs2
    assign load_use_hazard = id_ex_dmem_ren_out & (ex_rd != 5'd0) &
    (
        (id_uses_rs1 & (ex_rd == id_rs1)) |
        (id_uses_rs2 & (ex_rd == id_rs2))
    );


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

