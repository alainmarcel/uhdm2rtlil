// MikePopoloski/slang#329 (closed): Double backtick in macros
// https://github.com/MikePopoloski/slang/issues/329
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
// test.sv

`define WIDTH_PARAM(name) ``name``_width
`define DECL_PARAM(port) parameter integer `WIDTH_PARAM(``port``) = 1

module my_module #(
    `DECL_PARAM(x)
) (
    input [(x_width-1):0] x
);
endmodule

