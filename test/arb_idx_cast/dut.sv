// rr_arb_tree's index tree: a packed array of a TYPE-PARAMETER type, written
// in a generate loop with a cast over a concat whose part-select bounds are
// computed from the genvar.
module dut #(
    parameter int unsigned NumIn     = 4,
    parameter int unsigned NumLevels = 2,
    parameter int unsigned IdxWidth  = 2,
    parameter type         idx_t     = logic [IdxWidth-1:0]
) (
    input  logic                clk_i,
    input  logic [NumIn-1:0]    req_i,
    input  logic [NumLevels-1:0] rr_i,
    output idx_t                idx_o
);
  idx_t [2**NumLevels-2:0] index_nodes;
  logic [2**NumLevels-2:0] req_nodes;

  for (genvar level = 0; unsigned'(level) < NumLevels; level++) begin : gen_levels
    for (genvar l = 0; l < 2**level; l++) begin : gen_level
      logic sel;
      localparam int unsigned Idx0 = 2**level-1+l;
      localparam int unsigned Idx1 = 2**(level+1)-1+l*2;
      if (unsigned'(level) == NumLevels-1) begin : gen_first_level
        assign req_nodes[Idx0]   = req_i[l*2] | req_i[l*2+1];
        assign sel               = ~req_i[l*2] | req_i[l*2+1] & rr_i[NumLevels-1-level];
        assign index_nodes[Idx0] = idx_t'(sel);
      end else begin : gen_other_levels
        assign req_nodes[Idx0]   = req_nodes[Idx1] | req_nodes[Idx1+1];
        assign sel               = ~req_nodes[Idx1] | req_nodes[Idx1+1] & rr_i[NumLevels-1-level];
        assign index_nodes[Idx0] = (sel) ?
            idx_t'({1'b1, index_nodes[Idx1+1][NumLevels-unsigned'(level)-2:0]}) :
            idx_t'({1'b0, index_nodes[Idx1][NumLevels-unsigned'(level)-2:0]});
      end
    end
  end

  assign idx_o = index_nodes[0];
endmodule
