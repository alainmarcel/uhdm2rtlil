// YosysHQ/yosys#4574 (closed): Seemingly shareable memory ports don't get merged
// https://github.com/YosysHQ/yosys/issues/4574
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module bitram2x1(input CLK,
                 input [1:0] AD,
                 input [1:0] DI,
                 input WE,
                 output reg [1:0] DO);
  (* no_rw_check *)
  reg ram [7:0];

  integer word_addr = AD*2;

  always @(posedge CLK) begin
    if (WE) begin
      for (integer i = 0; i < 2; i=i+1) begin
         ram[word_addr+i] <= DI[i];
      end
    end

    for (integer i = 0; i < 2; i=i+1) begin
      DO[i] <= ram[word_addr+i];
    end
  end
endmodule

