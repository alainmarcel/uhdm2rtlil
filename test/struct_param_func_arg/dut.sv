package p;
  typedef struct packed { int unsigned n; logic [63:0] base; } cfg_t;
  function automatic cfg_t build();
    cfg_t c;
    c.n    = 3;
    c.base = 64'h1000;
    return c;
  endfunction
  // struct param passed as a FUNCTION ARGUMENT; field read from the formal
  function automatic logic in_region(cfg_t C, logic [63:0] a);
    if (C.n != 0) return (a >= C.base);
    else          return 1'b1;
  endfunction
endpackage

module dut #(parameter p::cfg_t CFG = p::build()) (
    input  logic [63:0] a_i,
    output logic        o_fn,      // via the function argument
    output logic [31:0] o_direct   // direct module-scope field read
);
  assign o_fn     = p::in_region(CFG, a_i);
  assign o_direct = CFG.n;
endmodule
