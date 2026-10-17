// A WHOLE interface ARRAY handed to a child from inside a GENERATE block,
// the array declared at module level:
//
//   reg_if register_if[6]();
//   generate if (1) begin : g_rbr
//     matcher u_matcher (.register_if(register_if), ...);
//
// Surelog binds that actual to the array's FIRST ELEMENT (`register_if[0]`)
// rather than to the array, so the interface-instance branch connected one
// element as the unindexed `register_if.value` -- a port the child (which
// declares register_if[0..5].value) does not have, and `hierarchy` rejected
// the cell: "Module `matcher' ... does not have a port named
// 'register_if.value'".  At module level the actual is the array itself and
// the array branch fans every element out.  UHDM-only: yosys's read_verilog
// rejects the interface-array port.
interface reg_if;
  logic [31:0] value;
  modport host (input value);
endinterface

module matcher (
  reg_if.host   register_if[6],
  output logic  o_match,
  output logic [3:0] o_nib
);
  assign o_match = register_if[5].value[7+:1] == 1'h0;
  assign o_nib   = register_if[3].value[11:8];
endmodule

module csr (
  input  logic [31:0] i_regval, i_v3,
  output logic        o_match,
  output logic [3:0]  o_nib
);
  reg_if register_if[6]();
  assign register_if[5].value = i_regval;
  assign register_if[3].value = i_v3;
  generate if (1) begin : g_rbr
    matcher u_matcher (.register_if(register_if), .o_match(o_match), .o_nib(o_nib));
  end endgenerate
endmodule

module csr_flat (input logic [31:0] i_regval, i_v3, output logic o_match, output logic [3:0] o_nib);
  csr dut (.*);
endmodule
