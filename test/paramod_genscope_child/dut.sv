// gpio_o device-output root: a PARAMETERIZED module instantiated inside a
// GENERATE scope, which itself instantiates a CHILD module — like the degu SoC's
// gen_gpio.gpio (tcb_lite_dev_gpio paramod) -> gpio (tcb_dev_gpio).  Does the
// paramod's child get imported, or is the paramod body incomplete?
module child (input logic x, output logic o);
  assign o = ~x;
endmodule
module mid #(parameter int N = 4) (input logic x, output logic o);
  child c (.x(x), .o(o));        // child instantiation inside the paramod
endmodule
module dut (input logic x, output logic o);
  generate if (1) begin: g
    mid #(8) m (.x(x), .o(o));   // parameterized mid inside a generate scope
  end endgenerate
endmodule
