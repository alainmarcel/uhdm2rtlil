// Smallest struct-bus interface-array repro (mirrors rp32 tcb_lite_if's
// req/rsp packed-struct signals on an array of interface ports).
typedef struct packed { logic wen; logic [7:0] adr; } req_t;
typedef struct packed { logic [7:0] rdt;            } rsp_t;

interface myif (input logic clk, input logic rst);
  req_t req;
  rsp_t rsp;
  modport man (input clk, input rst, output req, input  rsp);
  modport sub (input clk, input rst, input  req, output rsp);
endinterface

// array of interface ports: drive req per element, read rsp back
module drv (myif.man m [2-1:0]);
  assign m[0].req = '{wen: 1'b1, adr: 8'd10};
  assign m[1].req = '{wen: 1'b0, adr: 8'd20};
endmodule

// subordinate: echoes req.adr onto rsp.rdt
module sub (myif.sub s);
  assign s.rsp = '{rdt: s.req.adr};
endmodule

module dut (input logic clk, input logic rst,
            output logic [7:0] o0, output logic [7:0] o1);
  myif arr [2-1:0] (.clk(clk), .rst(rst));
  drv  d  (.m(arr));
  sub  s0 (.s(arr[0]));
  sub  s1 (.s(arr[1]));
  assign o0 = arr[0].rsp.rdt;   // = 10
  assign o1 = arr[1].rsp.rdt;   // = 20
endmodule
