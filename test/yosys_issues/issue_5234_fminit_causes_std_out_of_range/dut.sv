// YosysHQ/yosys#5234 (open): fminit causes std::out_of_range
// https://github.com/YosysHQ/yosys/issues/5234
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module counter(input clk, input rst, output logic is_full);


    logic [1:0] ctr;
    always @(posedge clk) begin
        if (rst) begin
            ctr <= 0;
        end else begin
            ctr <= ctr+1;
        end
    end
    assign is_full = (ctr == 2'b11);

endmodule

