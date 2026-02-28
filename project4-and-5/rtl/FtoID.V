module FtoID (
    input wire clk;
    input wire rst,
    input wire [31:0] i_pc,
    input wire [31:0] i_imem_rdata,
    output reg [31:0] o_pc,
    output reg [31:0] o_imem_rdata
);

// FtoID: Fetch to Instruction Decode Register
always @(posedge clk) begin
    if (rst) begin
        o_pc <= 32'b0;
        o_imem_rdata <= 32'b0;
    end else begin
        o_pc <= i_pc;
        o_imem_rdata <= i_imem_rdata;
    end
end

endmodule