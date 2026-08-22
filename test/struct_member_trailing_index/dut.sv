// Trailing dynamic index on the LAST member of a hierarchical LHS:
//   d[pc][row].sat[hist] = val;
// Surelog dropped the `[hist]` select (it is a Select sibling of the
// Ps_or_hierarchical_identifier, outside the Hierarchical_identifier the LHS
// was compiled from), so the write clobbered the WHOLE sat member.  The
// frontend then also had to (a) accept the trailing named bit_select as the
// field path elem, (b) write only the indexed sub-slice, and (c) evaluate the
// struct element width with the current instance (the parameterized sat
// range collapsed the 20-bit element to 5 bits, landing writes on the wrong
// entry).  Distilled from CVA6 bht2lvl's saturation-counter table update.
// NOTE: `arr[i].field[k]` on a PER-ELEMENT-only array (no flat wire) is a
// separate pre-existing gap and is not covered here.
module struct_member_trailing_index (
    input  logic [0:0]  pc,
    input  logic [0:0]  row,
    input  logic [2:0]  hist,
    input  logic [2:0]  ak,
    input  logic [1:0]  val,
    output logic [19:0] e00,
    output logic [19:0] e01,
    output logic [19:0] e10,
    output logic [19:0] e11,
    output logic [19:0] fs
);
  typedef struct packed {
    logic              valid;
    logic [2:0]        h;
    logic [7:0][1:0]   sat;
  } e_t;

  // 2-D unpacked array of structs: multi-index + trailing member select.
  e_t d[1:0][1:0];
  always_comb begin
    d[0][0] = '0; d[0][1] = '0;
    d[1][0] = '0; d[1][1] = '0;
    d[pc][row].sat[hist] = val;
    d[pc][row].valid = 1'b1;
  end
  assign e00 = d[0][0];
  assign e01 = d[0][1];
  assign e10 = d[1][0];
  assign e11 = d[1][1];

  // Flat s.field[k] shape that already worked — the Surelog merge must not
  // double-apply the select here.
  e_t s;
  always_comb begin
    s = '0;
    s.sat[ak] = val;
    s.h = 3'h5;
  end
  assign fs = s;
endmodule
