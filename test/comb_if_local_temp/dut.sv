// if-based variant of the same class: temp local to one branch.  No latch.
module comb_if_local_temp (
  input  logic        sel,
  input  logic [31:0] a,
  output logic [15:0] y
);
  logic [31:0] t;
  always_comb begin
    if (sel) begin
      t = a ^ 32'hA5A5_5A5A;
      y = t[15:0] + t[31:16];
    end else begin
      y = a[15:0];
    end
  end
endmodule
