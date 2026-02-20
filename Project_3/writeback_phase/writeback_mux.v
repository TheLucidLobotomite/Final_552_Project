module writeback_mux (
    input wire  [1:0]rd_dest_select,
    input wire [31:0] ALU_result,
    input wire [31:0] PC_plus_4,
    input wire [31:0] o_immediate;
    input wire [31:0] data_read_from_dmem,
    output wire [31:0] writeback_mux_out,
);

assign writeback_mux_out = rd_dest_select[1]? 
                        (rd_dest_select[0]? data_read_from_dmem : PC_plus_4) :
                        (rd_dest_select[0]? o_immediate : ALU_result);


    
endmodule