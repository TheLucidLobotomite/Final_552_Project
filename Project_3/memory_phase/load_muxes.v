module load_muxes(
    input wire [2:0] load_sel,
    input wire [31:0] Read_data_from_dmem,
    output reg [31:0] load_mux_out
);


assign load_mux_out =   load_sel[2]     ? Read_data_from_dmem : 
                        (load_sel[1]    ? (load_sel[0] ? {{16{1'b0}}, Read_data_from_dmem[15:0]} : {{24{1'b0}}, Read_data_from_dmem[7:0]}) : 
                        (load_sel[0]    ? {{16{Read_data_from_dmem[15]}}, Read_data_from_dmem[15:0]} : {{24{Read_data_from_dmem[7]}}, Read_data_from_dmem[7:0]}));
    
endmodule