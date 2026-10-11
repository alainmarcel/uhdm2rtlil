// RSD BypassController: SelectReg reads `intEX[i].writeReg` / `.dstRegNum`
// on an UNPACKED array of packed structs passed as a function argument.  The
// formal is staged as one flat vector (or the concat of the caller's element
// wires), Surelog binds no Actual_group on the select, and both the
// `arg[k].member` hier_path and the `arg[k][hi:lo]` var_select resolved to X.
typedef struct packed { logic [6:0] dstRegNum; logic writeReg; } opnd_t;
function automatic logic [6:0] FieldOfElem(input opnd_t arr [2]);
  return arr[1].dstRegNum;
endfunction
function automatic logic FlagOfElem(input opnd_t arr [2]);
  return arr[0].writeReg;
endfunction
function automatic logic [3:0] SliceOfElem(input logic [7:0] arr [2]);
  return arr[1][6:3];
endfunction
module tf_formal_array_elem_select(input logic [15:0] x, output logic [6:0] f, output logic g, output logic [3:0] s);
  opnd_t a [2];
  logic [7:0] b [2];
  always_comb begin
    a[0] = x[7:0]; a[1] = x[15:8];
    b[0] = x[7:0]; b[1] = x[15:8];
    f = FieldOfElem(a);
    g = FlagOfElem(a);
    s = SliceOfElem(b);
  end
endmodule
