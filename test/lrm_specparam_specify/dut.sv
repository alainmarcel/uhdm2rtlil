// IEEE 1800-2023 30 / 6.20.5: a specify block and specparams describe timing
// only; synthesis ignores them and the module's logic must be unchanged.
module dut(input logic a, b, output logic y, z);
  specparam tRise = 1.2, tFall = 0.8;
  assign y = a & b;
  assign z = a ^ b;
  specify
    specparam tPD = 2;
    (a => y) = (tRise, tFall);
    (b => y) = tPD;
    (a, b *> z) = tPD;
  endspecify
endmodule
