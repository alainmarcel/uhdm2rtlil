// MikePopoloski/slang#518 (closed): Compatibility mode for mixed continuous and procedural assignments
// https://github.com/MikePopoloski/slang/issues/518
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m(output logic a);
    always_comb a = 0;
endmodule

module top;

    typedef struct packed {
        logic a;
        logic b;
    } s;

    s s1[2];

    always_comb begin
        for (int p=0; p < 2; p++) begin
            s1[p].b = 0;
        end
    end

    for (genvar i = 0; i < 2; i++) begin
        m m1(.a(s1[i].a));
    end

endmodule

