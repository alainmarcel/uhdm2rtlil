package func_param_table_pkg; typedef logic [3:0] nib_t; endpackage
module func_param_table_core #(parameter int W = 8, parameter bit EN = 1'b0) (input logic [2:0] rnd, input logic [5*W-1:0] s_i, output logic [5*W-1:0] s_o);
  localparam int Rot [5][2] = '{ '{0, 3}, '{1, 4}, '{2, 0}, '{3, 1}, '{4, 2} };
  localparam logic [W-1:0] RC [8] = '{8'h01, 8'h82, 8'h8a, 8'h00, 8'h8b, 8'h01, 8'h81, 8'h09};
  function automatic logic [5*W-1:0] pi(logic [5*W-1:0] st);
    logic [5*W-1:0] r;
    for (int x = 0; x < 5; x++) r[x*W +: W] = st[Rot[x][1]*W +: W] ^ st[Rot[x][0]*W +: W];
    return r;
  endfunction
  function automatic logic [5*W-1:0] iota(logic [5*W-1:0] st, logic [2:0] rr);
    logic [5*W-1:0] r; r = st; r[W-1:0] = st[W-1:0] ^ RC[rr][W-1:0]; return r;
  endfunction
  if (EN) begin : g_m
    assign s_o = iota(pi(s_i), rnd);
  end else begin : g_s
    assign s_o = pi(s_i) ^ iota(s_i, rnd);
  end
endmodule
module func_param_table_wrapper_override import func_param_table_pkg::*; (input logic [2:0] rnd, input logic [39:0] s_i, output logic [39:0] s_o);
  func_param_table_core #(.W(8), .EN(1'b1)) u (.rnd, .s_i, .s_o);
endmodule
