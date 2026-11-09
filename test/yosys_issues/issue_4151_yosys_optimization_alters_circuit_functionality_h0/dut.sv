// YosysHQ/yosys#4151 (open): Yosys optimization alters circuit functionality
// https://github.com/YosysHQ/yosys/issues/4151
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): the input redeclaration `bit [95:0] in_data` -> `wire`; Verilator rejects an input port redeclared as a variable (the inputs are driven by the testbench, so 2-state vs 4-state is moot); the optimized logic the issue is about is unchanged

// ---- b0.sv
module top(in_data, out_data);
  bit [1:0] _00_;
  bit [1:0] _01_;
  bit _02_;
  bit _03_;
  bit _04_;
  bit _05_;
  bit [1:0] _06_;
  bit [1:0] _07_;
  bit _08_;
  bit _09_;
  bit _10_;
  bit celloutsig_0z;
  bit [1:0] celloutsig_1z;
  bit [1:0] celloutsig_2z;
  bit celloutsig_3z;
  input [95:0] in_data;
  wire [95:0] in_data;
  output out_data;
  bit out_data;
  assign celloutsig_1z = _01_ * _00_;
  assign celloutsig_2z = _05_ ? _06_ : _07_;
  assign celloutsig_3z = _02_ ? _03_ : _04_;
  assign celloutsig_0z = _09_ | _08_;
  assign _09_ = in_data[21];
  assign _08_ = in_data[51];
  assign _01_[0] = celloutsig_0z;
  assign _01_[1] = celloutsig_0z;
  assign _00_[0] = celloutsig_0z;
  assign _00_[1] = celloutsig_0z;
  assign _07_[0] = celloutsig_0z;
  assign _07_[1] = celloutsig_1z[0];
  assign _06_ = in_data[43:42];
  assign _05_ = celloutsig_1z[0];
  assign _04_ = celloutsig_2z[1];
  assign _03_ = celloutsig_2z[0];
  assign _02_ = in_data[43];
  assign _10_ = in_data[92];
  assign out_data = celloutsig_3z;
endmodule

