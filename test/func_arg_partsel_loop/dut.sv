// Reproducer for CVA6 wt_dcache_wbuffer repData64 "Base signal 'data' not
// found": a function INPUT argument (`data`) is part-selected inside the
// function body (`data[offset*8+:16]`).  The base is the call argument passed
// via input_mapping, not a module wire.
module func_arg_partsel_loop (
    input  logic [63:0] d_i,
    input  logic [2:0]  off_i,
    input  logic [1:0]  size_i,
    output logic [63:0] o_o
);
  function automatic logic [63:0] rep(
      input logic [63:0] data, input logic [2:0] offset, input logic [1:0] size);
    logic [63:0] out;
    unique case (size)
      2'b00:   for (int k = 0; k < 8; k++) out[k*8+:8]   = data[offset*8+:8];
      2'b01:   for (int k = 0; k < 4; k++) out[k*16+:16] = data[offset*8+:16];
      2'b10:   for (int k = 0; k < 2; k++) out[k*32+:32] = data[offset*8+:32];
      default: out = data;
    endcase
    return out;
  endfunction
  assign o_o = rep(d_i, off_i, size_i);
endmodule
