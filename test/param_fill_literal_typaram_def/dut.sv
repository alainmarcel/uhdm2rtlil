// `parameter fmt_logic_t FpFmtConfig = '1` bit-selected with a package enum
// (`FpFmtConfig[pk::FP8]`, fpnew_divsqrt_multi line 163) inside a module that
// also carries a `parameter type`: the type-parameter signature makes the
// reader import the DEFINITION too, where the parameter's value is the fill
// literal -- ONE bit -- so index 3 was out of range and the select fell
// through to the wire lookup: "Could not find wire 'FpFmtConfig' for bit
// select" (cv32e40p_fp_wrapper).  The fill must be as wide as the typespec.
package pk;
  typedef logic [0:4] fmt_logic_t;
  typedef enum logic [2:0] {FP32 = 0, FP64 = 1, FP16 = 2, FP8 = 3, FP16ALT = 4} fp_format_e;
endpackage
module leaf #(
  parameter pk::fmt_logic_t FpFmtConfig = '1,
  parameter type            TagType     = logic
) (
  input  logic [2:0] fmt, input TagType tag_i, output logic y, output TagType tag_o);
  always_comb y = FpFmtConfig[pk::FP8] & (fmt == pk::FP8);
  assign tag_o = tag_i;
endmodule
module mid #(
  parameter pk::fmt_logic_t FpFmtMask = '1,
  parameter type            TagType   = logic
) (
  input  logic [2:0] fmt, input TagType tag_i, output logic y, output TagType tag_o);
  if (1) begin : gen_merged
    leaf #(.FpFmtConfig(FpFmtMask), .TagType(TagType)) i_leaf (
      .fmt(fmt), .tag_i(tag_i), .y(y), .tag_o(tag_o));
  end
endmodule
module param_fill_literal_typaram_def (
  input  logic [2:0] fmt, input logic [3:0] tag_i,
  output logic y_on, y_off, output logic [3:0] tag_o);
  logic [3:0] unused_tag;
  mid #(.FpFmtMask(5'b10110), .TagType(logic [3:0])) i_on  (.fmt(fmt), .tag_i(tag_i), .y(y_on),  .tag_o(tag_o));
  mid #(.FpFmtMask(5'b11100), .TagType(logic [3:0])) i_off (.fmt(fmt), .tag_i(tag_i), .y(y_off), .tag_o(unused_tag));
endmodule
