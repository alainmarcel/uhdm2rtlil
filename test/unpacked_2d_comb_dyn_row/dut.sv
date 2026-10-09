// A 2-D UNPACKED array of 1-bit elements written at a DYNAMIC row index in an
// always_comb -- RSD SourceCAM's dispatch update:
//
//     logic nextSrcReady[ ISSUE_QUEUE_ENTRY_NUM ][ SRC_OP_NUM ];
//     always_comb begin
//         for (i) for (j) nextSrcReady[i][j] = srcReady[i][j] || match[i][j];
//         for (i) for (j) if (dispatch[i])
//             nextSrcReady[ dispatchPtr[i] ][j] = dispatchedSrcReady[i][j];
//
// Such an array is a flat vector (no packed dimension, so not a memory) and
// the dynamic write goes through the dynamic packed-select writer, which
// applied PACKED-range mirroring to the second unpacked range: `[2]` is
// `[0:1]`, counted as an ascending packed range, so column j landed at
// column 1 - j and the two source operands' ready bits swapped (SourceCAM
// `differs` even with its register-number memory fixed).  The first
// dimension already exempted an unpacked base; the second now does too.
//
// Inputs and outputs are packed vectors unpacked inside: the two frontends
// flatten a multi-dimensional unpacked PORT in different element orders.
module unpacked_2d_comb_dyn_row(
    input  logic [1:0] r,
    input  logic       v,
    input  logic [7:0] base_p,
    output logic [7:0] o_p,      // a[r][1] = v           (constant column)
    output logic [7:0] q_p,      // for (j) b[r][j] = ... (loop column)
    output logic [7:0] pk_p      // control: a PACKED [0:3][0:1] array, mirroring kept
);
    logic a [4][2];
    logic b [4][2];
    logic [0:3][0:1] pk;
    always_comb begin
        for (int i = 0; i < 4; i++) for (int j = 0; j < 2; j++) a[i][j] = base_p[i*2+j];
        a[r][1] = v;
        for (int i = 0; i < 4; i++) for (int j = 0; j < 2; j++) o_p[i*2+j] = a[i][j];
    end
    always_comb begin
        for (int i = 0; i < 4; i++) for (int j = 0; j < 2; j++) b[i][j] = base_p[i*2+j];
        for (int j = 0; j < 2; j++) b[r][j] = v ^ (j == 1);
        for (int i = 0; i < 4; i++) for (int j = 0; j < 2; j++) q_p[i*2+j] = b[i][j];
    end
    always_comb begin
        pk = base_p;
        pk[r][1] = v;
        pk_p = pk;
    end
endmodule
