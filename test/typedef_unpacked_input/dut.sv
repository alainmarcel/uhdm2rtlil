// Reproduction of a port-typedef pattern from a CCSDS turbo-encoder
// design: an unpacked array of typedef'd vectors as a module input,
// plus an output of the same typedef element type so observability
// can be checked through a port.
//
// Original (port-only, non-synthesizable) form:
//   module ccsds_turbo_enc_paddr_gen(iP);
//     parameter int cW = 14;
//     typedef logic [cW-1 : 0] ptab_dat_t;
//     input  ptab_dat_t iP [4];
//   endmodule
//
// The unpacked-array input is observed by selecting one element with
// a runtime `sel` index — no whole-array port pass-through (yet).

module ccsds_turbo_enc_paddr_gen
#(
    parameter int cW = 14
)
(
    input  logic [cW-1:0] iP [4],
    input  logic    [1:0] sel,
    output logic [cW-1:0] o
);
    typedef logic [cW-1:0] ptab_dat_t;
    ptab_dat_t observed;
    assign observed = iP[sel];
    assign o = observed;
endmodule
