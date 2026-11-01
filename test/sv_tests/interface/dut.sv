// Converted from chipsalliance/sv-tests (interface).
// Upstream connects an interface instance to a submodule with the IMPLICIT named port form (`.iface`) and gives the submodule no body, so nothing crosses the interface.
// The construct and upstream's OWN ASSERTED VALUES are kept; the computation now
// runs on real ports, so the values are proven instead of printed.
// Upstream kept as orig.sv.
interface test_bus;
  logic test_pad;
endinterface: test_bus
module sub(test_bus iface, output logic o);
  // The member is read THROUGH the interface port.
  assign o = iface.test_pad;
endmodule
module top(input logic x, output logic o);
   test_bus iface();
   assign iface.test_pad = x;
   // `.iface` is the implicit named connection: the port and the instance share
   // the name, which is the construct under test.
   sub sub (.iface, .o(o));
endmodule
