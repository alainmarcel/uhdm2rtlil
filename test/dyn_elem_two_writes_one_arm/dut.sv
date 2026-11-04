// Two DYNAMIC-index writes to the same unpacked array in one arm of a
// combinational block: `n[i] = d0; n[i+1] = d1;` (OpenPiton noc1buffer's CAS
// request fills two data slots).
module dut(input logic v, input logic cas, input logic idx,
           input logic [7:0] b0, input logic [7:0] b1,
           input logic [7:0] d0, input logic [7:0] d1,
           output logic [7:0] q0, output logic [7:0] q1);
  logic [7:0] n [0:1];
  logic idx_p1;
  always @* begin
    n[0] = b0;
    n[1] = b1;
    idx_p1 = idx + 1'b1;
    if (v) begin
      if (cas) begin
        n[idx]    = d0;
        n[idx_p1] = d1;
      end else begin
        n[idx] = d0;
      end
    end
  end
  assign q0 = n[0];
  assign q1 = n[1];
endmodule
