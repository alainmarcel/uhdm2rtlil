// YosysHQ/yosys#5487 (open): `proc_prune` undefines connections / incorrect scheduling semantics optimisation
// https://github.com/YosysHQ/yosys/issues/5487
// Code block(s) from the issue (variant v1); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module inout_task_bug(clk, in_bus, bus_reg_out, out_bus);
  input clk;
  wire clk;
  input in_bus;
  wire in_bus;
  output bus_reg_out;
  wire bus_reg_out;
  output out_bus;
  reg out_bus;
  wire _0_;
  wire _1_;
  wire _2_;
  wire _3_;
  reg bus_reg;
  reg \toggle$func$<<EOT:17$1.bus ;
  assign _3_ = ~ bus_reg;
  always_comb begin
  end
  always_ff @(posedge clk) begin
      out_bus <= _1_;
      bus_reg <= _0_;
      \toggle$func$<<EOT:17$1.bus  <= 1'hx;
  end
  assign bus_reg_out = bus_reg;
  assign _1_ = _3_;
  assign _0_ = _3_;
  assign _2_ = _3_;
endmodule

