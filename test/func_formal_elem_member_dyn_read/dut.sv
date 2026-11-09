// A member of an element of an UNPACKED array-of-struct function formal,
// read through a RUNTIME index: `a[sel.lane].value`.  RSD BypassNetwork's
// SelectData returns `intEX[sel.lane.intLane].value` this way; the read fell
// through to "Could not resolve struct member access" and a constant X, so
// SelectData returned 0 on every bypass path (all operand outputs stuck at 0,
// 120 diverging co-simulated cycles).  The constant-index form (`b[0].value`)
// was already handled.  The array is sized to the full 2-bit lane range so no
// index is out of bounds (that read is X, LRM 7.4.6, and the co-sim would
// legitimately disagree).
typedef struct packed { logic valid; logic [7:0] data; } val_t;
typedef struct packed { logic [3:0] tag; val_t value; } op_t;
typedef struct packed { logic [1:0] stg; logic [1:0] lane; } sel_t;

module dut (
    input  sel_t s,
    input  val_t d0,
    input  val_t d1,
    input  val_t d2,
    input  val_t d3,
    input  val_t m0,
    output val_t y
);
  function automatic val_t pick(input sel_t sel, input op_t a [4], input op_t b [1]);
    if (sel.stg == 2'd0) return a[sel.lane].value;
    else if (sel.stg == 2'd1) return b[0].value;
    else return '0;
  endfunction

  op_t A [4];
  op_t B [1];
  always_comb begin
    A[0].tag = 4'h1; A[0].value = d0;
    A[1].tag = 4'h2; A[1].value = d1;
    A[2].tag = 4'h3; A[2].value = d2;
    A[3].tag = 4'h5; A[3].value = d3;
    B[0].tag = 4'h4; B[0].value = m0;
    y = pick(s, A, B);
  end
endmodule
