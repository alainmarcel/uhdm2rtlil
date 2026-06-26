// Minimal regression for generate-scope register-file memory inference.
//
// A `logic [XLEN-1:0] mem [0:2**AW-1]` array declared inside a generate block
// (here the `else` branch) used to be imported by the UHDM frontend as a single
// 1-bit wire — both the packed element width (XLEN) and the unpacked dimension
// (2**AW) were dropped — so every read returned ~0.  This reproduces the rp32
// r5p_gpr_1r1w bug in isolation: the gen-scope variable loop must create an
// RTLIL memory (like the module-level path) for an array_var that is a memory.
module gpr_genscope_repro #(
  parameter AW   = 5,
  parameter XLEN = 32,
  parameter SEL  = 0   // selects the generate branch
)(
  input  logic            clk,
  input  logic            wen,
  input  logic [AW-1:0]   a_rd,
  input  logic [AW-1:0]   a_rs,
  input  logic [XLEN-1:0] d_rd,
  output logic [XLEN-1:0] d_rs
);
generate
if (SEL == 1) begin: gen_alt
  assign d_rs = '0;
end
else begin: gen_default
  logic [XLEN-1:0] mem [0:2**AW-1];
  always_ff @(posedge clk) if (wen) mem[a_rd] <= d_rd;
  assign d_rs = mem[a_rs];
end
endgenerate
endmodule
