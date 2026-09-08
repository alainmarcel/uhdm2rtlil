// A generate-scope-local unpacked array of ENUM type, assigned per-element and
// passed whole to a submodule port.  Before the is_memory_array enum fix, the
// enum array collapsed to a single 1-bit wire (only logic_typespec elements
// were recognised as packed), so the port connection zero-padded it and the
// element drivers dangled -> submodule read undriven.  This is the ibex_core
// g_pmp.pmp_req_type / pmp_priv_lvl (`pmp_req_e/priv_lvl_e [PMPNumChan]`) gap
// that made the whole-core cosim diverge deep in execution.
package genp;
  typedef enum logic [1:0] { A, B, C, D } e_t;
endpackage
module genscope_enum_array_sub #(parameter int N = 3)
  (input genp::e_t in_arr [N], output logic [1:0] o);
  assign o = in_arr[0] ^ in_arr[1] ^ in_arr[2];
endmodule
module genscope_enum_array_port(input logic [1:0] sel, output logic [1:0] o);
  import genp::*;
  if (1) begin : g
    e_t arr [3];
    assign arr[0] = A;
    assign arr[1] = sel[0] ? B : C;
    assign arr[2] = e_t'(sel);
    genscope_enum_array_sub #(.N(3)) u(.in_arr(arr), .o(o));
  end
endmodule
