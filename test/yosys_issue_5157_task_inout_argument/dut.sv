// YosysHQ/yosys#5157: `read_verilog`: `inout` parameters not copied out of tasks
// https://github.com/YosysHQ/yosys/issues/5157
// A task's INOUT formal enters with the actual's value and leaves through it:
// `val++` / `--val` on the formal must reach the caller's variable.
module dut(output logic [7:0] out_val, output logic [7:0] out_twice,
           input logic [7:0] in_val, input logic cond);
  logic [7:0] var_m6, var_t;
  task automatic update_conditional(input logic cond, inout logic [7:0] val);
    if (cond) val++;
    else      --val;
  endtask
  task automatic add3(inout logic [7:0] v);
    v = v + 8'd3;
  endtask
  always_comb begin
    var_m6 = in_val;
    update_conditional(cond, var_m6);
    out_val = var_m6;
    var_t = in_val;
    add3(var_t);
    add3(var_t);
    out_twice = var_t;
  end
endmodule
