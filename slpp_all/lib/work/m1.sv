module dut();
typedef struct packed { logic a; } top_t;
parameter top_t P = 1'b1;
localparam logic f = P.a;
endmodule
