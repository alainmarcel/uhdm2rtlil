// MikePopoloski/slang#1350 (closed): case-dup handling when gen-case style syntax used within an always_comb block
// https://github.com/MikePopoloski/slang/issues/1350
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module A #(
   int A = 1
) (
   input logic a,
   input logic b,
   output logic c
);
   always_comb begin
       case (1'b1)
          A > 0:  c = a & b;
          A < 0:  c = a | b;
          A == 0: c = a ^ b;
       endcase
   end
endmodule

