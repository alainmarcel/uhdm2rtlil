// TWO dynamic writes to the same vector in ONE always_ff arm -- the shape of
// scr1_pipe_ifu's full-word queue write:
//
//     q_data[ADR_W'(q_wptr)]        <= imem_rdata_lo;
//     q_data[ADR_W'(q_wptr + 1'b1)] <= imem_rdata_hi;
//
// Both elements belong in the next state.  current_comb_values is suppressed
// inside an always_ff body to keep non-blocking semantics, so the masked
// read-modify-write of the second store started from the REGISTERED value,
// and because the handler first removes any earlier action for the same
// target, only the LAST write survived: the other element kept its old value.
module dut (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       wr_en,
    input  logic [2:0] p,
    input  logic       a,
    input  logic       b,
    input  logic [1:0] sel,
    input  logic [15:0] d,
    output logic [7:0] v_out,
    output logic [7:0] w_out,
    output logic [15:0] m_out,
    output logic [15:0] m_out2
);
  logic [7:0] v;
  logic [7:0] w;
  // Wider elements take the OTHER handler (per-element wires), which had the
  // same defect: a dynamic index touches every element, so both writes
  // target the same per-element temps and the second dropped the first.
  logic [15:0] m [4];

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      v <= '0;
      w <= '0;
      m <= '{4{16'h0}};
    end else if (wr_en) begin
      case (sel)
        2'd1: begin
          v[p]        <= a;        // two writes, same vector, one arm
          v[p + 3'd1] <= b;
          m[p[1:0]]             <= d;        // the same shape, wider elements
          m[p[1:0] + 2'd1]      <= ~d;
        end
        2'd2: begin
          v[p]        <= a;        // three, with the last overlapping the first
          v[p + 3'd1] <= b;
          v[p]        <= b;
        end
        default: begin
          w[p]        <= a;        // a different vector in the same block
          v[p + 3'd2] <= b;
        end
      endcase
    end
  end

  assign v_out  = v;
  assign w_out  = w;
  assign m_out  = m[p[1:0]];
  assign m_out2 = m[p[1:0] + 2'd1];
endmodule
