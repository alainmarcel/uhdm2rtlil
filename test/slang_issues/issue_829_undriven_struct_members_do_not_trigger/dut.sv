// MikePopoloski/slang#829 (open): Undriven struct members do not trigger -Wunassigned-variable
// https://github.com/MikePopoloski/slang/issues/829
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
typedef struct {
    logic a;
    logic b;
} s_t;

module top(
    output logic x, y, z
);
    s_t s;
    always_comb s.a = 1'b1;

    always_comb begin
        if (s.b) begin
            x = 1'b1;
        end else begin
            x = 1'b0;
        end
    end

    always_comb y = s.b;

    always_comb begin
        z = s.b ? 1'b1 : 1'b0;
    end

endmodule

