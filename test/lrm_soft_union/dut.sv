// IEEE 1800-2023 7.3.1 (new in 2023): a SOFT packed union may have members of
// different widths; narrower members are right-justified.
module dut(input logic [15:0] a, input logic [3:0] b,
           output logic [15:0] y, output logic [3:0] z);
  typedef union soft { logic [15:0] w; logic [3:0] n; } u_t;
  u_t u, v;
  always_comb begin
    u.w = a;
    z   = u.n;
    v.w = '0;
    v.n = b;
    y   = v.w ^ a;
  end
endmodule
