// povik/sv-elab#109 (closed): Support 'foreach' loops
// https://github.com/povik/sv-elab/issues/109
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module mwe_foreach (
        input logic a [4],
        output logic [3:0] b);

        always_comb begin
                foreach(a[i]) begin : gen_loop
                        b[i] = a[i];
                end
        end
endmodule

