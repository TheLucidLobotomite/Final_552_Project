module control (
    input wire [31:0] i_imem_rdata,
    output reg jump,
    output reg jalr,
    output reg branch,
    output reg [2:0] branch_type,
    output reg [1:0] rd_dest_select,
    output reg [2:0] store_sel,
    output reg [2:0] load_sel,
    output reg o_dmem_ren,
    output reg o_dmem_wen,
    output reg [2:0] i_opsel,
    output reg i_arith,
    output reg i_unsigned,
    output reg i_sub,
    output reg auipc,
    output reg i_alu_src,
    output reg i_rd_wen,
    output reg [5:0] i_format
);
wire [6:0] opcode = i_imem_rdata[6:0];
wire [2:0] funct3 = i_imem_rdata[14:12];
wire [6:0] funct7 = i_imem_rdata[31:25];

always @(*) begin
    if(opcode == 7'b0110011) begin // R-type
        jump = 0;
        jalr = 0;
        branch = 0;
        branch_type = 3'b000;
        rd_dest_select = 2'b00;
        o_dmem_wen = 0;
        o_dmem_ren = 0;
        i_opsel = funct3;
        i_arith = (funct3 == 3'b101) ? funct7[5] : 0;
        i_sub = (funct3 == 3'b000) ? funct7[5] : 0;
        i_unsigned = (funct3 == 3'b011);
        auipc = 0;
        i_alu_src = 1;
        i_rd_wen = 1;
        i_format = 6'b000001;
    end else if(opcode == 7'b0010011) begin // Arithmetic I-type
        jump = 0;
        jalr = 0;
        branch = 0;
        branch_type = 3'b000;
        rd_dest_select = 2'b00;
        o_dmem_wen = 0;
        o_dmem_ren = 0;
        i_opsel = funct3;
        i_arith = (funct3 == 3'b101) ? funct7[5] : 0;
        i_sub = 0;
        i_unsigned = (funct3 == 3'b011) ? 1 : 0;
        auipc = 0;
        i_alu_src = 0;
        i_rd_wen = 1;
        i_format = 6'b000010;
    end else if(opcode == 7'b0110111) begin // U-type LUI
        jump = 0;
        jalr = 0;
        branch = 0;
        branch_type = 3'b000;
        rd_dest_select = 2'b01;
        o_dmem_wen = 0;
        o_dmem_ren = 0;
        i_opsel = 3'b000; 
        i_arith = 0;
        i_sub = 0;
        i_unsigned = 0;
        auipc = 0;
        i_alu_src = 0;
        i_rd_wen = 1;
        i_format = 6'b010000;
    end else if(opcode == 7'b0010111) begin // U-type AUIPC
        jump = 0;
        jalr = 0;
        branch = 0;
        branch_type = 3'b000;
        rd_dest_select = 2'b00;
        o_dmem_wen = 0;
        o_dmem_ren = 0;
        i_opsel = 3'b000; 
        i_arith = 0;
        i_sub = 0;
        i_unsigned = 0;
        auipc = 1;
        i_alu_src = 0;
        i_rd_wen = 1;
        i_format = 6'b010000;        
    end else if(opcode == 7'b0000011) begin // I-type load
        jump = 0;
        jalr = 0;
        branch = 0;
        branch_type = 3'b000;
        rd_dest_select = 2'b11;
        load_sel = funct3;
        o_dmem_wen = 0;
        o_dmem_ren = 1;
        i_opsel = 3'b000;
        i_arith = 0;
        i_sub = 0;
        i_unsigned = 0;
        auipc = 0;
        i_alu_src = 0;
        i_rd_wen = 1;
        i_format = 6'b000010;
    end else if(opcode == 7'b0100011) begin // S-type
        jump = 0;
        jalr = 0;
        branch = 0;
        branch_type = 3'b000;
        store_sel = funct3;
        o_dmem_wen = 1;
        o_dmem_ren = 0;
        i_opsel = 3'b000;
        i_arith = 0;
        i_sub = 0;
        i_unsigned = 0;
        auipc = 0;
        i_alu_src = 0;
        i_rd_wen = 0;
        i_format = 6'b000100;
    end else if(opcode == 7'b1100011) begin // B-type
        jump = 0;
        jalr = 0;
        branch = 1;
        branch_type = funct3;
        o_dmem_wen = 0;
        o_dmem_ren = 0;
        i_opsel = 3'b000;
        i_arith = 0;
        i_sub = 0;
        i_unsigned = (funct3[1]) ? 1 : 0; 
        auipc = 0;
        i_alu_src = 1;
        i_rd_wen = 0;
        i_format = 6'b001000;
    end else if(opcode == 7'b1101111) begin // J-type JAL
        jump = 1;
        jalr = 0;
        branch = 0;
        branch_type = 3'b010;
        rd_dest_select = 2'b10;
        o_dmem_wen = 0;
        o_dmem_ren = 0;
        i_opsel = 3'b000;
        i_arith = 0;
        i_sub = 0;
        i_unsigned = 0;
        auipc = 0;
        i_alu_src = 0;
        i_rd_wen = 1;
        i_format = 6'b100000;        
    end else if(opcode == 7'b1100111) begin // I-type JALR
        jump = 0;
        jalr = 1;
        branch = 0;
        rd_dest_select = 2'b10;
        o_dmem_wen = 0;
        o_dmem_ren = 0;
        i_opsel = 3'b000; 
        i_arith = 0;
        i_sub = 0;
        i_unsigned = 0;
        auipc = 0;
        i_alu_src = 0; 
        i_rd_wen = 1;
        i_format = 6'b000010;        
    end else begin 
        printf("Unsupported instruction with opcode %b\n", opcode);
        $stop;    
    end
end    
endmodule