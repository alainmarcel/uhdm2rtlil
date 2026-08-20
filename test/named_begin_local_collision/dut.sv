// The SAME named begin block appearing in SEVERAL always blocks of one module,
// each with its own block-local.  CVA6's fpnew_cast_multi has three
// `begin : special_results`, each declaring `special_res`.
//
// All three block-locals were named `\special_results.special_res`, so the
// second addWire aborted yosys outright:
//     Assert `count_id(wire->name) == 0' failed
// Reusing the wire instead would be worse than the crash: two unrelated
// block-locals would MERGE into one net, silently tying the blocks together.
module dut (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       sel,
    output logic [3:0] x,
    output logic [3:0] y,
    output logic [3:0] z
);
  always_comb begin : blk_x
    begin : special_results
      logic [3:0] special_res;
      special_res = a & b;
      x = special_res;
    end
  end

  always_comb begin : blk_y
    begin : special_results
      logic [3:0] special_res;
      special_res = a | b;
      y = special_res;
    end
  end

  always_comb begin : blk_z
    begin : special_results
      logic [3:0] special_res;
      special_res = sel ? a : b;
      z = special_res;
    end
  end
endmodule
