// Two async-reset always_ff blocks that each write a DIFFERENT field of the
// same storage struct, off the same reset — the shape every PeakRDL-generated
// `*_reg` module in chipsalliance/caliptra-rtl has (one always_ff per register
// field, all reset by `hwif_in.reset_b`).
//
// Two things went wrong in the importer and `proc` refused the design:
//
//   ERROR: Async reset \hwif_in [8] yields non-constant value
//   16'mmmmmmmmmmmmmmmm for signal \field_storage.
//
//   1. both processes SHARED one temp wire ($0\field_storage), because the
//      full-signal temp path reuses an existing temp while the part-select
//      path dedups it ($0\x, $1\x);
//   2. the async-reset sync rules updated the WHOLE signal even though each
//      process writes only its own field, so the reset value was constant in
//      the written bits and undefined elsewhere.
//
// Either one alone makes proc_arst unable to see a constant reset value, so
// the whole module fails to synthesise.  12 of caliptra_top's 21 top-level
// instances were lost to this.
//
// The reset arrives as a STRUCT MEMBER of an input (as in the real RTL), and
// both fields are observable at the output so a dropped write cannot hide.

typedef struct packed {
  logic       reset_b;
  logic [7:0] data;
} hwif_in_t;

typedef struct packed {
  logic [7:0] f0;
  logic [7:0] f1;
} store_t;

module dut (
  input  logic     clk,
  input  hwif_in_t hwif_in,
  input  logic     load_f0,
  input  logic     load_f1,
  output store_t   field_storage,
  output logic [7:0] sum
);
  always_ff @(posedge clk or negedge hwif_in.reset_b) begin
    if (~hwif_in.reset_b)  field_storage.f0 <= 8'h00;
    else if (load_f0)      field_storage.f0 <= hwif_in.data;
  end

  always_ff @(posedge clk or negedge hwif_in.reset_b) begin
    if (~hwif_in.reset_b)  field_storage.f1 <= 8'hFF;
    else if (load_f1)      field_storage.f1 <= hwif_in.data ^ 8'h5A;
  end

  // Reads both fields back, so a field that keeps the other's value (the
  // shared-temp bug) or holds X (the whole-signal reset bug) is visible here.
  assign sum = field_storage.f0 + field_storage.f1;
endmodule
