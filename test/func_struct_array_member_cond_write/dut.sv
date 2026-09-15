// A package function returning a packed array of packed structs: a
// replicated default, then CONDITIONAL member writes into elements
// (OpenTitan otp_ctrl_part_pkg::named_part_access_pre:
//   part_access_pre = {{32'(2*NumPart)}{MuBi8False}};
//   if (!reg2hw.vendor_test_read_lock) part_access_pre[VendorTestIdx].read_lock = MuBi8True;
// ...).  In the Egret top the member writes were lost and every partition
// read-lock stayed MuBi8False (read_slang: MuBi8True after reset).
package func_struct_array_member_cond_write_pkg;
  parameter int NumPart = 4;
  parameter int IdxA = 0, IdxB = 1, IdxC = 3;
  typedef enum logic [7:0] { MuBi8True = 8'h96, MuBi8False = 8'h69 } mubi8_t;
  typedef struct packed { mubi8_t read_lock; mubi8_t write_lock; } part_access_t;
  typedef struct packed { logic a_read_lock; logic b_read_lock; logic c_read_lock; logic [4:0] other; } reg2hw_t;

  function automatic part_access_t [NumPart-1:0] named_access(reg2hw_t reg2hw);
    part_access_t [NumPart-1:0] acc;
    logic unused;
    unused = ^reg2hw;
    acc = {{32'(2*NumPart)}{MuBi8False}};
    if (!reg2hw.a_read_lock) begin
      acc[IdxA].read_lock = MuBi8True;
    end
    if (!reg2hw.b_read_lock) begin
      acc[IdxB].read_lock = MuBi8True;
    end
    if (!reg2hw.c_read_lock) begin
      acc[IdxC].write_lock = MuBi8True;
    end
    return acc;
  endfunction
endpackage

module func_struct_array_member_cond_write
  import func_struct_array_member_cond_write_pkg::*;
(
  input  reg2hw_t                        reg2hw_i,
  input  logic                           lock_lc_i,
  output part_access_t [NumPart-1:0]     access_o,
  output part_access_t [NumPart-1:0]     access_ca_o
);
  assign access_ca_o = named_access(reg2hw_i);
  always_comb begin
    access_o = named_access(reg2hw_i);
    if (lock_lc_i) begin
      access_o[2].write_lock = MuBi8True;
      access_o[2].read_lock  = MuBi8True;
    end
  end
endmodule
