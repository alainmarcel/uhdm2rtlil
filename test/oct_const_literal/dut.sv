// OCTAL-based literals.  Surelog stores `3'o7` as `OCT:7` with
// vpiConstType 4 (vpiOctConst), and import_constant handled NO octal constant
// at all -- it warned "Unsupported constant type: 4" and returned all-X, so
// every octal literal in every design read as X.
//
// OpenPiton's OpenSPARC FPU writes its pipeline-ID decode entirely in octal:
//     {(m5stg_id[4:2]==3'o7), ..., (m5stg_id[4:2]==3'o0)}
// All eight comparisons therefore compared against the same X, and fpu_add,
// fpu_add_ctl, fpu_mul and fpu_mul_ctl diverged on 853 co-simulated cycles
// between them -- read_slang clean on all four.
module dut(input  logic [4:0] id,
           output logic [7:0] dec,
           output logic [2:0] o7,
           output logic [5:0] w6,
           output logic [3:0] trunc,
           output logic [7:0] wide);
  // the OpenPiton shape: a one-hot decode written as octal comparisons
  assign dec = {(id[4:2] == 3'o7), (id[4:2] == 3'o6),
                (id[4:2] == 3'o5), (id[4:2] == 3'o4),
                (id[4:2] == 3'o3), (id[4:2] == 3'o2),
                (id[4:2] == 3'o1), (id[4:2] == 3'o0)};
  assign o7    = 3'o7;
  assign w6    = 6'o52;
  assign trunc = 4'o17;   // five bits of digits TRUNCATED to four
  assign wide  = 8'o7;    // zero-extended
endmodule
