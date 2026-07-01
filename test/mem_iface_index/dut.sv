// Memory indexed by an interface struct field: `mem[s.req.adr]`.  Earlier this
// collapsed `mem` to a bare 32-bit wire (memory not detected) — the interface
// binding fix (gap 2) may or may not have resolved the detection too.
interface tcb_if;
  typedef struct packed {
    logic [7:0]  adr;
    logic [31:0] wdt;
    logic        wen;
  } req_t;
  req_t        req;
  logic [31:0] rdt;
  modport sub (input req, output rdt);
endinterface

module mem_core (input logic clk, tcb_if.sub s);
  logic [31:0] mem [0:255];
  always_ff @(posedge clk) begin
    if (s.req.wen) mem[s.req.adr] <= s.req.wdt;
    s.rdt <= mem[s.req.adr];
  end
endmodule

module mem_iface_index (
  input  logic        clk,
  input  logic [7:0]  adr,
  input  logic [31:0] wdt,
  input  logic        wen,
  output logic [31:0] rdt
);
  tcb_if s();
  assign s.req.adr = adr;
  assign s.req.wdt = wdt;
  assign s.req.wen = wen;
  assign rdt       = s.rdt;
  mem_core u_core (.clk(clk), .s(s.sub));
endmodule
