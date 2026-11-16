// IEEE 1800-2023 7.4.6: an indexed part-select of an UNPACKED array selects a
// contiguous run of elements; its start may be a variable while its width is
// constant.
module dut(input logic [7:0] a, b, c, d, input logic [1:0] i,
           output logic [7:0] p, q, output logic [7:0] r, s);
  logic [7:0] arr [4];
  logic [7:0] two [2];
  logic [7:0] dwn [2];
  assign arr = '{a, b, c, d};
  always_comb begin
    two = arr[i[0] +: 2];          // elements i[0], i[0]+1
    dwn = arr[2'(i | 2'd1) -: 2];  // elements i|1 and the one below it
  end
  assign p = two[0]; assign q = two[1];
  assign r = dwn[0]; assign s = dwn[1];
endmodule
