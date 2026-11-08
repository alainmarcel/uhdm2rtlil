// YosysHQ/yosys#5878: Verilog backend struggles with multidimensional array
// indices into array dimensions from Verilog
// https://github.com/YosysHQ/yosys/issues/5878
// `foreach` over a 3-D unpacked array with a 1-indexed dimension inside an
// always_ff (the writes) and an always_comb (a reduction over every element);
// and the 1-D form over a `[3:1]` array.  (Packed ports only: the co-sim
// harness cannot drive unpacked-array ports.)
module dut(input logic clk, input logic [2:0] da, db, input logic [5:0] en,
           input logic [3:0] d1, input logic [3:1] en1,
           output logic [2:0] a1, a2, a3, b1, b2, b3, output logic out,
           output logic [3:0] o1, o2, o3);
  logic [2:0] my_array [1:0][0:0][3:1];
  logic [2:0] data_in [1:0][0:0];
  logic enable [1:0][0:0][3:1];
  always_comb begin
    data_in[0][0] = da; data_in[1][0] = db;
    enable[0][0][1] = en[0]; enable[0][0][2] = en[1]; enable[0][0][3] = en[2];
    enable[1][0][1] = en[3]; enable[1][0][2] = en[4]; enable[1][0][3] = en[5];
  end
  always_ff @(posedge clk) begin
    foreach (my_array[sch, disp, src]) begin
      if (enable[sch][disp][src]) my_array[sch][disp][src] <= data_in[sch][disp] + src;
    end
  end
  assign a1 = my_array[0][0][1]; assign a2 = my_array[0][0][2]; assign a3 = my_array[0][0][3];
  assign b1 = my_array[1][0][1]; assign b2 = my_array[1][0][2]; assign b3 = my_array[1][0][3];
  logic out_tmp;
  always_comb begin
    out_tmp = 1'b0;
    foreach (my_array[sch, disp, src]) out_tmp ^= ^my_array[sch][disp][src];
  end
  assign out = out_tmp;
  logic [3:0] arr1 [3:1];
  always_ff @(posedge clk) foreach (arr1[i]) if (en1[i]) arr1[i] <= d1 + i;
  assign o1 = arr1[1]; assign o2 = arr1[2]; assign o3 = arr1[3];
endmodule
