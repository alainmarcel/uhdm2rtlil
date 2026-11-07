// YosysHQ/yosys#1688: $finish statement in always blocks produce errors
// https://github.com/YosysHQ/yosys/issues/1688
// A $display + $finish inside an always_ff: synthesis keeps the register and ignores the simulation control (yosys 0.70 read_verilog errors out).

module dut(input logic clk, input logic [3:0] a, output logic [3:0] q);
  always_ff @(posedge clk) begin
    q <= a + 1;
    if (a == 4'hF) begin
      $display("overflow");
      $finish;
    end
  end
endmodule
