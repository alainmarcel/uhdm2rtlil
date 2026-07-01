// Interface modport port connection: a submodule instantiated with an
// interface modport port passed as `.s(s.sub)`.  Surelog represents the
// actual as a UHDM hier_path <iface>.<modport>; the child carries the
// interface as flattened `<port>.<field>` ports.  The counter is driven
// INSIDE the child (through the modport output) and read by the top, so
// this isolates the modport port-connection path.
interface tcb_if;
  logic [31:0] cnt;
  logic        act;
  modport sub (output cnt, output act);
endinterface

module dev (input logic clk, input logic rst, tcb_if.sub s);
  always_ff @(posedge clk)
    if (rst) begin s.cnt <= 32'd0; s.act <= 1'b0; end
    else     begin s.cnt <= s.cnt + 32'd1; s.act <= 1'b1; end
endmodule

module iface_modport_conn (
  input  logic        clk,
  input  logic        rst,
  output logic [31:0] cnt,
  output logic        act
);
  tcb_if s();
  dev u_dev (.clk(clk), .rst(rst), .s(s.sub));
  assign cnt = s.cnt;
  assign act = s.act;
endmodule
