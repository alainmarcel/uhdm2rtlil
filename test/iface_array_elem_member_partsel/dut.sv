// Part-select of an INTERFACE-ARRAY element member whose bound is a folded
// wide-constant expression -- caliptra_top's AHB responder addresses:
//
//   responder_inst[N].haddr[`CALIPTRA_SLAVE_ADDR_WIDTH(N)-1:0]
//   `define CALIPTRA_SLAVE_ADDR_WIDTH(n) \
//       $clog2((`CALIPTRA_SLAVE_ADDR_MASK >> (32*n)) & {32{1'b1}})
//
// An interface array elaborates to one interface_inst per element, so the
// member flattens to the wire `resp[0].haddr`.  The hier_path's VpiName,
// though, carries the whole select EXPRESSION text
// (`resp[0].haddr[$clog2({...} ^ {...} >> 32 * 0 & {32{1'b1}}) - 1:0]`), so
// every name-driven lookup in import_hier_path misses it and the read fell
// through to X.  In Caliptra that left 13 AHB slave `haddr_i` ports -- SHA512,
// SHA256, SHA3, DOE, ECC, HMAC, MLDSA, ... -- driven with a constant X.
//
// The trailing part_select is a ref_obj: its Actual_group() is the elaborated
// `logic_var work@<top>.resp[0].haddr`, which names the wire directly.
`define BASE {32'h2000_5000, 32'h1004_0000, 32'h1001_1000, 32'h1000_0000}
`define MASK {32'h2000_5FFF, 32'h1004_1FFF, 32'h1001_1FFF, 32'h1000_7FFF}
`define AMSK (`BASE ^ `MASK)
`define AW(n) $clog2((`AMSK >> (32*n)) & {32{1'b1}})

interface ahb_if;
  logic [31:0] haddr;
  modport resp (input haddr);
endinterface

// A responder sized by the same folded width, reading the slice as a port
// actual (the caliptra_top shape).
module slave #(parameter int W = 1) (input logic [W-1:0] a, output logic [15:0] y);
  assign y = 16'(a);
endmodule

module iface_array_elem_member_partsel (
  input  logic [31:0] a0,
  input  logic [31:0] a1,
  input  logic [31:0] a3,
  output logic [15:0] p0,   // port-actual path, slice width `AW(0) = 15
  output logic [15:0] p1,   // `AW(1) = 12
  output logic [15:0] p3,   // `AW(3) = 12
  output logic [15:0] d1,   // direct continuous-assign read of the same slice
  output logic [31:0] widths
);
  ahb_if resp[4] ();
  assign resp[0].haddr = a0;
  assign resp[1].haddr = a1;
  assign resp[3].haddr = a3;

  slave #(.W(`AW(0))) s0 (.a(resp[0].haddr[`AW(0)-1:0]), .y(p0));
  slave #(.W(`AW(1))) s1 (.a(resp[1].haddr[`AW(1)-1:0]), .y(p1));
  slave #(.W(`AW(3))) s3 (.a(resp[3].haddr[`AW(3)-1:0]), .y(p3));

  assign d1 = 16'(resp[1].haddr[`AW(1)-1:0]);

  // The folded widths themselves, so a wrong fold is visible too:
  // AW(0)=15 (mask 0x7FFF), AW(1)=12 (0xFFF), AW(2)=13 (0x1FFF), AW(3)=12.
  assign widths = {8'(`AW(3)), 8'(`AW(2)), 8'(`AW(1)), 8'(`AW(0))};
endmodule
