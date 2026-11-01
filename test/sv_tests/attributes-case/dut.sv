// Converted from chipsalliance/sv-tests (attributes-case).
// Upstream attaches `full_case` / `parallel_case` to three case statements inside an `initial` block, where synthesis never sees them, and `a` is never driven.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
module top(input logic [1:0] a, output bit b0, output bit b1, output bit b2);
  // The three attribute spellings are kept verbatim, one per case statement, and
  // each case now drives its own output: an attribute that changed the decoding
  // (full_case/parallel_case legitimately can) would show up as a different value.
  always_comb begin
    (* full_case, parallel_case *)
    case (a)
      2'b00 :
        b0 = 0;
      2'b01, 2'b10 :
        b0 = 1;
      default :
        b0 = 0;
    endcase
    (* full_case = 1 *)
    (* parallel_case = 1 *)
    case (a)
      2'b00 :
        b1 = 0;
      2'b01, 2'b10 :
        b1 = 1;
      default :
        b1 = 0;
    endcase
    (* full_case, parallel_case = 0 *)
    case (a)
      2'b00 :
        b2 = 0;
      2'b01, 2'b10 :
        b2 = 1;
      default :
        b2 = 0;
    endcase
  end
endmodule
