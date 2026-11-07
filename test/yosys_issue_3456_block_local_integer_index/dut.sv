// YosysHQ/yosys#3456: latch inferred when indexing with incremented integer
// https://github.com/YosysHQ/yosys/issues/3456
// A block-local integer, incremented between two element writes, indexes an unpacked array in always_comb: both elements are written, no latch.
module dut(input logic [17:0] conf_offset, output logic [17:0] o0, o1);
  logic [17:0] next_bval [0:1];
  always_comb begin: SETNEXTBVAL
    integer qp;
    qp = 0;
    next_bval[qp] = conf_offset; qp = qp + 1;
    next_bval[qp] = ~conf_offset;
  end
  assign o0 = next_bval[0];
  assign o1 = next_bval[1];
endmodule
