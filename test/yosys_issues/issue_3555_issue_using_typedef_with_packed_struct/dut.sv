// YosysHQ/yosys#3555 (closed): Issue using typedef with packed struct in packed union
// https://github.com/YosysHQ/yosys/issues/3555
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py
// HAND-EDITED (keep on re-harvest): the issue's typedefs (its first code block) restored; StaticAssert reads the union member through the typedef ALIAS

// ---- b0.sv
typedef struct packed {
  logic [7:0] a;
  logic [7:0] b;
} Foo;

typedef Foo Bar;

typedef union packed {
  Bar bar;
  Foo foo;
} FooBar;

module StaticAssert (input FooBar x, output logic [7:0] ba, output logic [7:0] fb,
                     output logic [15:0] whole, output logic [7:0] nbits);
  assign ba = x.bar.a;
  assign fb = x.foo.b;
  assign whole = x.bar;
  assign nbits = $bits(FooBar);
  if ($bits(Foo) != 16)
    $error("Foo is not the right length");
  if ($bits(Bar) != 16)
    $error("Bar is not the right length");
  if ($bits(FooBar) != 16)
    $error("FooBar is not the right length");
endmodule

