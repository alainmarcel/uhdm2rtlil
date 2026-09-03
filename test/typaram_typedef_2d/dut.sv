// typedef chain over a TYPE PARAMETER with appended packed dims:
//   word_t (type param) -> pair_t = word_t[1:0] -> entry_t = pair_t[1:0][1:0]
// Surelog leaves entry_t as unsupported_typespec, so nets typed by it import
// as 1-bit wires (hpdcache_memctrl data_wentry/data_rentry).
module typaram_typedef_2d #(
    parameter type word_t = logic [7:0]
)(
    input  logic [7:0]  a,
    input  logic [7:0]  b,
    output logic [63:0] o
);
  typedef word_t [1:0]      pair_t;
  typedef pair_t [1:0][1:0] entry_t;

  entry_t e;
  always_comb begin
    e = '0;
    e[0][0] = {a, b};
    e[1][1] = {b, a};
  end
  assign o = e;
endmodule
