// Reproducer for chipsalliance/synlig#686 — `break` inside a
// for-loop body raised "Encountered unhandled object '' of type
// 'break_stmt'".  Original source is orv64's
// `rtl/common/pygmy_func.sv` (commented-out form preserved as
// `pygmy_func copy.sv`) — the `lru8_get_replace_way_id`
// function's "find empty way" first-match loop:
//
//   for (int i = 0; i < 8; i++) begin
//     if (~way_valid[i] & way_enable[i]) begin
//       has_empty_way  = '1;
//       replace_way_id = i;
//       break;
//     end
//   end
//
// We keep orv64's `package pygmy_func` + `function automatic void
// lru8_get_replace_way_id(...)` form so this exercises break inside
// a task-call inline, not just a standalone always_comb loop.  The
// DUT exposes the function outputs as module outputs so a co-sim
// sweep over `way_valid` / `way_enable` checks the first-match-wins
// semantics our static unrolling has to emulate (proc otherwise
// gives last-write-wins).
package pygmy_func;
  function automatic void lru8_get_replace_way_id (
    output logic [2:0] replace_way_id,
    output logic       has_empty_way,
    input  logic [7:0] way_valid,
    input  logic [7:0] way_enable
  );
    has_empty_way  = 1'b0;
    replace_way_id = 3'b0;
    for (int i = 0; i < 8; i++) begin
      if (~way_valid[i] & way_enable[i]) begin
        has_empty_way  = 1'b1;
        replace_way_id = i[2:0];
        break;
      end
    end
  endfunction
endpackage

module for_break (
    input  logic [7:0] way_valid,
    input  logic [7:0] way_enable,
    output logic       has_empty_way,
    output logic [2:0] replace_way_id
);
    import pygmy_func::*;
    always_comb
        lru8_get_replace_way_id(replace_way_id, has_empty_way, way_valid, way_enable);
endmodule
