// MikePopoloski/slang#895 (closed): Potential Misinterpretation of Assignment Types in Task Calls within Always Blocks
// https://github.com/MikePopoloski/slang/issues/895
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module top (__i_clk_40m, __i_data1);
  wire clk_40m;
  reg data2;
  wire [1:0] data1;

  always @(posedge clk_40m) begin
    light(data1, data2); // Call to task light
  end

  task light;
    input data1;
    output data2;

    begin
      data2 <= !data1; // Intended as non-blocking assignment in task
    end
  endtask

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic __i_clk_40m;
  assign clk_40m = __i_clk_40m;
  input logic [1:0] __i_data1;
  assign data1 = __i_data1;
endmodule

