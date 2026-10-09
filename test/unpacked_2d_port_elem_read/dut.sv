// An element read of a 2-D UNPACKED PORT with packed elements -- RSD's
// ReadyBitTable:
//
//     input logic [REG_NUM_BIT_WIDTH-1:0] dispatchedSrcRegNum [DISPATCH_WIDTH][SRC_OP_NUM],
//     ...
//     readyRA[i*SRC_OP_NUM + j] = dispatchedSrcRegNum[i][j];
//
// read_uhdm materialises such a port as a flat vector plus linear element
// wires, and the var_select read of `x[i][j]` has a 2-D handler keyed on
// the geometry attributes the internal 2-D arrays carry
// (unpacked_outer_low / inner_low / inner_size).  The port import stamped
// only the element count and width, so that handler never matched and the
// read took the FIRST index as the element and the second as a BIT of it:
// every 5-bit register number read as one bit (5'00001 for all-ones) and
// ReadyBitTable's ready lookups addressed the wrong entries.  The port now
// carries the same geometry.  Inputs stay a packed vector in the miter
// through the harness shim (the two frontends flatten a 2-D unpacked port
// in different element orders).
module unpacked_2d_port_elem_read(
    input  logic [4:0] x [2][2],
    output logic [4:0] o00, o01, o10, o11,
    output logic [4:0] ra_sum
);
    logic [4:0] ra [4];
    always_comb for (int i = 0; i < 2; i++) for (int j = 0; j < 2; j++) ra[i*2 + j] = x[i][j];
    assign o00 = x[0][0];
    assign o01 = x[0][1];
    assign o10 = x[1][0];
    assign o11 = x[1][1];
    assign ra_sum = ra[0] + ra[1] + ra[2] + ra[3];
endmodule
