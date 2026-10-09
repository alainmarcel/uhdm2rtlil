// A `function automatic void` whose for loop assigns its OUTPUT formals and
// a body-local under an `if` and reads them back in later iterations:
// a lane-priority pick (`if (en && req[i] && !trig_o) begin trig_o = 1;
// idx_o = i; end`) plus a running count -- RSD CommitStage's DecideCommit
// (`recoveryTrigger`, `recoveredIndex`, `recoveryStart` over COMMIT_WIDTH).
// The loop body is unrolled by the comb path with the body's locals bridged
// in; unpatched read_uhdm could not resolve them as LHS ("Reference to
// unknown signal") and read them back from the WIRE (the final value, a
// combinational loop) instead of the in-flight value.
module void_func_local_loop_ssa(input logic [3:0] req, input logic en, output logic trig, output logic [1:0] idx, output logic [1:0] cnt);
  function automatic void Pick(output logic trig_o, output logic [1:0] idx_o, output logic [1:0] cnt_o, input logic en_i, input logic req_i[4]);
    logic [1:0] c;
    trig_o = 0; idx_o = 0; c = 0;
    for (int i = 0; i < 4; i++) begin
      if (en_i && req_i[i] && !trig_o) begin trig_o = 1; idx_o = i; end
      if (req_i[i]) c = c + 1;
    end
    cnt_o = c;
  endfunction
  logic req_a[4];
  always_comb begin
    for (int i = 0; i < 4; i++) req_a[i] = req[i];
    Pick(.trig_o(trig), .idx_o(idx), .cnt_o(cnt), .en_i(en), .req_i(req_a));
  end
endmodule
