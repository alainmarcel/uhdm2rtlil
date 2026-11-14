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

module mwe (__o_o1, __o_o2);

    logic [8:0] o1;
    logic [8:0] o2;

    always_comb begin
        o1 = my_sum(1,3);
    end

    always_comb begin
        o2 = my_sum(4,5);
    end


  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [8:0] __o_o1;
  assign __o_o1 = o1;
  output logic [8:0] __o_o2;
  assign __o_o2 = o2;
endmodule

