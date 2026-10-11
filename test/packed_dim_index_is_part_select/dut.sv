// An index of a PACKED multi-dimensional array that is itself a part-select of
// ANOTHER signal was mistaken for a trailing slice OF THE ARRAY: the index's
// own base/width became the slice position, so the access landed on a fixed
// field instead of the addressed element.
//
// Read shape, from caliptra-ss adams-bridge sample_in_ball_shuffler:
//     input logic [1:0][3:0][1:0] rddata_i;
//     always_comb nxt_i = rddata_i[0][indexj_i[1:0]];
// Write shape (one-hot bit addressed by another signal's slice):
//     dispatchVector[i][ptr[i*2 +: 2]] = 1'b1;
//
// A genuine trailing slice names the array itself (`arr[1][3:0]` is a
// part_select named `arr`), so the two are told apart by name; both forms are
// exercised here.
module packed_dim_index_is_part_select(
  input  logic [15:0] d,
  input  logic [7:0]  sel,
  input  logic [1:0]  en,
  output logic [1:0]  rd_elem,
  output logic [7:0]  wr_vec,
  output logic [3:0]  slice_lo,
  output logic [1:0]  slice_ips
);
  logic [1:0][3:0][1:0] rddata;
  logic [1:0][3:0]      dispatchVector;
  logic [1:0][3:0]      arr;

  always_comb begin
    rddata = d;
    arr    = d[7:0];

    // READ: trailing index is a part-select of another signal.
    rd_elem = rddata[0][sel[1:0]];

    // WRITE: dynamic one-hot bit addressed by another signal's slice.
    for (int i = 0; i < 2; i++) begin
      dispatchVector[i] = '0;
      if (en[i]) begin
        dispatchVector[i][sel[i*2 +: 2]] = 1'b1;
      end
    end
    wr_vec = dispatchVector;

    // Genuine trailing slices OF THE ARRAY must keep working.
    slice_lo  = arr[1][3:0];
    slice_ips = arr[0][2 +: 2];
  end
endmodule
