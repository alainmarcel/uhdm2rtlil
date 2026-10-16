// A packed 2-D array passed as a FORMAL of a constant function, read per
// element inside the body (`sub[i-1]`, `sub[i]`).
//
// rggen_or_reducer (rggen-sv-rtl) folds its reduction schedule that way:
//
//   localparam bit [N-1:0][15:0] SUB_N_LIST  = get_sub_n_list(N);
//   localparam bit [N-1:0][15:0] OFFSET_LIST = get_offset_list(SUB_N_LIST);
//   localparam int               NEXT_N      = get_next_n(SUB_N_LIST);
//
// register_function_local registers the inner element width of a packed
// multi-dim LOCAL, but the formal-binding loop registered nothing for a packed
// multi-dim FORMAL, so `sub[i-1]` read ONE BIT of the argument: OFFSET_LIST
// folded to all zeros and NEXT_N counted set bits instead of non-zero
// elements.  At N = 5 the reducer then read entries 0..2 for every slot and
// lost entries 3 and 4 -- rggen's generated register blocks (block_0, block_1,
// uart_csr) diverged on every readback.
//
// Values at N = 5: SUB = [2,3,0,0,0], OFF = [0,2,5,5,5], NEXT = 2.
module dut (
  output logic [15:0] s0, s1, s2,
  output logic [15:0] o0, o1, o2,
  output logic [31:0] nn
);
  localparam int N = 5;

  function automatic bit [N-1:0][15:0] gsl(int n);
    bit [N-1:0][15:0] list;
    int list_index;
    bit [15:0] current_n;
    bit [15:0] half_n;
    list = '0; list_index = 0; current_n = 16'(n);
    while (current_n > 0) begin
      half_n = current_n / 2;
      if ((current_n > 4) && (half_n <= 4)) list[list_index] = half_n;
      else if (current_n >= 4)             list[list_index] = 4;
      else                                 list[list_index] = current_n;
      current_n  -= list[list_index];
      list_index += 1;
    end
    return list;
  endfunction

  function automatic bit [N-1:0][15:0] gol(bit [N-1:0][15:0] sub);
    bit [N-1:0][15:0] list;
    for (int i = 0; i < N; ++i) begin
      if (i == 0) list[i] = 0;
      else        list[i] = sub[i-1] + list[i-1];
    end
    return list;
  endfunction

  function automatic int gnn(bit [N-1:0][15:0] sub);
    int next_n = 0;
    for (int i = 0; i < N; ++i) next_n += ((sub[i] != 0) ? 1 : 0);
    return next_n;
  endfunction

  localparam bit [N-1:0][15:0] SUB  = gsl(N);
  localparam bit [N-1:0][15:0] OFF  = gol(SUB);
  localparam int               NEXT = gnn(SUB);

  assign s0 = SUB[0]; assign s1 = SUB[1]; assign s2 = SUB[2];
  assign o0 = OFF[0]; assign o1 = OFF[1]; assign o2 = OFF[2];
  assign nn = NEXT;
endmodule
