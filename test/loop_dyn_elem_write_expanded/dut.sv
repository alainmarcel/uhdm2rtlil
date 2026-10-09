// RSD LRU_Counter's write port: a dynamic WHOLE-element write to an expanded
// unpacked array (struct-typed arrays are expanded, never a $mem) INSIDE an
// unrolled for loop of an always_ff, after per-member reset writes to the same
// elements.  Unpatched read_uhdm imported the loop-path LHS `body[idx[i]]`
// through import_expression, which returns the element READ mux, and the
// write landed on that dead temp: body was only ever reset.
// (test/dyn_elem_write_after_bit_reset is the same write WITHOUT the loop.)
module loop_dyn_elem_write_expanded(input logic clk, input logic rst, input logic we, input logic idx, input logic [1:0] d,
                                    output logic [1:0] q0, output logic [1:0] q1);
  typedef logic [0:0] R;
  typedef struct packed { R [1:0] rank; } E;
  E body [2];
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 2; i++) for (int j = 0; j < 2; j++) body[i].rank[j] <= 0;
    end else begin
      for (int i = 0; i < 1; i++) if (we) body[idx] <= d;
    end
  end
  assign q0 = body[0]; assign q1 = body[1];
endmodule
