module dut();
typedef struct packed {
  logic a;
  logic b;
} top_t;
parameter top_t P = 2'b10;
localparam logic f = 1'b0;
endmodule
