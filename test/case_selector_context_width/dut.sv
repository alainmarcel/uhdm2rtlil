// The case EXPRESSION is evaluated at the max of its own self-size and every
// item's (LRM 12.5.1).  `case (q[0] + q[1] + ... + q[7])` with 4-bit items
// (hdmi tmds_channel's ones count) is a sum of 1-bit terms whose self-size
// is 1: read_uhdm imported it without the items' width, the sum wrapped to
// one bit, and every count above 1 fell into the default arm (10 co-sim
// divergences: the DC-balance choice went wrong).  The same sum assigned
// to a 4-bit variable (`n1d`) was already sized by its assignment.
module case_selector_context_width (
  input  logic [7:0]        q,
  output logic signed [4:0] n1,
  output logic [3:0]        n1d,
  output logic [1:0]        sel
);
  always_comb begin
    n1d = q[0] + q[1] + q[2] + q[3] + q[4] + q[5] + q[6] + q[7];
    case (q[0] + q[1] + q[2] + q[3] + q[4] + q[5] + q[6] + q[7])
      4'b0000: n1 = 5'sd0;
      4'b0001: n1 = 5'sd1;
      4'b0010: n1 = 5'sd2;
      4'b0011: n1 = 5'sd3;
      4'b0100: n1 = 5'sd4;
      4'b0101: n1 = 5'sd5;
      4'b0110: n1 = 5'sd6;
      4'b0111: n1 = 5'sd7;
      4'b1000: n1 = 5'sd8;
      default: n1 = 5'sd0;
    endcase
    // the same class inside an if arm (CaseRule-level case importer)
    sel = 2'd0;
    if (q[7]) begin
      case (q[0] + q[1] + q[2])
        2'd0: sel = 2'd0;
        2'd1: sel = 2'd1;
        2'd2: sel = 2'd2;
        2'd3: sel = 2'd3;
      endcase
    end
  end
endmodule
