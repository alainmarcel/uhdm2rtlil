// bw_r_itlb shape: ONE negedge block; per entry a guarded NON-BLOCKING write
// (with an else arm that reads the entry through a blocking temp), then further
// down the same block a guarded BLOCKING read of the same entry into the same
// temp, forwarded with a non-blocking assignment.  The late read must see the
// entry's value from BEFORE the edge, never the write that is landing.
module dut (
  input  logic       clk,
  input  logic       we,
  input  logic       tri_en,
  input  logic       re,
  input  logic       rd,
  input  logic [1:0] wsel,
  input  logic [1:0] rsel,
  input  logic [7:0] wd,
  output logic [7:0] q,
  output logic [7:0] q2
);
  reg [7:0] ram [0:1];
  reg [7:0] tmp;
  reg [7:0] tmp2;    // written through a full-width RANGE, as the TLBs do
  always @(negedge clk) begin
    if (wsel[0] & we) begin
      if (~tri_en) begin
        ram[0] <= wd;
        q <= wd;
        q2 <= wd;
      end else begin
        tmp = ram[0];
        q <= tmp;
        tmp2[7:0] = ram[0];
        q2 <= {tmp2[7:4], tmp2[3:0]};
      end
    end
    if (wsel[1] & we) begin
      if (~tri_en) begin
        ram[1] <= wd;
        q <= wd;
        q2 <= wd;
      end else begin
        tmp = ram[1];
        q <= tmp;
        tmp2[7:0] = ram[1];
        q2 <= {tmp2[7:4], tmp2[3:0]};
      end
    end
    if (rsel[0] & re) begin
      tmp = ram[0];
      tmp2[7:0] = ram[0];
      if (rd) begin q <= tmp; q2 <= {tmp2[7:4], tmp2[3:0]}; end
    end
    if (rsel[1] & re) begin
      tmp = ram[1];
      tmp2[7:0] = ram[1];
      if (rd) begin q <= tmp; q2 <= {tmp2[7:4], tmp2[3:0]}; end
    end
  end
endmodule
