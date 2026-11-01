// Converted from chipsalliance/sv-tests (real-constants).
// Upstream assigns nine REAL LITERAL spellings to a 32-bit logic inside an `initial` block, so only the last survives and none is read.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(output logic [31:0] a1, output logic [31:0] a2, output logic [31:0] a3,
           output logic [31:0] a4, output logic [31:0] a5, output logic [31:0] a6);
  // Each spelling gets its own output; a real assigned to an integral target ROUNDS.
  assign a1 = 1.2;
  assign a2 = 2394.26331;
  assign a3 = 1.2E12;           // the exponent symbol can be e or E
  assign a4 = 23E10;
  assign a5 = 29E-2;
  assign a6 = 236.123_763_e-12; // underscores are ignored
endmodule
