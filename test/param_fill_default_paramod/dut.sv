// A child instance whose `bit [W-1:0] MASK = '1` parameter (all-ones fill
// default, width from another parameter) is NOT overridden.  The $paramod cell
// type must encode MASK the same as the module definition: the elaborated value
// is 2^W-1 (BIN:111..1), which std::stoi overflows/throws on for W=32 -> the old
// code fell back to zeros, making the cell type differ from the definition
// (blackbox / "Target module not found") — the rp32 mouse SoC gpio SYS_IRQ='1
// case that left gpio_o undriven.
module child #(
  parameter int           W    = 8,
  parameter bit           MIN  = 1'b0,
  parameter bit [W-1:0]   IEN  = '0,
  parameter bit [W-1:0]   MASK = '1
) (input logic [W-1:0] a, output logic [W-1:0] o);
  assign o = (a & MASK) | IEN;   // MASK all-ones -> o = a
endmodule

module param_fill_default_paramod #(parameter int W = 32) (
  input  logic [W-1:0] a,
  output logic [W-1:0] o
);
  generate if (1) begin : gen_c
    child #(.W(W), .MIN(1'b1)) u (.a(a), .o(o));   // IEN/MASK defaulted
  end endgenerate
endmodule
