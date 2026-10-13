// A packed array PORT whose ELEMENT TYPE IS A TYPEDEF carries THREE widths:
//     typedef logic [IW-1:0] Idx;
//     Idx [DW-1:0][SR-1:0] ptr;        // outer DW x middle SR x leaf IW
// Surelog puts only the two DECLARED dimensions in the port typespec's
// Ranges() and the leaf width in its Elem_typespec, so a reader that
// multiplies the ranges alone measures the element as SR, not SR*IW.  Then
// `ptr[i][j]` -- the element read -- selects the LAST dimension's stride,
// which is ONE BIT instead of IW.
//
// RSD declares its issue-queue pointers exactly this way
//     IssueQueueIndexPath [DISPATCH_WIDTH-1:0][ISSUE_QUEUE_SRC_REG_NUM-1:0]
//         dispatchedSrcRegPtr
// and shifts by them, so ProducerMatrix's matrix update was built from single
// bits of each pointer.
localparam int DW = 2, SR = 2, IW = 4, NE = 16;
typedef logic [IW-1:0] Idx;

module packed_typedef_elem_leaf_width
  (input  Idx   [DW-1:0][SR-1:0] ptr,
   input  logic [DW-1:0][SR-1:0] rdy,
   // the element read on its own, so the width is observable without the
   // dynamic write below
   output logic [IW-1:0]         elem,
   output logic [DW-1:0][NE-1:0] o);

    logic [DW-1:0][NE-1:0] dv;

    assign elem = ptr[1][0];

    always_comb begin
        for (int i = 0; i < DW; i++) begin
            dv[i] = '0;
            for (int j = 0; j < SR; j++) begin
                if (!rdy[i][j]) begin
                    dv[i][ptr[i][j]] = 1'b1;
                end
            end
        end
        o = dv;
    end
endmodule
