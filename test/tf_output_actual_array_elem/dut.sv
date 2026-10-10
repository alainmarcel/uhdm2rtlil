// RSD DCacheMissHandler: a void function whose OUTPUT actual is an unpacked-array
// ELEMENT (`MergeStoreDataToLine(mergedLine[i], ...)`).  The element had just been
// assigned a constant, so read_uhdm imported the actual as that VALUE and the
// write-back landed on 8'0: the merged line never reached the MSHR.
function automatic void Merge(output logic [7:0] dst, input logic [7:0] a, input logic [7:0] b, input logic [1:0] dirty);
  for (int i = 0; i < 2; i++) begin
    for (int k = 0; k < 4; k++) begin
      dst[i*4 + k] = dirty[i] ? b[i*4 + k] : a[i*4 + k];
    end
  end
endfunction
module tf_output_actual_array_elem(input logic [15:0] a, input logic [15:0] b, input logic [3:0] dirty, output logic [15:0] y);
  logic [7:0] merged [2];
  always_comb begin
    merged[0] = '0; merged[1] = '0;
    Merge(merged[1], a[15:8], b[15:8], dirty[3:2]);
    y = {merged[1], merged[0]};
  end
endmodule
