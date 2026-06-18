// Observable: the constant size-cast is XOR'd with an input so the output
// toggles (Verilator constant-folds the runtime struct-array cast it otherwise
// can't build).  NOTE: this is a UHDM-correct / Yosys-Verilog-frontend-bug
// divergence — `my_struct_array'(16'hAB)` truncates to the 6-bit array width
// (= 6'h2b; UHDM and Verilator agree), but the Yosys Verilog frontend produces
// 6'h03 (wrong), so formal equivalence cannot pass.  Verified by Verilator
// co-sim.
module top(input logic [5:0] din, output logic [5:0] o);
   typedef struct packed {
      logic [2:0] x;
   } my_struct;

   typedef my_struct [1:0] my_struct_array;

   logic [15:0] a = 16'hAB;

   assign o = my_struct_array'(a) ^ din;

endmodule
