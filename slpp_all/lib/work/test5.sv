module dut();
typedef struct packed {
  logic a;
  logic b;
} top_t;

top_t s;
localparam logic f = s.a;
endmodule
