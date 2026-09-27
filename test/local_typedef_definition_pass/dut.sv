// A module-local typedef whose member width depends on a module parameter,
// used through a struct-typed net, member-selected in an always_comb -- the
// pulp_riscv_dbg dmi_jtag shape (`dmi_t dmi; assign dmi = dmi_t'(dr_q);
// address_d = dmi.address;`) with the parameter OVERRIDDEN by the parent
// (NumDmiWordAbits 16 -> 7).
//
// The AllModules definition pass imports dmi_jtag_l with the parameter
// DEFAULT, and its `dmi_t` typespec node is shared with the elaborated
// instance.  The node has no parent, so it looked like a relayed
// type-parameter clone and was measured in that instance: the `dmi` net came
// out 41 bits (7+32+2) while the member offsets, folded in the definition's
// own scope, said address = [49:34] (16 bits).  `dmi.address` then built an
// RTLIL chunk past the wire and read_uhdm aborted on an assertion -- the
// whole egret chip read of the 2026-09-27 pavona nightly.  Reading this file
// is the test; the slang miter proves the elaborated instance.
module dmi_jtag_l #(
  parameter int unsigned NumDmiWordAbits = 16
) (
  input  logic                        clk,
  input  logic [NumDmiWordAbits+33:0] dr_q,
  input  logic                        upd,
  output logic [NumDmiWordAbits-1:0]  address_q,
  output logic [31:0]                 data_q,
  output logic [1:0]                  op_q
);
  typedef struct packed {
    logic [NumDmiWordAbits-1:0] address;
    logic [31:0]                data;
    logic [1:0]                 op;
  } dmi_t;
  dmi_t dmi;
  assign dmi = dmi_t'(dr_q);
  logic [NumDmiWordAbits-1:0] address_d;
  logic [31:0] data_d;
  logic [1:0]  op_d;
  always_comb begin
    address_d = address_q;
    data_d    = data_q;
    op_d      = op_q;
    if (upd) begin
      address_d = dmi.address;
      data_d    = dmi.data;
      op_d      = dmi.op;
    end
  end
  always_ff @(posedge clk) begin
    address_q <= address_d;
    data_q    <= data_d;
    op_q      <= op_d;
  end
endmodule
module local_typedef_definition_pass (
  input  logic        clk,
  input  logic [40:0] dr_q,
  input  logic        upd,
  output logic [6:0]  a,
  output logic [31:0] d,
  output logic [1:0]  op
);
  dmi_jtag_l #(.NumDmiWordAbits(7)) dap (.clk(clk), .dr_q(dr_q), .upd(upd), .address_q(a), .data_q(d), .op_q(op));
endmodule
