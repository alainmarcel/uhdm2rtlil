// A data-dependent `while` loop in always_comb -- cvw's lzc (leading-zero
// count), which cnt and zbb build on:
//   i = 0; while ((i < WIDTH) && (!num[WIDTH-1-i])) i = i + 1;
// The comb statement importers had no vpiWhile case at all ("Unsupported
// statement type in comb context: 70"), so the loop vanished and ZeroCnt
// stayed 0 (131 / 86 / 16 co-sim divergences across the three modules).
// It is now unrolled as a bounded nest of guarded iterations, each guard
// evaluated against the in-flight values of the previous ones; the depth
// comes from the constant conjunct `i < WIDTH`.  `sum_ones` is the same
// shape with a data-dependent body under a conditional (CaseRule path).
module while_comb_bounded #(
  parameter WIDTH = 8
) (
  input  logic [WIDTH-1:0]           num,
  input  logic                       en,
  output logic [$clog2(WIDTH+1)-1:0] ZeroCnt,
  output logic [3:0]                 ones_lo
);
  integer i, j;
  always_comb begin
    i = 0;
    while ((i < WIDTH) && (!num[WIDTH-1-i])) begin
      i = i + 1;
    end
    ZeroCnt = i[$clog2(WIDTH+1)-1:0];
  end
  always_comb begin
    ones_lo = 4'd0;
    j = 0;
    if (en) begin
      while (j < 4) begin
        ones_lo = ones_lo + num[j];
        j = j + 1;
      end
    end
  end
endmodule
