// povik/sv-elab#376 (open): Function called from multiple procedural blocks yields conflicting drivers on the shared argument wire (spurious $dlatch)
// https://github.com/povik/sv-elab/issues/376
// Code block(s) from the issue; harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
module t4kq (
  input  wire g7w,
  input  wire n2c,
  input  wire e9d,
  output reg  r5m,
  output reg  w3z
);

  function q8j;
    input h6t;
    q8j = ~h6t;
  endfunction

  // call site 1: unconditional
  always @* r5m = q8j(n2c);

  // call site 2: conditionally reached
  always @* begin
    w3z = 1'b0;
    if (g7w) w3z = q8j(e9d);
  end
endmodule

