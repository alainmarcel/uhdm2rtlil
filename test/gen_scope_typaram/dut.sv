// CVA6 id_stage genblk3[0].decoder_i: a `parameter type` module instantiated
// inside a GENERATE block.  import_instance built the cell type without the
// per-type-binding $typaram signature, so the cell referenced bare `\leaf`
// while the module was imported as `\leaf$typaram_...` -> unresolved blackbox
// that `hierarchy -check` rejects.
module leaf #(parameter type T = logic) (
    input  T d_i,
    output T d_o
);
    assign d_o = d_i;
endmodule

module gen_scope_typaram (
    input  logic [7:0] a,
    output logic [7:0] o
);
    typedef struct packed { logic [3:0] x; logic [3:0] y; } pair_t;
    for (genvar i = 0; i < 1; i++) begin : blk
        leaf #(.T(pair_t)) u (.d_i(a), .d_o(o));
    end
endmodule

module tb;
    logic [7:0] a, o;
    gen_scope_typaram t (.a(a), .o(o));
endmodule
