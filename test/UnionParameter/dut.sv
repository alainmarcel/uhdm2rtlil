package some_package; // verilog_lint: waive package-filename
typedef union packed {
  logic [3:0] bunn1_t;
  logic [3:0] bunn2_t;
} flimish_giant;

/* verilator lint_off WIDTHTRUNC */
parameter flimish_giant LovingHome = '{default: 1};
/* verilator lint_on WIDTHTRUNC */
endpackage : some_package

// Restructured to be observable.  This is a UHDM-only test: the Yosys Verilog
// frontend cannot parse a union-typed parameter with an assignment-pattern
// initializer, so equivalence is verified against Verilator co-sim instead.
// `'{default: 1}` sets every union member to 1; for this 4-bit packed union the
// resolved value is 4'd1, so `LovingHome.bunn1_t == 4'd1`.
module top(input [3:0] din, output [3:0] o);
   assign o = some_package::LovingHome.bunn1_t ^ din;
endmodule
