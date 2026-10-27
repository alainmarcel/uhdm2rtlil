// A CONCATENATION LHS whose operands are elements of an unpacked array picked
// by the enclosing GENERATE loop's genvar.
//
// Every access to `prio` and `unused` uses a constant index (the genvar is one),
// so neither becomes a `$mem`: both are materialised as per-element registers
// \prio[0], \prio[1], ... and there is NO \prio wire at all.  The scan that
// allocates the always_ff temp wires therefore has to name the ELEMENT, and
// for a concat operand the index arrives as a `ref_obj` bound to the
// per-generate-instance parameter holding the iteration value -- not as a
// literal constant.  Resolving only literals left the bare array name `prio`,
// which is not a wire, and the read ABORTED with
//
//     ERROR: Signal prio not found in module
//
// taking down the whole module.  This is OpenC910's ct_prio, the round-robin
// priority matrix instantiated by nine ct_ciu_* units, reduced: the reset arm
// writes both arrays' row i through one concatenation.
module varsel_concat_genvar_elem #(parameter NUM = 4) (
  input                  clk,
  input                  rst_b,
  input  [NUM-1:0]       valid,
  input                  clr,
  output [NUM-1:0]       sel
);
  reg [NUM-1:0] prio   [NUM-1:0];
  reg [NUM-1:0] unused [NUM-1:0];
  wire [NUM-1:0] clr_bus = {NUM{clr}} & sel;

  genvar i;
  generate
    for (i = 0; i < NUM; i = i + 1) begin : PRIO_MATRIX_GEN
      always @(posedge clk or negedge rst_b) begin
        if (!rst_b)
          {prio[i][NUM-1:0], unused[i][NUM-1:0]} <= {{NUM{1'b0}}, {NUM{1'b1}}} << i;
        else if (|clr_bus)
          prio[i][NUM-1:0] <= (clr_bus == ({{(NUM-1){1'b0}}, 1'b1} << i))
                            ? ~clr_bus
                            : prio[i][NUM-1:0] & ~clr_bus;
      end
    end
  endgenerate

  generate
    for (i = 0; i < NUM; i = i + 1) begin : SEL_GEN
      assign sel[i] = valid[i] && !(|(valid & prio[i][NUM-1:0]));
    end
  endgenerate
endmodule
