// A module-level unpacked array (memory) whose dynamic write (always_ff) and
// dynamic read (continuous assign) both live inside a generate block.  The
// const-access analyzer only scanned module-level processes, so it missed the
// gen-scope accesses and degraded `storage` to per-element wires, dropping the
// dynamic write/read to X.
module genscope_mem_access #(parameter int Width = 8, parameter int Depth = 4) (
  input  logic                   clk,
  input  logic                   we,
  input  logic [$clog2(Depth)-1:0] waddr,
  input  logic [$clog2(Depth)-1:0] raddr,
  input  logic [Width-1:0]       wd,
  output logic [Width-1:0]       rd);
  logic [Width-1:0] storage [Depth];
  if (Depth > 1) begin : g
    always_ff @(posedge clk) if (we) storage[waddr] <= wd;
    assign rd = storage[raddr];
  end
endmodule
