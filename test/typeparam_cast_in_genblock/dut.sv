// A size cast to a TYPE PARAMETER, written INSIDE a generate block.
//
// A generate block is its own DesignComponent and does not carry the enclosing
// module's parameters, so Surelog's type lookup for the cast found nothing and
// emitted an `unsupported_typespec` -- which every consumer measures as ONE
// BIT.  `narrow_chan_t'(wide_i)` therefore kept only bit 0 and zero-filled the
// rest, instead of truncating to the bound struct's low 5 bits.  The identical
// cast one line OUTSIDE the generate block was always fine, and so was a cast
// to a package typedef inside it -- both are kept here as controls.
//
// Reduced from PULP axi_id_prepend's
//   assign slv_b_chans_o[i] = slv_b_chan_t'(mst_b_chans_i[i]);
// which silently dropped the B-channel response bits of axi_id_serialize.
package pk;
  typedef struct packed { logic [2:0] id; logic [1:0] resp; logic [1:0] user; } wide_t;    // 7
  typedef struct packed { logic [0:0] id; logic [1:0] resp; logic [1:0] user; } narrow_t;  // 5
endpackage

module prep #(
  parameter type         narrow_chan_t = logic,
  parameter type         wide_chan_t   = logic,
  parameter int unsigned NoBus         = 2
) (
  input  wide_chan_t   [NoBus-1:0] wide_i,
  output narrow_chan_t             flat_o,     // control: outside the generate
  output narrow_chan_t [NoBus-1:0] gen_o,      // the bug
  output logic         [4:0]       gen_pkg_o   // control: package typedef inside
);
  assign flat_o = narrow_chan_t'(wide_i[0]);

  for (genvar i = 0; i < NoBus; i++) begin : gen_prep
    assign gen_o[i] = narrow_chan_t'(wide_i[i]);
  end

  for (genvar i = 0; i < 1; i++) begin : gen_pkg
    assign gen_pkg_o = pk::narrow_t'(wide_i[0]);
  end
endmodule

module typeparam_cast_in_genblock (
  input  logic [13:0] wide_i,
  output logic [4:0]  flat_o,
  output logic [9:0]  gen_o,
  output logic [4:0]  gen_pkg_o
);
  prep #(.narrow_chan_t(pk::narrow_t), .wide_chan_t(pk::wide_t), .NoBus(2))
    u (.wide_i(wide_i), .flat_o(flat_o), .gen_o(gen_o), .gen_pkg_o(gen_pkg_o));
endmodule
