// Reproducer for CVA6 csr_regfile chunk-width assert: a block-local
// `automatic <struct> var` inside an always_comb whose struct has fields, with
// a member write (`v.field = ...`).  If get_width collapses the block-local
// struct_var to width 1, the member slice `\v[off+:w]` overflows.
package p;
  typedef struct packed {
    logic [3:0]  mode;
    logic [15:0] asid;
    logic [43:0] ppn;
  } satp_t;
endpackage

module blocklocal_struct_width (
    input  logic        clk_i,
    input  logic [63:0] wdata_i,
    output logic [15:0] asid_o
);
  p::satp_t satp_q;
  always_comb begin : upd
    automatic p::satp_t vsatp;
    vsatp = satp_q;
    vsatp.asid = vsatp.asid & 16'hFF00;
    asid_o = vsatp.asid;
  end
  always_ff @(posedge clk_i) satp_q <= p::satp_t'(wdata_i);
endmodule
