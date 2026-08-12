// Repro of CVA6 cva6_fifo_v3.sv:75 / lsu_bypass.sv:67 / load_unit.sv:155
// spurious latches on importer-generated $auto$...import_bit_select wires: a
// DYNAMIC-index element (or element-field) write into a small unpacked array
// (`mem_n[write_pointer_q] = data_i;`,
// `mem_n[read_pointer_q].valid = 1'b0;`) inside an always_comb with a
// whole-array default.  The dynamic LHS must go through the masked-write
// path, not the READ path — a $shiftx read-output wire that ends up as a
// process update target self-holds and latches (slang: 0 latches).
module latch_fifo_dynfield #(
    parameter int unsigned N = 4,
    parameter int unsigned W = 8
) (
    input  logic [W-1:0]         data_i,
    input  logic [1:0]           wptr_i,
    input  logic [1:0]           rptr_i,
    input  logic                 push_i,
    input  logic                 pop_i,
    output logic [N-1:0][W-1:0]  mem_o,
    output logic [N-1:0]         valid_o
);
  typedef struct packed {
    logic [W-1:0] data;
    logic         valid;
  } entry_t;

  entry_t mem_q[N];
  entry_t mem_n[N];

  // feedback-free "registers" for a purely combinational miter
  always_comb begin
    for (int unsigned k = 0; k < N; k++) begin
      mem_q[k].data  = data_i ^ W'(k);
      mem_q[k].valid = pop_i;
    end
  end

  always_comb begin : read_write_comb
    mem_n = mem_q;
    if (push_i) begin
      mem_n[wptr_i].data  = data_i;
      mem_n[wptr_i].valid = 1'b1;
    end
    if (pop_i) begin
      mem_n[rptr_i].valid = 1'b0;
    end
  end

  always_comb begin
    for (int unsigned k = 0; k < N; k++) begin
      mem_o[k]   = mem_n[k].data;
      valid_o[k] = mem_n[k].valid;
    end
  end
endmodule
