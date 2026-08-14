// Repro: a `default:` listed FIRST in a case statement must not swallow the
// later arms.  RTLIL switch cases are priority-ordered and the default rule
// has an empty compare (matches everything), so emitting arms in source order
// made every selector value take the default (CVA6 decoder's R4-type
// `unique case (opcode)` lists `default: op = FMADD` first — FNMSUB/FNMADD
// decoded as FMADD).  LRM 12.5: the default applies only when no other item
// matches, regardless of its position.
module case_default_first (
    input  logic [1:0] sel_i,
    input  logic [7:0] a_i,
    output logic [7:0] y_o,
    output logic [7:0] z_o
);
  // default first, then specific arms
  always_comb begin
    unique case (sel_i)
      default: y_o = 8'hAA;
      2'b01:   y_o = a_i;
      2'b10:   y_o = ~a_i;
    endcase
  end

  // default in the middle
  always_comb begin
    case (sel_i)
      2'b00:   z_o = a_i + 8'd1;
      default: z_o = 8'h55;
      2'b11:   z_o = a_i - 8'd1;
    endcase
  end
endmodule
