// YosysHQ/yosys#2654 (closed): Yosys asserts on signed signal assigned to unsigned instance port
// https://github.com/YosysHQ/yosys/issues/2654
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// HAND-EDITED (keep on re-harvest): ports added: a observes a_ff, ax = a_ff ^ t over a new input t (the snippet had no ports; a_ff is a constant)

// ---- b0.sv
module my_dff #( parameter WIDTH=1) (output logic signed [WIDTH-1:0] dout);

    assign dout = 0;

endmodule

module test(input logic [31:0] t, output logic [31:0] a, output logic [31:0] ax);
        assign a = a_ff;
        assign ax = a_ff ^ t;
        wire signed [31:0] a_ff;

        my_dff #(32) u_my_dff(
                .dout(a_ff[31:0])
        );
endmodule

