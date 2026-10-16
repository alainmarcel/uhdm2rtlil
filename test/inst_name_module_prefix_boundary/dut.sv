// A module whose name is a PREFIX of the wrapper that instantiates it
// (`csr` inside `csr_flat`), with an instance inside a generate block.
//
// import_instance derives the cell name by searching the elaborated full
// name `work@csr_flat.dut.g_rbr.u_register` for `work@csr` -- which matched
// the `csr` of `csr_flat` -- and named the cell `_flat.dut.g_rbr.u_register`:
// a name nothing else (the interface port expansion, the gen-scope wires)
// could ever match.  The match must end at a path boundary.
module leaf (input logic a, output logic y);
  assign y = ~a;
endmodule

module csr (input logic a, output logic y);
  generate if (1) begin : g_rbr
    leaf u_register (.a(a), .y(y));
  end endgenerate
endmodule

module csr_flat (input logic a, output logic y);
  csr dut (.*);
endmodule
