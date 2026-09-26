// A DESCENDING for loop inside an `if` of a comb block, with a blocking
// accumulator:  offset = 0;  for (i = W-1; i >= 0; i = i - 1) begin
//   if (frame_ptr_reg == offset) d = tag[i*8 +: 8];  offset = offset + 1; end
// (verilog-ethernet axis_stat_counter's byte serialiser).  The CaseRule-path
// loop parser accepted only ascending forms (`<`/`<=` with `++`/`+= N`), so
// the loop was "unsupported ... skipping": no byte was ever emitted (85
// co-sim divergences).  The Process-level unroller already handled
// descending loops; the CaseRule path now mirrors it (`>=`/`>`, `--`,
// `-= N`, `i = i - N`, downward iteration).  The ascending twin was fine.
module comb_caserule_descending_for #(
  parameter TAG_BYTE_WIDTH = 4
) (
  input  logic [3:0]                 frame_ptr_reg,
  input  logic [TAG_BYTE_WIDTH*8-1:0] tag,
  input  logic                       en,
  output logic [7:0]                 d
);
  integer i, offset;
  always @* begin
    d = 8'd0;
    offset = 0;
    if (en) begin
      for (i = TAG_BYTE_WIDTH-1; i >= 0; i = i - 1) begin
        if (frame_ptr_reg == offset) begin
          d = tag[i*8 +: 8];
        end
        offset = offset + 1;
      end
    end
  end
endmodule
