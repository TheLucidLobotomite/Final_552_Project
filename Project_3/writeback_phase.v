module writeback_phase (
    input  wire [ 1:0] rd_dest_select,
    input  wire [31:0] alu_result,
    input  wire [31:0] pc_plus_4,
    input  wire [31:0] o_immediate,
    input  wire [31:0] load_mux_out,
    output wire [31:0] writeback_mux_out
);

    assign writeback_mux_out =  rd_dest_select[1] ?
                                (rd_dest_select[0] ? load_mux_out : pc_plus_4) :
                                (rd_dest_select[0] ? o_immediate  : alu_result);

endmodule
