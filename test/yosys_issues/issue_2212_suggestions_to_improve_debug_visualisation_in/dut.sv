// YosysHQ/yosys#2212 (open): Suggestions to Improve debug/visualisation in SMT2 backend for SBY
// https://github.com/YosysHQ/yosys/issues/2212
// Code block(s) from the issue; harvested by test/yosys_issues/harvest.py

// ---- b0.sv
`default_nettype none
module fsm (input wire clk, rstn, start, a, b, c, d,
            output reg [1:0] state_val);
        
        localparam [3:0] s0=0, s1=1, s2=2, s3=3;
        reg [1:0] ps, ns;

        wire jump_s2, jump_s3, return_w;
        assign jump_s2 = &({a,b,c,d});
        assign jump_s3 = (~a & b & c & ~d);
        assign return_w  = (a | d & ~b);

        always @(posedge clk) begin
                if (~rstn) ps <= s0;
                else       ps <= ns;
        end
        
        always @(*) begin
                ns = ps;
                case (ps)
                        s0: if (start)   ns = s1;
                        s1: if (jump_s2) ns = s2;
                        s2: if (jump_s3) ns = s3;
                        s3: if (return_w)  ns = s0;
                endcase
        end
        assign state_val = ps;

        // Assertion logic
        always @(*) assume (rstn == 1'b1);
        always @(posedge clk) if (ps == s2 && jump_s3) assert (ps == s3);
endmodule

// ---- b1.sv
// Assert container
module assert_always (input wire event_m, disable_e, precondition, condition);
`ifndef _SV_
	always @(*) assume (disable_e == 1'b1);
	always @(posedge event_m)
                if (precondition) assert (condition);
`else
	assert_always_i: assert property (@(posedge event_m) disable iff (!disable_e) 
					    precondition |-> condition);
`endif

// Assert container instance
wire cause  = (ps == s2 && jump_s3);
wire effect = (ps == s3); // check ns instead, to fix it
assert_always checker_inst (clk, rstn, cause, effect);
endmodule

