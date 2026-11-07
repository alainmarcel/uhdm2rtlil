// YosysHQ/yosys#3291 (closed): ERROR: 2nd expression of procedural for-loop is not constant!
// https://github.com/YosysHQ/yosys/issues/3291
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module GetInsnPtr(
    output logic headOfThisInsn[2],
    input  logic last [2]
);
    always_comb begin
        for (int i = 0; i < 2; i++) begin
            headOfThisInsn[i] = 0;
            for (int j = i - 1; 0 <= j; j--) begin
                if (last[j]) begin
                    headOfThisInsn[i] = j + 1;
                    break;
                end
            end
        end
    end
endmodule

