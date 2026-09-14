// Unpacked array declared in a GENERATE block and written only through an
// instance output CONCAT actual (OpenTitan aes_core gen_state_out_masked:
// `prim_buf … .out_o({state_done_buf[1], state_done_buf[0]})`, the masked
// state shares).  The instance-written-array scans only recognised a bare
// `a[i]` actual, so the array became a writer-less $memory whose $memrd data
// wires the instance output was wired onto: both shares read 0 and the
// ciphertext XORed to 0 (aes_wrap co-sim, cycle 139).
module buf2 #(parameter int Width = 16) (input logic [Width-1:0] in_i, output logic [Width-1:0] out_o);
  assign out_o = in_i;
endmodule
module genscope_array_inst_concat_write #(parameter bit Masked = 1) (input logic [3:0][3:0][7:0] a0, input logic [3:0][3:0][7:0] a1, input logic sel,
                     output logic [3:0][3:0][7:0] x_o);
  if (!Masked) begin : gen_plain
    assign x_o = a0;
  end else begin : gen_masked
    logic [3:0][3:0][7:0] m [2];
    for (genvar s = 0; s < 2; s++) begin : g
      assign m[s] = sel ? (s == 0 ? a0 : a1) : 128'h11;
    end
    logic [3:0][3:0][7:0] b [2];
    buf2 #(.Width(2*128)) u (.in_i({m[1], m[0]}), .out_o({b[1], b[0]}));
    assign x_o = b[0] ^ b[1];
  end
endmodule
