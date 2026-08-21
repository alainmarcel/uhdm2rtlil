// Minimal: a block-local STRUCT assigned from an input, then its FIELD read
// in the same always_comb.
module dut #(
    parameter int unsigned EXP_BITS = 5,
    parameter int unsigned MAN_BITS = 10
) (
    input  logic [EXP_BITS+MAN_BITS:0] operand_i,
    output logic                       exp_nz_o,
    output logic [EXP_BITS-1:0]        exp_o
);
  typedef struct packed {
    logic                sign;
    logic [EXP_BITS-1:0] exponent;
    logic [MAN_BITS-1:0] mantissa;
  } fp_t;

  for (genvar op = 0; op < 1; op++) begin : gen_op
    fp_t value;                    // block-local struct INSIDE a genvar block
    always_comb begin
      value    = operand_i;
      exp_o    = value.exponent;
      exp_nz_o = (value.exponent != '0);
    end
  end
endmodule
