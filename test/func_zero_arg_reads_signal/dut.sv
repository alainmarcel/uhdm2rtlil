// A ZERO-argument function reading an interface port member and a struct
// PARAMETER field (`error_check()` in tnoc_error_checker): "all arguments are
// constant" held vacuously and the call was folded to 0.  The evaluator now
// reports that it touched a signal and the call is inlined instead.
// zero-argument function in an always_comb reading an interface PORT member and a STRUCT PARAMETER field
package cfgp;
  typedef struct packed { int size_x; int size_y; } cfg_t;
  localparam cfg_t DEF = '{size_x: 3, size_y: 3};
endpackage
interface types;
  typedef struct packed { logic [3:0] x; logic [3:0] y; } id_t;
  typedef struct packed { logic inv; id_t dest; logic [6:0] rest; } hdr_t;
endinterface
module child import cfgp::*; #(parameter cfg_t C = DEF)(types t, input logic [15:0] data, input logic head, output logic [1:0] route);
  typedef t.hdr_t hdr_t;
  function automatic logic error_check();
    hdr_t header;
    header = hdr_t'(data);
    if (header.inv) return '1;
    else if (header.dest.x >= C.size_x) return '1;
    else if (header.dest.y >= C.size_y) return '1;
    else return '0;
  endfunction
  always_comb begin
    if (head) route = (error_check()) ? 2'b10 : 2'b01;
    else route = 2'b00;
  end
endmodule
module top import cfgp::*; (input logic [15:0] data, input logic head, output logic [1:0] route);
  types t();
  child #(.C(DEF)) c (.t(t), .data(data), .head(head), .route(route));
endmodule
