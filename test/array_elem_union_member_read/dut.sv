// An element of an UNPACKED array of a packed UNION, read through a member:
//     mulSubInfo[i] = complexOpInfo[i].mulSubInfo;
//
// unpacked_array_elem_struct_ts() resolves the element typespec for every
// `arr[i].member` handler, and it used to return the element only when it was
// a struct_typespec -- so a packed UNION element was declined and the read
// fell through to a path that cannot address it: read_uhdm warned
// "Could not resolve struct member access 'complexOpInfo.mulSubInfo'" and
// left the consumers at a constant.
//
// Reduced from RSD ComplexIntegerExecutionStage.sv:192-194, whose
// `ComplexOpInfo complexOpInfo [COMPLEX_ISSUE_WIDTH]` is exactly this shape
// (233 co-sim divergences, read_slang clean).
//
// The union members are packed STRUCTS of differing field layout, so reading
// the wrong one is visible: mulCode sits at bits [1:0] of the element and
// divCode at the same bits but behind a different field name, while
// mulGetUpper / padding occupy bit 2.  Every member of a packed union starts
// at offset 0, so the element's own geometry is what must be right.
typedef struct packed {
    logic       mulGetUpper;
    logic [1:0] mulCode;
} MulOpSubInfo;

typedef struct packed {
    logic       isDiv;
    logic [1:0] divCode;
} DivOpSubInfo;

typedef union packed {
    MulOpSubInfo mulSubInfo;
    DivOpSubInfo divSubInfo;
} ComplexOpInfo;

module array_elem_union_member_read (
    input  logic [5:0] d,
    output logic [1:0] getUpper,
    output logic [3:0] mulCode,
    output logic [1:0] isDiv,
    output logic [3:0] divCode
);
    ComplexOpInfo complexOpInfo [2];
    MulOpSubInfo  mulSubInfo    [2];
    DivOpSubInfo  divSubInfo    [2];

    always_comb begin
        for (int i = 0; i < 2; i++) begin
            complexOpInfo[i] = d[i*3 +: 3];
            mulSubInfo[i]    = complexOpInfo[i].mulSubInfo;
            divSubInfo[i]    = complexOpInfo[i].divSubInfo;
        end
        for (int i = 0; i < 2; i++) begin
            getUpper[i]        = mulSubInfo[i].mulGetUpper;
            mulCode[i*2 +: 2]  = mulSubInfo[i].mulCode;
            isDiv[i]           = divSubInfo[i].isDiv;
            divCode[i*2 +: 2]  = divSubInfo[i].divCode;
        end
    end
endmodule
