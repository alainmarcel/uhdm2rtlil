// An indexed part-select with a DYNAMIC base on a struct member,
// `mst_resp.r.data[8*(b + off) +: 8]` -- PULP axi_dw_downsizer's read-data
// byte serialization.  Only the constant-base form of the struct-member
// slice was handled; a dynamic base fell through to the generic hier-path
// decoder, which resolved the whole read to ONE bit at the member's offset
// (`{7'0, mst_resp[13]}` for every byte), so the downsized R data read
// back zero on every beat.  The reader now shifts the FIELD slice by the
// base, for a nested member (`s.r.data[...]`) and a direct one (`s.data[...]`),
// `+:` and `-:` alike.  The slang miter fails without the fix.
typedef struct packed {
  logic [3:0]  id;
  logic [31:0] data;
  logic [1:0]  resp;
  logic        last;
  logic [8:0]  user;
} r_t;
typedef struct packed {
  r_t   r;
  logic r_valid;
  logic ar_ready;
} resp_t;

module struct_member_dyn_indexed_partsel (
  input  logic        clk_i, rst_ni,
  input  resp_t       mst_resp_i,
  input  r_t          r_i,
  input  logic        valid_i,
  input  logic [1:0]  off_i,
  input  logic [2:0]  size_i,
  input  logic [4:0]  hi_i,
  output logic [63:0] data_o,
  output logic [7:0]  byte_o,
  output logic [3:0]  nib_o
);
  resp_t mst_resp;
  assign mst_resp = mst_resp_i;

  // Nested member, `+:`, dynamic base built from a loop variable and locals.
  logic [7:0][7:0] r_data;
  logic [63:0]     data_q;
  always_comb begin
    r_data = data_q;
    if (valid_i) begin
      automatic logic [31:0] mo;
      automatic logic [31:0] so;
      mo = off_i;
      so = size_i;
      for (int b = 0; b < 8; b++) begin
        if ((b >= so) && (b - so < (1 << size_i)) && (b + mo - so < 4)) begin
          r_data[b] = mst_resp.r.data[8*(b + mo - so) +: 8];
        end
      end
    end
  end
  always_ff @(posedge clk_i or negedge rst_ni)
    if (!rst_ni) data_q <= '0; else data_q <= r_data;
  assign data_o = data_q;

  // Direct member, `+:` from a port.
  assign byte_o = r_i.data[8*off_i +: 8];
  // Direct member, `-:` with a dynamic upper index.
  assign nib_o  = r_i.data[(hi_i | 5'd3) -: 4];   // base >= 3: in bounds
endmodule
