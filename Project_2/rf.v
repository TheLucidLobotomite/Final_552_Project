`default_nettype none

// The register file is effectively a single cycle memory with 32-bit words
// and depth 32. It has two asynchronous read ports, allowing two independent
// registers to be read at the same time combinationally, and one synchronous
// write port, allowing a register to be written to on the next clock edge.
// The register `x0` is hardwired to zero, and writes to it are ignored.
module rf #(
    // When this parameter is set to 1, "RF bypass" mode is enabled. This
    // allows data at the write port to be observed at the read ports
    // immediately without having to wait for the next clock edge. This is
    // a common forwarding optimization in a pipelined core (project 5), but
    // will cause a single-cycle processor to behave incorrectly.
    //
    // You are required to implement and test both modes. In project 3 and 4,
    // you will set this to 0, before enabling it in project 5.
    parameter BYPASS_EN = 0
) (
    
    input  wire        i_clk,		// Global clock.
    input  wire        i_rst,		// Synchronous active-high reset.
	
    // Both read register ports are asynchronous (zero-cycle). That is, read
    // data is visible combinationally without having to wait for a clock.
    input  wire [ 4:0] i_rs1_raddr,	// Register read port 1, with input address [0, 31] and output data.
    output wire [31:0] o_rs1_rdata,
    input  wire [ 4:0] i_rs2_raddr,	// Register read port 2, with input address [0, 31] and output data.
    output wire [31:0] o_rs2_rdata,
	
    // The register write port is synchronous. When write is enabled, the
    // write data is visible after the next clock edge.
    input  wire        i_rd_wen,	// Write register enable, address [0, 31] and input data.
    input  wire [ 4:0] i_rd_waddr,
    input  wire [31:0] i_rd_wdata
);
	// Need register storage
	reg [31:0] register [31:0];
	integer i; // Need this for my loop
	
	// Internal wires for register read data (before bypass logic)
	wire [31:0] rs1_reg_data;
	wire [31:0] rs2_reg_data;

	always @(posedge i_clk) begin
    if (i_rst) begin
        // Thankfully we can use loop here otherwise 32 lines of copy paste lol
		// I think the loop will be unrolled to the 32 lines during synthesis, but if I am wrong... oh well
        for (i = 0; i < 32; i = i + 1) begin
            register[i] <= 32'b0;
        end
    end else if (i_rd_wen && i_rd_waddr != 5'b0) begin
        register[i_rd_waddr] <= i_rd_wdata;
    end
end
	
	// Read from register file (without bypass)
	assign rs1_reg_data = (i_rs1_raddr == 5'b0) ? 32'b0 : register[i_rs1_raddr];
	assign rs2_reg_data = (i_rs2_raddr == 5'b0) ? 32'b0 : register[i_rs2_raddr];
	
	// Apply bypass logic if enabled
	generate
		if (BYPASS_EN) begin
			// With bypass: if writing to the same register being read, forward the write data
			assign o_rs1_rdata = (i_rd_wen && (i_rd_waddr == i_rs1_raddr) && (i_rd_waddr != 5'b0)) ? i_rd_wdata : rs1_reg_data;
			assign o_rs2_rdata = (i_rd_wen && (i_rd_waddr == i_rs2_raddr) && (i_rd_waddr != 5'b0)) ? i_rd_wdata : rs2_reg_data;
		end else begin
			// Without bypass: just output the register data
			assign o_rs1_rdata = rs1_reg_data;
			assign o_rs2_rdata = rs2_reg_data;
		end
	endgenerate

endmodule

`default_nettype wire
