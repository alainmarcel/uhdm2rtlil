// Dynamic element select on a packed-array parameter + multi-index reads of
// a fully packed 3-D variable (fpnew_opgroup_block / fpnew_cast_multi shapes):
//  - UT[sel] with a runtime index must $shiftx the parameter constant with
//    ascending-range element order (element 0 at the MSBs).
//  - pipe[k][j] on `logic [0:N][2:0][W-1:0]` must slice the right chunk.
package pdes_pkg;
  typedef enum logic [1:0] {NONE, PARALLEL, MERGED} ut_e;
  localparam int unsigned NFMT = 5;
  typedef ut_e [0:NFMT-1] fmt_ut_t;
endpackage

module param_dyn_elem_select (
    input  logic        clk,
    input  logic [2:0]  sel,
    input  logic [31:0] din,
    output logic [1:0]  ut_out,
    output logic [31:0] pipe_out,
    output logic        is_par
);
  localparam pdes_pkg::fmt_ut_t UT =
      {pdes_pkg::PARALLEL, pdes_pkg::MERGED, pdes_pkg::NONE,
       pdes_pkg::MERGED, pdes_pkg::PARALLEL};

  // dynamic element select on the parameter (ascending [0:4])
  assign ut_out = UT[sel];
  assign is_par = (UT[sel] == pdes_pkg::PARALLEL);

  // packed 3-D pipeline array, read with two const indices
  logic [0:1][2:0][31:0] pipe;

  always_ff @(posedge clk) begin
    pipe[0][0] <= din;
    pipe[0][1] <= din ^ 32'hffff_ffff;
    pipe[0][2] <= din + 32'd1;
    pipe[1]    <= pipe[0];
  end

  assign pipe_out = pipe[1][0];
endmodule
