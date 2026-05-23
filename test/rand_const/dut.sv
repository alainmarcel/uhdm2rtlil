// Adapted from third_party/yosys/tests/various/rand_const.sv.
// Per IEEE 1800-2017 §18.4 the `rand` / `randc` keywords are only
// allowed on class members; Surelog correctly rejects them at module
// scope.  Yosys' Verilog reader is permissive and accepts them as a
// no-op extension at module scope.  `const` (§6.20.6) is LRM-standard
// for module-scope variable declarations and is kept verbatim — only
// the non-LRM `rand` modifiers are dropped.

module top;
	const reg rx;
	const reg ry;
	reg rz;
	const integer ix;
	const integer iy;
	integer iz;
endmodule
