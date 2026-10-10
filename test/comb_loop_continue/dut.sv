// `continue` inside an unrolled always_comb for loop (RSD LoadQueue's violation
// scan: `if (!port.executeLoad[li]) continue; if (addr != ...) continue;
// ... violation[si] = TRUE;`).  Unpatched read_uhdm imported `continue` as a
// NO-OP, so the statements after it still ran for that iteration and every
// lane flagged a conflict (153 co-sim divergences, read_slang clean).  The
// fix guards the rest of the iteration like a `break` site does, without
// suppressing the later iterations.
module comb_loop_continue(input logic [3:0] en, input logic [1:0] a0, input logic [1:0] a1, input logic [1:0] a2, input logic [1:0] a3, input logic [1:0] b, input logic [3:0] age, input logic [1:0] sage, output logic viol, output logic [7:0] pc);
  logic [1:0] a [4];
  always_comb begin
    a[0] = a0; a[1] = a1; a[2] = a2; a[3] = a3;
    viol = 1'b0; pc = '0;
    for (int li = 0; li < 4; li++) begin
      if (!en[li]) begin
        continue;
      end
      if (a[li] != b) begin
        continue;
      end
      if (age[li] >= sage) begin
        viol = 1'b1;
        pc = a[li] + li;
      end
    end
  end
endmodule
