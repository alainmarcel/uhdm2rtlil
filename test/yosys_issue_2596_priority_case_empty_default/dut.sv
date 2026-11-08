// YosysHQ/yosys#2596: assertpmux pass generates wrong assertions for priority case
// https://github.com/YosysHQ/yosys/issues/2596
// A `priority case` WITH an explicit (empty) `default;` is fully covered: when
// no item matches, nothing executes and the register holds (LRM 12.5.1).
module dut(input logic clk, input logic [1:0] foo, output logic out1, out2);
  always_ff @(posedge clk) begin
    priority case (1)
      foo == 3: out1 = 0;
      foo[0]:   out1 = 1;
      default;
    endcase
    unique case (foo)
      2'd2: out2 = 0;
      2'd1: out2 = 1;
      default: ;
    endcase
  end
endmodule
