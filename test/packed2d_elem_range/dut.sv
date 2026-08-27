// Element-range part-select of a packed 2-D array: `arr[N-1:0]` selects the
// first N ELEMENTS (N*W bits), not the first N bits.
// CVA6 scoreboard.sv:317 `rvfi_issue_pointer_o = issue_pointer[NrIssuePorts-1:0]`
// where issue_pointer is [NrIssuePorts:0][TRANS_ID_BITS-1:0].
module dut #(
    parameter int unsigned NP = 2,
    parameter int unsigned W  = 3
) (
    input  logic [NP:0][W-1:0]   arr_i,
    output logic [NP-1:0][W-1:0] range_o,
    output logic [NP-1:0][W-1:0] range_var_o,
    output logic [W-1:0]         elem_o
);
  //  Element RANGE off a PORT.
  assign range_o = arr_i[NP-1:0];

  //  Same, but off an internal VARIABLE — how CVA6 scoreboard declares
  //  issue_pointer.  Variables do not get the packed geometry attributes that
  //  ports and nets do.
  logic [NP:0][W-1:0] arr_v;
  assign arr_v = arr_i;
  assign range_var_o = arr_v[NP-1:0];

  //  Single element, for contrast (already known good).
  assign elem_o  = arr_i[1];
endmodule
