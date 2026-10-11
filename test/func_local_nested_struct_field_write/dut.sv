// RSD BypassController: SelectReg builds its BypassSelect result in a local
// `ret` whose `lane` member is itself a struct (`ret.lane.intLane = i`).  The
// inlined function body handled only the two-element `local.field` write; the
// nested one was DROPPED without a warning and the function returned its
// `'0` default -- no bypass lane was ever selected.
typedef enum logic [1:0] { S_INT_EX = 0, S_INT_WB = 1, S_MEM_MA = 2, S_MEM_WB = 3 } stage_t;
typedef struct packed { logic intLane; logic complexLane; logic memLane; } lane_t;
typedef struct packed { logic valid; stage_t stg; lane_t lane; } sel_t;
function automatic sel_t Sel(input logic a, input logic b, input logic [1:0] lane);
  sel_t ret;
  ret.valid = 1'b0;
  ret.stg = S_INT_EX;
  ret.lane.intLane = 0;
  ret.lane.memLane = 0;
  ret.lane.complexLane = 0;
  if (a) begin
    ret.valid = 1'b1; ret.stg = S_INT_WB; ret.lane.intLane = lane;
  end else if (b) begin
    ret.valid = 1'b1; ret.stg = S_MEM_MA; ret.lane.memLane = 1'b1;
  end
  return ret;
endfunction
// The same write inside a loop with `break` (SelectReg's real shape) comes
// through the function statement importer instead of the inline path.
function automatic sel_t SelLoop(input logic [1:0] hit);
  sel_t ret;
  ret = '0;
  for (int i = 0; i < 2; i++) begin
    if (hit[i]) begin ret.valid = 1'b1; ret.lane.intLane = i; break; end
  end
  return ret;
endfunction
module func_local_nested_struct_field_write(input logic a, input logic b, input logic [1:0] lane, input logic [1:0] hit, output logic [5:0] o, output logic [5:0] p);
  always_comb begin o = Sel(a, b, lane); p = SelLoop(hit); end
endmodule
