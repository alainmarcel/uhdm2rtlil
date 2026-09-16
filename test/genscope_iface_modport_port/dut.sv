// A module instance INSIDE a generate scope whose actual is an interface
// MODPORT (`.p(bif.src)`).  The top-level instance path already paired the
// modport's fields with the child's flattened `<port>.<field>` ports, but the
// generate-scope path had no hier_path case at all: the actual fell through to
// import_expression, resolved to 1'x, and `hierarchy` rejected the cell for
// referencing a port the child does not declare.
//
// caliptra-rtl's el2_mem does this for the ICCM:
//   if (pt.ICCM_ENABLE) begin : iccm
//     el2_ifu_iccm_mem iccm (..., .iccm_mem_export(mem_export_local.veer_iccm));
//
// The DUT drives every modport field from the outside and reads the results
// back out, so a dropped field shows up as an X on `oa`/`ob` rather than
// being optimised away.
interface bus_if ();
  logic       clk;
  logic [3:0] a, b;
  logic [3:0] c;
  modport src(input clk, output a, b, input c);
endinterface

module bus_child (bus_if.src p, input logic [3:0] din);
  // Reads an INPUT field of the modport and writes two OUTPUT fields, so all
  // three directions have to survive the connection.
  assign p.a = din ^ p.c;
  assign p.b = {din[2:0], p.clk};
endmodule

module dut (
  input  logic       clk,
  input  logic [3:0] din,
  input  logic [3:0] cin,
  output logic [3:0] oa,
  output logic [3:0] ob
);
  // A localparam, not a module parameter: a parameterised top leaves the
  // module with `dynports` and synth folds it away, which would make this
  // test vacuous.
  localparam int EN = 1;

  bus_if bif();
  assign bif.clk = clk;
  assign bif.c   = cin;

  generate
    if (EN) begin : g
      bus_child u (.p(bif.src), .din(din));
    end
  endgenerate

  assign oa = bif.a;
  assign ob = bif.b;
endmodule
