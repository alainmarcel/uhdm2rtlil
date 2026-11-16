// IEEE 1800-2023 7.12.5 (new in 2023): the array map method returns an array
// of the same shape with every element transformed by the with clause.
module dut(input logic [3:0] arr [4], output logic [3:0] y [4]);
  always_comb y = arr.map() with (item ^ {2'b01, item[3:2]});
endmodule
