// `'{default: v}` over a MULTI-RANGE packed logic parameter fills each WORD
// element with v -- iDMA's synth wrapper `logic [NumDim-1:0][31:0] RepWidths
// = '{default: RepWidth}` -- not every bit.  The per-bit fill turned
// `'{default: 32}` into ALL ONES, so each repetition width read 2^32-1, the
// generate-scope `localparam RepWidth = RepWidths[d-2]` sized every
// per-dimension counter to 3 bits, and every nD transfer looked zero-length
// (cheshire's idma_nd_midend_synth: req_ready_o 1 where the RTL says 0).
// read_verilog cannot parse a multi-range packed parameter with a default
// pattern, so the gates are the read_slang miter and the structural check.
module mid #(
  parameter int unsigned NumDim = 32'd2,
  parameter logic [NumDim-1:0][31:0] RepWidths = '{default: 'd0}
) (
  input  logic [95:0] reps_i,
  output logic [95:0] rep_o
);
  for (genvar d = 2; d <= NumDim; d++) begin : gen_dim
    localparam int unsigned RepWidth = RepWidths[d-2];
    logic [RepWidth-1:0] local_rep;
    assign local_rep = reps_i[(d-2)*32 +: RepWidth];
    assign rep_o[(d-2)*32 +: 32] = 32'(local_rep);
  end
  assign rep_o[95:64] = '0;
endmodule

module dut #(
  parameter int unsigned NumDim   = 32'd3,
  parameter int unsigned RepWidth = 32'd16
) (
  input  logic [95:0] reps_i,
  output logic [95:0] rep_o
);
  localparam logic [NumDim-1:0][31:0] RepWidths = '{default: RepWidth};
  mid #(.NumDim(NumDim), .RepWidths(RepWidths)) u_m (.reps_i(reps_i), .rep_o(rep_o));
endmodule
