// YosysHQ/yosys#248 (closed): SystemVerilog enum types
// https://github.com/YosysHQ/yosys/issues/248
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module foo(input clk, input rst,
  output logic [31:0] __o_state);
   typedef enum {S0, S1, S2} state_t;
   state_t state;

   always_ff @(posedge clk) begin
    if (rst) begin
      state <= S0;
    end else begin
      state <= state.next();     
    end
  end

  // controllable/observable ports added by test/yosys_issues/observe.py
  assign __o_state = state;
endmodule

