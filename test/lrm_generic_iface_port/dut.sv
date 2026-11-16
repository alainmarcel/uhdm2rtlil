// IEEE 1800-2023 25.3.3: a GENERIC interface port.  `interface bus` takes
// whatever interface instance is connected; its members are found by name.
interface simple_if;
  logic [7:0] data;
  logic       valid;
endinterface

module consumer(interface bus, output logic [7:0] y);
  assign y = bus.valid ? bus.data : 8'h00;
endmodule

module dut(input logic [7:0] d, input logic v, output logic [7:0] y);
  simple_if i();
  assign i.data  = d;
  assign i.valid = v;
  consumer u(.bus(i), .y(y));
endmodule
