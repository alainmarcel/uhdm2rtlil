// In the memory-write for-loop fallback (always_ff whose loop body writes a
// memory), PACKED-VECTOR bit-select writes coexisting with a WHOLE-vector
// write lost every flop: the sync rule got `update \v_reg [0]`,
// `update \v_reg [1]` AND `update \v_reg`, and `proc` resolves overlapping
// updates by dropping the register.
//
// Two defects behind it.  `pending_sync_assignments` is a std::map keyed by
// SigSpec, so per-bit and whole-wire writes were separate keys with no
// source order; and the conditional-write else-value was an EXACT key lookup,
// so `v_reg <= 0` under reset took the raw wire as its else and erased the
// per-bit pipeline shifts before it.  Fixed by stamping each write with its
// order and resolving every bit to the LATEST covering write
// (pending_inflight), then emitting ONE update per base wire.
//
// This is verilog-axis axis_fifo's `m_axis_tvalid_pipe_reg`; with it the
// module's flop count finally matches read_slang (5/5).
`default_nettype none
module forloop_bitsel_wholewrite_sync #(parameter PIPE = 1, parameter W = 8, parameter AW = 3)
(
    input  wire         clk,
    input  wire         rst,
    input  wire         rdy,
    input  wire         push,
    input  wire [AW-1:0] raddr,
    output wire [W-1:0] dout,
    output wire         vout
);
reg [W-1:0] mem[2**AW-1:0];
reg [W-1:0] p_reg[PIPE+1-1:0];
reg [PIPE+1-1:0] v_reg = 0;
integer j;
always @(posedge clk) begin
    if (rdy) begin
        v_reg[PIPE+1-1] <= 1'b0;
    end
    // descending loop mixing a MEMORY-ish array shift with PACKED-VECTOR
    // bit-select writes in the same body
    for (j = PIPE+1-1; j > 0; j = j - 1) begin
        if (rdy || ((~v_reg) >> j)) begin
            v_reg[j]   <= v_reg[j-1];
            p_reg[j]   <= p_reg[j-1];
            v_reg[j-1] <= 1'b0;
        end
    end
    if (rdy || ~v_reg) begin
        v_reg[0] <= 1'b0;
        p_reg[0] <= mem[raddr];
        if (push) begin
            v_reg[0] <= 1'b1;
        end
    end
    if (rst) begin
        v_reg <= 0;
    end
end
assign dout = p_reg[PIPE+1-1];
assign vout = v_reg[PIPE+1-1];
endmodule
