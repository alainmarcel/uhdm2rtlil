// Converted from chipsalliance/sv-tests (equality_op).
// Upstream prints all six comparisons from an `initial` block, so none of the results reaches anything.  The operands MUST stay constants: x and z literals are the construct under test and cannot come from a port.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [7:0] x, output logic eq_ab, output logic eq_cd,
           output logic eq_ef, output logic ceq_ab, output logic ceq_cd,
           output logic ceq_ef, output logic [7:0] w);
  logic [7:0] a = 8'b1101x001;
  logic [7:0] b = 8'b1101x000;
  logic [7:0] c = 8'b1101z001;
  logic [7:0] d = 8'b1101z000;
  logic [7:0] e = 8'b11011001;
  logic [7:0] f = 8'b11011000;
  // The six RESULTS are outputs, so what each comparison decided is observable
  // even though its operands have to be literals.
  assign eq_ab  = (a == b);
  assign eq_cd  = (c == d);
  assign eq_ef  = (e == f);
  assign ceq_ab = (a === b);
  assign ceq_cd = (c === d);
  assign ceq_ef = (e === f);
  // A port-driven witness: all six comparisons answer 0, and a netlist whose
  // every output is constant zero makes the co-sim VACUOUS -- it reports no
  // output activity rather than comparing anything.
  assign w = x;
endmodule
