// An ELEMENT of an interface-ARRAY element's packed-struct-array member
// written in an always_comb -- tnoc's packet serializer building its
// header flit:
//
//     tnoc_flit_if flit_if[3](types);          // tnoc_flit [FLITS-1:0] flit
//     always_comb begin
//       flit_if[0].flit[0] = '{ flit_type: TNOC_HEADER_FLIT, ... };
//
// The element writer accepted only a plain port as the base; with an
// interface-array ELEMENT (`flit_if[0]`, a bit_select) it declined and the
// write fell to the struct-array element-field writer, which drove ONE bit:
// the header flit (291 bits) stayed undriven all the way into the flit mux.
//
// UHDM-only (interfaces); test_slang_equiv.ys proves the flattened
// members against read_slang -- without the fix thirty of each thirty-two
// bits are undriven.
interface flit_if #(parameter int CH = 2);
  typedef struct packed { logic head; logic tail; logic [13:0] data; } flit_t;
  logic  [CH-1:0] valid;
  flit_t [CH-1:0] flit;
endinterface

module top (
  input  logic [13:0]      i_data0, i_data1,
  input  logic             i_sel,
  output logic [1:0][15:0] o_flit0,
  output logic [1:0][15:0] o_flit2
);
  flit_if f[3]();
  always_comb begin
    f[0].flit[0] = '{head: 1'b1, tail: 1'b0, data: i_data0};
    f[0].flit[1] = '{head: 1'b0, tail: 1'b1, data: i_data1};
    f[2].flit[0] = i_sel ? f[0].flit[1] : f[0].flit[0];
    f[2].flit[1] = '{head: i_sel, tail: ~i_sel, data: i_data0 ^ i_data1};
  end
  assign o_flit0 = f[0].flit;
  assign o_flit2 = f[2].flit;
endmodule
