// IEEE 1800-2023 11.4.13 (new in 2023): inside with an absolute tolerance
// range [c +/- t] and a relative one [c +%- p].  [A +%- B] is
// [A - A*B/100.0 : A + A*B/100.0], a REAL range: [50 +%- 3] is
// [48.5 : 51.5], which holds 49, 50 and 51 but not 48 or 52.
module dut(input logic [7:0] a, output logic abs_in, rel_in, rel_frac, both);
  assign abs_in   = a inside {[8'd100 +/- 8'd5]};
  assign rel_in   = a inside {[8'd50 +%- 8'd10]};
  assign rel_frac = a inside {[8'd50 +%- 8'd3]};
  assign both     = a inside {[8'd10 +/- 8'd2], [8'd200 : 8'd210]};
endmodule
