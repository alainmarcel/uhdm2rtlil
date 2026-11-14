// MikePopoloski/slang#1297 (closed): Internal variable of function are seen affected multiple time
// https://github.com/MikePopoloski/slang/issues/1297
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
// mwe.sv
function logic [8:0] my_sum(logic [7:0] a, logic [7:0] b);
    logic [8:0] out;
    out = a + b;
    return out;
endfunction;

module mwe ();

    logic [8:0] o1;
    logic [8:0] o2;

    always_comb begin
        o1 = my_sum(1,3);
    end

    always_comb begin
        o2 = my_sum(4,5);
    end

endmodule

