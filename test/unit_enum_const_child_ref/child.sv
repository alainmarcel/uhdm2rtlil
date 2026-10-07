// Reads the $unit enum constants from a file that does NOT declare them.
module unit_enum_child (
    input  logic       sel_byte,
    input  logic       sel_hword,
    output logic [1:0] width_o
);

    assign width_o = sel_byte  ? UWIDTH_BYTE
                   : sel_hword ? UWIDTH_HWORD
                               : UWIDTH_WORD;

endmodule
