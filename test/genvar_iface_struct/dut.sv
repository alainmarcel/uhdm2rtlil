// Genvar-indexed interface-ARRAY element STRUCT-FIELD assignment in a generate
// loop: `for(genvar i) assign man[i].req.field = ...` — the demux pattern from
// the degu SoC's tcb_lite_lib_demultiplexer gen_req loop.  The genvar i must
// fold (0/1 in gen_req[i]) so man[i].req.<field> resolves to \man[i].req's slice.
interface myif (input logic clk, input logic rst);
  typedef struct packed { logic lck; logic [7:0] adr; } req_t;
  logic  vld;
  req_t  req;
  modport man (input clk, input rst, output vld, output req);
  modport sub (input clk, input rst, input  vld, input  req);
endinterface

module demux #(parameter int IFN=2) (myif.sub sub, myif.man man[IFN-1:0], input logic sel);
  for (genvar i=0; i<IFN; i++) begin: gen_req
    assign man[i].vld     = (sel == i) ? sub.vld     : 1'b0;
    assign man[i].req.lck = (sel == i) ? sub.req.lck : 1'b0;
    assign man[i].req.adr = (sel == i) ? sub.req.adr : 8'h00;
  end
endmodule

module dut #(parameter int IFN=2)(input logic clk, input logic rst, input logic sel,
           input logic svld, input logic slck, input logic [7:0] sadr,
           output logic [1:0] mvld, output logic [1:0] mlck, output logic [15:0] madr);
  myif s(.clk(clk), .rst(rst));
  myif m[IFN-1:0](.clk(clk), .rst(rst));
  assign s.vld = svld;
  assign s.req.lck = slck;
  assign s.req.adr = sadr;
  demux #(2) d(.sub(s), .man(m), .sel(sel));
  assign mvld = {m[1].vld, m[0].vld};
  assign mlck = {m[1].req.lck, m[0].req.lck};
  assign madr = {m[1].req.adr, m[0].req.adr};
endmodule
