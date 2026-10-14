// A MODULE-LEVEL loop variable read AFTER its loop, where the loop is a
// SIBLING of itself across the iterations of an enclosing loop -- the shape of
// cvw's carry-less multiplier (src/ieu/bmu/clmul.sv), shared by the clmul,
// zbc, bitmanipalu and alu rows.
//
// `j`'s post-loop value is `i+1` (the init runs, then the condition fails), and
// `R[i] = S[8*i+j-1]` reads exactly that.  But `loop_values["j"]` SURVIVES the
// inner loop, because `j` is declared at module level -- so from outer
// iteration 1 on, the leftover entry made the inner loop look NESTED inside an
// enclosing loop over `j` and its post-loop value was RESTORED to the 1 that
// iteration 0 left behind.  Every `R[i]` then read `S[8*i]`, the first partial
// product, instead of the accumulated one.
module dut (
    input  logic [7:0] X,
    input  logic [7:0] Y,
    output logic [7:0] R
);
    logic [63:0] S;
    integer i, j;

    always_comb begin
        for (i = 0; i < 8; i++) begin : outer
            S[8*i] = X[0] & Y[i];
            for (j = 1; j <= i; j++) begin : inner
                S[8*i+j] = (X[j] & Y[i-j]) ^ S[8*i+j-1];
            end
            R[i] = S[8*i+j-1];
        end
    end
endmodule
