// A vector declared with a NEGATIVE lower bound (`logic [W-1:-1] cnt`, the
// 'n.1' fixed-point counter of OpenTitan's i3c_timing_pkg::tm_cycles_init)
// selected by its declared indices: `cnt[W-1:0]` is the integer part (the
// vector shifted right by one), not the low W bits.
module dut (input logic [3:0] sel, output logic [9:0] y, output logic [9:0] z, output logic [3:0] w, output logic h);
  localparam int unsigned W = 10;
  function automatic logic [W-1:-1] cyc(int unsigned v);
    logic [W-1:-1] r;
    r = v;
    return r;
  endfunction
  function automatic logic [W-1:0] cyc_init(int unsigned v);
    logic [W-1:-1] cnt;
    cnt = cyc(v) - 'b1;
    return cnt[W-1:0];
  endfunction
  assign y = cyc_init(2);          // (2 - 1) = 0.5 cycles -> integer part 0
  assign z = cyc_init(sel);        // runtime: (sel - 1) >> 1
  logic [3:-2] r;
  assign r = {sel, 2'b11};
  assign w = r[3:0];               // the integer part: sel
  assign h = r[-1];                // one of the fraction bits: 1
endmodule
