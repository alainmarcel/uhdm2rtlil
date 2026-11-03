// A NESTED for-loop whose start names the ENCLOSING loop's variable, inside
// a function the importer inlines: aib-protocols' asyncfifo f_gray2binary
//   for (index_i = 0; ...) for (index_j = index_i + 1; ...)
//     binary[index_i] = ^{binary[index_i], gray[index_j]};
// The inner loop's start `index_i + 1` was folded by UHDM's reducer, which
// knows nothing of the inlined iteration, to 0 -- every inner loop ran from
// 0, and the gray-to-binary XOR chain was wrong on every bit but the top
// one (rd_numfilled 276 diverging co-simulated cycles, read_slang clean).
// read_verilog cannot miter this (the function uses `reg` loop variables it
// lowers differently), so the gates are the read_slang miter and a
// `sat -prove` of the known gray-to-binary values.
module dut #(parameter FIFO_ADDR_WID = 3) (
  input  [FIFO_ADDR_WID-1:0] gray_i,
  output [FIFO_ADDR_WID-1:0] bin_o
);
function automatic [FIFO_ADDR_WID-1:0] f_gray2binary;
input [FIFO_ADDR_WID-1:0] gray;
reg  [FIFO_ADDR_WID-1:0]      binary;
reg  [FIFO_ADDR_WID-1:0]      index_i;
reg  [FIFO_ADDR_WID-1:0]      index_j;
begin
  binary = gray;
  for(index_i=0; index_i<FIFO_ADDR_WID; index_i=index_i+1)
    for(index_j=index_i+1; index_j<FIFO_ADDR_WID; index_j=index_j+1)
      binary[index_i] = ^{binary[index_i], gray[index_j]};
  f_gray2binary = binary;
end
endfunction
assign bin_o = f_gray2binary(gray_i);
endmodule
