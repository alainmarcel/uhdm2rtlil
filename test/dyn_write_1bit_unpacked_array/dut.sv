// A dynamic write to an unpacked array of ONE-BIT elements, the shape of
// scr1_pipe_ifu's instruction queue:
//
//     logic q_err [4];
//     q_err[ADR_W'(q_wptr)] <= imem_resp_er;
//
// Such an array is an `array_var` whose Ranges() is the UNPACKED dimension,
// and import_module keeps it as one flat wire (one-bit elements are not worth
// per-element wires).  emit_dynamic_packed_select_write looked for PACKED
// ranges only, found none and declined, so the write fell through to the
// generic LHS import's READ path: the $shiftx built there became the
// process's target, `check` reported the mux and the $shiftx as two drivers
// of one wire, and `opt_muxtree` then hard-errored "Y port signal already
// driven" -- scr1_pipe_ifu's sweep row.
//
// Wider elements (q_data) always worked and are kept for contrast.  Two
// dynamic writes to the SAME array in one arm (scr1's WR_FULL case) are a
// separate defect: the second must build on the first's in-flight value.
module dut (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       wr_en,
    input  logic [2:0] wptr,
    input  logic       err_in,
    input  logic [1:0] sel,
    input  logic [15:0] data_in,
    output logic       err_out,
    output logic       err_zero_out,
    output logic [15:0] data_out
);
  localparam int unsigned ADR_W = 2;

  logic        q_err [4];     // one-bit elements: the case that declined
  logic [15:0] q_data [4];    // wider elements, for contrast

  always_ff @(posedge clk, negedge rst_n) begin
    if (~rst_n) begin
      q_err  <= '{4{1'b0}};
      q_data <= '{4{16'h0}};
    end else if (wr_en) begin
      case (sel)
        2'd1: begin
          q_err [ADR_W'(wptr)]        <= err_in;
          q_data[ADR_W'(wptr)]        <= data_in;
        end
        2'd2: begin
          q_err [ADR_W'(wptr + 1'b1)] <= ~err_in;
          q_data[ADR_W'(wptr + 1'b1)] <= ~data_in;
        end
        default: ;
      endcase
    end
  end

  assign err_out      = q_err[ADR_W'(wptr)];
  assign err_zero_out = q_err[0];
  assign data_out     = q_data[ADR_W'(wptr)];
endmodule
