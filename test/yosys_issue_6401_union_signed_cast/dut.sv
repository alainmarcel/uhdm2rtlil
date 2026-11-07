// YosysHQ/yosys#6401's `union packed signed` case, split out of
// test/yosys_issue_6406_sv_casts: a cast to a signed packed UNION must make the
// result signed (Icarus: 64'hFFFF_FFFF_FFFF_FFAC), but UHDM's union_typespec has
// no signedness property, so Surelog cannot record `packed signed` on a union
// and read_uhdm zero-extends.  Tracked in test/slang_miter_expected_fail.txt
// until the UHDM model carries it.
module dut (output logic [63:0] union_signed, union_unsigned);
  typedef union packed signed   { logic [7:0] value; } signed_union;
  typedef union packed unsigned { logic signed [7:0] value; } unsigned_union;
  wire [7:0] a = 8'hAC;
  assign union_signed   = signed_union'(a);
  assign union_unsigned = unsigned_union'(a);
endmodule
