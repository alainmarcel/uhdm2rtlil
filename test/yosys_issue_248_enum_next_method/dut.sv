// YosysHQ/yosys#248: SystemVerilog enum types
// https://github.com/YosysHQ/yosys/issues/248
// The built-in enum methods (LRM 6.19.5): next() / prev() wrap around,
// first() / last() / num() are constants.
module dut(input logic clk, rst, output logic [1:0] st, output logic [1:0] prv,
           output logic [1:0] fst, lst, output int n);
  typedef enum logic [1:0] {S0, S1, S2} state_t;
  state_t state, state_p;
  always_ff @(posedge clk) begin
    if (rst) begin state <= S0; state_p <= S2; end
    else begin state <= state.next(); state_p <= state_p.prev(); end
  end
  assign st = state;
  assign prv = state_p;
  assign fst = state.first();
  assign lst = state.last();
  assign n = state.num();
endmodule
