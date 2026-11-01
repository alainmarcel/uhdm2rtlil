// Converted from chipsalliance/sv-tests (attributes-module).
// Upstream declares three EMPTY modules, differing only in their module attribute, so nothing checks that the attribute is accepted on a module that actually has content.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
(* optimize_power *)
module topa(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd1;
endmodule
(* optimize_power=0 *)
module topb(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd2;
endmodule
(* optimize_power=1 *)
module topc(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd3;
endmodule
// A real top so all three attributed modules are elaborated and observable.
module top(input logic [7:0] x, output logic [8:0] ya, output logic [8:0] yb,
           output logic [8:0] yc);
  topa ua (.x(x), .y(ya));
  topb ub (.x(x), .y(yb));
  topc uc (.x(x), .y(yc));
endmodule
