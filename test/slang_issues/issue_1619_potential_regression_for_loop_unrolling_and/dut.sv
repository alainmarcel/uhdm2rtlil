// MikePopoloski/slang#1619 (closed): Potential regression for loop-unrolling and driver-conflict logic
// https://github.com/MikePopoloski/slang/issues/1619
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top;
    parameter W  = 16;
    parameter P1 = 8;
    parameter P2 = 2;

    logic [W-1:0] sig1;
    logic [P1-1:0][P2-1:0] sig2;


    for (genvar i=0;i<P1;i++) begin: gen_i
        always_comb begin
            for (int j=0; j<P2;j++) begin
                sig1[(i*P1 + j) +: 1] = sig2[i][j];
            end
        end
    end
endmodule

