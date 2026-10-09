// RSD BlockMultiPortRAM's read-address pipeline: an unpacked array declared
// inside a generate scope, written AS A WHOLE by a non-blocking assignment of
// the scope's always_ff and read per element.  Unpatched read_uhdm made the
// array a $memory (the scope-whole check looked at the scope's cont_assigns
// and instance actuals only, not its always blocks): the whole-array write
// landed on a stray 1-bit `genblk1.raReg` wire and every read returned X --
// the bank select address of the real RAM was X and Verilator could not
// even build the netlist.  Elements are 2 bits (W == 1 hides geometry).
module genscope_whole_array_nba(input logic clk, input logic [1:0] ra0, input logic [1:0] ra1,
                                output logic [1:0] q0, output logic [1:0] q1);
  logic [1:0] ra [2];
  assign ra[0] = ra0; assign ra[1] = ra1;
  generate if (1) begin
    logic [1:0] raReg [2];
    always_ff @(posedge clk) raReg <= ra;
    assign q0 = raReg[0]; assign q1 = raReg[1];
  end endgenerate
endmodule
