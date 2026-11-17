// IEEE 1800-2023 10.10: unpacked array concatenation.  The braces build an
// UNPACKED array element by element (a whole array, an element and a slice
// may all appear as items), unlike a packed concatenation.  An array item
// contributes its elements in left-to-right order, so its range direction
// matters: `two` / `arr` ascend, `dsc` / `dt` descend.
module dut(input  logic [7:0] a, b, c, d,
           output logic [7:0] y0, y1, y2, y3,
           output logic [7:0] z0, z1, z2, z3,
           output logic [7:0] w0, w1, w2, w3,
           output logic [7:0] u0, u1, u2, u3);
  logic [7:0] arr [4];
  logic [7:0] two [2];
  logic [7:0] rot [4];
  logic [7:0] dsc [1:0];
  logic [7:0] dt  [3:0];
  logic [7:0] uu  [4];
  assign arr = {a, b, c, d};
  assign two = {b ^ c, d};
  assign rot = {two, arr[0:1]};
  assign dsc = {c, a};
  assign dt  = {dsc, two};
  assign uu  = {dt[2:1], dsc};
  assign {y0, y1, y2, y3} = {arr[0], arr[1], arr[2], arr[3]};
  assign {z0, z1, z2, z3} = {rot[0], rot[1], rot[2], rot[3]};
  assign {w0, w1, w2, w3} = {dt[3], dt[2], dt[1], dt[0]};
  assign {u0, u1, u2, u3} = {uu[0], uu[1], uu[2], uu[3]};
endmodule
