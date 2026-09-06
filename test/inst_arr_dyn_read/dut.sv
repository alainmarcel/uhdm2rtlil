// A module-level unpacked array whose elements are driven by per-index
// INSTANCE outputs, then read at a DYNAMIC index in an always_comb
// (mirrors ibex_cs_registers' mhpmcounter[mhpmcounter_idx]).  The element
// wires materialize and the instance outputs connect, but the dynamic read
// from those per-element wires collapsed — the counter FFs went dead.
module iadr_sub (
  input  logic [7:0] d_i,
  output logic [7:0] q_o
);
  assign q_o = d_i + 8'h11;
endmodule

module inst_arr_dyn_read (
  input  logic [31:0] d_i,
  input  logic [1:0]  sel_i,
  output logic [7:0]  rd_o
);
  logic [15:0] arr [4];
  for (genvar i = 0; i < 4; i++) begin : g
    iadr_sub u (.d_i(d_i[i*8 +: 8]), .q_o(arr[i][7:0]));
  end
  always_comb begin
    rd_o = arr[sel_i][7:0];
  end
endmodule
