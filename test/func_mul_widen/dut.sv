module func_mul_widen (
  input  logic [1:0] spimm,
  input  logic [3:0] rlist,
  output logic [6:0] adj,
  output logic [4:0] adj_word,
  output logic [4:0] off
);
  function automatic logic [6:0] stack_adj_base(input logic [3:0] rl);
    unique case (rl)
      4'd4, 4'd5, 4'd6, 4'd7: return 7'd16;
      4'd8, 4'd9:             return 7'd32;
      default:                return 7'd0;
    endcase
  endfunction

  function automatic logic [6:0] stack_adj(input logic [3:0] rl, input logic [1:0] sp);
    return stack_adj_base(rl) + sp * 16;
  endfunction

  function automatic logic [4:0] stack_adj_word(input logic [3:0] rl, input logic [1:0] sp);
    logic [6:0] tmp;
    logic [1:0] unused_tmp;
    tmp = stack_adj(.rl(rl), .sp(sp));
    unused_tmp = tmp[1:0];
    return tmp[6:2];
  endfunction

  assign adj = stack_adj(rlist, spimm);
  assign adj_word = stack_adj_word(.rl(rlist), .sp(spimm));
  always_comb off = stack_adj_word(.rl(rlist), .sp(spimm)) - 5'd1;
endmodule
