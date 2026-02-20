module write_data_mux (
    input wire [2:0] store_sel,
    input wire [31:0] o_rs2_rdata,
    input wire [15:0] o_rs2_rdata_16,
    input wire [7:0] o_rs2_rdata_8,

    output reg [31:0] write_data_mux_out
);

write_data_mux_out =   store_sel[1] ? o_rs2_rdata : 
                        (store_sel[0] ?o_rs2_rdata_16 : o_rs2_rdata_8);
endmodule