// `$bits` of an ANONYMOUS packed vector type -- `$bits(logic [31:0])`, the
// type written inline rather than through a typedef.  Surelog's getTypespec
// returned the base type without its packed dimension, so the size folded to
// 1 and every width derived from it collapsed: test/ext_ip/gen_flat_wrapper.py
// could not size an unpacked-array port element that way and had to compute
// the packed-range product by hand instead.
//
// Fixed upstream in chipsalliance/Surelog#4198 (getTypespec delegates to
// compileTypespec when a Packed_dimension follows).
module bits_of_anonymous_packed_type (
    output int unsigned w32, w8, w3, w1,
    output int unsigned sum,
    output logic [$bits(logic [15:0])-1:0] sized   // a width DERIVED from it
);
  assign w32 = $bits(logic [31:0]);
  assign w8  = $bits(logic [7:0]);
  assign w3  = $bits(logic [2:0]);
  assign w1  = $bits(logic);
  assign sum = $bits(logic [31:0]) + $bits(logic [7:0]);
  assign sized = '1;                                // 16 bits wide, not 1
endmodule
