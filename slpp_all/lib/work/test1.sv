module dut();
typedef struct packed {
  logic a;
  logic b;
} sub_t;

typedef struct packed {
  sub_t c;
  sub_t d;
} top_t;

parameter top_t P = 4'b1100;

always_comb begin
  assert(P == 4'b1100);
end
endmodule
