// Combinational LUT built in a named always_comb with an unrolled for-loop,
// writing a per-element bit-select, plus a dynamic-index read.
// Mirrors Ibex ibex_cs_registers gen_mhpmevent:
//   * comb array written only in a combinational block (must NOT become $mem)
//   * array size given by an expression bound `[0 : N-1]`
//   * `for(i) arr[i]='0; if(i>=B) arr[i][i-B]=1'` — loop-unrolled constant index
//   * dynamic read `arr[sel]`
module comb_2d_bitsel #(
    parameter int N = 8,
    parameter int B = 3
) (
    input  logic [$clog2(N)-1:0] sel,
    output logic [N-1:0]         y
);
    logic [N-1:0] lut [0:N-1];

    always_comb begin : gen_lut
        for (int i = 0; i < N; i++) begin
            lut[i] = '0;
            if (i >= B) begin
                lut[i][i - B] = 1'b1;
            end
        end
    end

    assign y = lut[sel];
endmodule
