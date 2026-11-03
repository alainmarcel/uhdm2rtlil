// A packed parameter TABLE written as one FLAT concatenation and read with
// several indices: `pkg::LUT[2][1][3]`.  UHDM's evaluator walked the concat
// one operand per index -- right only when the concat is nested one level per
// dimension -- so a flat table with more operands than its outer dimension
// has elements picked operand 1 of the flat list and then BIT 0 of it, and a
// table Surelog had already folded to a constant was not handled before the
// first index at all.  core-v-mcu's tcdm_interconnect_pkg tables
// (`ClosNLut/ClosMLut/ClosRLut`, `logic [3:1][4:0][12:2][15:0]` = 165 flat
// literals) made `ClosR` 0: every generate loop bounded by it ran zero times
// and clos_net lost all of its crossbar nodes (320 cells where read_slang
// builds 1247; contiguous_crossbar and interleaved_crossbar likewise).
package lut_pkg;
  localparam logic [2:1][1:0][3:2][7:0] LUT = {8'd1, 8'd2, 8'd3, 8'd4, 8'd5, 8'd6, 8'd7, 8'd8};
  localparam logic [1:0][1:0][15:0]     T2  = {16'd3, 16'd5, 16'd6, 16'd7};
endpackage

module dut (
    input  logic [7:0]  a,
    output logic [7:0]  y,
    output logic [15:0] z,
    output logic [7:0]  m
);
  localparam int unsigned N = 32'(lut_pkg::LUT[2][1][3]);   // first element: 1
  localparam int unsigned M = 32'(lut_pkg::LUT[1][0][2]);   // last element: 8
  localparam int unsigned K = lut_pkg::T2[1][0];            // 5
  for (genvar k = 0; unsigned'(k) < N; k++) begin : g_n
    assign y[k] = ~a[k];
  end
  for (genvar k = N; unsigned'(k) < M; k++) begin : g_m
    assign y[k] = a[k];
  end
  assign z = K;
  assign m = M;
endmodule
