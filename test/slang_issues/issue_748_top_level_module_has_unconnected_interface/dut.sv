// MikePopoloski/slang#748 (closed): top-level module has unconnected interface port
// https://github.com/MikePopoloski/slang/issues/748
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
interface some_if;
logic a;
logic b;
modport master (input a, output b);
modport slave (output a, input b);
endinterface;

// ---- b1.sv
module dut_dummy(
  some_if.master my_if,
  output c
);
assign my_if.b = 0;
assign c = my_if.a;
endmodule

// ---- b2.sv
module tb (__o_c);
logic c;
some_if my_if();
dut_dummy dut (.my_if(my_if.master), .c(c));
initial begin
  my_if.a = 1;
end

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_c;
  assign __o_c = c;
endmodule

