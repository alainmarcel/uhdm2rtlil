// Reproduces chipsalliance/UHDM-integration-tests
// `tests/InterfaceParameterSetValue/top.sv`.  The construct under
// test is:
//   - parameter override on an interface instance (`#(.W(16))`)
//   - net-decl-assign initializer on a parameterised interface signal
//     (`logic [W-1:0] start_addr = '1`)
//   - reading the interface signal from the parent via the instance
//     path (`u_sim_sram_if.start_addr`)
//   - SystemVerilog static-cast of an interface signal to `int`
//
// The original DUT has no inputs (the only signal is a constant
// initializer), so co-sim would only check a single static value.
// To make the test observable across many cycles, an input `in` is
// XORed into the result on its way to the output; the test still
// asserts that the *upper* 16 bits stay zero (the `int` cast keeps
// the parameter at 16) and that the *lower* 16 bits equal
// `~in` (which is `'1 ^ in`).  When `in==0`, that lower 16 bits is
// `16'hFFFF`, matching the original test's expected
// `o == 32'h0000FFFF`.
interface sim_sram_if;
   parameter int W = 32;
   logic [W-1:0] start_addr = '1;
endinterface

module top (
    input  logic [15:0] in,
    output int          o
);
   sim_sram_if #(.W(16)) u_sim_sram_if();
   assign o = int'(u_sim_sram_if.start_addr) ^ {16'h0000, in};
endmodule
