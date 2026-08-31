// Dynamic struct-field writes into a PER-ELEMENT-only unpacked array (the
// async-reset clear loop demotes `arr` to per-element registers, so no flat
// \arr wire exists).  Both the plain `arr[wi].valid` and the
// trailing-indexed `arr[wi].sat[wk]` writes were dropped ("Could not resolve
// struct member access") — the elements never left their reset value.
// Distilled from CVA6-style saturation-counter tables.
module perelem_struct_field_write (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [1:0]  wi,
    input  logic [2:0]  wk,
    input  logic [1:0]  val,
    input  logic [1:0]  ri,
    output logic [19:0] out
);
  typedef struct packed {
    logic            valid;
    logic [2:0]      h;
    logic [7:0][1:0] sat;
  } e_t;

  e_t arr[3:0];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 4; i++) arr[i] <= '0;
    end else begin
      arr[wi].sat[wk] <= val;   // dynamic element + dynamic trailing field index
      arr[wi].h       <= 3'h5;  // dynamic element, plain field
      arr[0].valid    <= 1'b1;  // constant element, plain field
    end
  end

  assign out = arr[ri];
endmodule
