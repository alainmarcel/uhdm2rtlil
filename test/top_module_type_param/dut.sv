// A TOP module that itself has a `parameter type`.  Its `$typaram` per-binding
// signature must NOT be appended to the top's RTLIL name (it is the sole
// instance of its def), so `hierarchy -top top_module_type_param` finds it
// (CVA6's top `cva6` has type params — else it imported as `cva6$typaram_...`
// and `hierarchy -top cva6` failed "Module not found").
module top_module_type_param #(
    parameter type data_t = logic [7:0]
) (
    input  data_t in_i,
    output logic  parity_o
);
  assign parity_o = ^in_i;
endmodule
