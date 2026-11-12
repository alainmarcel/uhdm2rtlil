// povik/sv-elab#387 (open): `case ... inside` covering every selector value still emits a combinational loop (full case not detected)
// https://github.com/povik/sv-elab/issues/387
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module full_case (
    input  logic [2:0] sel,
    input  logic [3:0] a,
    output logic [3:0] y
);
    always_comb begin
        case (sel) inside
            3'b000: y = a;
            3'b001: y = a - 1;
            3'b010: y = a + 2;
            3'b011: y = '0;
            3'b100: y = a;
            3'b101: y = a - 1;
            3'b110: y = a;
            3'b111: y = a - 1;
        endcase
    end
endmodule

