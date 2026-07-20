// A memory-write always_ff that also registers ONE field of a wide interface
// signal (`sub.rsp.rdt <= mem[adr]`), while sibling fields are continuous
// (`sub.rsp.sts='0`, `sub.rsp.err=1'b0`).  The clocked update must drive only
// the written bits (rdt); a full-width `\sub.rsp <= $0\sub.rsp` collides with the
// constant sts/err drivers (rp32 r5p_soc_memory / degu_soc, "Drivers
// conflicting with a constant 1'0 driver").
interface bus_if;
  typedef struct packed { logic [31:0] rdt; logic sts; logic err; } rsp_t;
  logic clk, trn, ren, wen;
  logic [3:0]  byt;
  logic [31:0] wdt;
  logic [3:0]  adr;
  rsp_t rsp;
  modport sub (input clk, input trn, input ren, input wen, input byt,
               input wdt, input adr, output rsp);
endinterface

module mem (bus_if.sub sub);
  logic [31:0] m [0:15];
  always @(posedge sub.clk)
  if (sub.trn) begin
    if (sub.ren) sub.rsp.rdt <= m[sub.adr];
    if (sub.wen) begin
      if (sub.byt[0]) m[sub.adr][ 7: 0] <= sub.wdt[ 7: 0];
      if (sub.byt[1]) m[sub.adr][15: 8] <= sub.wdt[15: 8];
      if (sub.byt[2]) m[sub.adr][23:16] <= sub.wdt[23:16];
      if (sub.byt[3]) m[sub.adr][31:24] <= sub.wdt[31:24];
    end
  end
  assign sub.rsp.sts = '0;
  assign sub.rsp.err = 1'b0;
endmodule

module mem_ff_partial_rsp (
  input  logic        clk, trn, ren, wen,
  input  logic [3:0]  byt, adr,
  input  logic [31:0] wdt,
  output logic [31:0] o_rdt,   // registered read data
  output logic        o_sts,   // 0
  output logic        o_err    // 0
);
  bus_if b ();
  assign b.clk=clk; assign b.trn=trn; assign b.ren=ren; assign b.wen=wen;
  assign b.byt=byt; assign b.adr=adr; assign b.wdt=wdt;
  mem u (.sub(b));
  assign o_rdt = b.rsp.rdt;
  assign o_sts = b.rsp.sts;
  assign o_err = b.rsp.err;
endmodule
