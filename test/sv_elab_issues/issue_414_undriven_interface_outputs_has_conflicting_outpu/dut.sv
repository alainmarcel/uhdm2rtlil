// povik/sv-elab#414 (open): Undriven interface outputs has conflicting outputs due to 'x bits
// https://github.com/povik/sv-elab/issues/414
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
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

