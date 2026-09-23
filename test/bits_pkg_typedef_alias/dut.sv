// `$bits(pkg::T)` where T is a typedef OF ANOTHER PACKAGE TYPEDEF.
//
// Surelog folds the plain `$bits(pk::base_t)` to a constant before the reader
// sees it, but an ALIAS arrives unfolded, as a `ref_obj (pk::alias_t)` with no
// vpiActual.  Nothing then resolves it -- it is not a variable, a net, or a
// module signal -- so it fell through to the unknown-signal fallback, $bits
// answered 1, and every port sized by it became ONE BIT.
//
// In the wild: the generated AXI wrappers size each flat port with
// `logic [$bits(pkg::port_t)-1:0]`, so read_uhdm gave them width 1 against
// read_slang's 220/86 and the miter could not even be built --
// "No matching port in gate module was found for \mst_resp_i_flat".
//
// The package's typespecs are already indexed by name, so the fix is to
// consult that index before giving up.
package pk;
  typedef struct packed {
    logic [31:0] a;
    logic [15:0] b;
    logic        c;
  } base_t;                       // 49 bits
  typedef base_t alias_t;         // the alias is what breaks
endpackage

module dut (
  input  logic [$bits(pk::alias_t)-1:0] d_i,   // must be 49, was 1
  input  logic [$bits(pk::base_t)-1:0]  e_i,   // control: always worked
  output logic [$bits(pk::alias_t)-1:0] q_o,
  output logic                          p_o
);
  pk::alias_t v;
  assign v   = d_i;
  assign q_o = v;
  assign p_o = ^e_i;
endmodule
