// `parameter [N-1:0][W-1:0] P` -- a packed 2-D parameter declared WITHOUT a
// base type -- is typed by Surelog as an int_typespec carrying both ranges.
// `P[i]` must select the whole W-bit element (black-parrot
// bp_me_bedrock_register's `addr inside {base_addr_p[i]}` register decode),
// not bit i of the flattened value.  (A module-level `x = P[1]` is folded by
// Surelog itself to a constant and is not exercised here.)
package p;
  localparam dev_w = 20;
  localparam [dev_w-1:0] A0 = (dev_w)'('h0_0008);
  localparam [dev_w-1:0] A1 = (dev_w)'('h0_0010);
  localparam [dev_w-1:0] A2 = (dev_w)'('h0_8200);
endpackage
module reg_dec #(parameter els_p = 1, parameter [els_p-1:0][19:0] base_addr_p = '0)
  (input logic [19:0] addr, output logic [els_p-1:0] m, output logic [els_p-1:0][19:0] e);
  for (genvar i = 0; i < els_p; i++) begin : dec
    wire addr_match = addr inside {base_addr_p[i]};
    assign m[i] = addr_match;
    assign e[i] = addr ^ base_addr_p[i];   // the element itself, kept active for the co-sim
  end
endmodule
module top import p::*; (input logic [19:0] addr, output logic [2:0] m, output logic [2:0][19:0] e);
  reg_dec #(.els_p(3), .base_addr_p({A2, A1, A0})) r (.addr(addr), .m(m), .e(e));
endmodule
