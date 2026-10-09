// A GROUPED ANSI port list: the direction keyword written once for several
// typed declarations.  Surelog attached a typespec only to the FIRST
// declaration after each keyword; the rest reached compileAnsiPortDeclaration
// with no PortDir node of their own and took a branch written for interface
// ports, which drops the packed dimension -- so `b` and `c` elaborated as 1-bit
// nets with no typespec at all (read_uhdm: b 1 bit, c 1 bit; read_slang: 4 and
// 16), and the miter could not even pair the two netlists' ports.
//
// RSD (rsd-devel/rsd) writes every port list this way: 12 of its modules --
// Picker, CircularRangePicker (`request` 1 bit instead of 16, `tailPtr` 1
// instead of 4), ControlQueue, MicroOpPicker, ProducerMatrix, the FP32
// pipelines, RenameStageSerializer, MultiWidthFreeList -- reported
// `No matching port in gate module` for exactly this.  Fixed in Surelog #4209 (bumped here).
module ansi_grouped_port_dims #(parameter N = 16)(
input
    logic [3:0]   a,
    logic [3:0]   b,
    logic [N-1:0] c,
output
    logic [3:0]   d,
    logic         e,
    logic [N-1:0] f
);
  assign d = a ^ b ^ c[3:0];
  assign e = |c;
  assign f = c + {12'd0, b};
endmodule
