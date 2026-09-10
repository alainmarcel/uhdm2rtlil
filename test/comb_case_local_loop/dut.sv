// unified_mul's exact shape, isolated: a temp assigned then read via a
// part-select inside an unrolled for-loop, all within one case arm.  Packed
// output (no unpacked-array write) to isolate the temp-read-in-loop from array
// handling.  No latch expected; must be equivalent to slang.
module comb_case_local_loop (
  input  logic [1:0]  mode,
  input  logic [63:0] a,
  output logic [63:0] o
);
  logic [63:0] t;
  always_comb begin
    o = '0;
    unique case (mode)
      2'd0: for (int i = 0; i < 4; i++) o[16*i +: 16] = a[16*i +: 16];
      2'd2: begin
        t = {a[31:0], a[63:32]};
        for (int i = 0; i < 4; i++) o[16*i +: 16] = t[16*i +: 16];
      end
      default: ;
    endcase
  end
endmodule
