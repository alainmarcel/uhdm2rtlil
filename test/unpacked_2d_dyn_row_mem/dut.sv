// A 2-D UNPACKED array written at a DYNAMIC row index -- RSD's SourceCAM:
//
//     RegNumPath srcRegNum[ ISSUE_QUEUE_ENTRY_NUM ][ SRC_OP_NUM ];
//     always_ff @(posedge clk) begin
//         if (rst) for (i) for (j) srcRegNum[i][j] <= 0;
//         else for (i) if (dispatch[i]) for (j)
//             srcRegNum[ dispatchPtr[i] ][j] <= dispatchedSrcRegNum[i][j];
//
// The array becomes a $mem.  Its memory was sized from the FIRST unpacked
// range only (4 words of 3 bits for `[4][2]`): every access used the row as
// the word address, so the column index landed as a BIT of the word on a
// write and was ignored on a read, and the unrolled reset loop collapsed
// onto one shared write port (only the last element reset).  Now the memory
// holds R*C words in row-major order with its geometry stamped as
// attributes, every write and read linearizes the leading indices, and the
// unrolled-loop writes get one write action per iteration like the 1-D form.
//
// Inputs are packed vectors unpacked inside: the two frontends flatten a
// multi-dimensional unpacked PORT in different element orders, which would
// make the miter compare the wrong elements.
module unpacked_2d_dyn_row_mem(
    input  logic        clk, rst,
    input  logic [1:0]  dispatch,
    input  logic [3:0]  ptr_p,      // 2 x 2-bit row pointers
    input  logic [11:0] dSrc_p,     // 2 x 2 x 3-bit data
    output logic [23:0] regs_p,     // all 4 x 2 x 3 bits read back
    output logic [2:0]  col0_of_1   // srcRegNum[1][0]: the constant-column form
);
    logic [1:0] ptr [2];
    logic [2:0] dSrc [2][2];
    always_comb for (int i = 0; i < 2; i++) begin
        ptr[i] = ptr_p[i*2 +: 2];
        for (int j = 0; j < 2; j++) dSrc[i][j] = dSrc_p[(i*2+j)*3 +: 3];
    end
    logic [2:0] srcRegNum[4][2];
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 4; i++) for (int j = 0; j < 2; j++) srcRegNum[i][j] <= 0;
        end else begin
            for (int i = 0; i < 2; i++)
                if (dispatch[i])
                    for (int j = 0; j < 2; j++) srcRegNum[ptr[i]][j] <= dSrc[i][j];
            // the constant-column form, a second port on the same memory
            if (dispatch[0] && dispatch[1]) srcRegNum[ptr[1]][0] <= dSrc[0][1];
        end
    end
    always_comb for (int i = 0; i < 4; i++) for (int j = 0; j < 2; j++) regs_p[(i*2+j)*3 +: 3] = srcRegNum[i][j];
    assign col0_of_1 = srcRegNum[1][0];
endmodule
