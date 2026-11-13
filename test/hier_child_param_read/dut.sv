// sv-elab regress.sv r33 (sv-elab#423): a PARAMETER of a child instance
// read through a hierarchical reference.  Surelog binds neither path
// element, and read_uhdm resolved `u.P[1]` as a struct member and drove X.
// The ascending (`P[2]`, `[0:1]`) and descending (`[1:0]`) unpacked arrays
// pick element k by their declared range; a scalar parameter reads whole.
module leaf #(parameter int P[2] = '{0, 3},
              parameter int D[1:0] = '{5, 7},
              parameter int S = 9) ();
endmodule
module top(output logic [31:0] w, output logic [31:0] v,
           output logic [31:0] d1, output logic [31:0] s);
  leaf u ();
  leaf #(.P('{11, 12})) o ();
  assign w  = u.P[1];
  assign v  = o.P[0];
  assign d1 = u.D[1];
  assign s  = u.S;
endmodule
