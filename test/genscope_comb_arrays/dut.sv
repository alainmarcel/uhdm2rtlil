// Two generate-scope unpacked-array classes that must NOT become $memory:
// 1. stage[] element-written by genvar CONT_ASSIGNS in nested generate-for
//    children (a $memwr needs a process, so those writes were silently
//    mis-lowered onto memrd DATA wires — ibex_alu's clmul stage arrays).
// 2. acc[] written in an always_comb via '{default} + unrolled for loops
//    with read-after-write chaining (ibex_alu's bitcnt_partial Brent-Kung
//    tree), plus a compound |= smear on a vector in the same generate
//    scope (the in-flight lookup must resolve scope-qualified keys or the
//    chain closes a comb loop through its own final value).
module genscope_comb_arrays #(
  parameter bit EN = 1'b1
) (
  input  logic [7:0]  a_i,
  input  logic [7:0]  b_i,
  output logic [7:0]  st_o,
  output logic [5:0]  cnt_o,
  output logic [7:0]  mask_o
);
  if (EN) begin : g_en
    logic [7:0] stage [4];
    for (genvar i = 0; i < 4; i++) begin : gen_st
      assign stage[i] = (a_i << i) ^ (b_i >> i);
    end
    assign st_o = stage[0] ^ stage[1] ^ stage[2] ^ stage[3];

    logic [5:0] acc [8];
    logic [7:0] smear;
    always_comb begin
      acc = '{default: '0};
      for (int unsigned i = 1; i < 8; i += 2) begin
        acc[i] = {5'h0, a_i[i]} + {5'h0, a_i[i-1]};
      end
      for (int unsigned i = 3; i < 8; i += 4) begin
        acc[i] = acc[i-2] + acc[i];
      end
      acc[7] = acc[3] + acc[7];

      smear = b_i;
      smear |= smear << 1;
      smear |= smear << 2;
      smear |= smear << 4;
    end
    assign cnt_o = acc[7];
    assign mask_o = smear;
  end else begin : g_off
    assign st_o = a_i;
    assign cnt_o = '0;
    assign mask_o = b_i;
  end
endmodule
