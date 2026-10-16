// An element select of a PACKED 2-D localparam array, indexed by a loop
// variable, used as the condition of a comb if/else chain.
//
// rggen_or_reducer (rggen-sv-rtl) builds its reduction tree that way:
//
//   localparam bit [N-1:0][15:0] SUB_N_LIST = get_sub_n_list(N);
//   for (int i = 0; i < NEXT_N; ++i)
//     if      (SUB_N_LIST[i] == 4) next_data[i] = <four-way OR>;
//     else if (SUB_N_LIST[i] == 2) next_data[i] = i_data[o+0] | i_data[o+1];
//     else                         next_data[i] = i_data[o+0];
//
// read_uhdm evaluated SUB_N_LIST[i] wrongly, fell through to the ELSE arm and
// emitted `next_data = i_data[0]` with no OR at all -- so rggen_mux dropped
// every entry but the first (19 of its 64 input combinations wrong) and the
// three generated register blocks diverged with it.
//
// It hid behind the parameter default: at N = 1 the correct arm IS the else
// arm, so rggen_or_reducer's own sweep row proved while every instantiation
// with N >= 2 was wrong.
module dut #(
  parameter int N = 2
)(
  input  logic [N-1:0][1:0] i_data,
  output logic [1:0]        o_data,
  output logic [15:0]       o_list0
);
  function automatic bit [N-1:0][15:0] mk_list(int n);
    bit [N-1:0][15:0] list;
    list    = '0;
    list[0] = 16'(n);          // for N=2 this is 2, which must select the OR arm
    return list;
  endfunction

  localparam bit [N-1:0][15:0] LIST = mk_list(N);

  assign o_list0 = LIST[0];

  always_comb begin
    for (int i = 0; i < 1; ++i) begin
      if (LIST[i] == 2) begin
        o_data = i_data[0] | i_data[1];
      end
      else begin
        o_data = i_data[0];
      end
    end
  end
endmodule
