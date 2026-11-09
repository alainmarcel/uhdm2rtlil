// A task OUTPUT argument that is a MEMBER of an unpacked-array element (OpenTitan
// i3c_target_fsm: `fmt_data_out(txd_data_o[t].rdata_nq, txd_data_o[t].rdata_pq, ...)`).
// Unpatched read_uhdm resolved only a bare `arr[k]` actual to its element wire: the
// member actual was imported as the element's in-flight VALUE (after `x[0] = '0`, a
// constant), the write-back had no target, and every field stayed 0.
typedef struct packed { logic [8:0] rdata_nq; logic [8:0] rdata_pq; logic [1:0] rlast; } txd_t;
module dut (input logic [15:0] ud0, input logic first, input logic [1:0] ur, output logic [19:0] flat);
  task automatic fmt(output logic [8:0] nq, output logic [8:0] pq, output logic [1:0] rl,
                     input logic [15:0] d, input logic f, input logic [1:0] u);
    nq = d[8:0]; pq[8] = !f; pq[7:0] = d[15:8]; rl = u;
  endtask
  txd_t x [1]; always_comb begin x[0] = '0; fmt(x[0].rdata_nq, x[0].rdata_pq, x[0].rlast, ud0, first, ur); end assign flat = x[0];
endmodule
