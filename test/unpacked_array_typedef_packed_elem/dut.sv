// An element read of an UNPACKED array whose element is a packed array of a
// typedef'd leaf (`sp2v_e [7:0] we_o [2]`, OpenTitan aes_control's
// `sp2v_e [NumRegsKey-1:0] key_init_we_o [NumSharesKey]`).  Surelog models it
// as an array_var with a BARE array_typespec (no element typespec, no range)
// and keeps the geometry on the first element and the array's own unpacked
// range; measured from the bare typespec the element was ONE bit, so
// `we_o[g0]` read bit g0 of the 48-bit flat wire and the flat shim's output
// was a zero-extended bit.  Fixed in the bit-select handler.
package pkg;
  typedef enum logic [2:0] { SP2V_HIGH = 3'b100, SP2V_LOW = 3'b011 } sp2v_e;
endpackage
module leaf (input logic [7:0] we_i, output pkg::sp2v_e [7:0] we_o [2]);
  import pkg::*;
  for (genvar s = 0; s < 2; s++) begin : g_s
    for (genvar i = 0; i < 8; i++) begin : g_i
      assign we_o[s][i] = we_i[i] ? SP2V_HIGH : SP2V_LOW;
    end
  end
endmodule
module dut (input logic [7:0] we_i, output logic [47:0] we_o_flat);
  import pkg::*;
  sp2v_e [7:0] we_o [2];
  for (genvar g0 = 0; g0 < 2; g0++) begin : g_flat
    assign we_o_flat[(g0)*(($bits(sp2v_e))*(8)) +: (($bits(sp2v_e))*(8))] = we_o[0 + g0];
  end
  leaf u_dut (.we_i, .we_o);
endmodule
