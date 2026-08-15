// CVA6 cva6_tlb match_vmid repro: `'{default: V}` assigned to a PACKED
// VECTOR replicates V into EVERY element (1-bit elements for a plain
// vector) — `logic [3:0] m = '{default: 1}` is 4'b1111, not 4'b0001.
// The importer's default-pattern handler only filled struct/union members;
// vector targets fell through to the generic loop and got the literal value
// (match_vmid = RVH ? '{default:0} : '{default:1} came out 4'b0001, so
// 3 of 4 TLB ways could never match).
module pattern_default_packed #(
  parameter bit RVH = 1'b0
)(
  input  logic       sel,
  output logic [3:0] m_param,
  output logic [3:0] m_dyn,
  output logic [3:0] m_plain
);
  always_comb begin
    m_param = RVH ? '{default: 0} : '{default: 1};
    m_dyn   = sel ? '{default: 0} : '{default: 1};
    m_plain = '{default: 1};
  end
endmodule
