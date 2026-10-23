// An unpacked array of packed UNIONS written member by member
// (`evt[k].txdr.code = ...`) and by a member pattern (`evt[k].ccc = '{...}`),
// OpenTitan i3c_targ_async_events' async_evt.  Two gaps: the element-field
// writer resolved the element type as a STRUCT only, so a union element was
// declined and the nested writes fell through to the read path (dropped);
// and the pattern's target typespec lookup stopped at the ARRAY type of the
// base, so the named pattern had no member widths.  Every element read 0:
// 38 diverging co-simulated cycles, read_slang clean.
package p;
  typedef enum logic [3:0] { Ev_CCC = 4'd0, Ev_Tx = 4'd1, Ev_Bus = 4'd2, Ev_Count = 4'd3 } ev_e;
  typedef struct packed { ev_e code; logic [7:0] ccc; logic has_defb; logic [7:0] defb; logic [10:0] rsv; } ccc_t;
  typedef struct packed { ev_e code; logic [3:0] err; logic [3:0] tid; logic [15:0] left; logic [3:0] rsv; } txd_t;
  typedef struct packed { ev_e code; logic [7:0] evt; logic [19:0] rsv; } bus_t;
  typedef union packed { ccc_t ccc; txd_t txdr; bus_t bus; } ev_t;
endpackage
module dut (input logic [7:0] c, input logic [7:0] db, input logic hd, input logic [3:0] err, input logic [3:0] tid,
          input logic [15:0] left, input logic [7:0] bev,
          output logic [31:0] o0, o1, o2);
  import p::*;
  ev_t evt [Ev_Count];
  always_comb begin
    for (int unsigned et = 0; et < int'(Ev_Count); et++)
      evt[et] = '0;
    evt[Ev_CCC].ccc = '{ code: Ev_CCC, ccc: c, defb: db, has_defb: hd, default: '0 };
    evt[Ev_Tx].txdr.code = Ev_Tx;
    evt[Ev_Tx].txdr.err  = err;
    evt[Ev_Tx].txdr.tid  = tid;
    evt[Ev_Tx].txdr.left = left;
    evt[Ev_Bus].bus.code = Ev_Bus;
    evt[Ev_Bus].bus.evt  = bev;
  end
  assign o0 = evt[0]; assign o1 = evt[1]; assign o2 = evt[2];
endmodule
