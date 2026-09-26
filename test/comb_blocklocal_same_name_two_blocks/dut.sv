// Two always_comb blocks that each declare the SAME automatic block-locals
// (`automatic int unsigned idx_base, shift; automatic logic new_index;`)
// and assign/read them inside nested unrolled loops — common_cells
// cc_plru_tree.  The second block's locals get renamed wires (`shift$2`) and
// their blocking writes are recorded under that name, but a read asked for
// the bare `shift`, missed the in-flight map and fell through to the wire's
// FINAL value: every earlier iteration read the last one's, and plru_o was
// wrong from cycle 0 (301 co-sim divergences).  Either block alone was fine.
// A missed bare-name lookup now retries under the resolved wire name.
module comb_blocklocal_same_name_two_blocks #(parameter int unsigned Entries = 4) (input logic [Entries-1:0] used_i, input logic [2*(Entries-1)-1:0] plru_tree_q, output logic [2*(Entries-1)-1:0] plru_tree_d, output logic [Entries-1:0] plru_o);
  localparam int unsigned LogEntries = $clog2(Entries);
  always_comb begin : plru_replacement
    automatic int unsigned idx_base, shift;
    automatic logic new_index;
    idx_base = 0; shift = 0; new_index = 1'b0;
    plru_tree_d = plru_tree_q;
    for (int unsigned i = 0; i < Entries; i++) begin
      if (used_i[i]) begin
        for (int unsigned lvl = 0; lvl < LogEntries; lvl++) begin
          idx_base = $unsigned((2**lvl)-1);
          shift = LogEntries - lvl;
          new_index = 1'(~(i >> (shift-1)));
          plru_tree_d[idx_base + (i >> shift)] = new_index;
        end
      end
    end
  end
  always_comb begin : plru_output
    automatic int unsigned idx_base, shift;
    automatic logic new_index;
    idx_base = 0; shift = 0; new_index = 1'b0;
    plru_o = '1;
    for (int unsigned i = 0; i < Entries; i += 1) begin
      for (int unsigned lvl = 0; lvl < LogEntries; lvl++) begin
        idx_base = $unsigned((2**lvl)-1);
        shift = LogEntries - lvl;
        new_index = 1'(i >> (shift-1));
        if (new_index) plru_o[i] &= plru_tree_q[idx_base + (i>>shift)];
        else           plru_o[i] &= ~plru_tree_q[idx_base + (i>>shift)];
      end
    end
  end
endmodule
