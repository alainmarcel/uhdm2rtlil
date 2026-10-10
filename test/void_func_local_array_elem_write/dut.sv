// Element writes to an UNPACKED-array local of a `function automatic void`
// as plain body statements (`t[1] = ...` on `logic [1:0] t[4]`): the
// inliner wrote ONE BIT at bit 1 of the 8-bit temp instead of element 1
// (RSD CommitStage's per-lane `recovery[i]` / `opRefetchType[i]` writes in
// DecideCommit).  2-bit elements make the element/bit confusion visible.
module void_func_local_array_elem_write(input logic [7:0] x, input logic [1:0] k, output logic [1:0] y0, output logic [1:0] y1, output logic [1:0] y2, output logic [1:0] y3);
  function automatic void Spread(output logic [1:0] o[4], input logic [7:0] x_i, input logic [1:0] k_i);
    logic [1:0] t[4];
    t[0] = x_i[1:0] + k_i;
    t[1] = x_i[3:2] ^ k_i;
    t[2] = x_i[5:4] | k_i;
    t[3] = x_i[7:6] & k_i;
    o = t;
  endfunction
  logic [1:0] r[4];
  always_comb begin
    Spread(.o(r), .x_i(x), .k_i(k));
    y0 = r[0]; y1 = r[1]; y2 = r[2]; y3 = r[3];
  end
endmodule
