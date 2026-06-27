// Struct-bus interface array WITHOUT struct field access — verifies struct
// signal WIDTH + whole-struct connection through array interface ports.
typedef struct packed { logic wen; logic [7:0] adr; } req_t;
interface myif (input logic clk, input logic rst);
  req_t req;
  modport man (input clk, input rst, output req);
  modport sub (input clk, input rst, input  req);
endinterface
module drv (myif.man m [2-1:0]);
  assign m[0].req = '{wen: 1'b1, adr: 8'd10};
  assign m[1].req = '{wen: 1'b0, adr: 8'd20};
endmodule
module dut (input logic clk, input logic rst,
            output logic [8:0] o0, output logic [8:0] o1);
  myif arr [2-1:0] (.clk(clk), .rst(rst));
  drv  d (.m(arr));
  assign o0 = arr[0].req;   // 9'b1_00001010 = 266
  assign o1 = arr[1].req;   // 9'b0_00010100 = 20
endmodule
