// Early `return` inside a for loop of an automatic function: the unroll must
// STOP contributing after the first taken return, or a priority encoder
// becomes an OR of all matches (CVA6 miss_handler get_victim_cl returned
// 0x9a — every set bit — instead of 0x02, and evict_way_q went non-one-hot).
module func_loop_return (
    input  logic [7:0] mask,
    output logic [7:0] oh,
    output logic [3:0] cnt
);
  function automatic logic [7:0] first_oh(input logic [7:0] m);
    logic [7:0] r = '0;
    for (int unsigned i = 0; i < 8; i++) begin
      if (m[i]) begin
        r[i] = 1'b1;
        return r;
      end
    end
    return r;
  endfunction

  // A second shape: early return of a computed value mid-loop.
  function automatic logic [3:0] first_idx(input logic [7:0] m);
    for (int unsigned i = 0; i < 8; i++) begin
      if (m[i]) return 4'(i);
    end
    return 4'hF;
  endfunction

  assign oh  = first_oh(mask);
  assign cnt = first_idx(mask);
endmodule
