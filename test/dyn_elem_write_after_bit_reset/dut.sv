// A dynamic WHOLE-element write to an expanded unpacked array (a struct-typed
// array is expanded, never a $mem) after per-member writes to the same
// elements in the same always_ff.  RSD LRU_Counter: the reset loop clears
// `body[i].rank[j]`, the else arm writes `body[index] <= writeEntry`.
// Unpatched read_uhdm took the RAW element wire as the else-value of the
// dynamic write's hold mux and the reset writes were discarded: body never
// reset.  Elements are 2 bits (1-bit ranks hide element geometry).
module dyn_elem_write_after_bit_reset(input logic clk, input logic rst, input logic we, input logic idx, input logic [1:0] d,
                                      output logic [1:0] q0, output logic [1:0] q1);
  typedef logic [0:0] R;
  typedef struct packed { R [1:0] rank; } E;
  E body [2];
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int i = 0; i < 2; i++) for (int j = 0; j < 2; j++) body[i].rank[j] <= 0;
    end else begin
      if (we) body[idx] <= d;
    end
  end
  assign q0 = body[0]; assign q1 = body[1];
endmodule
