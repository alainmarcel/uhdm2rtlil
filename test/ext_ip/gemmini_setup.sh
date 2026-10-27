#!/bin/bash
# Gemmini (ucb-bar/gemmini) Verilog through the LOCAL rocket-chip mill build.
#
# Gemmini is a Chisel LIBRARY -- a RoCC accelerator, not a generator -- and it
# is normally built inside chipyard.  Three things stand between the checkout
# and a row, all measured on 2026-10-27:
#
#  * It needs rocket-chip on the classpath and has no elaboration target of its
#    own, so (exactly as test/ext_ip/boom_setup.sh does) it is compiled as an
#    extra module APPENDED to the rocket-chip checkout's build.sc -- the one
#    this family clones alongside and the rocket-chip family already
#    elaborates.  mill, firtool and dtc come from rocket_setup.sh.
#    Gemmini's build.sbt pins chisel3 3.6.0 against rocket-chip's 6.7.0, and
#    that costs NOTHING: a bare compile produces not one Chisel-version error.
#  * All 38 errors of that bare compile are TWO symbols from FireSim's
#    annotation library, `midas.targetutils.PerfCounter` and
#    `.SynthesizePrintf`, which live in firesim and reach Gemmini only through
#    chipyard.  Both are pure instrumentation for FPGA-accelerated simulation
#    and carry no hardware, so gemmini_harness/midas/targetutils/ shims them
#    (a no-op counter, and the plain Printable the printf needs).
#  * Gemmini ships no config the generator can instantiate: every accelerator
#    mixin is `class LeanGemminiConfig[T <: Data : Arithmetic, U, V](
#    gemminiConfig: ... = GemminiConfigs.leanConfig)` -- type parameters with a
#    context bound AND a defaulted argument -- while the generator reflects on
#    each `--config`.  gemmini_harness/gemminisweep/ owns the no-arg wrappers,
#    composed with rocket-chip's DefaultConfig rather than chipyard's
#    AbstractConfig, and widens the system bus to 128 bits because the default
#    16x16 8-bit array moves 16 bytes a beat.
#
# The generator is rocket-chip's own: run the assembly jar with --top and one
# --config per class, then lower the CHIRRTL with firtool --split-verilog.
set -e
ROOT=$PWD                              # the gemmini checkout ($EXT_IP_ROOT/gemmini)
ROCKET=${ROCKET_DIR:-$(cd "$ROOT/../rocket-chip" && pwd)}
HARNESS=${GEMMINI_HARNESS:-$(cd "$(dirname "$0")/gemmini_harness" && pwd)}
TOOLS=${ROCKET_TOOLS:-$HOME/ext/tools}
FIRTOOL_VERSION=1.162.0
CONFIG=${GEMMINI_CONFIG:-gemminisweep.LeanGemminiRocketConfig}
TOP=${GEMMINI_TOP:-freechips.rocketchip.system.TestHarness}
OUT=$ROOT/gemmini_sv

export PATH="$TOOLS/bin:$TOOLS/firtool-$FIRTOOL_VERSION/bin:$PATH"
[ -d "$ROCKET" ] || { echo "gemmini_setup: no rocket-chip checkout at $ROCKET" >&2; exit 2; }
command -v mill    >/dev/null || { echo "gemmini_setup: mill missing -- run rocket_setup.sh first" >&2; exit 2; }
command -v firtool >/dev/null || { echo "gemmini_setup: firtool missing -- run rocket_setup.sh first" >&2; exit 2; }
command -v dtc     >/dev/null || { echo "gemmini_setup: dtc missing -- run rocket_setup.sh first" >&2; exit 2; }

cd "$ROCKET"
git submodule update --init --recursive --depth 1 2>/dev/null || git submodule update --init --recursive
# firtool >= 1.5x has no `-dedup`; the checked-in build.sc still passes it.
sed -i '/^        "-dedup",$/d' build.sc

if ! grep -q 'object gemminiemu' build.sc; then
  cat >> build.sc <<EOF

// ---- added by uhdm2rtlil test/ext_ip/gemmini_setup.sh ----
object gemmini extends ScalaModule {
  override def millSourcePath = os.Path("$ROOT")
  def scalaVersion = T(v.scala)
  override def sources = T.sources(
    os.Path("$ROOT") / "src" / "main" / "scala",
    os.Path("$HARNESS"))
  override def moduleDeps = Seq(rocketchip(v.chiselCrossVersions.keys.head))
  override def ivyDeps = Agg(v.chiselCrossVersions.values.head._1)
  override def scalacPluginIvyDeps = Agg(v.chiselCrossVersions.values.head._2)
  override def scalacOptions = Seq(
    "-language:reflectiveCalls",
    "-Ymacro-annotations",
    "-P:chiselplugin:genBundleElements")
}

object gemminiemu extends ScalaModule {
  def scalaVersion = T(v.scala)
  override def moduleDeps = Seq(gemmini)
  override def ivyDeps = Agg(v.chiselCrossVersions.values.head._1, v.mainargs)
  override def scalacPluginIvyDeps = Agg(v.chiselCrossVersions.values.head._2)
  // The same entry point rocket-chip declares for its own module
  // (common.sc); without it the assembly jar has no Main-Class.
  override def mainClass = T(Some("freechips.rocketchip.diplomacy.Main"))
}
EOF
fi

mill gemminiemu.assembly
# `mill show` prints the PathRef as "v0:<hash>:/abs/path" (older mill as
# "ref:/abs/path"); strip whichever prefix is there or java sees a path that
# starts with the hash and reports "Unable to access jarfile".
JAR=$(mill show gemminiemu.assembly | tr -d '"' | sed -E 's@^(ref:)?v[0-9]+:[0-9a-f]+:@@; s@^ref:@@')

rm -rf "$OUT"; mkdir -p "$OUT/chirrtl"
java -jar "$JAR" --dir "$OUT/chirrtl" --top "$TOP" \
     $(printf -- '--config %s ' $(echo "$CONFIG" | tr '_' ' '))

FIR=$(ls "$OUT"/chirrtl/*.fir | head -1)
ANNO=$(ls "$OUT"/chirrtl/*anno.json | head -1)

# Chisel stamps an EnumComponentAnnotation on every enum-typed signal (457 of
# them here) purely so waveform tooling can name the enumerators; it carries
# no hardware.  Where such a signal is a field of a MEMORY PORT -- Gemmini's
# `Queue6_TagWithIdAndTotalRows`, whose entries hold a `NormCmd` enum --
# firtool models the port differently and cannot resolve the target, and that
# is a HARD error even under --disable-annotation-unknown:
#   error: Unable to resolve target of annotation:
#     {class = "chisel3.experimental.EnumAnnotations$EnumComponentAnnotation",
#      enumTypeName = "gemmini.NormCmd",
#      target = "TestHarness.Queue6_...io_deq_bits_MPORT.tag.addr.norm_cmd"}
# Drop just those -- the enum annotations that point INTO a memory port -- and
# leave every other annotation (DontTouch, BlackBoxInline, Inline, DecodeTable)
# untouched, so the emitted RTL is unchanged.
ANNO_FILTERED="$OUT/chirrtl/filtered.anno.json"
python3 - "$ANNO" "$ANNO_FILTERED" <<'PYEOF'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
a = json.load(open(src))
def drops(x):
    cls = x.get("class", "")
    if "EnumAnnotations$Enum" not in cls:
        return False
    t = x.get("target", "")
    # Both spellings appear: a named read port `io_deq_bits_MPORT` and the
    # bare write port `MPORT`.
    return "MPORT" in t
kept = [x for x in a if not drops(x)]
json.dump(kept, open(dst, "w"))
sys.stderr.write("gemmini_setup: dropped %d of %d annotations (enum metadata on memory ports)\n"
                 % (len(a) - len(kept), len(a)))
PYEOF

firtool "$FIR" --annotation-file="$ANNO_FILTERED" --disable-annotation-unknown \
        -O=debug --split-verilog --preserve-values=named \
        --output-annotation-file=mfc.anno.json -o="$OUT/sv"
ls "$OUT"/sv/*.sv 2>/dev/null | wc -l
