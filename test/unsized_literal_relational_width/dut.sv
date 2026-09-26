// The operands of a comparison are sized to max(self-size(A), self-size(B))
// (LRM 11.8.2), and an UNSIZED literal is 32 bits (LRM 5.7.1).  Surelog
// stores an unsized literal at 64 bits and read_uhdm took that as the
// operand context, so `~(ip | mask) == 0` (verilog-ethernet arp's in-subnet
// broadcast test) inverted at 64 bits: the upper 32 bits were never zero
// and the direct-reply arm was dead (arp, ip_complete and ip_complete_64
// formal counterexamples with defined inputs; random co-sim never hit it).
// The sized twin `~ip == 32'd0` was already correct.
module unsized_literal_relational_width (
  input  logic [31:0] ip,
  input  logic [31:0] mask,
  input  logic [31:0] gw,
  output logic        bcast,
  output logic        insub,
  output logic        sized,
  output logic        lt,
  output logic        lo_bcast,
  output logic        lo_ne,
  output logic [7:0]  act
);
  assign bcast = ~(ip | mask) == 0;
  assign insub = ((ip ^ gw) & mask) == 0;
  assign sized = ~ip == 32'd0;
  assign lt    = ~(ip & mask) < 5;
  // the same shapes on values random stimulus does reach (co-sim activity):
  // `~x == 0` is true only when ALL 32 bits of x are set, so widen x first
  assign lo_bcast = ~(ip | mask | 32'hffffff00) == 0;
  assign lo_ne    = ~(ip | 32'hfffffff0) != 0;
  assign act      = ip[7:0] ^ mask[7:0];
endmodule
