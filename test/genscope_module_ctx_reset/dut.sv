// Reproducer for the CVA6 module-context-leak segfault: a parent module whose
// own generate-scope continuous assign (referencing a parameter) is imported
// AFTER a child instance whose hierarchy import overwrote the current RTLIL
// `module`.  Without restoring `module` across child imports, the parent's
// later gen-scope logic resolves parameters against a stale/null module and
// segfaults in import_ref_obj.
module gchild #(parameter int GW = 1) (
    input  logic [GW-1:0] gi,
    output logic          go
);
  assign go = ^gi;
endmodule

module child #(parameter int CW = 2) (
    input  logic [CW-1:0] ci,
    output logic          co
);
  logic g;
  gchild #(.GW(CW)) u_g (.gi(ci), .go(g));   // grandchild -> hierarchy recursion
  assign co = g;
endmodule

module genscope_module_ctx_reset #(parameter int WIDTH = 8) (
    input  logic [WIDTH-1:0] in_i,
    output logic             c_o,
    output logic [WIDTH-1:0] p_o
);
  // gen scope 1: child instance (drives `module` through hierarchy recursion)
  if (WIDTH > 1) begin : gen_inst
    child #(.CW(4)) u_c (.ci(in_i[3:0]), .co(c_o));
  end
  // gen scope 2: continuous assign referencing the top PARAMETER, imported
  // AFTER the child — must see `module` restored to this parent.
  if (WIDTH > 1) begin : gen_use
    assign p_o = in_i ^ {WIDTH{1'b1}};
  end
endmodule
