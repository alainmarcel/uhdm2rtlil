// An unpacked array declared through a TYPEDEF that carries the unpacked
// dimension: `typedef logic [6:0] entry_t [3:0]; entry_t taps;` -- PULP
// axi_opt_lfsr's XNOR tap table (axi_lite_lfsr / axi_lfsr).  The array is
// assigned whole and read per element, so it takes the whole-array flat-wire
// path, which read the dimensions from the array_var's own Ranges(); those
// are EMPTY here (the dimension lives on the typedef's array_typespec), so
// the table was "left unmaterialized" as a 1-bit wire, every tap read was
// out of range, and the LFSR feedback bit was wrong from the first cycle.
// The dimensions and element type now come from the typespec when the var
// has none.  The slang miter fails without the fix.
module typedef_unpacked_array_var_dims (
  input  logic [63:0] q,
  input  logic [1:0]  t,
  input  logic        sel,
  output logic        fb,
  output logic [6:0]  e_o
);
  typedef logic [6:0] entry_t [3:0];
  entry_t taps;
  always_comb begin
    if (sel) taps = { 'd64, 'd63, 'd61, 'd60 };
    else     taps = { 'd32, 'd30, 'd26, 'd25 };
    fb = q[taps[3]-1];
    for (int unsigned i = 0; i < 3; i++) begin
      if (taps[i] != 0) fb = fb ^ q[taps[i]-1];
    end
    e_o = taps[t];
  end
endmodule
