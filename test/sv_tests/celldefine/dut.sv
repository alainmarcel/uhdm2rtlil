// Converted from chipsalliance/sv-tests (celldefine).
// Upstream declares one EMPTY module inside the `celldefine region and one outside it, so neither the region nor the modules carry anything.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
`celldefine
module cd(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd1;
endmodule
`endcelldefine
module ncd(input logic [7:0] x, output logic [8:0] y);
  assign y = x + 8'd2;
endmodule
// A real top so both the celldefined module and the one outside the region are
// elaborated and observable.
module top(input logic [7:0] x, output logic [8:0] y_cd, output logic [8:0] y_ncd);
  cd  u_cd  (.x(x), .y(y_cd));
  ncd u_ncd (.x(x), .y(y_ncd));
endmodule
