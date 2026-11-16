// IEEE 1800-2023 11.4.13: an inside set whose items are VARIABLES, not
// constants.  Each integral item is compared with ==?, which for 2-state data
// is ordinary equality, and a range [lo:hi] may take its bounds from signals.
// (read_slang refuses a non-constant item; Verilator is the reference.)
module dut(input logic [7:0] a, b, c, output logic y, n, output logic [1:0] k);
  assign y = a inside {b, c, 8'd3};
  assign n = !(a inside {b ^ c, [c:b]});
  always_comb begin
    k = 2'd0;
    if (a inside {b, c}) k = 2'd1;
    else if (b inside {a + 8'd1, c}) k = 2'd2;
  end
endmodule
