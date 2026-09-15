// A child parameter set from an indexed part-select of a wide parameter,
// with base and width taken from members of a struct-array localparam
// indexed by the genvar (OpenTitan otp_ctrl:
//   .DataDefault(RndCnstPartInvDefault[PartInfo[k].offset*8 +: PartInfo[k].size*8])).
// In the Egret top every partition's DataDefault came out all X, so the
// partition outputs before initialization read 0 instead of the defaults.
package genvar_param_slice_by_struct_array_member_pkg;
  typedef enum logic [1:0] { Unbuffered, Buffered } part_variant_e;
  typedef struct packed {
    part_variant_e variant;
    logic [11:0]   offset;
    logic [11:0]   size;
  } part_info_t;
  parameter part_info_t PartInfoDefault = '{variant: Unbuffered, offset: 12'd0, size: 12'd1};
  parameter int NumPart = 3;
  // Wide (> 64-bit) random default, overridden from the top as in Egret's
  // top_egret_rnd_cnst_pkg::RndCnstOtpCtrlPartInvDefault.
  // Built like top_egret_rnd_cnst_pkg: SIZE CASTS of wide concatenations.
  parameter logic [199:0] RndCnstPartInvDefaultTop = {
    96'({80'hA5_0123456789ABCDEF_FE, 16'hDCBA}),
    104'({72'h98_76543210_0F1E2D3C, 32'h4B5A6978})
  };
  parameter part_info_t [NumPart-1:0] PartInfo = '{
    '{variant: Buffered,   offset: 12'd6, size: 12'd2},
    '{variant: Buffered,   offset: 12'd2, size: 12'd4},
    '{variant: Unbuffered, offset: 12'd0, size: 12'd2}
  };
endpackage

module genvar_param_slice_by_struct_array_member_part
  import genvar_param_slice_by_struct_array_member_pkg::*;
#(
  // Struct-typed Info and a DataDefault sized by one of its members, as
  // otp_ctrl_part_buf declares them.
  parameter part_info_t Info = PartInfoDefault,
  parameter logic [Info.size*8-1:0] DataDefault = '0
) (
  input  logic                   init_done_i,
  input  logic [Info.size*8-1:0] data_i,
  output logic [Info.size*8-1:0] data_o
);
  assign data_o = init_done_i ? data_i : DataDefault;
endmodule

module genvar_param_slice_by_struct_array_member_otp
  import genvar_param_slice_by_struct_array_member_pkg::*;
#(
  parameter logic [199:0] RndCnstPartInvDefault = '0
) (
  input  logic        init_done_i,
  input  logic [63:0] data_i,
  output logic [63:0] data_o
);
  for (genvar k = 0; k < NumPart; k++) begin : gen_partitions
    if (PartInfo[k].variant == Unbuffered) begin : gen_unbuffered
      assign data_o[PartInfo[k].offset*8 +: PartInfo[k].size*8] = data_i[PartInfo[k].offset*8 +: PartInfo[k].size*8];
    end else if (PartInfo[k].variant == Buffered) begin : gen_buffered
      genvar_param_slice_by_struct_array_member_part #(
        .Info(PartInfo[k]),
        .DataDefault(RndCnstPartInvDefault[PartInfo[k].offset*8 +: PartInfo[k].size*8])
      ) u_part (
        .init_done_i,
        .data_i(data_i[PartInfo[k].offset*8 +: PartInfo[k].size*8]),
        .data_o(data_o[PartInfo[k].offset*8 +: PartInfo[k].size*8])
      );
    end
  end
endmodule

module genvar_param_slice_by_struct_array_member (
  input  logic        init_done_i,
  input  logic [63:0] data_i,
  output logic [63:0] data_o
);
  genvar_param_slice_by_struct_array_member_otp #(
    .RndCnstPartInvDefault(genvar_param_slice_by_struct_array_member_pkg::RndCnstPartInvDefaultTop)
  ) u_otp (.init_done_i, .data_i, .data_o);
endmodule
