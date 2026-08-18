module dut (
    input  logic [63:0] base_i,
    input  logic [2:0]  addr_i,
    input  logic        we_i,
    input  logic [63:0] wdata_i,
    output logic [63:0] o
);
  logic [63:0] q[4:1], d[4:1];
  always_comb for (int unsigned k = 1; k <= 4; k++) q[k] = base_i + 64'(k);
  always_comb begin
    d = q;                                   // whole-array default
    if (we_i && addr_i >= 3'd1 && addr_i <= 3'd4)
      d[addr_i] = wdata_i;                   // guarded DYNAMIC-index write
  end
  assign o = d[1] ^ d[2] ^ d[3] ^ d[4];
endmodule
