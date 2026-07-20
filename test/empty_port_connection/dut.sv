// Minimal repro for an explicitly EMPTY named port connection: `.unused()`.
//
// Surelog encodes an empty named port connection as a `vpiNullOp` operation in
// the port's vpiHighConn.  The UHDM frontend must treat it as "leave this port
// unconnected", NOT pass it to import_operation (which warned "Unsupported
// operation type: 36" and produced no port binding).
//
// Reduced from the rp32 mouse SoC, where `r5p_mouse`'s unused `tcb_xen`
// execute-enable output is tied off as `.tcb_xen()`.
//
// Structured for observability: `sub`'s used output `sum` drives the top output
// `y`, while its second output `carry` is left unconnected via `.carry()`.  The
// design is fully equivalent between the UHDM and Verilog front ends.

module adder_with_carry (
  input  logic [7:0] a,
  input  logic [7:0] b,
  output logic [7:0] sum,
  output logic       carry   // deliberately left unconnected by the parent
);
  assign {carry, sum} = a + b;
endmodule

module empty_port_connection (
  input  logic [7:0] a,
  input  logic [7:0] b,
  output logic [7:0] y
);
  adder_with_carry u_add (
    .a     (a),
    .b     (b),
    .sum   (y),
    .carry (      )   // empty named port connection -> vpiNullOp
  );
endmodule
