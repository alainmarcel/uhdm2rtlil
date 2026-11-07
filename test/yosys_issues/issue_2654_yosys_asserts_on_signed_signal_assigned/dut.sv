// YosysHQ/yosys#2654 (closed): Yosys asserts on signed signal assigned to unsigned instance port
// https://github.com/YosysHQ/yosys/issues/2654
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module my_dff #( parameter WIDTH=1) (output logic signed [WIDTH-1:0] dout);

    assign dout = 0;

endmodule

module test;
        wire signed [31:0] a_ff;

        my_dff #(32) u_my_dff(
                .dout(a_ff[31:0])
        );
endmodule

