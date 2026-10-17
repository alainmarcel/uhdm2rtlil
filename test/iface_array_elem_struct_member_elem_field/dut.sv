// A struct FIELD of an ELEMENT of an interface member that is a packed
// array of structs, read through an interface-array element -- tnoc's
// packet serializer:
//
//     tnoc_flit_if flit_if[3](types);          // tnoc_flit [FLITS-1:0] flit
//     if (flit_if[2].flit[0].tail) begin ...
//
// The struct-field hier_path branch accepted only [base, member, field...]
// with plain references after the base; a bit_select in the middle made it
// decline and the access fell to the struct decoder: "Could not resolve
// struct member access 'flit_if[2].flit[0].tail'" -> 1'x.  The member wire
// is now sliced by the array's element geometry and the field taken from
// the element's struct type.
//
// UHDM-only (interfaces); test_slang_equiv.ys proves the three reads
// against read_slang.
interface flit_if #(parameter int CH = 2);
  typedef struct packed { logic head; logic tail; logic [13:0] data; } flit_t;
  logic  [CH-1:0] valid;
  flit_t [CH-1:0] flit;
  modport sender (output valid, flit);
  modport receiver (input valid, flit);
  // UHDM-only: yosys's read_verilog rejects `return` (its own interface
  // elaboration disagrees with read_slang on this design anyway)
  function automatic logic any_valid();
    return |valid;
  endfunction
endinterface

module top (
  input  logic [2:0][1:0]       i_valid,
  input  logic [2:0][1:0][15:0] i_flit,
  output logic                  o_tail2, o_tail0,
  output logic [13:0]           o_data
);
  flit_if f[3]();
  for (genvar k = 0; k < 3; ++k) begin : g
    assign f[k].valid = i_valid[k];
    assign f[k].flit  = i_flit[k];
  end
  always_comb begin
    o_tail2 = f[2].flit[0].tail;
    o_tail0 = f[0].flit[1].tail;
    o_data  = f[1].flit[0].data;
  end
endmodule
