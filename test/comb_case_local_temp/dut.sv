// Repro of unified_mul A32/B32: a temp written AND read only inside a single
// case arm.  always_comb must NOT infer a latch (slang SSAs it: X elsewhere,
// and the held value is never observed).  read_uhdm currently infers a latch.
module comb_case_local_temp (
  input  logic [1:0]  mode,
  input  logic [31:0] a,
  output logic [15:0] y
);
  logic [31:0] t;                 // written+read only in mode==2
  always_comb begin
    unique case (mode)
      2'd0:    y = a[15:0];
      2'd1:    y = a[31:16];
      2'd2: begin
        t = {a[15:0], a[31:16]};
        y = t[15:0] ^ t[31:16];
      end
      default: y = '0;
    endcase
  end
endmodule
