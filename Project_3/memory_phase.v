module memory_phase (
    input  wire [31:0] alu_result,
    input  wire [2:0]  load_sel,
    input  wire [2:0]  store_sel,
    input  wire        dmem_ren,
    input  wire        dmem_wen,
    input  wire [31:0] o_rs2_rdata,
    input  wire [31:0] i_dmem_rdata,

    output wire [31:0] o_dmem_addr,
    output wire        o_dmem_ren,
    output wire        o_dmem_wen,
    output wire [31:0] o_dmem_wdata,
    output wire [ 3:0] o_dmem_mask,
    output wire [31:0] load_mux_out
);
    assign o_dmem_addr = {alu_result[31:2], 2'b00};
    assign o_dmem_ren  = dmem_ren;
    assign o_dmem_wen  = dmem_wen;

    wire [1:0] byte_offset = alu_result[1:0];

    // Byte Masking (000 - byte, 001 - half, 010 word)
    assign o_dmem_mask = store_sel[1] ? 4'b1111 :                                   // SW / LW
        (!store_sel[1] && store_sel[0]) ? (byte_offset[1] ? 4'b1100 : 4'b0011) :    // SH / LH
        (byte_offset == 2'b00) ? 4'b0001 :                                          // SB / LB — one byte lane based on offset
        (byte_offset == 2'b01) ? 4'b0010 :
        (byte_offset == 2'b10) ? 4'b0100 :
                                 4'b1000;

    // Actually setting the data
    assign o_dmem_wdata = store_sel[1] ? o_rs2_rdata :                                      // SW: full word, no shift
        (!store_sel[1] && store_sel[0]) ?
            (byte_offset[1] ? {o_rs2_rdata[15:0], 16'b0} : {16'b0, o_rs2_rdata[15:0]}) :    // SH: 16-bit half-word
        (byte_offset == 2'b00) ? {24'b0, o_rs2_rdata[7:0]}         :                        // SB: single byte shifted into correct lane
        (byte_offset == 2'b01) ? {16'b0, o_rs2_rdata[7:0],  8'b0}  :
        (byte_offset == 2'b10) ? { 8'b0, o_rs2_rdata[7:0], 16'b0}  :
                                 {o_rs2_rdata[7:0], 24'b0};

    // load_sel encoding (funct3):
    //   3'b000 = LB  (sign-extend byte)
    //   3'b001 = LH  (sign-extend half)
    //   3'b010 = LW  (full word)
    //   3'b100 = LBU (zero-extend byte)
    //   3'b101 = LHU (zero-extend half) 
    wire [31:0] shifted_rdata = load_sel[1] ? i_dmem_rdata :                                // LW: no shift needed                   
        (!load_sel[1] && load_sel[0]) ?
        (byte_offset[1] ? {16'b0, i_dmem_rdata[31:16]} : {16'b0, i_dmem_rdata[15:0]}) :     // LH / LHU
        (byte_offset == 2'b00) ? {24'b0, i_dmem_rdata[ 7: 0]} :                             // LB / LBU
        (byte_offset == 2'b01) ? {24'b0, i_dmem_rdata[15: 8]} :
        (byte_offset == 2'b10) ? {24'b0, i_dmem_rdata[23:16]} :
                                 {24'b0, i_dmem_rdata[31:24]};

    // Load Mux
    assign load_mux_out = load_sel[1] ? shifted_rdata :                                                         // LW: full word 
        (!load_sel[1] && load_sel[0]) ? 
            (load_sel[2] ? {16'b0,shifted_rdata[15:0]} : {{16{shifted_rdata[15]}},  shifted_rdata[15:0]}) :     // LH / LHU/
        (load_sel[2] ? {24'b0, shifted_rdata[7:0]} : {{24{shifted_rdata[7]}},  shifted_rdata[7:0]});            // LB / LBU

endmodule