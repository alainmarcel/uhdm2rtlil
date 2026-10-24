// A combinational for-loop whose condition is a CONJUNCTION of the loop-variable
// bound and a runtime term: `for (int i = 0; i < 8 && found == 0; i++)`.  The
// unroller recognised only a bare comparison, reported "cannot unroll" and
// dropped the whole body, so the leading-zero count below was 0 for every
// operand -- VeeR EH2's ALU (eh2_exu_alu_ctl) counts leading/trailing zeros
// with exactly this loop and diverged on 25 co-simulated cycles.  The
// comparison bounds the unrolling; the runtime term is evaluated per
// iteration against the in-flight values and, once false, keeps every later
// iteration from running (the loop exits).  read_verilog refuses a
// non-constant loop condition, so the read_slang miter is the formal gate and
// the structural check pins the values.
module dut (
    input  logic [7:0] a,
    output logic [3:0] clz,
    output logic [3:0] first_one_plus1
);
    logic [7:0] os;
    logic       found;
    always_comb begin
        os    = a;
        clz   = 4'd0;
        found = 1'b0;
        for (int i = 0; i < 8 && found == 0; i++) begin
            if (os[7] == 1'b0) begin
                clz = clz + 4'd1;
                os  = os << 1;
            end else
                found = 1'b1;
        end
    end
    // the same shape with the runtime term FIRST and a `break` in the body
    logic hit;
    always_comb begin
        hit = 1'b0;
        first_one_plus1 = 4'd0;
        for (int j = 0; !hit && j < 8; j++) begin
            if (a[j]) begin
                first_one_plus1 = 4'(j) + 4'd1;
                hit = 1'b1;
                break;
            end
        end
    end
endmodule
