// povik/sv-elab#229 (closed): x values from partially initialised unpacked structs
// https://github.com/povik/sv-elab/issues/229
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module top(
    output logic o
);
    typedef struct {
        logic tag;
        logic a;
    } t_res;

    function automatic t_res value();
        t_res r;
        r.tag = 1'b1;
        return r;
    endfunction

    always_comb begin
        t_res x;
        x = value();
        o = x.tag == 1'b1;
    end
endmodule

