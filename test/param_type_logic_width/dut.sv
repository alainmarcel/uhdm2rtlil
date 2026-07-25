// CVA6 load_store_unit.sv:614 `shift_reg #(.dtype(logic [$bits(a)+$bits(b)-1:0]))`:
// a `parameter type` port bound to a computed-width `logic` vector.  The port
// `input dtype d_i` collapsed to 1 bit -> resized at flatten (corrupt conn).
module shift_reg #(parameter type dtype = logic) (
    input  dtype d_i,
    output dtype d_o
);
    assign d_o = d_i;
endmodule

module param_type_logic_width #(parameter int W = 5) (
    input  logic [7:0] a,
    input  logic [W-1:0] b,
    output logic [8+W-1:0] o
);
    // dtype bound to a logic vector whose width is a $bits() sum
    shift_reg #(.dtype(logic [$bits(a) + $bits(b) - 1:0])) u (
        .d_i({a, b}),
        .d_o(o)
    );
endmodule

module tb;
    logic [7:0] a;
    logic [4:0] b;
    logic [12:0] o;
    param_type_logic_width #(.W(5)) t (.a(a), .b(b), .o(o));
endmodule
