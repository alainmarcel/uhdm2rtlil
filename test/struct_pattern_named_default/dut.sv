// A struct assignment pattern mixing NAMED member tags with a `default:`
// fill — fpnew_fma's ADD-arm info injection:
//   info_a = '{is_normal: 1'b1, is_boxed: 1'b1, default: 1'b0};
// The importer's '{default: V} handler filled EVERY member with the default
// and dropped the named tags, so is_normal read 0 and the injected 1.0
// multiplicand lost its implicit mantissa bit (aes64/fma results zeroed).
module struct_pattern_named_default (
    input  logic       sel_i,
    input  logic [7:0] raw_i,
    output logic [7:0] o
);
  typedef struct packed {
    logic is_normal;
    logic is_subnormal;
    logic is_zero;
    logic is_inf;
    logic [2:0] cls;
    logic is_boxed;
  } info_t;

  info_t info;

  always_comb begin
    info = raw_i;
    if (sel_i) info = '{is_normal: 1'b1, is_boxed: 1'b1, default: 1'b0};
  end

  assign o = info;
endmodule
