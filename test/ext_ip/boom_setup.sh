#!/bin/bash
# BOOM (riscv-boom/riscv-boom) Verilog through the LOCAL rocket-chip mill build.
#
# BOOM is a Chisel LIBRARY, not a generator: it has no elaboration target and
# no usable config, and three separate things block the obvious routes.
#
#  * Its own `build.sc` resolves rocketchip / cde / hardfloat / diplomacy as
#    `1.6-snapshot` ivy artifacts, and those are NOT published on Maven
#    Central -- `mill boom.compile` fails on all three.  Chipyard gets them
#    from a local `publishLocal`.  So BOOM is compiled as an extra module
#    INSIDE the rocket-chip checkout, which the rocket family already clones
#    with its dependency submodules and already elaborates.
#  * rocket-chip pins scala 2.13.12 / chisel 6.7.0 and BOOM pins 2.13.14 /
#    6.5.0.  Both are binary compatible, and one build has to pick one pair:
#    this uses rocket-chip's, since the rocketchip module is the dependency.
#  * Every BOOM core mixin takes a defaulted argument
#    (`WithNLargeBooms(n: Int = 1)`), which is NOT a no-argument constructor,
#    and rocket-chip's generator instantiates each `--config` by reflection.
#    boom_harness/boomsweep/BoomSweepConfigs.scala owns the no-arg wrappers.
#
# The generator is rocket-chip's own: run the assembly jar with --top and one
# --config per class, then lower the CHIRRTL with firtool --split-verilog,
# exactly as rocket-chip's `emulator[...].mfccompiler.compile` does.
set -e
ROOT=$PWD                              # the riscv-boom checkout ($EXT_IP_ROOT/riscv-boom)
ROCKET=${ROCKET_DIR:-$(cd "$ROOT/../rocket-chip" && pwd)}
HARNESS=${BOOM_HARNESS:-$(cd "$(dirname "$0")/boom_harness" && pwd)}
TOOLS=${ROCKET_TOOLS:-$HOME/ext/tools}
FIRTOOL_VERSION=1.162.0
CONFIG=${BOOM_CONFIG:-boomsweep.LargeBoomV4Config}
TOP=${BOOM_TOP:-freechips.rocketchip.system.TestHarness}
OUT=$ROOT/boom_sv

export PATH="$TOOLS/bin:$TOOLS/firtool-$FIRTOOL_VERSION/bin:$PATH"
[ -d "$ROCKET" ] || { echo "boom_setup: no rocket-chip checkout at $ROCKET" >&2; exit 2; }
command -v mill    >/dev/null || { echo "boom_setup: mill missing -- run rocket_setup.sh first" >&2; exit 2; }
command -v firtool >/dev/null || { echo "boom_setup: firtool missing -- run rocket_setup.sh first" >&2; exit 2; }
command -v dtc     >/dev/null || { echo "boom_setup: dtc missing -- run rocket_setup.sh first" >&2; exit 2; }

cd "$ROCKET"
git submodule update --init --recursive --depth 1 2>/dev/null || git submodule update --init --recursive
# firtool >= 1.5x has no `-dedup`; the checked-in build.sc still passes it.
sed -i '/^        "-dedup",$/d' build.sc

# Append the BOOM modules to rocket-chip's build ONCE.  `boom` compiles the
# BOOM sources plus the harness configs against the local rocketchip module;
# `boomemu` exists only for its assembly jar, which is what the generator runs.
if ! grep -q 'object boomemu' build.sc; then
  cat >> build.sc <<EOF

// ---- added by uhdm2rtlil test/ext_ip/boom_setup.sh ----
object boom extends ScalaModule {
  override def millSourcePath = os.Path("$ROOT")
  def scalaVersion = T(v.scala)
  // ONLY the v4 tree.  BOOM v3's common/ imports a \`pmu\` package
  // (CanHavePMUEvents, PMUParams, PMURegistry, PMUScopeKey, PMUTileLink) that
  // lives in chipyard, not in this repository and not in rocket-chip: all 19
  // compile errors of a whole-tree build come from those seven v3 files, and
  // v4 produces only warnings.  v4 is self-contained (its own util/, ifu/,
  // exu/, lsu/, common/), so the family elaborates the v4 cores.
  override def sources = T.sources(
    os.Path("$ROOT") / "src" / "main" / "scala" / "v4",
    os.Path("$HARNESS"))
  override def resources = T.sources(os.Path("$ROOT") / "src" / "main" / "resources")
  override def moduleDeps = Seq(rocketchip(v.chiselCrossVersions.keys.head))
  override def ivyDeps = Agg(v.chiselCrossVersions.values.head._1)
  override def scalacPluginIvyDeps = Agg(v.chiselCrossVersions.values.head._2)
  override def scalacOptions = Seq(
    "-language:reflectiveCalls",
    "-Ymacro-annotations",
    "-P:chiselplugin:genBundleElements")
}

object boomemu extends ScalaModule {
  def scalaVersion = T(v.scala)
  override def moduleDeps = Seq(boom)
  override def ivyDeps = Agg(v.chiselCrossVersions.values.head._1, v.mainargs)
  override def scalacPluginIvyDeps = Agg(v.chiselCrossVersions.values.head._2)
  // The SAME entry point rocket-chip's own rocketchip module declares
  // (common.sc: freechips.rocketchip.diplomacy.Main) -- it is the generator
  // that takes --dir / --top / --config and writes CHIRRTL plus the
  // annotation file.  Without it the assembly jar has no Main-Class and java
  // reports "no main manifest attribute".
  override def mainClass = T(Some("freechips.rocketchip.diplomacy.Main"))
}
EOF
fi

mill boomemu.assembly
# `mill show` prints the PathRef as "v0:<hash>:/abs/path" (and older mill as
# "ref:/abs/path"); strip whichever prefix is there or java sees a path that
# starts with the hash and reports "Unable to access jarfile".
JAR=$(mill show boomemu.assembly | tr -d '"' | sed -E 's@^(ref:)?v[0-9]+:[0-9a-f]+:@@; s@^ref:@@')

rm -rf "$OUT"; mkdir -p "$OUT/chirrtl"
java -jar "$JAR" --dir "$OUT/chirrtl" --top "$TOP" \
     $(printf -- '--config %s ' $(echo "$CONFIG" | tr '_' ' '))

FIR=$(ls "$OUT"/chirrtl/*.fir | head -1)
ANNO=$(ls "$OUT"/chirrtl/*anno.json | head -1)
firtool "$FIR" --annotation-file="$ANNO" --disable-annotation-unknown \
        -O=debug --split-verilog --preserve-values=named \
        --output-annotation-file=mfc.anno.json -o="$OUT/sv"
ls "$OUT"/sv/*.sv 2>/dev/null | wc -l
