// Literal-SIZE interface-array instantiation `myif m[2]` must create exactly TWO
// instances (m[0], m[1]).  Surelog used to elaborate THREE (m[0..2]); fixed in
// the Surelog submodule (DesignElaboration size-vs-range unpacked dimension).
interface myif (input logic clk);
  logic [7:0] d;
  modport mp (input clk, output d);
endinterface

module child (myif.mp p, input logic [7:0] v);
  assign p.d = v;
endmodule

module dut (input logic clk, input logic [7:0] v0, input logic [7:0] v1,
            output logic [15:0] o);
  myif m[2] (.clk(clk));
  child c0 (.p(m[0]), .v(v0));
  child c1 (.p(m[1]), .v(v1));
  assign o = {m[1].d, m[0].d};
endmodule
