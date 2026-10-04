// An INSTANCE ARRAY whose vector actuals are partitioned across the members
// (LRM 28.3.5): `camline lines[7:0](.we(wes), .match(hits), .tag(tags))`
// hands member k bit k of `wes`/`hits` and 3-bit slice k of `tags`.  The
// hierarchy-path instance import connected every member to the WHOLE actual,
// which yosys' hierarchy pass then resized to the LOW bits: all eight
// members read `wes[0]` and drove `hits[0]`, and `tags` reached only its
// low slice.  CORE-V Wally's tlbcam (8 camlines) matched nothing: 201 of 301
// co-sim cycles diverged.  The gate is the ordinary read_verilog equivalence
// (read_verilog partitions instance-array actuals) plus the co-sim.
module camline (
  input        clk,
  input        we,
  input  [2:0] key_in,
  input  [2:0] query,
  output [2:0] tag,
  output       match
);
  reg [2:0] key;
  always @(posedge clk) if (we) key <= key_in;
  assign match = (key == query);
  assign tag   = match ? key : 3'd0;
endmodule

module dut (
  input         clk,
  input  [7:0]  wes,
  input  [2:0]  key_in,
  input  [2:0]  query,
  output [23:0] tags,
  output [7:0]  hits
);
  camline lines[7:0] (.clk(clk), .we(wes), .key_in(key_in), .query(query),
                      .tag(tags), .match(hits));
endmodule
