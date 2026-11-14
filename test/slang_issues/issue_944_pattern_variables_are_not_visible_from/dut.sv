// MikePopoloski/slang#944 (closed): Pattern variables are not visible from initializers in child scope
// https://github.com/MikePopoloski/slang/issues/944
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module m (__o_pc);
    int i;
    always_comb begin
        if (i matches .a) begin
            automatic int pc = a; // 5
        end
    end

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [31:0] __o_pc;
  assign __o_pc = pc;
endmodule

