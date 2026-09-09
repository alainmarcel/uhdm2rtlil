// A function whose RETURN TYPE is a packed struct, built field-by-field from a
// struct argument, then returned.  The function-local struct var got width 1
// (only integer_var/logic_var were sized) so every field write collapsed, and
// the field-write typespec didn't resolve for the return var -> the function
// returned 0.  This is tlul's extract_d2h_rsp_intg feeding the D-channel
// integrity ECC (tlul_{cmd,rsp}_intg_{gen,chk}).
package sp;
  typedef struct packed { logic [2:0] opcode; logic [2:0] size; logic error; } rsp_t;
endpackage
module func_struct_return(input logic [2:0] op, sz, input logic er, output logic [6:0] o);
  import sp::*;
  function automatic rsp_t extract(logic [2:0] a, logic [2:0] s, logic e);
    rsp_t p;
    p.opcode = a;
    p.size   = s;
    p.error  = e;
    return p;
  endfunction
  rsp_t r;
  assign r = extract(op, sz, er);
  assign o = {r.opcode, r.size, r.error};
endmodule
