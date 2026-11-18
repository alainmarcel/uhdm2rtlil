// povik/sv-elab#33 (closed): Bit-typed variables with unpacked dimensions crash the frontend
// https://github.com/povik/sv-elab/issues/33
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top (__o__bit_0, __o__bit_1, __o__bit_2, __o__bit_3, __o__bit_4, __o__bit_5, __o__bit_6, __o__bit_7);

bit _bit [7:0];
logic _logic [7:0];
reg _reg [7:0];


  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o__bit_0;
  output logic __o__bit_1;
  output logic __o__bit_2;
  output logic __o__bit_3;
  output logic __o__bit_4;
  output logic __o__bit_5;
  output logic __o__bit_6;
  output logic __o__bit_7;
  assign __o__bit_0 = _bit[0];
  assign __o__bit_1 = _bit[1];
  assign __o__bit_2 = _bit[2];
  assign __o__bit_3 = _bit[3];
  assign __o__bit_4 = _bit[4];
  assign __o__bit_5 = _bit[5];
  assign __o__bit_6 = _bit[6];
  assign __o__bit_7 = _bit[7];
endmodule

