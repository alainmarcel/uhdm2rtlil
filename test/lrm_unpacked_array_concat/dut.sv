// IEEE 1800-2023 10.10: unpacked array concatenation.  The braces build an
// UNPACKED array element by element (a whole array, an element and a slice
// may all appear as items), unlike a packed concatenation.
module dut(input  logic [7:0] a, b, c, d,
           output logic [7:0] y0, y1, y2, y3,
           output logic [7:0] z0, z1, z2, z3);
  logic [7:0] arr [4];
  logic [7:0] two [2];
  logic [7:0] rot [4];
  assign arr = {a, b, c, d};
  assign two = {b ^ c, d};
  assign rot = {two, arr[0:1]};
  assign {y0, y1, y2, y3} = {arr[0], arr[1], arr[2], arr[3]};
  assign {z0, z1, z2, z3} = {rot[0], rot[1], rot[2], rot[3]};
endmodule
