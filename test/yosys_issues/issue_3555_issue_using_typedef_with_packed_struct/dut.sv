// YosysHQ/yosys#3555 (closed): Issue using typedef with packed struct in packed union
// https://github.com/YosysHQ/yosys/issues/3555
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module StaticAssert;
  if ($bits(Foo) != 16)
    $error("Foo is not the right length");
  if ($bits(Bar) != 16)
    $error("Bar is not the right length");
  if ($bits(FooBar) != 16)
    $error("FooBar is not the right length");
endmodule

