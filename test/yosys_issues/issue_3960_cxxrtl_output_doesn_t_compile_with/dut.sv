// YosysHQ/yosys#3960 (closed): CXXRTL output doesn't compile with zero-sized ports on modules
// https://github.com/YosysHQ/yosys/issues/3960
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- c0.sv
module x (
  input [6:5]w1,
  input [5:6]w2,
  input [-5:-6]w3,
  input [-6:-5]w4,
  input [0:-1]w5,
  input [-1:0]w6
);
  generate
    $info("w1=%1d w2=%1d w3=%1d w4=%1d w5=%1d w6=%1d", $bits(w1), $bits(w2), $bits(w3), $bits(w4), $bits(w5), $bits(w6));
  endgenerate
endmodule

