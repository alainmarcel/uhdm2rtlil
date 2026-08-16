// CVA6 store_unit endian_data repro: a part-select write inside an if/case
// arm, AFTER a whole-signal assign whose RHS is a struct FIELD, must target
// the signal's own bits — not the struct field's offset.  The LHS import
// received current_comb_values as input_mapping and substituted the base
// (\ctrl slice / constant) for the write target, shifting the write by the
// field offset (bit 39 of the AMO operand corrupted in CVA6 store_unit).
typedef enum logic [7:0] {
  OP_B = 8'd10, OP_H = 8'd20, OP_W = 8'd73
} op_e;

typedef struct packed {
  logic        valid;
  logic [63:0] data;
  logic [7:0]  be;
  op_e         op;
} ctrl_t;

module comb_partsel_after_struct_assign (
  input  logic        mbe,
  input  ctrl_t       ctrl,
  input  logic [63:0] raw,
  output logic [63:0] endian_data,
  output logic [63:0] o_const_init
);
  // store_unit shape: struct-field init + byte-swap part-select arms
  always_comb begin
    endian_data = ctrl.data;
    if (mbe) begin
      case (ctrl.op)
        OP_B: endian_data[7:0]  = ctrl.data[7:0];
        OP_H: endian_data[15:0] = {ctrl.data[7:0], ctrl.data[15:8]};
        OP_W: endian_data[31:0] = {ctrl.data[7:0], ctrl.data[15:8],
                                   ctrl.data[23:16], ctrl.data[31:24]};
        default: endian_data[63:0] = raw;
      endcase
    end
  end

  // constant-init variant: the write target collapsed to a CONSTANT LHS
  // (the assignment was silently dropped)
  always_comb begin
    o_const_init = 64'd0;
    if (mbe) o_const_init[7:0] = raw[7:0];
  end
endmodule
