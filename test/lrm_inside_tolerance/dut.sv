// IEEE 1800-2023 11.4.13 (new in 2023): inside with an absolute tolerance
// range [c +/- t] and a relative one [c +%- p].
module dut(input logic [7:0] a, output logic abs_in, rel_in, both);
  assign abs_in = a inside {[8'd100 +/- 8'd5]};
  assign rel_in = a inside {[8'd50 +%- 8'd10]};
  assign both   = a inside {[8'd10 +/- 8'd2], [8'd200 : 8'd210]};
endmodule
