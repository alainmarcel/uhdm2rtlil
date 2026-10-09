// A `function automatic void` with an UNPACKED-ARRAY output formal bound to a
// module unpacked array at the call (`DecideCommit(.commit(commit), ...)` on
// `logic commit[COMMIT_WIDTH]`, RSD CommitStage).  The actual imports as the
// concat of the array's element wires, and unpatched read_uhdm's write-back
// handled a single wire only: the array was never written (2-bit elements so
// an element/bit confusion would show as well).
module void_func_array_output_arg(input logic [7:0] x, input logic k, output logic [1:0] y0, output logic [1:0] y1, output logic [1:0] y2, output logic [1:0] y3, output logic any_o);
  function automatic void Copy(output logic [1:0] o[4], output logic any_o_, input logic [1:0] x_i[4], input logic k_i);
    o = x_i;
    any_o_ = k_i;
  endfunction
  logic [1:0] xa[4];
  logic [1:0] r[4];
  always_comb begin
    xa[0] = x[1:0]; xa[1] = x[3:2]; xa[2] = x[5:4]; xa[3] = x[7:6];
    Copy(.o(r), .any_o_(any_o), .x_i(xa), .k_i(k));
    y0 = r[0]; y1 = r[1]; y2 = r[2]; y3 = r[3];
  end
endmodule
