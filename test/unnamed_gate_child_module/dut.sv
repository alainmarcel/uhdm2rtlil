// An UNNAMED gate instance (LRM 28.3.4) inside a CHILD module.  Surelog's
// module definition lost the gate's first terminal (and dropped other unnamed
// gates outright); read_uhdm imported child bodies from that definition and
// stopped with "Gate has insufficient terminals".  pulpissimo hyper_macro via
// tech_cells_generic pad_functional_pd (`buf (O, PAD);`), openpiton SRAM models.
module child (input logic a, b, c, output logic y, z, w, o1, o2, n);
  and  (y, a, b);
  xor  (z, a, b, c);
  not  (w, c);
  buf  (o1, o2, a);          // multi-output buf: every output but the last
  nand g_named (n, b, c);    // a named gate keeps working
endmodule

module dut (input logic a, b, c,
            output logic y0, z0, w0, p0, q0, n0,
            output logic y1, z1, w1, p1, q1, n1);
  child u0 (.a(a),  .b(b), .c(c), .y(y0), .z(z0), .w(w0), .o1(p0), .o2(q0), .n(n0));
  child u1 (.a(~a), .b(c), .c(b), .y(y1), .z(z1), .w(w1), .o1(p1), .o2(q1), .n(n1));
endmodule
