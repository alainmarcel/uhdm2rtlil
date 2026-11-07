// YosysHQ/yosys#3657: an async-reset flop whose body is a plain assignment
// with the reset folded into a ternary, not an `if (r) ... else ...`:
//
//     always_ff @(posedge ck, posedge r) q <= r ? '0 : d;
//
// read_verilog aborts ("Async reset \r yields non-constant value") and
// read_slang refuses the shape ("simple if-else pattern expected").  The
// LRM is clear: on a posedge of r the body runs with r == 1 and q takes 0;
// on a posedge of ck it takes d (r is 0 there, or the reset is already
// holding q at 0) -- an $adff with ARST_VALUE 0 and D = d.
module dut(input logic d, r, ck, output logic q, output logic [3:0] w,
           output logic [1:0] s);
  always_ff @(posedge ck, posedge r) q <= r ? '0 : d;
  // the same with a non-trivial clocked value, a negedge reset, and a
  // begin/end body
  always_ff @(posedge ck or negedge r) begin
    w <= !r ? 4'd0 : w + 4'd1;
  end
  // two registers in one body, the reset value of the second is 2'b11
  always_ff @(posedge ck, posedge r) begin
    s <= r ? 2'b11 : {s[0], d};
  end
endmodule
