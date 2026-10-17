// A function called THROUGH an interface instance whose type / value
// parameters are overridden at the instantiation -- tnoc's selector:
//
//     tbcm_selector #(.DATA_TYPE(tnoc_flit), .ENTRIES(ENTRIES)) u_selector();
//     assign sender_if.flit = u_selector.mux(i_select, flit);
//
// `mux` returns DATA_TYPE and takes `DATA_TYPE [ENTRIES-1:0] data`.  The call
// was inlined in the CALLER's instance context, where the interface's
// parameters are unknown, so DATA_TYPE fell back to the interface's default
// (`logic [WIDTH-1:0]`, WIDTH 8): the 291-bit flit mux returned 8 bits and
// 580 bits of every tnoc flit output were undriven (packet serializer,
// error checker, axi muxes).  The second instance overrides the VALUE
// parameter WIDTH instead, which the default type is written over.
//
// UHDM-only (interfaces); test_slang_equiv.ys proves both outputs against
// read_slang -- without the fix each is 8 bits zero-extended.
interface selector #(
  parameter int  WIDTH     = 8,
  parameter type DATA_TYPE = logic [WIDTH-1:0],
  parameter int  ENTRIES   = 2
);
  function automatic DATA_TYPE mux(
    logic [ENTRIES-1:0]     select,
    DATA_TYPE [ENTRIES-1:0] data
  );
    for (int i = 0; i < ENTRIES; ++i)
      if (select[i]) return data[i];
    return DATA_TYPE'(0);
  endfunction
endinterface

module top (
  input  logic [1:0]        i_select,
  input  logic [1:0][31:0]  i_data,
  input  logic [2:0]        i_select3,
  input  logic [2:0][15:0]  i_data3,
  output logic [31:0]       o_data,
  output logic [15:0]       o_data3
);
  typedef logic [31:0] word_t;
  selector #(.DATA_TYPE(word_t), .ENTRIES(2)) u_sel_type();
  selector #(.WIDTH(16), .ENTRIES(3))         u_sel_width();
  assign o_data  = u_sel_type.mux(i_select, i_data);
  assign o_data3 = u_sel_width.mux(i_select3, i_data3);
endmodule
