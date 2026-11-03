// A net declared as a packed array of a typedef'd STRUCT
// (`idma_pkg::idma_busy_t [NumBEs-1:0] backend_busy_d`, iDMA's mp dist
// midend) is a packed_array_net in the definition view and a logic_net with
// a packed_array_typespec once elaborated; neither shape got element
// geometry stamped, so `backend_busy_d[i] = idma_busy_i[i]` in the comb loop
// wrote ONE BIT per element (bit i from bit 8*i of the port), `&backend_busy_q`
// stuck at 0 and cheshire's idma_mp_midend_synth row was `differs` /
// 2 diverging cycles.  read_verilog cannot parse the package struct array
// port, so the gates are the read_slang miter and a `sat -prove` of the
// element-wise copy.
package p;
  typedef struct packed {
    logic buffer_busy;
    logic r_dp_busy;
    logic w_dp_busy;
    logic r_leg_busy;
    logic w_leg_busy;
    logic eh_fsm_busy;
    logic eh_cnt_busy;
    logic raw_coupler_busy;
  } busy_t;
endpackage
module dut #(parameter int unsigned NumBEs = 5) (
  input  logic clk_i, rst_ni,
  input  p::busy_t [NumBEs-1:0] idma_busy_i,
  output p::busy_t [NumBEs-1:0] d_o,
  output logic all_busy_o
);
  p::busy_t [NumBEs-1:0] backend_busy_d, backend_busy_q;
  always_comb begin
    backend_busy_d = backend_busy_q;
    for (int unsigned i = 0; i < NumBEs; i++) begin
      backend_busy_d[i] = idma_busy_i[i];
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) backend_busy_q <= ('1);
    else backend_busy_q <= (backend_busy_d);
  end
  assign all_busy_o = &backend_busy_q;
  assign d_o = backend_busy_d;
endmodule
