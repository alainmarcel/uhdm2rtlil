# Multi-file SystemVerilog project — imported from jeras/UHDM-tests
# (tcb_if.sv + tcb_gpio.sv + tcb_gpio_wrap.sv).  Exercises a
# parameterised SV `interface` with an internal `generate` block
# (DLY-conditional response queue) and `.sub` / `.man` modports,
# instantiated by `tcb_gpio_wrap` and passed to `tcb_gpio` as a
# `.sub` modport port.

# top: tcb_gpio_wrap
# mode: uhdm-only

tcb_if.sv
tcb_gpio.sv
tcb_gpio_wrap.sv
