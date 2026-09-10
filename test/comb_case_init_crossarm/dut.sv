// Guard: a '0-initialized signal read AFTER the case.  In the default arm c
// keeps its init '0 — a DEFINED value the fix must preserve (never X).  Mirrors
// the CVA6 decoder interrupt_cause caution.
module comb_case_init_crossarm (
  input  logic [1:0]  mode,
  input  logic [31:0] a,
  output logic [31:0] y
);
  logic [31:0] c;
  always_comb begin
    c = '0;                        // init
    unique case (mode)
      2'd0: c = a;
      2'd1: c = a + 32'd1;
      default: ;                   // c holds init '0 here
    endcase
    y = c;                         // read in ALL modes (cross-arm observation)
  end
endmodule
