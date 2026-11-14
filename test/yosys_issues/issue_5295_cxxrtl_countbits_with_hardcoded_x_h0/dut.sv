// YosysHQ/yosys#5295 (closed): cxxrtl countbits with hardcoded `x`
// https://github.com/YosysHQ/yosys/issues/5295
// Code block(s) from the issue (variant h0); harvested by test/yosys_issues/harvest.py

// ---- b0.sv
module countbits (__o_cnt, __o_in_d);
    logic [7:0] in_d;
    logic [3:0] cnt;

    assign cnt = $countbits(in_d, 1'b1);
    assign in_d = 8'h8F; 

    always_comb assert(cnt == 4'd5);

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic [3:0] __o_cnt;
  assign __o_cnt = cnt;
  output logic [7:0] __o_in_d;
  assign __o_in_d = in_d;
endmodule

