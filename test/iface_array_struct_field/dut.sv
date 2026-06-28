// Smallest repro: struct field access on an interface ARRAY ELEMENT signal
// (`arr[0].req.adr`) — the first hier_path element is a bit_select.
typedef struct packed { logic wen; logic [7:0] adr; } req_t;

interface myif (input logic clk, input logic rst);
  req_t req;
  modport man (input clk, input rst, output req);
  modport sub (input clk, input rst, input  req);
endinterface

module drv (myif.man m, input logic [7:0] a);
  assign m.req = '{wen: 1'b1, adr: a};
endmodule

module dut (input logic clk, input logic rst,
            input logic [7:0] a, output logic [7:0] o);
  myif arr [2-1:0] (.clk(clk), .rst(rst));
  drv  d0 (.m(arr[0]), .a(a));
  assign o = arr[0].req.adr;     // array element + struct field
endmodule
