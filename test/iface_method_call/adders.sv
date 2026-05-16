// Reduced from the original synlig-style reproducer: a single half-
// adder instance whose interface-method call drives the observable
// outputs.  The original two-instance design wires both half-adders
// onto the same `hintf` signals (a multi-driver combinational loop
// that Verilator refuses to converge on); a single instance is
// sufficient to exercise the UHDM frontend's `method_func_call`
// lowering, which is the construct under test.
module adders (
    output       su,
    output       cout_obs,
    input        a,
    input        b
);
    intf1 hintf();

    ha_itf h1(hintf, su, cout_obs, a, b);
endmodule
