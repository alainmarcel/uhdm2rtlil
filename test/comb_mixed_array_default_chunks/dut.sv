// always_comb: whole-array default on a MIXED unpacked array (flat wire +
// per-element alias wires) followed by conditional indexed-part-select
// writes into its elements inside unrolled for loops (keccak_round storage_d).
// Every element/chunk write must fold onto the ONE `$0\sd` temp — a
// per-element temp double-drove the alias against the flat's update.
module comb_mixed_array_default_chunks #(
  parameter int W = 64,
  localparam int DIN = 16,
  localparam int ENT = W / DIN,
  localparam int S = 2
) (
  input  logic [S*W-1:0]          ko_f,
  input  logic [S*W-1:0]          stg_f,
  input  logic [S*DIN-1:0]        data_f,
  input  logic [$clog2(ENT)-1:0]  addr,
  input  logic                    xm,
  input  logic                    sel,
  output logic [S*W-1:0]          o_f,
  output logic [W-1:0]            r
);
  logic [W-1:0]   ko  [S];
  logic [W-1:0]   stg [S];
  logic [DIN-1:0] data[S];
  logic [W-1:0]   sd  [S];

  for (genvar g = 0; g < S; g++) begin : g_unpack
    assign ko[g]   = ko_f[g*W +: W];
    assign stg[g]  = stg_f[g*W +: W];
    assign data[g] = data_f[g*DIN +: DIN];
    assign o_f[g*W +: W] = sd[g];
  end

  always_comb begin
    sd = ko;                                   // whole-array default
    if (xm) begin
      for (int j = 0; j < S; j++)
        for (int unsigned i = 0; i < ENT; i++)
          if (addr == i[$clog2(ENT)-1:0])
            sd[j][i*DIN +: DIN] = stg[j][i*DIN +: DIN] ^ data[j];
          else
            sd[j][i*DIN +: DIN] = stg[j][i*DIN +: DIN];
    end
    // whole-element write + read-after-write in the same block
    if (sel) sd[1] = ~ko[0];
    r = sd[0] ^ sd[1];
  end

endmodule
