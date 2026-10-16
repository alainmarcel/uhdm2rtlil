// A BIT-SELECT whose BASE is a loop variable and whose INDEX is another loop
// variable, inside a function the reader unrolls:  `j[i]`.
//
// The part-select paths (import_part_select / import_indexed_part_select)
// substitute a loop variable's constant value before the wire lookup, because
// `k[1:0]` arrives as a vpiPartSelect carrying VpiName="k" rather than a
// reference.  The BIT-select path did not, so `j[i]` went looking for a wire
// named `j` and the read died with
//     ERROR: Could not find wire 'j' for bit select
// losing the whole module.  tnoc's tbcm_mux (rtl/bcm/tbcm_mux.sv, get_index)
// is the real case: a one-hot select is converted to a binary index by testing
// bit i of each candidate index j.
module dut #(
  parameter int ENTRIES     = 4,
  parameter int INDEX_WIDTH = 2
)(
  input  logic [ENTRIES-1:0]     i_select,
  output logic [INDEX_WIDTH-1:0] o_index
);
  assign o_index = get_index(i_select);

  function automatic logic [INDEX_WIDTH-1:0] get_index(
    logic [ENTRIES-1:0] select
  );
    logic [INDEX_WIDTH-1:0] index;
    for (int i = 0; i < INDEX_WIDTH; ++i) begin
      logic [ENTRIES-1:0] temp;
      for (int j = 0; j < ENTRIES; ++j) begin
        temp[j] = select[j] & j[i];   // <-- base AND index are loop variables
      end
      index[i] = |temp;
    end
    return index;
  endfunction
endmodule
