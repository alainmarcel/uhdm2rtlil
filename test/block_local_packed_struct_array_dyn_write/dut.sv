// A BLOCK-LOCAL packed array of structs (`slot_t [N-1:0] slots;` declared
// inside the always_comb) updated through a dynamic element index — the
// keymgr_dpe_ctrl slot-update shape written with a local accumulator.  A
// bit_select on a block-local carries no Actual_group and Surelog attaches
// the WHOLE-array typespec (`slot_t [N-1:0]`) to the promoted variable next
// to its own outer range, so the dynamic packed-select writer took the flat
// wire width as the element width: `slots[slot_dst_sel_i] = '0` cleared the
// whole array and the following per-slot field writes landed on the stale
// value.  The writer now resolves a block-local base through the promoted
// variable's object and descends to the typespec's element when it spans the
// entire wire.
package blp_pkg;
  parameter int Shares = 2, KeyWidth = 64, EntropyWidth = 32, EntropyRounds = KeyWidth/EntropyWidth, DpeNumSlots = 3;
  typedef enum logic [1:0] { BootStageCreator = 2'd0, BootStageOwner = 2'd1, BootStageRuntime = 2'd2 } boot_stage_e;
  typedef struct packed { logic allow_child; logic exportable; } policy_t;
  typedef struct packed {
    logic valid;
    boot_stage_e boot_stage;
    logic [Shares-1:0][KeyWidth-1:0] key;
    logic [31:0] max_key_version;
    policy_t key_policy;
  } slot_t;
  typedef enum logic [2:0] { SlotIdle, SlotDestRandomize, SlotLoadRoot, SlotLoadFromKmac, SlotErase, SlotWipeAll, SlotWipeInternalOnly } update_e;
endpackage
module block_local_packed_struct_array_dyn_write import blp_pkg::*; (input logic clk_i, input logic rst_ni, input update_e update_sel, input logic [1:0] slot_dst_sel_i, input logic cnt,
  input logic [Shares-1:0][EntropyWidth-1:0] entropy_i, input logic [Shares-1:0][KeyWidth-1:0] root_key_i, input logic [Shares-1:0][KeyWidth-1:0] kmac_data_i,
  input logic [31:0] max_key_version_i, input policy_t slot_policy_i, output slot_t [DpeNumSlots-1:0] key_slots_o);
  slot_t [DpeNumSlots-1:0] key_slots_q, key_slots_d;
  always_comb begin
    slot_t [DpeNumSlots-1:0] slots;
    slots = key_slots_q;
    unique case (update_sel)
      SlotDestRandomize: begin
        slots[slot_dst_sel_i] = '0;
        for (int j = 0; j < Shares; j++) begin
          slots[slot_dst_sel_i].key[j][cnt*EntropyWidth +: EntropyWidth] = entropy_i[0];
        end
      end
      SlotLoadRoot: begin
        slots[slot_dst_sel_i].valid = 1;
        slots[slot_dst_sel_i].boot_stage = BootStageCreator;
        slots[slot_dst_sel_i].key[0] ^= root_key_i[0];
        slots[slot_dst_sel_i].key[1] ^= root_key_i[1];
        slots[slot_dst_sel_i].max_key_version = max_key_version_i;
        slots[slot_dst_sel_i].key_policy = '{allow_child: 1'b1, exportable: 1'b0};
      end
      SlotLoadFromKmac: begin
        slots[slot_dst_sel_i].valid = 1;
        slots[slot_dst_sel_i].key = kmac_data_i;
        slots[slot_dst_sel_i].max_key_version = max_key_version_i;
        slots[slot_dst_sel_i].boot_stage = (slots[0].boot_stage == BootStageCreator) ? BootStageOwner : BootStageRuntime;
        slots[slot_dst_sel_i].key_policy = slot_policy_i;
      end
      SlotErase: begin
        slots[slot_dst_sel_i] = '0;
        for (int j = 0; j < Shares; j++) begin
          slots[slot_dst_sel_i].key[j][cnt*EntropyWidth +: EntropyWidth] = entropy_i[0];
        end
      end
      SlotWipeAll, SlotWipeInternalOnly: begin
        for (int i = 0; i < DpeNumSlots; i++) begin
          slots[i] = '0;
          for (int j = 0; j < Shares; j++) begin
            slots[i].key[j] = {EntropyRounds{entropy_i[j]}};
          end
        end
      end
      default:;
    endcase
    key_slots_d = slots;
  end
  always_ff @(posedge clk_i or negedge rst_ni) if (!rst_ni) key_slots_q <= '0; else key_slots_q <= key_slots_d;
  assign key_slots_o = key_slots_q;
endmodule
