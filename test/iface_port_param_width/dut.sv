// An interface port's members must be measured in the interface instance the
// PARENT connected, not in the interface's own declaration.
//
// `bus_if` declares `parameter int unsigned W = 0` -- the "you must override
// me" idiom this style of RTL uses everywhere -- so its members measure
// `[0-1:0]`, the degenerate `[-1:0]`, i.e. TWO bits.  `join_if` reaches the
// interface only through a modport port, and its flattened member wires
// (`\in.a`) were sized from that declaration whatever the parent bound, so
// yosys narrowed the connection ("Resizing cell port top.dut.in.a from 4 bits
// to 2 bits") and every bit above the second was dropped in silence.
//
// The parent connects a specific MODPORT (`.in(in_i.Slave)`), which Surelog
// represents as a hier_path rather than a ref_obj -- the form the elaborated
// port lookup did not recognise, so it never found the elaborated `in_i` with
// its `W = 4`.  PULP's axi_join_intf (AXI_ID_WIDTH 4) diverged from its own RTL
// on `b_id` at the first cycle for exactly this.
interface bus_if #(parameter int unsigned W = 0);
  logic [W-1:0] a;
  logic [W-1:0] b;
  modport Slave  (input a, output b);
  modport Master (output a, input b);
endinterface

module join_if (bus_if.Slave in, bus_if.Master out);
  assign out.a = in.a;
  assign in.b  = out.b;
endmodule

module dut #(parameter int unsigned W = 4) (
  input  logic [W-1:0] in_a,
  output logic [W-1:0] in_b,
  output logic [W-1:0] out_a,
  input  logic [W-1:0] out_b
);
  bus_if #(.W(W)) in_i ();
  bus_if #(.W(W)) out_i ();
  join_if u_join (.in(in_i.Slave), .out(out_i.Master));
  assign in_i.a  = in_a;
  assign in_b    = in_i.b;
  assign out_a   = out_i.a;
  assign out_i.b = out_b;
endmodule
