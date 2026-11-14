// MikePopoloski/slang#2012 (closed): -Wundriven-port treats assigns in uninstantiated generate blocks as drivers
// https://github.com/MikePopoloski/slang/issues/2012
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module t #(parameter int STUB = 1) (output logic a, output logic b, output logic c, output logic d);
  if (STUB == 0) begin : g_real
    assign a = '0;
    assign b = '0;
  end
endmodule

