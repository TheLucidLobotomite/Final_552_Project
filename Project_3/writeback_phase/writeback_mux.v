module writeback_mux (
    input mem_to_reg,
    input reg [31:0] ALU_result,
    input reg [31:0] regfile_data_mem_out,
    output reg [31:0] writeback_data_mem_out,
    output reg [31:0] writeback_mux_out
);

assign writeback_mux_out = mem_to_reg ? regfile_data_mem_out : ALU_result;


    
endmodule