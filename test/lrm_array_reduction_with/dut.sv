// IEEE 1800-2023 7.12.3: array reduction methods with a `with` clause.  The
// clause maps each item before reducing, and its type sets the result width.
module dut(input logic [3:0] arr [4], output logic [7:0] s, c, output logic [3:0] x, o);
  always_comb begin
    s = arr.sum() with (8'(item));
    c = arr.sum() with (8'(item > 4'd5));
    x = arr.xor() with (item.index[0] ? item : 4'h0);
    o = arr.or() with (item & 4'b0101);
  end
endmodule
