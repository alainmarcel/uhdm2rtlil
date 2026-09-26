// Two always blocks writing the SAME generate-scope register (verilog-
// ethernet oddr's GENERIC arm: q_reg written on posedge AND negedge clk).
// The second block gets its own temp ($1\genblk1.q_reg) but its body's
// name-based temp lookup found nothing registered under the name and fell
// back to `$0\<name>` — the FIRST block's temp.  The second block then
// assigned the first's $0 and updated from its own untouched $1: the
// negedge write vanished (q never took d_reg_2), and after flatten the
// shared $0 aliased two differently-initialised nets, which opt_clean
// rejected ("Conflicting init values" in rgmii_phy_if).  At module scope
// the direct-update path is taken and this never showed.
module genscope_two_procs_same_reg #(
  parameter TARGET = "GENERIC"
) (
  input  logic clk,
  input  logic d1,
  input  logic d2,
  output logic q
);
  generate
    if (TARGET == "XILINX") begin
      assign q = d1;
    end else begin
      reg d_reg_2 = 1'b0;
      reg q_reg = 1'b0;
      always @(posedge clk) d_reg_2 <= d2;
      always @(posedge clk) q_reg <= d1;
      always @(negedge clk) q_reg <= d_reg_2;
      assign q = q_reg;
    end
  endgenerate
endmodule
