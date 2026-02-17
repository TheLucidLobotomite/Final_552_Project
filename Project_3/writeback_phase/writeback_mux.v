module writeback_mux (
    input wire  mem_to_reg,
    input wire [31:0] ALU_result,
    input wire [31:0] regfile_data_mem_out,
    output wire [31:0] writeback_data_mem_out,
    output wire [31:0] writeback_mux_out
);

assign writeback_mux_out = mem_to_reg ? regfile_data_mem_out : ALU_result;


    
endmodule