// Issue #441: an async-reset always_ff inside a GENERATE scope assigns a
// generate-scope-LOCAL signal (rr_ptr).  The async-reset path looked for the
// bare name "rr_ptr" instead of the gen-scope-prefixed wire -> "Signal rr_ptr
// not found in module".
module dut #(parameter int N = 4) (
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  upd,
    output logic [$clog2(N)-1:0]  o
);
    generate if (N > 1) begin : g_rr
        logic [$clog2(N)-1:0] rr_ptr;       // generate-scope-local
        always_ff @(posedge clk or negedge rst_n) begin
            if (!rst_n)      rr_ptr <= '0;
            else if (upd)    rr_ptr <= rr_ptr + 1'b1;
        end
        assign o = rr_ptr;
    end endgenerate
endmodule
