// Repro of CVA6 frontend.sv:224 cf_type latch: a packed array of a 3-bit ENUM
// (`cf_t [1:0] cf_type`) defaulted in an unrolled for-loop
// (`cf_type[i] = NoCF` — wrote 1 bit at offset i, element width ignored) and
// conditionally assigned in case arms inside a downward for-loop
// (`cf_type[i] = Jump` — wrote [2:0] for BOTH iterations, element index
// ignored).  Element 1 was never properly written -> latch + wrong decode.
module latch_packed_enum_loop (
    input  logic [1:0] is_branch_i,
    input  logic [1:0] is_jump_i,
    output logic [5:0] cf_o
);
  typedef enum logic [2:0] {
    NoCF,
    Branch,
    Jump,
    JumpR,
    Return
  } cf_t;

  cf_t [1:0] cf_type;

  always_comb begin
    for (int i = 0; i < 2; i++) cf_type[i] = NoCF;
    for (int i = 1; i >= 0; i--) begin
      unique case ({is_branch_i[i], is_jump_i[i]})
        2'b00: ;
        2'b01: cf_type[i] = Jump;
        2'b10: cf_type[i] = Branch;
        default: cf_type[i] = JumpR;
      endcase
    end
  end

  assign cf_o = cf_type;
endmodule
