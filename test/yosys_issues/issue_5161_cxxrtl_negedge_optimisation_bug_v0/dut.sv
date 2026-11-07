// YosysHQ/yosys#5161 (closed): CXXRTL - negedge optimisation bug
// https://github.com/YosysHQ/yosys/issues/5161
// Code block(s) from the issue (variant v0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module bug;
    reg [6:0] reg_bug;
    reg clk = 1;
    
    always_ff @(negedge clk)
        reg_bug <= 7'b0011111;
    
    initial begin
        #1 clk = 0;  // negedge trigger
        #1 $display("reg_bug=%b expected=0011111 %s", 
                   reg_bug, reg_bug == 7'b0011111 ? "PASS" : "FAIL");
    end
endmodule

