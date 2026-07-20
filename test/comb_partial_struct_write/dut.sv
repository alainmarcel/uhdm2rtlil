// An always_comb that assigns only SOME fields of a wide interface/struct signal
// (rp32 r5p_lsu drives only tcb.req.wen/.ren), while the other fields are driven
// by continuous assigns (tcb.req.lck/.adr).  The comb process must update ONLY
// the bits it writes; a full-width update collides with the continuous drivers
// ("Drivers conflicting with a constant 1'0 driver").
interface bus_if;
  typedef struct packed { logic wen; logic ren; logic lck; logic [7:0] adr; } req_t;
  req_t req;
  modport man (output req);
endinterface

module drv (bus_if.man tcb, input logic sel, input logic [7:0] a);
  always_comb begin
    if (sel) begin tcb.req.wen = 1'b1; tcb.req.ren = 1'b0; end
    else     begin tcb.req.wen = 1'b0; tcb.req.ren = 1'b1; end
  end
  assign tcb.req.lck = 1'b0;
  assign tcb.req.adr = a;
endmodule

module comb_partial_struct_write (
  input  logic       sel,
  input  logic [7:0] a,
  output logic       o_wen,   // sel ? 1 : 0
  output logic       o_ren,   // sel ? 0 : 1
  output logic       o_lck,   // 0
  output logic [7:0] o_adr    // a
);
  bus_if tb ();
  drv u (.tcb(tb), .sel(sel), .a(a));
  assign o_wen = tb.req.wen;
  assign o_ren = tb.req.ren;
  assign o_lck = tb.req.lck;
  assign o_adr = tb.req.adr;
endmodule
