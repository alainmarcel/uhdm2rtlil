// A DYNAMIC indexed part-select write over the ELEMENTS of a packed 2-D
// variable -- snitch dspu's pv.insert (half-word):
//   simd_result = simd_gated.op_c;
//   simd_result[2*simd_gated.imm6[0] +: 2] = simd_op_a[1:0];
// `[2*s +: 2]` on a `logic [3:0][7:0]` selects two 8-bit elements, 16 bits at
// bit 16*s.  The dynamic write emitter worked in bits and wrote two BITS at bit
// 2*s: the inserted half-word kept 15 of op_c's 16 bits.
module dut (
    input  logic [31:0] a_i,
    input  logic [31:0] c_i,
    input  logic        s_i,
    output logic [31:0] r_o
);
    logic [3:0][7:0] simd_op_a, simd_op_c, simd_result;
    assign simd_op_a = a_i;
    assign simd_op_c = c_i;
    always_comb begin
        simd_result = simd_op_c;
        simd_result[2*s_i +: 2] = simd_op_a[1:0];
    end
    assign r_o = simd_result;
endmodule
