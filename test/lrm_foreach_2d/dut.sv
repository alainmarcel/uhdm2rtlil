// IEEE 1800-2023 12.7.3: foreach over two dimensions at once, with a
// descending and an ascending range, so each loop variable must follow its
// own dimension's direction.
module dut(input  logic [3:0] in [3:0][0:2],
           output logic [3:0] out [3:0][0:2],
           output logic [7:0] sum);
  always_comb begin
    sum = '0;
    foreach (in[i, j]) begin
      out[i][j] = in[i][j] + 4'(i) + 4'(2 * j);
      sum += 8'(in[i][j]);
    end
  end
endmodule
