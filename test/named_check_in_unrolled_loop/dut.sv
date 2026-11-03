// A NAMED immediate check inside a comb for-loop the importer unrolls:
// common_cells' cc_addr_decode_dync runs `ASSUME_I(name, cond, msg)` --
// `name: assume (cond) else $error(msg)` -- over every (i, j) rule pair in
// proc_check_addr_map.  The reader named the `$check` cell after the block
// label and `addCell` asserted on the second iteration
// (`count_id(cell->name) == 0`): PULP apb's apb_regs was a READ-FAIL.  The
// repeats are now suffixed like read_verilog's unrolled blocks.
module dut #(
  parameter int unsigned N = 4
) (
  input  logic [N-1:0][7:0] start_i,
  input  logic [N-1:0][7:0] end_i,
  output logic [N-1:0]      ok_o
);
  // The conditions hold by construction (the defect is in the cell NAMES,
  // and a check that can fire would stop the Verilator co-sim).
  always_comb begin
    for (int unsigned i = 0; i < N; i++) begin
      ok_o[i] = end_i[i] > start_i[i];
      rule_nonempty : assume (ok_o[i] == (end_i[i] > start_i[i]))
        else $error("rule %0d is inconsistent", i);
      for (int unsigned j = i + 1; j < N; j++) begin
        rule_disjoint : assert (i < j)
          else $error("rules %0d and %0d are not ordered", i, j);
      end
    end
  end
endmodule
