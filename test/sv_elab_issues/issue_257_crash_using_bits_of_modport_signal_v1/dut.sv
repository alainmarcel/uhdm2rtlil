// povik/sv-elab#257 (closed): Crash using `$bits` of modport signal
// https://github.com/povik/sv-elab/issues/257
// Code block(s) from the issue (variant v1); harvested by test/sv_elab_issues/harvest.py

// ---- b0.sv
interface bus_if #(parameter WIDTH = 8);
  logic [WIDTH-1:0] data;

  modport receiver_mp (input data);
endinterface

module receiver (output logic [31:0] width, bus_if.receiver_mp bus);
  always_comb begin
    width = $bits(bus.data);
  end
endmodule

module top (__i_narrow_bus_data);
  bus_if #(.WIDTH(8))  narrow_bus();
  receiver u_recv1(.bus(narrow_bus));  // Receives 8-bit data

  // controllable/observable ports added by test/yosys_issues/observe.py
  input logic [7:0] __i_narrow_bus_data;
  assign narrow_bus.data = __i_narrow_bus_data;
endmodule

