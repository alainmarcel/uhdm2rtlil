// A bit / part / indexed-part select of an interface-ARRAY ELEMENT's member:
// rggen's indirect-register match,
//
//   assign indirect_match = register_if[5].value[7+:1] == 1'h0;
//
// The hier_path is [bit_select(register_if, 5), indexed_part_select(value)].
// The element instance's member wire `register_if[5].value` exists (created
// by the array's import), but the path fell to the struct-member decoder,
// which has no struct to decode, and the read was dropped ("Could not
// resolve struct member access 'register_if[5].value[7+:1]'").
interface reg_if;
  logic [31:0] value;
  logic [7:0]  status;
  modport host (input value, status);
endinterface

// The selects sit in a module that receives the array through an
// interface-ARRAY PORT (rggen's register blocks are read that way, under a
// wrapper); yosys's read_verilog rejects that port shape, so this test is
// UHDM-only -- gated by test_structural.ys and the read_slang miter.  At top
// level read_verilog would silently declare `register_if[3].value` as an
// implicit 1-bit wire and the comparison would be vacuous.
module matcher (
  reg_if.host         register_if[6],
  output logic        o_match,
  output logic [3:0]  o_nib,
  output logic        o_bit
);
  assign o_match = register_if[5].value[7+:1] == 1'h0;
  assign o_nib   = register_if[3].value[11:8];
  assign o_bit   = register_if[2].status[6];
endmodule

module top (
  input  logic [31:0] i_v3, i_v5,
  input  logic [7:0]  i_s2,
  output logic        o_match,
  output logic [3:0]  o_nib,
  output logic        o_bit
);
  reg_if register_if[6]();
  assign register_if[3].value  = i_v3;
  assign register_if[5].value  = i_v5;
  assign register_if[2].status = i_s2;
  matcher u_matcher (.register_if(register_if), .o_match(o_match), .o_nib(o_nib), .o_bit(o_bit));
endmodule
