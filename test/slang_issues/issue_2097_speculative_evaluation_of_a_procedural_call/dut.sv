// MikePopoloski/slang#2097 (closed): Speculative evaluation of a procedural call reports index-oob from inside the called function
// https://github.com/MikePopoloski/slang/issues/2097
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module t (__o_v);
  function automatic logic f(logic [9:0] p0, logic [1:0] p1);
    return p0[p1];
  endfunction
  logic [7:0] v;
  always @(*) v = f(10'd5, 2'b0z);

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [7:0] __o_v;
  assign __o_v = v;
endmodule

