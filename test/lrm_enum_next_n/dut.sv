// IEEE 1800-2023 6.19.5.3/4: enum .next(N) and .prev(N) step N members along
// the declaration order (wrapping), not N in value.
module dut(input logic [1:0] i, output logic [3:0] n2, p3, n0);
  typedef enum logic [3:0] { A = 4'd1, B = 4'd4, C = 4'd6, D = 4'd9 } e_t;
  e_t e;
  always_comb begin
    case (i)
      2'd0: e = A;
      2'd1: e = B;
      2'd2: e = C;
      default: e = D;
    endcase
    n2 = e.next(2);
    p3 = e.prev(3);
    n0 = e.next(0);
  end
endmodule
