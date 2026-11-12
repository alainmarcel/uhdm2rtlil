// povik/sv-elab#191 (closed): release builds fail test `regress.sv`
// https://github.com/povik/sv-elab/issues/191
// Code block(s) from the issue (variant r28); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
// sv-elab tests/various/regress.sv r28
// issue 160 async set/reset from a struct field
module r28(input clk, input rst, input x, output q);
    typedef struct packed {
        logic x;
        logic q;
        logic clk;
        logic rst;
    } foo_t;
    foo_t bar;

    assign bar.clk = clk;
    assign bar.rst = rst;
    assign bar.x = x;
    assign q = bar.q;

    always_ff @(posedge bar.clk or negedge bar.rst) begin
        if (~bar.rst)
            bar.q <= 0;
        else
            bar.q <= bar.x;
    end
endmodule

