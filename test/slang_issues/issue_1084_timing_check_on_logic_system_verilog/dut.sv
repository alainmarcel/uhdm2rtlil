// MikePopoloski/slang#1084 (closed): Timing check on "logic" System Verilog port
// https://github.com/MikePopoloski/slang/issues/1084
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
`timescale 1ps/1ps

module clk_gate_and #(
    parameter G_FPGA_TYPE = "BUFG"  // bypass clock gate for FPGA target
) (
        input  logic clk_in,
        input  logic clk_en,

        output logic clk_out
    );

    always_comb
    begin
        clk_out = clk_en & clk_in;
    end
  
// synthesis translate_off
`ifndef TS_CMN_BLOCKS_SYNTHESIS

    specify
        specparam setup = 10;
        specparam hold = 10;

        $setup(posedge clk_in, clk_en, setup);
        $hold(posedge clk_in, clk_en, hold);
    endspecify

`endif
// synthesis translate_on

endmodule

