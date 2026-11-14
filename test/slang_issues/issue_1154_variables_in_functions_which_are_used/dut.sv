// MikePopoloski/slang#1154 (closed): Variables in functions which are used in generate blocks are identified as multi-driven
// https://github.com/MikePopoloski/slang/issues/1154
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
function signed [7:0] incr_sum;
        input signed [7:0] a;

        logic signed [7:0] tmp;
        begin
            tmp = 'd0;
            for (int i=0; i < 8; i=i+1) begin
                tmp = tmp + a[i];
            end
            incr_sum = tmp;
        end
endfunction

module test(input signed [7:0][2:0] a,
  output logic [23:0] __o_temp);
    generate genvar m;
    logic [7:0][2:0] temp;
        for (m = 0; m < 3; m=m+1) begin : t
            always_comb begin
                temp[m] = {incr_sum(a[m])};
            end
        end
    endgenerate

  // controllable/observable ports added by test/yosys_issues/observe.py
  assign __o_temp = temp;
endmodule

