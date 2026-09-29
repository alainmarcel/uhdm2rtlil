// `(* uhdm_src_lhs *)` marks every wire the SOURCE assigns somewhere in the
// module (procedural or continuous LHS, a child instance's output actual,
// a struct/array base of a select), so a sweep's undriven probe can tell a
// net the RTL never assigns (cva6 trigger_module under SDTRIG=0, id_stage's
// dcache_req_ports_o under RVZCMT=0 -- the CLAUDE.md source-class table)
// from a driver the reader dropped.  test_structural.ys asserts the marking.
module leaf (input logic a, output logic y);
  assign y = ~a;
endmodule
module dut #(parameter bit EN = 0) (
  input  logic       clk,
  input  logic [7:0] d,
  output logic [7:0] q_proc,     // procedural LHS
  output logic [7:0] q_cont,     // continuous LHS
  output logic [7:0] q_part,     // part-select LHS
  output logic       q_inst,     // child output actual
  output logic [7:0] q_never,    // never assigned anywhere: no attribute
  output logic [7:0] q_gated     // assigned only under a generate-if that is off: no attribute
);
  logic [7:0] arr [4];
  logic [7:0] sel;
  always_ff @(posedge clk) q_proc <= d;
  assign q_cont = d ^ 8'h55;
  assign q_part[3:0] = d[7:4];
  assign q_part[7:4] = d[3:0];
  leaf u (.a(d[0]), .y(q_inst));
  always_ff @(posedge clk) arr[d[1:0]] <= d;
  assign sel = arr[d[3:2]];
  if (EN) begin : g
    assign q_gated = d;
  end
endmodule
