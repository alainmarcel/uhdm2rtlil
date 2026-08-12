// Repro of CVA6 alu.sv:199 spurious latch on a block-local comb variable that
// IS unconditionally initialized: `logic sgn; sgn = 1'b0; if (…) sgn = 1'b1;`
// inside always_comb.  read_verilog/slang infer no latch (the init covers all
// paths); the UHDM import promoted `sgn` to a module wire with a self-hold
// default that survives, so proc_dlatch created a latch.
module comb_local_init_latch (
    input  logic [3:0] op,
    input  logic [7:0] a,
    input  logic [7:0] b,
    output logic       less
);
  always_comb begin
    logic sgn;
    sgn = 1'b0;
    if (op == 4'd3 || op == 4'd5) sgn = 1'b1;
    less = ($signed({sgn & a[7], a}) < $signed({sgn & b[7], b}));
  end
endmodule
