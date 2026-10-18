// An in-flight read of a NESTED struct field in an always_comb of a module
// imported as a CHILD: `csrNext.mstatus.MPIE = csrNext.mstatus.MIE` after
// `csrNext = csrReg` must read csrReg's MIE (the block's in-flight value),
// not the raw csrNext wire whose end-of-block value already has MIE cleared.
// The definition-view ref_obj of a child module carries no Actual_group, so
// the staged-local struct-field branch found no typespec and declined; the
// top-level import binds the ref and was always right (RSD CSR_Unit, MPIE
// never captured the old MIE on a trap).
typedef struct packed {
    logic [23:0] padding_2;
    logic MPIE;
    logic [2:0] padding_1;
    logic MIE;
    logic [2:0] padding_0;
} ms_t;
typedef struct packed {
    ms_t mstatus;
    logic [31:0] mepc;
    logic [31:0] mcycle;
} body_t;
module csr(input logic clk, rst, trig, we, input logic [31:0] wv_in, output body_t csrWholeOut);
  body_t csrReg, csrNext;
  always_ff @(posedge clk) begin
    if (rst) csrReg <= '0; else csrReg <= csrNext;
  end
  always_comb begin
    csrNext = csrReg;
    if (trig) begin
      csrNext.mstatus.MPIE = csrNext.mstatus.MIE;
      csrNext.mstatus.MIE = 0;
      csrNext.mepc = 32'h100;
    end
    else if (we) begin
      csrNext.mstatus = wv_in;
    end
  end
  assign csrWholeOut = csrReg;
endmodule
module top(input logic clk, rst, trig, we, input logic [31:0] wv_in, output logic [95:0] out);
  body_t w;
  csr dut(.clk(clk), .rst(rst), .trig(trig), .we(we), .wv_in(wv_in), .csrWholeOut(w));
  assign out = w;
endmodule
