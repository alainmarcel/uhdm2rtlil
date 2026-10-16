// A bit / part / indexed-part select of an INTERFACE INSTANCE's member, the
// instance declared inside a generate block.  rggen's
// `rggen_connect_bit_field_if` macro is exactly that, in an always_comb:
//
//   FIF.mask                  = RIF.mask[LSB+:WIDTH];
//   RIF.read_data[LSB+:WIDTH] = FIF.read_data;
//
// and its `rggen_tie_off_unused_signals` writes `RIF.read_data[__i] = '0` per
// genvar.  The PLAIN member (`RIF.valid`) resolved through the scope-qualified
// wire; the selected form fell to the struct-member decoder, which has no
// struct to decode, and the access was dropped ("Could not resolve struct
// member access 'bit_field_if.mask[0+:8]'"): 64 undriven bits here, and every
// rggen register block's read data came back zero.
interface bf_if #(parameter int WIDTH = 32);
  logic              valid;
  logic [WIDTH-1:0]  mask;
  logic [WIDTH-1:0]  read_data;
  logic [WIDTH-1:0]  value;
endinterface

module top (
  input  logic        i_valid,
  input  logic [31:0] i_mask,
  input  logic [7:0]  i_rd, i_val,
  output logic        o_valid,
  output logic [7:0]  o_mask,
  output logic [31:0] o_rd, o_val
);
  generate if (1) begin : g_rbr
    bf_if #(32) bit_field_if();
    // tie-off of the unused bits (rggen_tie_off_unused_signals, valid bits 0xff)
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
    if (1) begin : g_rbr
      bf_if #(8) bit_field_sub_if();
      // rggen_connect_bit_field_if(bit_field_if, bit_field_sub_if, 0, 8)
      always_comb begin
        bit_field_sub_if.valid           = bit_field_if.valid;
        bit_field_sub_if.mask            = bit_field_if.mask[0+:8];
        bit_field_if.read_data[0+:8]     = bit_field_sub_if.read_data;
        bit_field_if.value[0+:8]         = bit_field_sub_if.value;
      end
      assign bit_field_sub_if.read_data = i_rd;
      assign bit_field_sub_if.value     = i_val;
      assign o_valid = bit_field_sub_if.valid;
      assign o_mask  = bit_field_sub_if.mask;
    end
    assign bit_field_if.valid = i_valid;
    assign bit_field_if.mask  = i_mask;
    assign o_rd  = bit_field_if.read_data;
    assign o_val = bit_field_if.value;
  end endgenerate
endmodule
