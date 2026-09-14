// An attribute instance between the always keyword and the block
// (`always_comb (* xprop_off *) begin … end`, pulp_riscv_dbg dm_csrs /
// dm_mem as vendored by OpenTitan rv_dm): Surelog took the attribute as the
// statement, reported UH0701 "Unsupported statement Attr_spec" and DROPPED the
// whole always block — rv_dm's CSR read/write logic was missing from the UHDM
// while the miter still "proved" the empty side.  Surelog #4175 skips the
// attribute instance(s) in front of the statement.
module always_comb_attribute_instance (input logic clk_i, input logic a, input logic b, input logic [3:0] d_i,
  output logic y, output logic z, output logic [3:0] q_o);
  always_comb (* xprop_off *) begin : csr_read_write
    y = a & b;
  end
  always_comb (* full_case *) (* parallel_case *) begin
    z = a | b;
  end
  always_ff (* keep *) @(posedge clk_i) q_o <= d_i;
endmodule
