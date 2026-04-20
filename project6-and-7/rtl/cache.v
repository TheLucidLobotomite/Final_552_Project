`default_nettype none

module cache (
    // Global clock.
    input  wire        i_clk,
    // Synchronous active-high reset.
    input  wire        i_rst,
    // External memory interface. See hart interface for details. This
    // interface is nearly identical to the phase 5 memory interface, with the
    // exception that the byte mask (`o_mem_mask`) has been removed. This is
    // no longer needed as the cache will only access the memory at word
    // granularity, and implement masking internally.
    input  wire        i_mem_ready,
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_valid,
    // Interface to CPU hart. This is nearly identical to the phase 5 hart memory
    // interface, but includes a stall signal (`o_busy`), and the input/output
    // polarities are swapped for obvious reasons.
    //
    // The CPU should use this as a stall signal for both instruction fetch
    // (IF) and memory (MEM) stages, from the instruction or data cache
    // respectively. If a memory request is made (`i_req_ren` for instruction
    // cache, or either `i_req_ren` or `i_req_wen` for data cache), this
    // should be asserted *combinationally* if the request results in a cache
    // miss.
    //
    // In case of a cache miss, the CPU must stall the respective pipeline
    // stage and deassert ren/wen on subsequent cycles, until the cache
    // deasserts `o_busy` to indicate it has serviced the cache miss. However,
    // the CPU must keep the other request lines constant. For example, the
    // CPU should not change the request address while stalling.
    output wire        o_busy,
    // 32-bit read/write address to access from the cache. This should be
    // 32-bit aligned (i.e. the two LSBs should be zero). See `i_req_mask` for
    // how to perform half-word and byte accesses to unaligned addresses.
    input  wire [31:0] i_req_addr,
    // When asserted, the cache should perform a read at the aligned address
    // specified by `i_req_addr` and return the 32-bit word at that address,
    // either immediately (i.e. combinationally) on a cache hit, or
    // synchronously on a cache miss. It is illegal to assert this and
    // `i_dmem_wen` on the same cycle.
    input  wire        i_req_ren,
    // When asserted, the cache should perform a write at the aligned address
    // specified by `i_req_addr` with the 32-bit word provided in
    // `o_req_wdata` (specified by the mask). This is necessarily synchronous,
    // but may either happen on the next clock edge (on a cache hit) or after
    // multiple cycles of latency (cache miss). As the cache is write-through
    // and write-allocate, writes must be applied to both the cache and
    // underlying memory.
    // It is illegal to assert this and `i_dmem_ren` on the same cycle.
    input  wire        i_req_wen,
    // The memory interface expects word (32 bit) aligned addresses. However,
    // WISC-25 supports byte and half-word loads and stores at unaligned and
    // 16-bit aligned addresses, respectively. To support this, the access
    // mask specifies which bytes within the 32-bit word are actually read
    // from or written to memory.
    input  wire [ 3:0] i_req_mask,
    // The 32-bit word to write to memory, if the request is a write
    // (i_req_wen is asserted). Only the bytes corresponding to set bits in
    // the mask should be written into the cache (and to backing memory).
    input  wire [31:0] i_req_wdata,
    // THe 32-bit data word read from memory on a read request.
    output wire [31:0] o_res_rdata
);
    // These parameters are equivalent to those provided in the project
    // 6 specification. Feel free to use them, but hardcoding these numbers
    // rather than using the localparams is also permitted, as long as the
    // same values are used (and consistent with the project specification).
    //
    // 32 sets * 2 ways per set * 16 bytes per way = 1K cache
    localparam O = 4;            // 4 bit offset => 16 byte cache line
    localparam S = 5;            // 5 bit set index => 32 sets
    localparam DEPTH = 2 ** S;   // 32 sets
    localparam W = 2;            // 2 way set associative, NMRU
    localparam T = 32 - O - S;   // 23 bit tag
    localparam D = 2 ** O / 4;   // 16 bytes per line / 4 bytes per word = 4 words per line

    // The following memory arrays model the cache structure. As this is
    // an internal implementation detail, you are *free* to modify these
    // arrays as you please.

    // Backing memory, modeled as two separate ways.
    reg [   31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [   31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [1:0] valid [DEPTH - 1:0];
    reg       lru   [DEPTH - 1:0];

    // new variable for block fill byte offset
    reg [1:0] fill_block_offset;

    // Output registers because we have to use stupid Verilog and stupid wires
    reg        o_busy_r;
    reg [31:0] o_mem_addr_r;
    reg        o_mem_ren_r;
    reg        o_mem_wen_r;
    reg [31:0] o_mem_wdata_r;
    reg [31:0] o_res_rdata_r;
    assign o_busy = o_busy_r;
    assign o_mem_addr = o_mem_addr_r;
    assign o_mem_ren = o_mem_ren_r;
    assign o_mem_wen = o_mem_wen_r;
    assign o_mem_wdata = o_mem_wdata_r;
    assign o_res_rdata = o_res_rdata_r;

    // Finite State Machine states
    localparam READY = 2'b00;
    localparam FETCH = 2'b01;
    localparam FILL = 2'b10;
    localparam WRITEBACK = 2'b11;

    reg [1:0] state;
    reg [1:0] next_state;
    integer i;

    // lil bro's got you - rst is a synch so not in sensitivity list
    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= READY;
            next_state <= READY;

            for (i = 0; i < DEPTH; i = i + 1) begin
                valid[i] <= 0; // Invalidate all cache lines on reset
            end

            for (i = 0; i < DEPTH; i = i + 1) begin
                lru[i] <= 0; // Invalidate all cache lines on reset
            end

            // lil bro's got you - reset fill_block_offset here so it's always defined at startup
            fill_block_offset <= 0;
        end else begin
            state <= next_state;

            // lil bro's got you - can't have this stuff in combination bc it fucks with synthesis
            // Cant have a reg and a wire write to the same place given a single cycle
            case (state)
                READY: begin
                    if (i_req_ren) begin
                        if ( (tags0[i_req_addr[8:4]] == i_req_addr[31:9]) && valid[i_req_addr[8:4]][0] ) begin
                            lru[i_req_addr[8:4]] <= 1; // way 0 is most recently used
                        end else if ( (tags1[i_req_addr[8:4]] == i_req_addr[31:9]) && valid[i_req_addr[8:4]][1] ) begin
                            lru[i_req_addr[8:4]] <= 0; // way 1 is most recently used
                        end else begin
                            fill_block_offset <= 0; // start filling from the first word in the block
                        end
                    end

                    if (i_req_wen) begin
                        if ( (tags0[i_req_addr[8:4]] == i_req_addr[31:9]) && valid[i_req_addr[8:4]][0] ) begin //write to way 0
                            datas0[i_req_addr[8:4]][i_req_addr[3:2]][31:24] <= i_req_mask[3] ? i_req_wdata[31:24] : datas0[i_req_addr[8:4]][i_req_addr[3:2]][31:24];
                            datas0[i_req_addr[8:4]][i_req_addr[3:2]][23:16] <= i_req_mask[2] ? i_req_wdata[23:16] : datas0[i_req_addr[8:4]][i_req_addr[3:2]][23:16];
                            datas0[i_req_addr[8:4]][i_req_addr[3:2]][15:8] <= i_req_mask[1] ? i_req_wdata[15:8] : datas0[i_req_addr[8:4]][i_req_addr[3:2]][15:8];
                            datas0[i_req_addr[8:4]][i_req_addr[3:2]][7:0] <= i_req_mask[0] ? i_req_wdata[7:0] : datas0[i_req_addr[8:4]][i_req_addr[3:2]][7:0];
                            lru[i_req_addr[8:4]] <= 1; // way 0 is most recently used
                        end else if ( (tags1[i_req_addr[8:4]] == i_req_addr[31:9]) && valid[i_req_addr[8:4]][1] ) begin //write to way 1
                            datas1[i_req_addr[8:4]][i_req_addr[3:2]][31:24] <= i_req_mask[3] ? i_req_wdata[31:24] : datas1[i_req_addr[8:4]][i_req_addr[3:2]][31:24];
                            datas1[i_req_addr[8:4]][i_req_addr[3:2]][23:16] <= i_req_mask[2] ? i_req_wdata[23:16] : datas1[i_req_addr[8:4]][i_req_addr[3:2]][23:16];
                            datas1[i_req_addr[8:4]][i_req_addr[3:2]][15:8] <= i_req_mask[1] ? i_req_wdata[15:8] : datas1[i_req_addr[8:4]][i_req_addr[3:2]][15:8];
                            datas1[i_req_addr[8:4]][i_req_addr[3:2]][7:0] <= i_req_mask[0] ? i_req_wdata[7:0] : datas1[i_req_addr[8:4]][i_req_addr[3:2]][7:0];
                            lru[i_req_addr[8:4]] <= 0; // way 1 is most recently used
                        end else begin
                            fill_block_offset <= 0; // start filling from the first word in the block
                        end
                    end
                end
                FILL: begin
                    if (i_mem_valid) begin
                        if (lru[i_req_addr[8:4]] == 0) begin // evict way 0
                            tags0[i_req_addr[8:4]] <= i_req_addr[31:9];
                            datas0[i_req_addr[8:4]][fill_block_offset] <= i_mem_rdata; //place word 0
                            valid[i_req_addr[8:4]][0] <= 1; // mark way 0 as valid
                            if (fill_block_offset == 2'b11)
                                lru[i_req_addr[8:4]] <= 1; // way 0 is now most recently used
                            // lru[i_req_addr[8:4]] = 1; // way 0 is now most recently used
                            // $display("filled tag %h into index %h on way 0", tags0[i_req_addr[8:4]], i_req_addr[8:4]);
                            // $display("filled data %h into index %h, block offset %h on way 0", datas0[i_req_addr[8:4]][fill_block_offset], i_req_addr[8:4], fill_block_offset);
                            // $display("set valid bit for index %h to %b on way 0", i_req_addr[8:4], valid[i_req_addr[8:4]][0]);
                        end else begin // evict way 1
                            tags1[i_req_addr[8:4]] <= i_req_addr[31:9];
                            datas1[i_req_addr[8:4]][fill_block_offset] <= i_mem_rdata; //place word 0
                            valid[i_req_addr[8:4]][1] <= 1; // mark way 1 as valid
                            if (fill_block_offset == 2'b11)
                                lru[i_req_addr[8:4]] <= 0; // way 1 is now most recently used
                            // lru[i_req_addr[8:4]] = 0; // way 1 is now most recently used
                            // $display("filled tag %h into index %h on way 1", tags1[i_req_addr[8:4]], i_req_addr[8:4]);
                            // $display("filled data %h into index %h, block offset %h on way 1", datas1[i_req_addr[8:4]][fill_block_offset], i_req_addr[8:4], fill_block_offset);
                            // $display("set valid bit for index %h to %b on way 1", i_req_addr[8:4], valid[i_req_addr[8:4]][1]);
                        end

                        // lil bro's got you - before the set lru was behind a cycle, so I just added up into the actual fill statements
                        if (fill_block_offset == 2'b11) begin
                            fill_block_offset <= 0; // reset block offset for the next time we need to fill a block
                        end else begin
                            fill_block_offset <= fill_block_offset + 1; // move to the next word in the block
                        end
                    end
                end
                default: ; // Do nothing baby
            endcase
        end
    end

    always @(*) begin
        // lil bro's got you - default all outputs and next_state at the top so no
        next_state    = state;
        o_busy_r      = 0;
        o_mem_ren_r   = 0;
        o_mem_wen_r   = 0;
        o_mem_addr_r  = 32'b0;
        o_mem_wdata_r = 32'b0;
        o_res_rdata_r = 32'b0;

        case (state)
            READY: begin //resolve cache hits combinationally, otherwise miss
                o_busy_r = 0;
                o_mem_wen_r = 0;

                if ( ((tags0[i_req_addr[8:4]] == i_req_addr[31:9])) && valid[i_req_addr[8:4]][0] ) begin
                        o_res_rdata_r = datas0[i_req_addr[8:4]][i_req_addr[3:2]]; //& {{8{i_req_mask[3]}}, {8{i_req_mask[2]}}, {8{i_req_mask[1]}}, {8{i_req_mask[0]}}}; //read from way 0
                    // TO DO: add support for i_req_mask to specify bytes and half words
                end else if ( ((tags1[i_req_addr[8:4]] == i_req_addr[31:9])) && valid[i_req_addr[8:4]][1] ) begin
                        o_res_rdata_r = datas1[i_req_addr[8:4]][i_req_addr[3:2]]; //& {{8{i_req_mask[3]}}, {8{i_req_mask[2]}}, {8{i_req_mask[1]}}, {8{i_req_mask[0]}}}; //read from way 1
                    // TO DO: add support for i_req_mask to specify bytes and half words
                end else if (i_req_ren) begin
                        // lil bro's got you - o_busy must go high combinationally on a miss
                        o_busy_r = 1;
                        next_state = FETCH;
                end

                if (i_req_wen) begin
                    if ( ((tags0[i_req_addr[8:4]] == i_req_addr[31:9])) && valid[i_req_addr[8:4]][0] ) begin
                        // TO DO: add support for i_req_mask to specify bytes and half words
                        // WRITE-THROUGH:
                        if (i_mem_ready) begin
                            o_mem_addr_r = i_req_addr; // write to the same address in memory
                            o_mem_wdata_r = i_req_wdata; // write the same data to memory
                            o_mem_wen_r = 1;
                        end else begin
                            next_state = WRITEBACK; // if memory is not ready, go to writeback state to wait for it to be ready
                        end
                    end else if ( ((tags1[i_req_addr[8:4]] == i_req_addr[31:9])) && valid[i_req_addr[8:4]][1] ) begin
                        // TO DO: add support for i_req_mask to specify bytes and half words
                        // WRITE-THROUGH:
                        if (i_mem_ready) begin
                            o_mem_addr_r = i_req_addr; // write to the same address in memory
                            o_mem_wdata_r = i_req_wdata; // write the same data to memory
                            o_mem_wen_r = 1;
                        end else begin
                            next_state = WRITEBACK; // if memory is not ready, go to writeback state to wait for it to be ready
                        end
                    end else begin
                        // TO DO: add support for i_req_mask to specify bytes and half words
                        o_busy_r = 1;
                        next_state = FETCH;
                    end
                end
            end
            FETCH: begin // Request data from memory
                o_busy_r = 1;
                o_mem_addr_r = {i_req_addr[31:4], fill_block_offset, 2'b00}; // align address to cache line and add block offset
                if (i_mem_ready) begin
                    o_mem_ren_r = 1;
                    next_state = FILL;
                end
            end
            FILL: begin
                o_busy_r = 1;
                if (i_mem_valid) begin
                    o_mem_ren_r = 0;
                    if (fill_block_offset == 2'b11) begin
                        next_state = READY; // after filling the whole block, go back to ready state
                    end else begin
                        next_state = FETCH;
                    end
                end
            end
            WRITEBACK: begin
                o_busy_r = 1;
                if (i_mem_ready) begin
                    o_mem_addr_r = i_req_addr; // write to the same address in memory
                    o_mem_wdata_r = i_req_wdata; // write the same data to memory
                    o_mem_wen_r = 1;
                    next_state = READY; // after writeback, go back to ready state
                end
            end
            default: next_state = READY;
        endcase
    end

endmodule

`default_nettype wire