// MikePopoloski/slang#1759 (closed): compat vcs: allow '{default:'0} in port connections for unpacked arrays
// https://github.com/MikePopoloski/slang/issues/1759
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module sub(
  input logic [31:0] data [3:0]
);
endmodule

module top;
  sub u0(.data('{default:'0}));
endmodule

