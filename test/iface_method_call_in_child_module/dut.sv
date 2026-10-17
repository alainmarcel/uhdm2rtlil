// A method called on an interface INSTANCE declared in a module that is
// itself a CHILD (imported from the definition view, whose Interfaces() are
// empty): tnoc's AXI write/read mux instantiates tbcm_round_robin_arbiter,
// whose `u_selector.mux(...)` resolved at the top of its own row and not
// one level down.
interface sel #(parameter int WIDTH = 8, parameter int ENTRIES = 2);
  function automatic logic [WIDTH-1:0] mux(logic [ENTRIES-1:0] s, logic [ENTRIES-1:0][WIDTH-1:0] d);
    logic [WIDTH-1:0] r;
    r = '0;
    for (int i = 0; i < ENTRIES; i++) if (s[i]) r = r | d[i];
    return r;
  endfunction
endinterface

module mid (input logic [1:0] s, input logic [1:0][3:0] d, output logic [3:0] y);
  sel #(.WIDTH(4), .ENTRIES(2)) u_sel();
  assign y = u_sel.mux(s, d);
endmodule

module top (input logic [1:0] s, input logic [1:0][3:0] d, output logic [3:0] y);
  mid m (.s(s), .d(d), .y(y));
endmodule
