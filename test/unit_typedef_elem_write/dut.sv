// A dynamic ELEMENT write into a packed array whose element type is a $unit
// (compilation-unit) typedef: `typedef logic [7:0] mubi8_t;` at file scope,
// `mubi8_t [10:0] d; d[idx] = 8'h96;`.  The port wire carries the full
// geometry (11 elements of 8 bits) but the NET's typespec is only the element
// `mubi8_t`, and the write emitter read the element's own range [7:0] as the
// OUTER dimension: 8 elements of 11 bits, stride 11, an 11-bit mask -- a
// write to element 0 also cleared bit 8 (element 1's bit 0) and a write to
// element 2 smeared over elements 1..4.  A package or module typedef carries
// the full shape on the net and was never affected.
typedef logic [7:0] mubi8_t;
module dut (
  input  logic        we,
  input  logic [3:0]  idx,
  input  mubi8_t [10:0] q,
  output mubi8_t [10:0] d,
  output logic [7:0]  e2      // element 2 read back
);
  always_comb begin
    d = q;
    if (we) d[idx] = 8'h96;
  end
  assign e2 = d[2];
endmodule
