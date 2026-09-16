// `arr[idx].field[hi:lo]` — a part-select of a struct FIELD of an element of a
// PACKED array of packed structs.  Path_elems is
// [bit_select(arr[idx]), ref_obj(field), part_select(hi:lo)], a shape nothing
// resolved: the LHS imported as 1'x and the write was SILENTLY DROPPED.
//
// Because the bits it touched then became unknown, the comb process also fell
// back to a FULL-WIDTH update of the whole array, so with one process per
// generate iteration every iteration drove every bit.
//
// VeeR EL2's decoder (chipsalliance/caliptra-rtl) writes its non-blocking-load
// CAM exactly this way:
//     cam_in[i].tag[NBLOAD_TAG_MSB:0] = cam_write_tag[NBLOAD_TAG_MSB:0];
// and `flatten` rejected the result with conflicting drivers on
// `cam_array[3].cam_ff.din`.
//
// `wtag`/`wrd` are observable at the output, so a dropped write shows up as a
// stuck value rather than being optimised away.
typedef struct packed {
  logic       valid;
  logic       wb;
  logic [2:0] tag;
  logic [4:0] rd;
} cam_t;

module dut #(parameter N = 4) (
  input  logic [N-1:0] wen,
  input  logic [2:0]   wtag,
  input  logic [4:0]   wrd,
  input  cam_t [N-1:0] cam_prev,
  output cam_t [N-1:0] cam_in
);
  for (genvar i = 0; i < N; i++) begin : cam_array
    always_comb begin
      cam_in[i] = '0;                     // whole-element write
      if (wen[i]) begin
        cam_in[i].valid    = 1'b1;        // whole field
        cam_in[i].tag[1:0] = wtag[1:0];   // PART-SELECT of a field
        cam_in[i].rd[4:0]  = wrd[4:0];    // PART-SELECT of a field
      end
      else
        cam_in[i] = cam_prev[i];          // whole-element write
    end
  end
endmodule
