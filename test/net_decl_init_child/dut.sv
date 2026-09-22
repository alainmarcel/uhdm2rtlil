// A net-declaration initialiser (`wire t = expr;`) inside a CHILD module.
//
// Surelog turns such an initialiser into a cont_assign only during netlist
// elaboration, so it appears on the elaborated INSTANCE and NOT on the
// AllModules module definition -- and module bodies are imported from the
// definition, the elaborated pass only creating cells.  The top module
// therefore kept its initialisers while every child silently lost them.
//
// Hand-written RTL rarely notices (it drives with `assign`), but firtool emits
// nearly all combinational logic this way: XiangShan's TLBFA kept 19 of its
// 507 connects as a child of TLB, with 2038 undriven nets.
module leaf(input a, input b, input c, output o_and, output o_chain, output [3:0] o_vec);
  wire       t1 = a & b;            // initialiser feeding an output directly
  wire       t2 = t1 | c;           // ... and feeding another initialiser
  wire [3:0] t3 = {t2, t1, b, a};   // ... a vector one
  assign o_and   = t1;
  assign o_chain = t2;
  assign o_vec   = t3;
endmodule

module mid(input a, input b, input c, output o_and, output o_chain, output [3:0] o_vec);
  // one level deeper, so the recovery is exercised below the top's children too
  leaf u_leaf(.a(a), .b(b), .c(c), .o_and(o_and), .o_chain(o_chain), .o_vec(o_vec));
endmodule

module dut(input a, input b, input c,
           output o_and, output o_chain, output [3:0] o_vec,
           output o_top);
  // The top's OWN initialiser always worked -- keep one here so the test would
  // also catch a regression that broke it.
  wire t_top = a ^ b ^ c;
  assign o_top = t_top;
  mid u_mid(.a(a), .b(b), .c(c), .o_and(o_and), .o_chain(o_chain), .o_vec(o_vec));
endmodule
