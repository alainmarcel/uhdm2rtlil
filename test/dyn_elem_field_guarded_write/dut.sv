// Writing a struct field of a DYNAMICALLY-INDEXED packed-array element, where
// the write is guarded by a comparison that READS another field of the same
// dynamic element:
//     if (mem_n[idx].sbe.fu == CVXIF) mem_n[idx].sbe.rd = rd_i;
// CVA6 scoreboard.sv:214-216.  The unguarded write on the line above it
// (`mem_n[idx].sbe.result = ...`) already worked, so the guard's dynamic field
// READ is the part under test.
module dut (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [2:0] idx,
    input  logic       we,
    input  logic [4:0] rd_i,
    input  logic [7:0] wb_i,
    input  logic [2:0] outsel,

    output logic [24:0] out_o
);
  typedef struct packed {
    logic [7:0] pc;
    logic [3:0] fu;
    logic [4:0] rd;
    logic [7:0] result;
  } sbe_t;

  typedef struct packed {
    logic issued;
    sbe_t sbe;
  } mem_t;

  mem_t [7:0] mem_q, mem_n;

  always_comb begin
    mem_n = mem_q;
    //  Unguarded dynamic element field write (known good).
    mem_n[idx].sbe.result = wb_i;
    //  Guarded by a dynamic element field READ.
    if (mem_n[idx].sbe.fu == 4'd9) begin
      if (we) mem_n[idx].sbe.rd = rd_i;
      else mem_n[idx].sbe.rd = 5'd0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) mem_q <= '0;
    else mem_q <= mem_n;
  end

  assign out_o = mem_q[outsel].sbe;
endmodule
