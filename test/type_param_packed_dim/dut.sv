module dut #(
    parameter type id_t     = logic [1:0],
    parameter type resp_id_t = id_t,                   // chained
    localparam int DEPTH    = (1 << $bits(resp_id_t)), // 1<<2 = 4
    localparam type rt_t    = resp_id_t [DEPTH-1:0]    // 2*4 = 8
) (
    input  resp_id_t id_i,
    input  rt_t      rt_i,
    output logic     o
);
  assign o = ^{id_i, rt_i};
endmodule
