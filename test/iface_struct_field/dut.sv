// Smallest repro: struct FIELD access on a SINGLE interface port signal.
// reader reads s.req.adr (a field of a packed-struct interface signal).
typedef struct packed { logic wen; logic [7:0] adr; } req_t;

interface myif (input logic clk, input logic rst);
  req_t req;
  modport man (input clk, input rst, output req);
  modport sub (input clk, input rst, input  req);
endinterface

module reader (myif.sub s, output logic [7:0] o);
  assign o = s.req.adr;          // <-- struct field access (returns X today)
endmodule

module dut (input logic clk, input logic rst,
            input  logic [7:0] a, output logic [7:0] o);
  myif inst (.clk(clk), .rst(rst));
  assign inst.req = '{wen: 1'b1, adr: a};
  reader r (.s(inst), .o(o));
endmodule
