// Packed array of an ENUM typedef through a function (OpenTitan aes_ctr's
// aes_rev_order_sp2v): `sp2v_e [N-1:0]` formal / local / return.  The element
// selects `out[i] = in[N-1-i]` addressed a SINGLE BIT of the flat value (the
// outer dim sits on a packed_array_typespec, not a logic_typespec), so the
// reversed table came back as N one-bit values: ctr_we_o = 0x000024 instead
// of 0x924924.  Also covers the `{N{ENUM_CONST}}` whole-array default followed
// by a dynamic element write (aes_ctr's ctr_we_o_rev).
module func_packed_enum_array_reverse #(parameter int N = 8) (
  input  logic [2:0]      idx,
  input  logic [2:0]      we_raw,
  output logic [N-1:0][2:0] rev_o,
  output logic [N-1:0][2:0] tbl_o
);
  localparam int Sp2VWidth = 3;
  typedef enum logic [Sp2VWidth-1:0] { SP2V_HIGH = 3'b011, SP2V_LOW = 3'b100 } sp2v_e;
  function automatic sp2v_e [N-1:0] rev(sp2v_e [N-1:0] in);
    sp2v_e [N-1:0] out;
    for (int i = 0; i < N; i++) out[i] = in[N-1-i];
    return out;
  endfunction
  sp2v_e [N-1:0] tbl;
  always_comb begin
    tbl      = {N{SP2V_LOW}};
    tbl[idx] = sp2v_e'(we_raw);
  end
  assign tbl_o = tbl;
  assign rev_o = rev(tbl);
endmodule
