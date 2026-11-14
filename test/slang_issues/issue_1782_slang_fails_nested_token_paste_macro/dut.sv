// MikePopoloski/slang#1782 (closed): Slang fails nested token-paste macro expansion in parameterized macro
// https://github.com/MikePopoloski/slang/issues/1782
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
`define DEF(d,v) \
  `ifndef d \
    `define d v \
  `endif

`define INT(_param, _int)     int _param``_INT = _int
`define FRAC(_param, _frac=0) int _param``_FRAC = _frac

`define FIXED_LOCALPARAM(_param, _int, _frac=0) \
  localparam `INT(_param, _int); \
  localparam `FRAC(_param, _frac)

`define FIXED_WIDTH(_param) ((_param``_INT) + (_param``_FRAC))

`define FIXED_VAR(_param, _var) \
  `DEF(PARAM_NAME_``_var, _param) \
  logic signed [`FIXED_WIDTH(_param)-1:0] _var

`define INST(_mod, _inst, _suffix) ._mod``_suffix(_inst``_suffix)
`define INST2(_mod, _inst1, _inst2, _suffix) ._mod``_suffix({_inst1``_suffix, _inst2``_suffix})

`define FIXED_PARAM_INST(_mod, _inst) \
  `INST(_mod, _inst, _INT), \
  `INST(_mod, _inst, _FRAC)

`define FIXED_PARAM_INST2(_mod, _inst1, _inst2) \
  `INST2(_mod, _inst1, _inst2, _INT), \
  `INST2(_mod, _inst1, _inst2, _FRAC)

`define ADD2_PARAM_INST(_sum_param, _a_param, _b_param) \
  `FIXED_PARAM_INST(SUM, _sum_param), \
  `FIXED_PARAM_INST2(DIN, _a_param, _b_param)

`define ADD2(_sum_var, _a_var, _b_var) \
  fixed_add #(`ADD2_PARAM_INST(`PARAM_NAME_``_sum_var, `PARAM_NAME_``_a_var, `PARAM_NAME_``_b_var)) \
  u_add_``_sum_var ( \
    .sum(_sum_var), \
    .din({_a_var, _b_var}) \
  )

module fixed_add #(
  parameter int SUM_INT = 5,
  parameter int SUM_FRAC = 7,
  parameter int DIN_INT = '{4,4},
  parameter int DIN_FRAC = '{7,7}
) (
  output logic signed [SUM_INT+SUM_FRAC-1:0] sum,
  input  logic signed [DIN_INT[0]+DIN_FRAC[0]+DIN_INT[1]+DIN_FRAC[1]-1:0] din
);
  localparam int WA = DIN_INT[0] + DIN_FRAC[0];
  localparam int WB = DIN_INT[1] + DIN_FRAC[1];
  wire signed [WA-1:0] a = din[WA+WB-1:WB];
  wire signed [WB-1:0] b = din[WB-1:0];
  assign sum = $signed(a) + $signed(b);
endmodule

module using_add;
  `FIXED_LOCALPARAM(DATA, 4, 7);
  `FIXED_LOCALPARAM(SUM, 5, 7);

  `FIXED_VAR(DATA, a);
  `FIXED_VAR(DATA, b);
  `FIXED_VAR(SUM, sum);

  assign a = 'sd10;
  assign b = 'sd6;

  // This line triggers diagnostics in slang-server
  `ADD2(sum, a, b);
endmodule

