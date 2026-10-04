// An instance of a module NOBODY defines.  Surelog only warns ("Cannot find
// a module definition") and hands over an instance whose definition is a
// scoped placeholder; read_uhdm used to import that as an EMPTY module, so
// the design "read" and even scored "0 undriven" -- an empty cell has
// nothing undriven -- while read_slang and Verilator both refused the same
// sources (caliptra-ss's vendored OpenTitan ast/ files without their prim_*
// library).  read_uhdm must refuse too and name the module; the harness's
// `expect_read_error.txt` makes that refusal this test's PASS.
module dut (input clk_i, input en_i, output clk_o, output [3:0] q);
  prim_clock_buf u_buf (.clk_i(clk_i), .clk_o(clk_o));
  reg [3:0] cnt;
  always @(posedge clk_i) if (en_i) cnt <= cnt + 1;
  assign q = cnt;
endmodule
