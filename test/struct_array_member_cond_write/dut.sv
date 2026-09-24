// The axi_demux_simple shape verbatim: the conditionally-written value is a
// MEMBER of an element of a packed array of structs, `in_i[i].y`.
//
// This is the same ranged-temp bug as `struct_member_cond_write_ranged_temp`
// (an unconditional default write creates `$0\out_o[1:1]`, the conditional
// write missed it and was dropped), kept separately because `read_verilog`
// cannot lower the `s_t [N-1:0]` PORT: it makes `in_i` 3 bits instead of
// N*3 and hangs the per-element reads on unconnected `\in_i[k].y` wires, so
// equiv_make reports `Can't match gold port in_i_gold to a gate port`.
// read_slang lowers it correctly, so the miter against read_slang is the
// reference here -- see test_slang_equiv.ys.
typedef struct packed { logic x; logic y; logic z; } s_t;

module struct_array_member_cond_write #(
  parameter int unsigned N = 4
) (
  input  logic [1:0] sel_i,
  input  s_t [N-1:0] in_i,
  input  logic       other_i,
  output s_t         out_o
);
  always_comb begin
    out_o.y = 1'b0;
    for (int unsigned i = 0; i < N; i++) begin
      if (sel_i == i) begin
        out_o.y = in_i[i].y;
      end
    end
  end

  always_comb begin
    out_o.x = other_i;
    out_o.z = ~other_i;
  end
endmodule
