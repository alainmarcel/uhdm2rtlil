// Root #2 (naming): a module with a struct/type parameter whose value doesn't
// elaborate to an integer (like the degu's `isa_t ISA`) gets an empty param in
// the cell type ("\ISA=") that the module-def name OMITS -> cell/def mismatch ->
// blackbox -> not flattened -> outputs undriven.
typedef struct packed { logic [3:0] a; logic [3:0] b; } cfg_t;
module core #(parameter cfg_t CFG = '{a: 4'd5, b: 4'd3}, parameter int N = 2)
            (input logic [3:0] x, output logic [3:0] o);
  assign o = x ^ CFG.a;          // depends on the struct param
endmodule
module dut (input logic [3:0] x, output logic [3:0] o);
  core #(.N(2)) c (.x(x), .o(o));
endmodule
