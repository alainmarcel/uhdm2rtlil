// YosysHQ/yosys#5142 (closed): Warning: Ignoring boxed module $paramod\ALU\ALU_MODE=s32'00000000000000000000000000000010
// https://github.com/YosysHQ/yosys/issues/5142
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module blinky #(
    // Num of click cycle per led toggle.
    parameter integer DIV = (27000000 / 2)
) (
    input        sys_clk,
    output logic led       // Active low
);

  // ---- Reset generator.

  logic [3:0] reset_counter = 0;
  logic sys_reset = 1;

  always_ff @(posedge sys_clk) begin
    if (reset_counter < 3) begin
      sys_reset <= 1;
      reset_counter <= reset_counter + 1;
    end else begin
      sys_reset <= 0;
    end
  end

  // ---- Blinker

  reg [31:0] blink_counter;

  always_ff @(posedge sys_clk) begin
    if (sys_reset) begin
      blink_counter <= 0;
      led <= 1;
    end else if (blink_counter < (DIV - 1)) begin
      blink_counter <= blink_counter + 1;
    end else begin
      blink_counter <= 0;
      led <= ~led;
    end
  end

endmodule

