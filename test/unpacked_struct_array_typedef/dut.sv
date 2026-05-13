// Minimal exercise of three nested typedefs from a bug-report snippet:
//
//   typedef bit [7:0] foo_t;                  // 8-bit packed
//   typedef struct { foo_t f [7]; } bar_t;    // (unpacked) struct holding
//                                             // an unpacked array of 7
//                                             // foo_t elements
//   typedef bar_t foobar_t [2];               // unpacked array of 2 bar_t
//
// The original snippet had no inputs/outputs and never instantiated a
// variable of any of these types, so the typedefs were never elaborated
// past the declaration.  Rewrapped with an input that drives one element
// (fb[0].f[0]) and an output that reads it back, so the workflow has
// something to compute.

module top(
    input  logic [7:0] in_i,
    output logic [7:0] out_o
);
    typedef bit [7:0] foo_t;

    typedef struct {
        foo_t f [7];
    } bar_t;

    typedef bar_t foobar_t [2];

    foobar_t fb;

    assign fb[0].f[0] = in_i;
    assign out_o      = fb[0].f[0];
endmodule
