// RSD's microarchitecture configuration, as a SOURCE file instead of a set of
// command-line defines.
//
// Why this exists: the manifest's "defines" key reaches Surelog and read_slang
// only.  netlist_cosim.py builds the RTL side of the co-simulation with a
// hardcoded `-DSYNTHESIS` and has no way to take any others, so a design whose
// SHAPE is decided by defines gets a netlist built one way and an RTL
// reference built another -- and BOTH netlists then diverge from it.  That is
// what the first RSD probe reported: Decoder `⚠ shared div (uhdm=301,
// slang=301)`, read_slang diverging from the RTL exactly as much as we do,
// which is the signature of comparing against a differently-configured design
// rather than of a reader bug.
//
// Compiled first (manifest "harness_srcs"), it reaches the netlist side and
// the Verilator RTL side alike, because both read the same srcs.txt.  The
// values are RSD's own defaults from Processor/Src/Makefiles/CoreSources.inc.mk
// (RSD_SRC_CFG).
`ifndef RSD_MARCH_INT_ISSUE_WIDTH
 `define RSD_MARCH_INT_ISSUE_WIDTH 2
`endif
`ifndef RSD_MARCH_FP_PIPE
 `define RSD_MARCH_FP_PIPE
`endif
`ifndef RSD_ENABLE_ZBA
 `define RSD_ENABLE_ZBA
`endif
`ifndef RSD_ENABLE_ZICOND
 `define RSD_ENABLE_ZICOND
`endif
`ifndef RSD_SYNTHESIS
 `define RSD_SYNTHESIS
`endif
