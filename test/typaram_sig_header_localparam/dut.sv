// A child with a `parameter type` port gets a type-parameter signature from
// its port widths.  fpnew_fma sizes its ports by a HEADER localparam
// (`localparam int unsigned WIDTH = fpnew_pkg::fp_width(FpFormat)`), and
// probing that width while the PARENT was still the current RTLIL module
// fabricated a stray 1-bit `\WIDTH` wire in the parent ("Reference to unknown
// signal: WIDTH" in every fpnew_opgroup_fmt_slice).  test_structural.ys
// asserts the parent has no such wire.
package fmt_pkg;
  typedef enum logic [1:0] {FP32 = 0, FP16 = 1} fp_format_e;
  typedef struct packed {
    int unsigned exp_bits;
    int unsigned man_bits;
  } fp_encoding_t;
  localparam fp_encoding_t [0:1] FP_ENCODINGS = '{
    '{8, 23},   // FP32
    '{5, 10}    // FP16
  };
  function automatic int unsigned fp_width(fp_format_e fmt);
    return FP_ENCODINGS[fmt].exp_bits + FP_ENCODINGS[fmt].man_bits + 1;
  endfunction
endpackage

module leaf #(
  parameter fmt_pkg::fp_format_e FpFormat = fmt_pkg::FP32,
  parameter type TagType = logic,
  localparam int unsigned WIDTH = fmt_pkg::fp_width(FpFormat)
) (
  input  logic [2:0][WIDTH-1:0] operands_i,
  input  TagType                tag_i,
  output logic [WIDTH-1:0]      result_o,
  output TagType                tag_o
);
  assign result_o = operands_i[0] ^ operands_i[1] ^ operands_i[2];
  assign tag_o    = tag_i;
endmodule

module dut #(
  parameter fmt_pkg::fp_format_e FpFormat = fmt_pkg::FP16,
  parameter type                 TagType  = logic [3:0],
  localparam int unsigned        FP_WIDTH = fmt_pkg::fp_width(FpFormat)
) (
  input  logic                    clk_i,
  input  logic [1:0][2:0][FP_WIDTH-1:0] ops_i,
  input  TagType                  tag_i,
  output logic [1:0][FP_WIDTH-1:0] res_o,
  output TagType                  tag_o
);
  // the child sits in a generate loop, its type parameter RELAYED from the
  // parent's -- the fpnew_opgroup_fmt_slice / fpnew_fma shape
  for (genvar lane = 0; lane < 2; lane++) begin : gen_lanes
    if (lane < 2) begin : active_lane
      TagType lane_tag;
      leaf #(.FpFormat(FpFormat), .TagType(TagType)) lane_instance (
        .operands_i(ops_i[lane]), .tag_i(tag_i), .result_o(res_o[lane]), .tag_o(lane_tag));
      if (lane == 0) begin : gen_tag
        assign tag_o = lane_tag;
      end
    end
  end
endmodule
