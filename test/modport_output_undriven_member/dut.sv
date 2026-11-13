// povik/sv-elab#414: a modport OUTPUT the module never drives.  `user`
// drives only `p.y`; its parent drives `p.x` itself.  read_uhdm keeps the
// module boundary, so `p.x` used to be an undriven OUTPUT port of `user`
// that the parent saw as a second driver of its own `assign p.x = 1'b1`,
// and `opt` aborted with "Cell port top.u.p.x is driving constant bits".
// The undriven member is now an INPUT of `user` (test_structural.ys).
interface ifc;
  logic x, y;
  modport mp (output x, output y);
endinterface

module user(ifc.mp p);
  assign p.y = 1'b0;
endmodule

module top(output logic x, output logic y);
  ifc p();
  user u(p);
  assign p.x = 1'b1;
  assign x = p.x;
  assign y = p.y;
endmodule
