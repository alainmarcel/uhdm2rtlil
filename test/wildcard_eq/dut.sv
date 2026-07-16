// Wildcard equality `==?`: bits where the RHS pattern is x/z are don't-care.
// (rp32 tcb_lite_lib_decoder address match `adr ==? DAM[i]`, DAM has x wildcards.)
module wildcard_eq (
    input  logic [31:0] adr,
    output logic        mch_per,   // peripheral match (0x8002_0000 region)
    output logic        mch_mem    // data-memory match (0x8000_0000 region)
);
    localparam logic [31:0] DAM_PER = {12'h800, 4'b001x, 16'bxxxx_xxxx_xxxx_xxxx};
    localparam logic [31:0] DAM_MEM = {12'h800, 4'b000x, 16'bxxxx_xxxx_xxxx_xxxx};
    assign mch_per = adr ==? DAM_PER;
    assign mch_mem = adr ==? DAM_MEM;
endmodule
