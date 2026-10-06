// A function-local UNPACKED array whose elements are WIDER than one bit,
// written at the loop index and read back at a computed index.
//
// An array_var carries no Ranges() of its own and its unpacked dimension
// lives on an array_typespec, which bitselect_outer_dim did not accept, so
// every `tbl[i] = <element>` write became ONE BIT at bit i.  A one-bit
// element array was right by coincidence; wider ones lost every element past
// the first few, and the loss is INVISIBLE in the vector's low bits -- here
// stage2_idx[0] and [1] still read back correctly while [2] and [3] were 0.
//
// This is scr1_ipic's scr1_search_one_16 priority encoder, which selects the
// lowest set bit of a 16-bit vector through three stages of 2-way merges with
// 1-, 2- and 3-bit index tables.  read_uhdm reported index 0 for input 'h4
// (should be 2) and 1 for 'h8 (should be 3), so the SOI/EOI write of
// ipic_ipr_clr_req cleared the wrong interrupt.
module dut (
    input  logic [15:0] din,
    output logic        vd,
    output logic [3:0]  idx,
    // the stage tables, so a wrong element is pinned to its stage
    output logic [7:0]  s1idx,   // 8 x 1 bit  -- worked before
    output logic [7:0]  s2idx,   // 4 x 2 bits -- elements 2,3 were lost
    output logic [5:0]  s3idx    // 2 x 3 bits -- element 1 was lost
);
  typedef struct { logic vd; logic idx; } s2_t;
  typedef struct packed {
      logic       vd;
      logic [3:0] idx;
      logic [7:0] s1idx;
      logic [7:0] s2idx;
      logic [5:0] s3idx;
  } res_t;

  function automatic s2_t search_one_2(input logic [1:0] d);
      s2_t tmp;
  begin
      tmp.vd  = |d;
      tmp.idx = ~d[0];
      return tmp;
  end
  endfunction

  function automatic res_t search_one_16(input logic [15:0] d);
  begin
      logic [7:0] stage1_vd;
      logic [3:0] stage2_vd;
      logic [1:0] stage3_vd;
      logic       stage1_idx [7:0];
      logic [1:0] stage2_idx [3:0];
      logic [2:0] stage3_idx [1:0];
      res_t result;

      for (int unsigned i = 0; i < 8; ++i) begin
          s2_t tmp;
          tmp = search_one_2(d[(i+1)*2-1 -: 2]);
          stage1_vd[i]  = tmp.vd;
          stage1_idx[i] = tmp.idx;
      end
      for (int unsigned i = 0; i < 4; ++i) begin
          s2_t tmp;
          tmp = search_one_2(stage1_vd[(i+1)*2-1 -: 2]);
          stage2_vd[i]  = tmp.vd;
          stage2_idx[i] = (~tmp.idx) ? {tmp.idx, stage1_idx[2*i]}
                                     : {tmp.idx, stage1_idx[2*i+1]};
      end
      for (int unsigned i = 0; i < 2; ++i) begin
          s2_t tmp;
          tmp = search_one_2(stage2_vd[(i+1)*2-1 -: 2]);
          stage3_vd[i]  = tmp.vd;
          stage3_idx[i] = (~tmp.idx) ? {tmp.idx, stage2_idx[2*i]}
                                     : {tmp.idx, stage2_idx[2*i+1]};
      end

      result.vd    = |stage3_vd;
      result.idx   = (stage3_vd[0]) ? {1'b0, stage3_idx[0]} : {1'b1, stage3_idx[1]};
      result.s1idx = {stage1_idx[7], stage1_idx[6], stage1_idx[5], stage1_idx[4],
                      stage1_idx[3], stage1_idx[2], stage1_idx[1], stage1_idx[0]};
      result.s2idx = {stage2_idx[3], stage2_idx[2], stage2_idx[1], stage2_idx[0]};
      result.s3idx = {stage3_idx[1], stage3_idx[0]};
      return result;
  end
  endfunction

  res_t r;
  always_comb r = search_one_16(din);
  assign vd    = r.vd;
  assign idx   = r.idx;
  assign s1idx = r.s1idx;
  assign s2idx = r.s2idx;
  assign s3idx = r.s3idx;
endmodule
