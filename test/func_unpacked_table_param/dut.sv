// A MULTI-dim unpacked localparam built by a constant FUNCTION (common_cells
// sub_per_hash: `localparam perm_lists_t PERMUTATIONS = get_permutations(Key)`,
// `int unsigned [R][W]`).  Unpatched read_uhdm kept the evaluator's element order
// (element 0 at the LSB) where every read of the parameter expects element 0 of an
// ascending dimension at the MSB, so each PERM[0][i] read the mirrored entry.
module dut #(parameter int unsigned NoRounds = 1, parameter int unsigned InpWidth = 11)
  (output logic [3:0] p [11], output logic [3:0] q [11]);
  typedef int unsigned perm_lists_t [NoRounds][InpWidth];
  function automatic perm_lists_t get_permutations(input int unsigned seed);
    perm_lists_t indices;
    perm_lists_t perm_array;
    longint unsigned A = 2147483629;
    longint unsigned C = 2147483587;
    longint unsigned M = 2**31 - 1;
    longint unsigned index   = 0;
    longint unsigned advance = 0;
    longint unsigned rand_number = (A * seed + C) % M;
    for (int unsigned r = 0; r < NoRounds; r++) begin
      for (int unsigned i = 0; i < InpWidth; i++) begin
        indices[r][i] = i;
      end
      for (int unsigned i = 0; i < InpWidth; i++) begin
        if (i > 0) begin
          rand_number = (A * rand_number + C) % M;
          index = rand_number % i;
        end
        if (i != index) begin
          perm_array[r][i]     = perm_array[r][index];
          perm_array[r][index] = indices[r][i];
        end
      end
    end
    return perm_array;
  endfunction
  function automatic perm_lists_t get_idx(input int unsigned seed);
    perm_lists_t a;
    for (int unsigned i = 0; i < InpWidth; i++) a[0][i] = (i * 3 + seed) % InpWidth;
    return a;
  endfunction
  localparam perm_lists_t PERM = get_permutations(299034753);
  localparam perm_lists_t IDX = get_idx(1);
  for (genvar i = 0; i < 11; i++) begin : g
    assign p[i] = PERM[0][i];
    assign q[i] = IDX[0][i];
  end
endmodule
