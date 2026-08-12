// Repro of CVA6 perf_counters.sv:141 `generic_counter` spurious per-element
// latches: an unpacked array with a WHOLE-ARRAY default at the top of the
// always_comb (`generic_counter_d = generic_counter_q;`) followed by
// per-element writes from an unrolled for loop under runtime guards, plus a
// dynamic-index read.  The whole-array default must reach every per-element
// `$0\arr[k]` temp unconditionally — otherwise proc_dlatch infers a latch per
// element (slang: 0 latches; CVA6 shows generic_counter_d[0..5] and
// mhpmevent_d[0..5]).  Also models store_buffer.sv:161 commit_queue_n[0..3].
module latch_perf_counters #(
    parameter int unsigned N = 4
) (
    input  logic [63:0]      inc_i,
    input  logic [N-1:0]     ev_i,
    input  logic             we_i,
    input  logic [2:0]       addr_i,
    input  logic [63:0]      wdata_i,
    output logic [63:0]      data_o,
    output logic [63:0]      cnt_o
);
  logic [63:0] counter_d[N:1], counter_q[N:1];
  logic clk_i = 1'b0;  // keep the test purely combinational via feedback regs

  // simple registers so counter_q has drivers (comb-only miter still works)
  always_comb begin
    for (int unsigned k = 1; k <= N; k++) counter_q[k] = {16'h0, inc_i[47:0]} + 64'(k);
  end

  always_comb begin : generic_counter
    counter_d = counter_q;
    data_o    = 'b0;

    for (int unsigned i = 1; i <= N; i++) begin
      if (!we_i) begin
        if (ev_i[i-1]) begin
          counter_d[i] = counter_q[i] + 1'b1;
        end
      end
    end

    if (addr_i >= 3'd1 && addr_i <= 3'(N)) begin
      data_o = counter_q[addr_i];
    end

    if (we_i && addr_i >= 3'd1 && addr_i <= 3'(N)) begin
      counter_d[addr_i] = wdata_i;
    end
  end

  assign cnt_o = counter_d[1] ^ counter_d[2] ^ counter_d[3] ^ counter_d[4];
endmodule
