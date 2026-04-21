`default_nettype none

module cache (
    input  wire        i_clk,
    input  wire        i_rst,
    input  wire        i_mem_ready,
    output wire [31:0] o_mem_addr,
    output wire        o_mem_ren,
    output wire        o_mem_wen,
    output wire [31:0] o_mem_wdata,
    input  wire [31:0] i_mem_rdata,
    input  wire        i_mem_valid,
    output wire        o_busy,
    input  wire [31:0] i_req_addr,
    input  wire        i_req_ren,
    input  wire        i_req_wen,
    input  wire [ 3:0] i_req_mask,
    input  wire [31:0] i_req_wdata,
    output wire [31:0] o_res_rdata
);
    localparam O = 4;
    localparam S = 5;
    localparam DEPTH = (1 << S);
    localparam W = 2;
    localparam T = 32 - O - S;
    localparam D = ((1 << O) >> 2);

    reg [31:0] datas0 [DEPTH - 1:0][D - 1:0];
    reg [31:0] datas1 [DEPTH - 1:0][D - 1:0];
    reg [T - 1:0] tags0  [DEPTH - 1:0];
    reg [T - 1:0] tags1  [DEPTH - 1:0];
    reg [DEPTH-1:0] valid0;
    reg [DEPTH-1:0] valid1;
    reg [DEPTH-1:0] lru;

    reg [1:0] fill_block_offset;

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

    localparam INIT      = 3'b000;
    localparam READY     = 3'b001;
    localparam FETCH     = 3'b010;
    localparam FILL      = 3'b011;
    localparam WRITEBACK = 3'b100;
    localparam [S-1:0] LAST_SET = 5'd31;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [S-1:0] init_idx;

    reg [31:0] miss_addr;
    reg [31:0] miss_wdata;
    reg [3:0]  miss_mask;
    reg        miss_is_write;
    reg        miss_way;
    reg [31:0] miss_rdata_hold;
    reg        miss_resp_valid;

    wire [31:0] merged_hit_w0;
    wire [31:0] merged_hit_w1;
    wire [31:0] merged_fill_word;
    wire [31:0] req_mask32;
    wire [31:0] miss_mask32;

    assign req_mask32 = {{8{i_req_mask[3]}}, {8{i_req_mask[2]}}, {8{i_req_mask[1]}}, {8{i_req_mask[0]}}};
    assign miss_mask32 = {{8{miss_mask[3]}}, {8{miss_mask[2]}}, {8{miss_mask[1]}}, {8{miss_mask[0]}}};

    assign merged_hit_w0 = {
        i_req_mask[3] ? i_req_wdata[31:24] : datas0[i_req_addr[8:4]][i_req_addr[3:2]][31:24],
        i_req_mask[2] ? i_req_wdata[23:16] : datas0[i_req_addr[8:4]][i_req_addr[3:2]][23:16],
        i_req_mask[1] ? i_req_wdata[15:8]  : datas0[i_req_addr[8:4]][i_req_addr[3:2]][15:8],
        i_req_mask[0] ? i_req_wdata[7:0]   : datas0[i_req_addr[8:4]][i_req_addr[3:2]][7:0]
    };

    assign merged_hit_w1 = {
        i_req_mask[3] ? i_req_wdata[31:24] : datas1[i_req_addr[8:4]][i_req_addr[3:2]][31:24],
        i_req_mask[2] ? i_req_wdata[23:16] : datas1[i_req_addr[8:4]][i_req_addr[3:2]][23:16],
        i_req_mask[1] ? i_req_wdata[15:8]  : datas1[i_req_addr[8:4]][i_req_addr[3:2]][15:8],
        i_req_mask[0] ? i_req_wdata[7:0]   : datas1[i_req_addr[8:4]][i_req_addr[3:2]][7:0]
    };

    assign merged_fill_word = {
        miss_mask[3] ? miss_wdata[31:24] : i_mem_rdata[31:24],
        miss_mask[2] ? miss_wdata[23:16] : i_mem_rdata[23:16],
        miss_mask[1] ? miss_wdata[15:8]  : i_mem_rdata[15:8],
        miss_mask[0] ? miss_wdata[7:0]   : i_mem_rdata[7:0]
    };

    wire hit0;
    wire hit1;
    wire any_hit;

    assign hit0 = (tags0[i_req_addr[8:4]] == i_req_addr[31:9]) & valid0[i_req_addr[8:4]];
    assign hit1 = (tags1[i_req_addr[8:4]] == i_req_addr[31:9]) & valid1[i_req_addr[8:4]];
    assign any_hit = hit0 | hit1;

    always @(posedge i_clk) begin
        if (i_rst) begin
            state <= READY;
            next_state <= READY;
            init_idx <= {S{1'b0}};

            valid0 <= {DEPTH{1'b0}};
            valid1 <= {DEPTH{1'b0}};
            lru    <= {DEPTH{1'b0}};

            fill_block_offset <= 2'b00;
            miss_addr <= 32'b0;
            miss_wdata <= 32'b0;
            miss_mask <= 4'b0;
            miss_is_write <= 1'b0;
            miss_way <= 1'b0;
            miss_rdata_hold <= 32'b0;
            miss_resp_valid <= 1'b0;
        end else begin
            state <= next_state;
            case (state)

                READY: begin
                    miss_resp_valid <= 1'b0;

                    if (i_req_ren) begin
                        if (hit0) begin
                            lru[i_req_addr[8:4]] <= 1'b1;
                        end else if (hit1) begin
                            lru[i_req_addr[8:4]] <= 1'b0;
                        end else begin
                            fill_block_offset <= 2'b00;
                            miss_addr <= i_req_addr;
                            miss_wdata <= i_req_wdata;
                            miss_mask <= i_req_mask;
                            miss_is_write <= 1'b0;
                            if (~valid0[i_req_addr[8:4]])
                                miss_way <= 1'b0;
                            else if (~valid1[i_req_addr[8:4]])
                                miss_way <= 1'b1;
                            else
                                miss_way <= lru[i_req_addr[8:4]];
                        end
                    end

                    if (i_req_wen) begin
                        if (hit0) begin
                            datas0[i_req_addr[8:4]][i_req_addr[3:2]][31:24] <= i_req_mask[3] ? i_req_wdata[31:24] : datas0[i_req_addr[8:4]][i_req_addr[3:2]][31:24];
                            datas0[i_req_addr[8:4]][i_req_addr[3:2]][23:16] <= i_req_mask[2] ? i_req_wdata[23:16] : datas0[i_req_addr[8:4]][i_req_addr[3:2]][23:16];
                            datas0[i_req_addr[8:4]][i_req_addr[3:2]][15:8]  <= i_req_mask[1] ? i_req_wdata[15:8]  : datas0[i_req_addr[8:4]][i_req_addr[3:2]][15:8];
                            datas0[i_req_addr[8:4]][i_req_addr[3:2]][7:0]   <= i_req_mask[0] ? i_req_wdata[7:0]   : datas0[i_req_addr[8:4]][i_req_addr[3:2]][7:0];
                            lru[i_req_addr[8:4]] <= 1'b1;

                            miss_addr <= i_req_addr;
                            miss_wdata <= i_req_wdata;
                            miss_mask <= i_req_mask;
                            miss_is_write <= 1'b1;
                            miss_way <= 1'b0;
                        end else if (hit1) begin
                            datas1[i_req_addr[8:4]][i_req_addr[3:2]][31:24] <= i_req_mask[3] ? i_req_wdata[31:24] : datas1[i_req_addr[8:4]][i_req_addr[3:2]][31:24];
                            datas1[i_req_addr[8:4]][i_req_addr[3:2]][23:16] <= i_req_mask[2] ? i_req_wdata[23:16] : datas1[i_req_addr[8:4]][i_req_addr[3:2]][23:16];
                            datas1[i_req_addr[8:4]][i_req_addr[3:2]][15:8]  <= i_req_mask[1] ? i_req_wdata[15:8]  : datas1[i_req_addr[8:4]][i_req_addr[3:2]][15:8];
                            datas1[i_req_addr[8:4]][i_req_addr[3:2]][7:0]   <= i_req_mask[0] ? i_req_wdata[7:0]   : datas1[i_req_addr[8:4]][i_req_addr[3:2]][7:0];
                            lru[i_req_addr[8:4]] <= 1'b0;

                            miss_addr <= i_req_addr;
                            miss_wdata <= i_req_wdata;
                            miss_mask <= i_req_mask;
                            miss_is_write <= 1'b1;
                            miss_way <= 1'b1;
                        end else begin
                            fill_block_offset <= 2'b00;
                            miss_addr <= i_req_addr;
                            miss_wdata <= i_req_wdata;
                            miss_mask <= i_req_mask;
                            miss_is_write <= 1'b1;
                            if (~valid0[i_req_addr[8:4]])
                                miss_way <= 1'b0;
                            else if (~valid1[i_req_addr[8:4]])
                                miss_way <= 1'b1;
                            else
                                miss_way <= lru[i_req_addr[8:4]];
                        end
                    end
                end

                FILL: begin
                    if (i_mem_valid) begin
                        if (fill_block_offset == miss_addr[3:2])
                            miss_rdata_hold <= miss_is_write ? merged_fill_word : (i_mem_rdata & miss_mask32);

                        if (miss_way == 1'b0) begin
                            if (miss_is_write && (fill_block_offset == miss_addr[3:2]))
                                datas0[miss_addr[8:4]][fill_block_offset] <= merged_fill_word;
                            else
                                datas0[miss_addr[8:4]][fill_block_offset] <= i_mem_rdata;

                            if (fill_block_offset == 2'b11) begin
                                tags0[miss_addr[8:4]] <= miss_addr[31:9];
                                valid0[miss_addr[8:4]] <= 1'b1;
                                lru[miss_addr[8:4]] <= 1'b1;
                            end
                        end else begin
                            if (miss_is_write && (fill_block_offset == miss_addr[3:2]))
                                datas1[miss_addr[8:4]][fill_block_offset] <= merged_fill_word;
                            else
                                datas1[miss_addr[8:4]][fill_block_offset] <= i_mem_rdata;

                            if (fill_block_offset == 2'b11) begin
                                tags1[miss_addr[8:4]] <= miss_addr[31:9];
                                valid1[miss_addr[8:4]] <= 1'b1;
                                lru[miss_addr[8:4]] <= 1'b0;
                            end
                        end

                        if ((fill_block_offset == 2'b11) && (~miss_is_write))
                            miss_resp_valid <= 1'b1;

                        if (fill_block_offset == 2'b11)
                            fill_block_offset <= 2'b00;
                        else
                            fill_block_offset <= fill_block_offset + 1'b1;
                    end
                end

                default: begin
                end
            endcase
        end
    end

    wire        fill_last;
    wire [31:0] miss_way_wdata;
    

    assign fill_last        = i_mem_valid & (fill_block_offset == 2'b11);

    assign miss_way_wdata =
        miss_way ?
            datas1[miss_addr[8:4]][miss_addr[3:2]] :
            datas0[miss_addr[8:4]][miss_addr[3:2]];
    always @(*) begin
        next_state    = state;
        o_busy_r      = 0;
        o_mem_ren_r   = 0;
        o_mem_wen_r   = 0;
        o_mem_addr_r  = 32'b0;
        o_mem_wdata_r = 32'b0;
        o_res_rdata_r = 32'b0;

        case (state)

            READY: begin
               

                o_res_rdata_r = (miss_resp_valid) ? miss_rdata_hold :
                                 hit0 ? (datas0[i_req_addr[8:4]][i_req_addr[3:2]] & req_mask32) :
                                 hit1 ? (datas1[i_req_addr[8:4]][i_req_addr[3:2]] & req_mask32) :
                                 32'b0;


               o_mem_addr_r = (i_req_wen & (hit0 | hit1)) ? i_req_addr : 32'b0;

                o_mem_wdata_r =
                    (i_req_wen & hit0) ? merged_hit_w0 :
                    (i_req_wen & hit1) ? merged_hit_w1 :
                    32'b0;

                o_mem_wen_r = i_req_wen & (hit0 | hit1);

                o_busy_r =
            ((~miss_resp_valid) & (~hit0) & (~hit1) & (i_req_ren | i_req_wen));

             next_state =
                (((~miss_resp_valid) & (~hit0) & (~hit1) & (i_req_ren | i_req_wen)) ? FETCH : READY);


            end

            FETCH: begin
                o_busy_r = 1'b1;
                o_mem_addr_r = {miss_addr[31:4], fill_block_offset, 2'b00};
                o_mem_ren_r = 1'b1; // Only assert ren for one cycle to avoid unnecessary waiting when mem is already ready at the next cycle.

                next_state = (i_mem_ready) ? FILL : FETCH;
            end

            FILL: begin
                o_busy_r = 1'b1;

                o_res_rdata_r =
                    (i_mem_valid & (fill_block_offset == miss_addr[3:2])) ?
                        (miss_is_write ? merged_fill_word : (i_mem_rdata & miss_mask32)) :
                        miss_rdata_hold;

                o_mem_addr_r  = (fill_last & miss_is_write) ? miss_addr : 32'b0;
                o_mem_wdata_r = (fill_last & miss_is_write) ? miss_way_wdata : 32'b0;
                o_mem_wen_r   = fill_last & miss_is_write;

                next_state =
                    (i_mem_valid) ? ((fill_block_offset == 2'b11) ? READY : FETCH) :
                    FILL;
            end

            WRITEBACK: begin
                o_busy_r = 1'b1;
                o_mem_addr_r  = miss_addr;
                o_mem_wdata_r = miss_way_wdata;
                o_mem_wen_r   = 1'b1;
                next_state    = i_mem_ready ? READY : WRITEBACK;
            end

            default: begin
                next_state = READY;
            end
        endcase
    end

endmodule

`default_nettype wire
