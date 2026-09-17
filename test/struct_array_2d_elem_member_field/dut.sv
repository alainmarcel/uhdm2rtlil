// `s.arr[i][j].sub.f` — a member of an element of a MULTI-dimensional packed
// array of structs, itself a field of a struct.  Path_elems is
// [ref_obj(s), var_select(arr, i, j), ref_obj(sub), ref_obj(f)]: the
// `s.arr[i].sub.f` handler accepted only the single-index bit_select, so every
// two-index access fell through to "Could not resolve struct member access"
// and was read as X / written nowhere.
//
// Caliptra's key/PCR/data vaults drive their register block exactly this way,
//     kv_reg_hwif_in.KEY_ENTRY[entry][dword].data.we   = ...;
//     kv_reg_hwif_in.KEY_ENTRY[entry][dword].data.next = ...;
// so all 384 KEY_ENTRY write-enables and next-values were undriven and the
// vault never stored a key (1536 dropped writes in kv alone).
//
// The kv read mux adds a third shape — a NAMED trailing bit_select on the
// final member, `KEY_CTRL[entry].dest_valid.value[client]` — which the same
// handler now applies to the member slice (`ctrl_o` below).
//
// `hwif_in` is an output, so a dropped write is a stuck-at-zero field; the
// XOR-reduction of `hwif_out` reads (constant indexes from the unrolled loops
// plus one DYNAMIC element read) keeps every element observable.
typedef struct packed { logic we; logic [7:0] next; logic hwclr; } data_in_t;
typedef struct packed { data_in_t data; }                          entry_in_t;
typedef struct packed { entry_in_t [3:0][1:0] ENTRY; logic misc; } in_t;
typedef struct packed { logic [7:0] value; }                       data_out_t;
typedef struct packed { data_out_t data; }                         entry_out_t;
typedef struct packed { logic [3:0] value; }                       dv_out_t;
typedef struct packed { dv_out_t dv; }                             ctrl_out_t;
typedef struct packed { entry_out_t [3:0][1:0] ENTRY;
                        ctrl_out_t  [3:0]      CTRL; }             out_t;

module dut (
  input  logic [3:0] we_i,
  input  logic [1:0] sel_i,
  input  logic [1:0] esel_i,
  input  logic       dsel_i,
  input  logic [1:0] csel_i,
  input  logic [3:0] cen_i,
  input  logic [7:0] d_i,
  input  out_t       hwif_out,
  output in_t        hwif_in,
  output logic [7:0] rd_o,
  output logic [7:0] dyn_o,
  output logic [3:0] ctrl_o,
  output logic       ctrl_dyn_o
);
  always_comb begin
    hwif_in = '0;
    rd_o = '0;
    for (int e = 0; e < 4; e++) begin
      for (int d = 0; d < 2; d++) begin
        hwif_in.ENTRY[e][d].data.we    = we_i[e] & (sel_i[0] == d);
        hwif_in.ENTRY[e][d].data.next  = d_i + e + d;
        hwif_in.ENTRY[e][d].data.hwclr = sel_i[1];
        rd_o = rd_o ^ hwif_out.ENTRY[e][d].data.value;
      end
    end
    hwif_in.misc = sel_i[0];
    // Trailing member bit-select, constant index after unrolling.
    ctrl_o = '0;
    for (int e = 0; e < 4; e++)
      for (int c = 0; c < 4; c++)
        ctrl_o[e] = ctrl_o[e] ^ (hwif_out.CTRL[e].dv.value[c] & cen_i[c]);
  end
  // Dynamic element index AND dynamic trailing bit index.
  always_comb ctrl_dyn_o = hwif_out.CTRL[esel_i].dv.value[csel_i];
  // DYNAMIC two-index element read.
  always_comb dyn_o = hwif_out.ENTRY[esel_i][dsel_i].data.value;
endmodule
