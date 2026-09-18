// Regression for the Caliptra chip's 128 undriven `hwif_in` bits (hmac's
// HMAC512_NAME / HMAC512_VERSION `.next` fields).
//
// One always_comb writes, in this order: a plain struct FIELD, two
// CONSTANT-INDEXED elements of a struct member array, and then a for loop over
// another member array.  extract_assigned_signals folds the loop's writes onto
// the base name and absorbs the earlier field entry; that absorbed entry then
// looked like a WHOLE write of `hwif_in`, so the two constant-index element
// writes were pruned from the written-bits scan and the partial STa update
// dropped their bits — `NAMES` came out undriven.
package rp;
  typedef struct packed { logic [31:0] next; }                nfld_t;
  typedef struct packed { nfld_t NAME; }                      nreg_t;
  typedef struct packed { logic [31:0] next; logic we; }      tfld_t;
  typedef struct packed { tfld_t TAG; }                       treg_t;
  typedef struct packed { logic swwe; logic [7:0] other; }    ctrl_t;
  typedef struct packed {
    nreg_t [1:0]  NAMES;
    treg_t [15:0] TAGS;
    ctrl_t        CTRL;
  } reg_in_t;
endpackage

module dut import rp::*; (
  input  logic        rdy,
  input  logic [31:0] d,
  input  logic [15:0] we,
  input  logic [7:0]  oth,
  output reg_in_t     hwif_in
);
  localparam logic [63:0] CORE_NAME = 64'h4832_4d41_4335_3132;

  always_comb begin
    hwif_in.CTRL.swwe          = rdy;
    hwif_in.NAMES[0].NAME.next = CORE_NAME[31:0];
    hwif_in.NAMES[1].NAME.next = CORE_NAME[63:32];
    for (int dw = 0; dw < 16; dw++) begin
      hwif_in.TAGS[dw].TAG.next = rdy ? d : 32'h0;
      hwif_in.TAGS[dw].TAG.we   = we[dw];
    end
  end

  // A member no other statement of that process writes: the update rule must
  // stay partial, which is what exposed the dropped bits.
  always_comb hwif_in.CTRL.other = oth;
endmodule
