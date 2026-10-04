// caliptra-ss otp_ctrl_dai: `PartInfo[part_idx].secret` on a package
// localparam ARRAY of packed structs built from assignment patterns, with a
// RUNTIME index.  read_uhdm read every partition as non-secret (otp_size_o 1
// instead of 3); read_slang and the RTL agree on 3.
package pi_pkg;
  parameter int OtpByteAddrWidth = 12;
  parameter int DecLcStateWidth = 5;
  typedef enum logic [1:0] { Unbuffered, Buffered, LifeCycle } part_variant_e;
  typedef enum logic [2:0] { NoKey, SecretManufKey, SecretProdKey0, SecretProdKey1 } key_sel_e;
  parameter logic [DecLcStateWidth-1:0] DecLcStRaw = 5'd0;
  parameter logic [DecLcStateWidth-1:0] DecLcStDev = 5'd3;
  typedef struct packed {
    part_variant_e variant;
    logic [OtpByteAddrWidth-1:0] offset;
    logic [OtpByteAddrWidth-1:0] size;
    key_sel_e key_sel;
    logic secret;
    logic sw_digest;
    logic hw_digest;
    logic write_lock;
    logic read_lock;
    logic integrity;
    logic iskeymgr_creator;
    logic iskeymgr_owner;
    logic [DecLcStateWidth-1:0] lc_phase;
    logic zeroizable;
  } part_info_t;
  // four entries so every value of the 2-bit index names a partition (an
  // out-of-range select is X in the RTL and would only measure the testbench)
  parameter int NumPart = 4;
  localparam part_info_t PartInfo [NumPart] = '{
    '{ variant: Buffered, offset: 12'd0,   size: 72, key_sel: key_sel_e'('0),   secret: 1'b0, sw_digest: 1'b0, hw_digest: 1'b1,
       write_lock: 1'b1, read_lock: 1'b0, integrity: 1'b1, iskeymgr_creator: 1'b0, iskeymgr_owner: 1'b0, lc_phase: DecLcStDev, zeroizable: 1'b0 },
    '{ variant: Buffered, offset: 12'd72,  size: 80, key_sel: SecretManufKey,    secret: 1'b1, sw_digest: 1'b0, hw_digest: 1'b1,
       write_lock: 1'b1, read_lock: 1'b1, integrity: 1'b1, iskeymgr_creator: 1'b0, iskeymgr_owner: 1'b0, lc_phase: DecLcStDev, zeroizable: 1'b1 },
    '{ variant: Buffered, offset: 12'd152, size: 24, key_sel: SecretProdKey0,    secret: 1'b1, sw_digest: 1'b0, hw_digest: 1'b1,
       write_lock: 1'b1, read_lock: 1'b1, integrity: 1'b1, iskeymgr_creator: 1'b0, iskeymgr_owner: 1'b0, lc_phase: DecLcStDev, zeroizable: 1'b0 },
    '{ variant: Unbuffered, offset: 12'd176, size: 40, key_sel: NoKey,          secret: 1'b0, sw_digest: 1'b1, hw_digest: 1'b0,
       write_lock: 1'b1, read_lock: 1'b0, integrity: 1'b0, iskeymgr_creator: 1'b0, iskeymgr_owner: 1'b0, lc_phase: DecLcStRaw, zeroizable: 1'b0 }
  };
endpackage

module dut import pi_pkg::*; (input logic [1:0] idx, output logic secret, output logic [11:0] size,
                              output logic [1:0] osize, output logic [11:0] offset, output logic rl, output part_info_t pi, output part_info_t p0);
  assign pi = PartInfo[idx];
  assign p0 = PartInfo[3];
  assign secret = PartInfo[idx].secret;
  assign size   = PartInfo[idx].size;
  assign offset = PartInfo[idx].offset;
  assign rl     = PartInfo[idx].read_lock;
  always_comb begin
    osize = 2'(unsigned'(32 / 16 - 1));
    if (PartInfo[idx].secret) osize = 2'(unsigned'(64 / 16 - 1));
  end
endmodule
