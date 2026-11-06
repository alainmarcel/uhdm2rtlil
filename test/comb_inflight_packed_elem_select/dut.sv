// An indexed part-select over the ELEMENTS of a packed 2-D variable, read back
// in the same always_comb after a write to it -- snitch's dspu (SIMD average):
//   simd_result[2*i +: 2] = $signed(a[2*i +: 2]) + $signed(b[2*i +: 2]);
//   simd_result[2*i +: 2] = {simd_result[2*i+1][7] & s, simd_result[2*i +: 2]} >> 1;
// The in-flight read took the base from the comb value map and lost the
// declared geometry, so `[2*i +: 2]` selected two BITS of the 16-bit sum where
// the wire path selects two ELEMENTS: the half-word average read 1.
module dut (
    input  logic [31:0] a_i,
    input  logic [31:0] b_i,
    input  logic        s_i,
    output logic [31:0] r_o
);
    logic [3:0][7:0] simd_a, simd_b, simd_result;
    assign simd_a = a_i;
    assign simd_b = b_i;
    always_comb begin
        simd_result = 'b0;
        for (int i = 0; i < 2; i++) begin
            simd_result[2*i +: 2] = $signed(simd_a[2*i +: 2]) + $signed(simd_b[2*i +: 2]);
            simd_result[2*i +: 2] = {simd_result[2*i+1][7] & s_i, simd_result[2*i +: 2]} >> 1;
        end
    end
    assign r_o = simd_result;
endmodule
