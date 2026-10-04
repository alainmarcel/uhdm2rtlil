// verilog-pcie pcie_tlp_fifo_mux: a combinational unpacked array is filled
// by an unrolled for loop, then read and WRITTEN at a runtime index in the
// same always @* block.  The pre-scan scored the loop-variable index as
// dynamic and skipped it, so no element had a `$0\` temp: the unrolled
// writes landed untracked, the dynamic write then took the elements' OUTPUT
// wires as their current value and drove them from that -- a combinational
// loop (Verilator DIDNOTCONVERGE) with the loop's writes dead.  read_slang's
// netlist has no loop; the slang miter and `check -assert` are the gates.
module dut (
  input  logic [1:0] sel,
  input  logic [3:0] a,
  input  logic [3:0] b,
  output logic [3:0] y,
  output logic [3:0] z
);
  logic [3:0] arr [0:3];
  integer i;
  always @* begin
    for (i = 0; i < 4; i = i + 1) arr[i] = a + i[3:0];
    arr[sel] = arr[sel] + b;
    y = arr[sel ^ 2'b01];
    z = arr[sel];
  end
endmodule
