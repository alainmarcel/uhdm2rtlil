// A PURE unpacked array (1-bit element, so no packed dimension) declared
// INSIDE a generate block, with each element written by its own always_ff.
//
// `is_memory_array()` does not claim such an array — it needs both a packed
// and an unpacked dimension.  The module-level importer has a dedicated
// branch for this shape ("1D unpacked with bit-select-only access") that
// materialises `\v_q[0]`, `\v_q[1]`; the generate-scope importer had none, so
// the array fell through to the generic single-wire creation and came out as
// ONE 1-bit reg.  Element [1] was aliased onto [0] and every read of it was X.
//
// read_slang keeps 2 bits.  Pavona acc_alu_bignum's
// gen_pqc_wsr.kmac_msg_valid_q [Share] is the shape in the wild: it fed
// kmac_msg_pending_write_o[1], rw_after_last and write_during_last, so the
// module's co-sim diverged on kmac_intf_fatal_error_o.
module genscope_unpacked_array_per_elem_ff
  #(parameter bit En = 1'b1, localparam int Share = 2)
  (input  logic       clk_i,
   input  logic       rst_ni,
   input  logic [1:0] set_i,
   input  logic [1:0] clr_i,
   output logic [1:0] q_o,
   output logic       any_o);
generate
  if (En) begin : gen_blk
    logic v_q [Share];

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)       v_q[0] <= 1'b0;
      else if (set_i[0]) v_q[0] <= 1'b1;
      else if (clr_i[0]) v_q[0] <= 1'b0;
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
      if (!rst_ni)       v_q[1] <= 1'b0;
      else if (set_i[1]) v_q[1] <= 1'b1;
      else if (clr_i[1]) v_q[1] <= 1'b0;
    end

    // Read the elements both individually and combined, so a collapsed
    // array shows up on the outputs either way.
    assign q_o   = {v_q[1], v_q[0]};
    assign any_o = v_q[0] | v_q[1];
  end else begin : gen_off
    assign q_o   = '0;
    assign any_o = 1'b0;
  end
endgenerate
endmodule
