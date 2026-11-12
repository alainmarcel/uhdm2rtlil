// povik/sv-elab#32 (closed): Elaboration errors not being catched unless `--dump-ast` is specified
// https://github.com/povik/sv-elab/issues/32
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
package test_pkg;
typedef enum logic [1:0] {
    A,    B,    C,    D
} port_enum_t;
endpackage

module port_enum(
    input test_pkg::port_enum_t enum_in,
    output logic [1:0] bits_out );
    assign bits_out = enum_in;
    always_comb begin
        assert(enum_in === bits_out);
    end
endmodule

module port_enum_assign(
    input logic                 sel,
    input test_pkg::port_enum_t enum_in,
    input logic [1:0]           bits_in,
    output logic [1:0]          bits_out
);
    port_enum port_enum_inst (
        .enum_in(sel ? port_enum_t'(bits_in) : enum_in),
        .bits_out(bits_out) );
endmodule

module t01 (sel, enum_in, bits_in, bits_out);
    input logic sel;
    input logic [1:0] enum_in;
    input logic [1:0] bits_in;
    output logic [1:0] bits_out;

    port_enum_assign t (
        .enum_in(test_pkg::port_enum_t'(enum_in)),
        .* );
endmodule

