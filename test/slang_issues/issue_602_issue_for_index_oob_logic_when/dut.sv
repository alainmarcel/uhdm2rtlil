// MikePopoloski/slang#602 (closed): Issue for index-oob logic when signal index is a parameter also indexed by for-loop value
// https://github.com/MikePopoloski/slang/issues/602
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top #(
    parameter [2:0][4:0] IDX_MAP = {5'd1, 5'd3, 5'd4}
);

    logic [4:0] sig;

    always_comb begin
        for (int n = 0; n < 3; n++) begin
            if (sig[IDX_MAP[n]] != 'h0) begin
            end
        end
    end

endmodule

