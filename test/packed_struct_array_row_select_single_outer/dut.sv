// A packed array of structs with TWO packed dimensions (`s_t [0:0][2:1]`,
// black-parrot's per-column [E:W] link bundles with ic_x_dim_p = 1): `link[i]`
// selects a whole row of the outer dimension.  With the leaf struct taken as
// the element width, `link_li[0]` was one struct and the one-element outer
// dimension made the row index land on the inner [2:1] dimension -- the
// node's link port actuals became constant zeros in bp_io_complex.
typedef struct packed { logic v; logic [3:0] d; } s_t;
module node (input s_t [2:1] p_i, output s_t [2:1] p_o, input logic [3:0] k);
  assign p_o = ~p_i ^ {2{k}};
endmodule
module top (input s_t [0:0][2:1] in_i, input s_t [1:0][2:1] in2_i, input logic [3:0] k,
            output s_t [0:0][2:1] out_o, output s_t [2:1] row_o);
  s_t [0:0][2:1] link_li, link_lo;
  for (genvar i = 0; i < 1; i++) begin : n
    node io (.p_i(link_li[i]), .p_o(link_lo[i]), .k(k));
    assign link_li[i] = in_i[i];
  end
  assign out_o = link_lo;
  assign row_o = in2_i[1];
endmodule
