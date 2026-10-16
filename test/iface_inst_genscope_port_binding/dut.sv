// Interface instances declared inside GENERATE blocks, bound to child
// modules' modport ports -- rggen's register blocks:
//
//   generate if (1) begin : g_rbr
//     rggen_bit_field_if #(32) bit_field_if();
//     rggen_indirect_register u_register (.bit_field_if(bit_field_if), ...);
//     if (1) begin : g_rbr
//       rggen_bit_field_if #(8) bit_field_sub_if();
//       rggen_bit_field u_bit_field (.bit_field_if(bit_field_sub_if), ...);
//
// The instance's member wires live under the scope-qualified name
// (`g_rbr.bit_field_if.valid`); the port-binding site looked the bare
// VpiName up in name_map, found nothing, and left the port UNCONNECTED
// without a word -- every rggen register's bit-field interface floated
// (73 undriven bits here; uart_csr / block_1 read every register as zero).
// Also here: an interface-ARRAY ELEMENT's member select
// (`register_if[5].value[7+:1]`, rggen's indirect-register match).
interface bf_if #(parameter int WIDTH = 32);
  logic              valid;
  logic [WIDTH-1:0]  mask;
  logic [WIDTH-1:0]  read_data;
  logic [WIDTH-1:0]  value;
  modport register (output valid, mask, input read_data, value);
  modport bit_field (input valid, mask, output read_data, value);
endinterface

interface reg_if;
  logic [31:0] value;
  modport host (input value);
  modport regp (output value);
endinterface

module matcher (
  reg_if.host   register_if[6],
  output logic  o_match
);
  assign o_match = register_if[5].value[7+:1] == 1'h0;
endmodule

// the register side: drives valid/mask into the field interface, reads back
module reg_user (
  bf_if.register bit_field_if,
  input  logic        i_valid,
  input  logic [31:0] i_mask,
  output logic [31:0] o_rd, o_val
);
  always_comb begin
    bit_field_if.valid = i_valid;
    bit_field_if.mask  = i_mask;
  end
  assign o_rd  = bit_field_if.read_data;
  assign o_val = bit_field_if.value;
endmodule

// the field side: consumes valid/mask, produces read_data/value
module field_user (
  bf_if.bit_field bit_field_if,
  input  logic [7:0] i_rd, i_val,
  output logic       o_valid,
  output logic [7:0] o_mask
);
  assign bit_field_if.read_data = i_rd;
  assign bit_field_if.value     = i_val;
  assign o_valid = bit_field_if.valid;
  assign o_mask  = bit_field_if.mask;
endmodule

module csr (
  input  logic        i_valid,
  input  logic [31:0] i_mask,
  input  logic [7:0]  i_rd, i_val,
  input  logic [31:0] i_regval,
  output logic        o_valid,
  output logic [7:0]  o_mask,
  output logic [31:0] o_rd, o_val,
  output logic        o_match
);
  reg_if register_if[6]();
  assign register_if[5].value = i_regval;
  logic indirect_match;
  // the indirect-register match, read through an interface-ARRAY port
  // (yosys's read_verilog rejects that port shape, which keeps this test
  // UHDM-only -- at top level it would declare `bit_field_if.valid` etc. as
  // implicit 1-bit wires and the Verilog comparison would be vacuous)
  matcher u_matcher (.register_if(register_if), .o_match(indirect_match));
  generate if (1) begin : g_rbr
    bf_if #(32) bit_field_if();
    if (1) begin : __g_tie_off
      genvar __i;
      for (__i = 0; __i < 32; ++__i) begin : g
        if (((32'h000000ff >> __i) % 2) == 0) begin : g
          always_comb begin
            bit_field_if.read_data[__i] = '0;
            bit_field_if.value[__i]     = '0;
          end
        end
      end
    end
    assign o_match = indirect_match;
    reg_user u_register (.bit_field_if(bit_field_if), .i_valid(i_valid), .i_mask(i_mask), .o_rd(o_rd), .o_val(o_val));
    if (1) begin : g_rbr
      bf_if #(8) bit_field_sub_if();
      always_comb begin
        bit_field_sub_if.valid           = bit_field_if.valid;
        bit_field_sub_if.mask            = bit_field_if.mask[0+:8];
        bit_field_if.read_data[0+:8]     = bit_field_sub_if.read_data;
        bit_field_if.value[0+:8]         = bit_field_sub_if.value;
      end
      field_user u_bit_field (.bit_field_if(bit_field_sub_if), .i_rd(i_rd), .i_val(i_val), .o_valid(o_valid), .o_mask(o_mask));
    end
  end endgenerate
endmodule

module csr_flat (
  input  logic        i_valid,
  input  logic [31:0] i_mask,
  input  logic [7:0]  i_rd, i_val,
  input  logic [31:0] i_regval,
  output logic        o_valid,
  output logic [7:0]  o_mask,
  output logic [31:0] o_rd, o_val,
  output logic        o_match
);
  csr dut (.*);
endmodule
