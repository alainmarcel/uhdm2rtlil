// Gemmini instruments itself with TWO symbols from FireSim's annotation
// library, `midas.targetutils`, which lives in firesim and is pulled in by
// chipyard -- not by rocket-chip and not by Gemmini's own dependencies.  All
// 38 errors of a bare Gemmini compile are those two imports and their call
// sites; there is NOT ONE Chisel-version error, even though Gemmini's
// build.sbt pins chisel3 3.6.0 against the rocket-chip checkout's 6.7.0.
//
// Both symbols are pure INSTRUMENTATION for FPGA-accelerated simulation and
// carry no hardware: PerfCounter emits a FIRRTL annotation that FireSim turns
// into a counter in its own instrumentation harness, and SynthesizePrintf
// marks a printf for synthesis into that harness.  For a synthesis sweep the
// right behaviour is exactly a no-op, so the shim gives PerfCounter an empty
// body and SynthesizePrintf the plain Printable its format and arguments
// describe -- which is what `printf(SynthesizePrintf(...))` needs its result
// to be.
//
// This keeps the family free of a chipyard / firesim checkout.  If Gemmini is
// ever swept WITH FireSim instrumentation, drop this directory and put the
// real firesim module on the classpath instead.
package midas.targetutils

import chisel3._

object PerfCounter {
  def apply(target: Bool, name: String, description: String): Unit = ()
  def apply(target: UInt, name: String, description: String): Unit = ()
}

object SynthesizePrintf {
  def apply(format: String, args: Bits*): Printable = Printable.pack(format, args: _*)
  def apply(pable: Printable): Printable = pable
  def apply(name: String, format: String, args: Bits*): Printable =
    Printable.pack(format, args: _*)
}
