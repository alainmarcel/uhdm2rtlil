// MikePopoloski/slang#1363 (closed): Should queues be allowed access from different processes?
// https://github.com/MikePopoloski/slang/issues/1363
// Code block(s) from the issue; harvested by test/slang_issues/harvest.py

// ---- b0.sv
module queue_rw_tb (__o_clk, __o_item);
  logic clk;
  logic [7:0] queue[$]; // Dynamic queue

  initial begin
    clk = 0;
    forever #5 clk = ~clk; // 10 time unit clock
  end
	
  // Stop simulation
  initial begin
    #100 $finish;
  end

  // Producer: pushes 8-bit counters into the queue
  always_ff @(posedge clk) begin
    queue.push_back(1);
  end

  // Consumer: pops items from the queue
  logic [7:0] item;
  always_ff @(negedge clk) begin
    item = queue.pop_front();
  end

  // controllable/observable ports added by test/yosys_issues/observe.py
  output logic __o_clk;
  assign __o_clk = clk;
  output logic [7:0] __o_item;
  assign __o_item = item;
endmodule

