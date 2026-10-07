// A $unit (compilation-unit) scope enum typedef: declared at FILE scope here,
// and therefore visible from every other file of the same compilation unit --
// including child.sv, which never declares it.  Surelog binds a reference to
// one of these enum constants to the enum_const only inside the file that
// declared the typedef; in child.sv the name does not resolve and Surelog
// fabricates a 1-bit implicit net with that name instead, so the reference
// used to read ONE UNDRIVEN BIT rather than the 2-bit constant.
typedef enum logic [1:0] {
    UWIDTH_BYTE  = 2'b00,
    UWIDTH_HWORD = 2'b01,
    UWIDTH_WORD  = 2'b10
} unit_width_e;

module unit_enum_const_child_ref (
    input  logic       sel_byte,
    input  logic       sel_hword,
    output logic [1:0] width_top_o,
    output logic [1:0] width_child_o
);

    // Reference from the declaring file: this one always resolved.
    assign width_top_o = sel_hword ? UWIDTH_HWORD : UWIDTH_WORD;

    unit_enum_child u_child (
        .sel_byte  (sel_byte),
        .sel_hword (sel_hword),
        .width_o   (width_child_o)
    );

endmodule
