module control (
    input clk,
    input i_rst,
    input  wire [31:0] i_imem_rdata,
    output wire jump,
    output wire jalr,
    output wire branch,
    output wire [2:0] branch_type,
    output wire [1:0] rd_dest_select,
    output wire mem_wr,
    output wire mem_rd,
    output wire [2:0] i_opsel,
    output wire i_arith,
    output wire i_unsigned,
    output wire i_sub,
    output wire auipc,
    output wire i_alu_src,
    output wire i_rd_wen
    output wire [5:0] i_format
);
wire [6:0] opcode = i_imem_rdata[6:0];
wire [2:0] funct3 = i_imem_rdata[14:12];
wire [6:0] funct7 = i_imem_rdata[31:25];

always @(*) begin
    if(opcode == 7'b0110011) begin // R-type
        mem_wr = 0;
        mem_rd = 0;
        i_opsel = funct3;
        i_arith = (funct3 == 3'b101) ? funct7[5] : 0;
        i_sub = (funct3 == 3'b000) ? funct7[5] : 0;
        i_unsigned = (funct3 == 3'b011) ? 1 : 0;
        auipc = 0;
        i_alu_src = 1;
        i_rd_wen = 1;
    end else if(opcode == 7'b0010011) begin // I-type 
        jump = 0;
        jalr = 0;


    end




end    
endmodule