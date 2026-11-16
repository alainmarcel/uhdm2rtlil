// IEEE 1800-2023 12.7.3: foreach over two dimensions at once, with a
// descending and an ascending range, so each loop variable must follow its
// own dimension's direction.  `fold` XORs every visited element with its
// own index pair, so a skipped, repeated or mis-paired iteration shows up
// (an XOR fold rather than a sum keeps the SAT miter fast: two readers
// associate a 12-term addition chain differently).
module dut(input  logic [3:0] in [3:0][0:2],
           output logic [3:0] out [3:0][0:2],
           output logic [7:0] fold);
  always_comb begin
    fold = '0;
    foreach (in[i, j]) begin
      out[i][j] = in[i][j] + 4'(i) + 4'(2 * j);
      fold ^= {in[i][j], 4'(i * 3 + j)} << j;
    end
  end
endmodule
