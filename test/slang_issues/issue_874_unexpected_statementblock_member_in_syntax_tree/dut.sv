// MikePopoloski/slang#874 (closed): Unexpected StatementBlock Member in Syntax Tree for Simple SystemVerilog Module Using slang --ast-json
// https://github.com/MikePopoloski/slang/issues/874
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__o_a_0, __o_a_1, __o_a_2, __o_a_3);
    logic a [4];

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            a[2'(i)] = i;
        end
    end

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_a_0;
  output logic __o_a_1;
  output logic __o_a_2;
  output logic __o_a_3;
  assign __o_a_0 = a[0];
  assign __o_a_1 = a[1];
  assign __o_a_2 = a[2];
  assign __o_a_3 = a[3];
endmodule

