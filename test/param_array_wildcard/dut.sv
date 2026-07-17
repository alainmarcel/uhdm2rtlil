// A genvar-indexed packed-array PARAMETER whose elements carry x wildcards,
// used in `adr ==? DAM[i]` (rp32 tcb_lite_lib_decoder). Element extraction
// DAM[i] must preserve the defined bits of the x-pattern — else ==? sees an
// all-x mask and folds to constant 1 (every address "matches").
module decoder #(
    parameter int              IFN = 2,
    parameter logic [31:0]     DAM [IFN-1:0] = '{ 32'h0, 32'h0 }
)(
    input  logic [31:0] adr,
    output logic [IFN-1:0] mch
);
    for (genvar i=0; i<IFN; i++)
        assign mch[i] = adr ==? DAM[i];
endmodule

module param_array_wildcard (
    input  logic [31:0] adr,
    output logic [1:0]  mch
);
    // DAM[1] (UART) = bit6 must be 1; DAM[0] (GPIO) = bit6 must be 0; rest x.
    decoder #(
        .IFN (2),
        .DAM ({{17'bx, 15'bxx_xxxx_x1xx_xxxx},
               {17'bx, 15'bxx_xxxx_x0xx_xxxx}})
    ) u (.adr(adr), .mch(mch));
endmodule
