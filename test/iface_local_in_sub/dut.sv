// Minimal repro for: a local interface instance declared inside a non-top
// module needs per-field flattening.  Surelog's AllModules form of `sub`
// stores the interface as a plain `logic_net` placeholder — only the
// elaborated `top.u_sub` carries the proper `interface_inst`.  Without
// the augmentation, the frontend emits a bare 1-bit wire and downstream
// hier_path reads stay undriven.
interface my_iface;
    logic a;
    logic [3:0] b;
endinterface

module sub (output logic out_a, output logic [3:0] out_b);
    my_iface inst();
    assign inst.a = 1'b1;
    assign inst.b = 4'b1010;
    assign out_a = inst.a;
    assign out_b = inst.b;
endmodule

module top (output logic out_a, output logic [3:0] out_b);
    sub u_sub(.out_a(out_a), .out_b(out_b));
endmodule
