// Reproducer for chipsalliance/synlig#1093
// (UHDM-integration-tests/tests/IndexedPartSelectOfArrayElement/top.sv).
// The DUT chains three constructs:
//   - an unpacked array of packed structs with an assignment-pattern
//     initializer (`tl_h2d_t a[1:0] = '{8'h12, 8'h34}`)
//   - a struct-member access on an array element (`a[0].source`)
//   - an indexed part-select with the `-:` operator
//     (`source[6 -: 2]`, i.e. `source[6:5]`)
//
// Per the upstream init order `a[1:0] = '{8'h12, 8'h34}`:
//     a[1] = 8'h12, a[0] = 8'h34
// so `a[0].source = 8'h34 = 8'b0011_0100` and
//    a[0].source[6:5] = 2'b11 = 2'd3 → expected `o == 2`'d3.
//
// The bare upstream DUT has no inputs (purely a static read of an
// initializer).  Added an `input [2:0] base` so co-sim can also
// observe a *dynamic* indexed part-select (`a[0].source[base -: 2]`)
// on `o2` — the construct under test (the `-:` operator) is the same
// shape, just with a runtime base.  A dynamic *element* index
// (`a[sel].source[…]`) is a separate feature (requires mux'ing the
// per-element wires) and is not part of this issue.
module top (
    input  logic [2:0] base,
    output logic [1:0] o,
    output logic [1:0] o2
);
   typedef struct packed {
      logic [7:0] source;
   } tl_h2d_t;

   tl_h2d_t a[1:0] = '{8'h12, 8'h34};

   assign o  = a[0].source[6 -: 2];
   assign o2 = a[0].source[base -: 2];
endmodule
