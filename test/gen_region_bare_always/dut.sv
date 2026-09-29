// An always_ff written directly inside a `generate ... endgenerate` region,
// next to a genvar loop (cv32e40p_register_file_ff's "R0 is nil" block).
// Surelog lifts a bare region's items into the module's process list only
// when the region holds no loop; with the loop present the always stays
// under gen_region -> begin, and read_uhdm never imported it: mem[0] had no
// driver (32 undriven bits in cv32e40p_core).
module gen_region_bare_always #(parameter N = 4) (
  input  logic clk, rst_n,
  input  logic [N-1:0] we,
  input  logic [7:0] wdata,
  input  logic [1:0] raddr,
  output logic [7:0] rdata,
  output logic       any_set
);
  logic [N-1:0][7:0] mem;
  logic [N-1:0] nz;
  genvar i;
  generate
    // R0 is nil -- a bare always_ff inside the generate region, not in a loop
    always_ff @(posedge clk or negedge rst_n) begin
      if (~rst_n) mem[0] <= 8'b0;
      else        mem[0] <= 8'b0;
    end
    // a bare continuous assign in the same region
    assign any_set = |nz;
    for (i = 1; i < N; i++) begin : gen_rf
      always_ff @(posedge clk, negedge rst_n) begin
        if (rst_n == 1'b0) mem[i] <= 8'b0;
        else if (we[i])    mem[i] <= wdata;
      end
      assign nz[i] = |mem[i];
    end
  endgenerate
  assign nz[0] = 1'b0;
  assign rdata = mem[raddr];
endmodule
