// Configs the Gemmini family elaborates.
//
// Gemmini ships its accelerator mixins in `gemmini.Configs`, but not one of
// them can be instantiated by the generator: every one is
// `class LeanGemminiConfig[T <: Data : Arithmetic, U <: Data, V <: Data](
//    gemminiConfig: GemminiArrayConfig[T,U,V] = GemminiConfigs.leanConfig)`,
// i.e. type parameters with a context bound AND a defaulted argument, and the
// generator instantiates each `--config` by reflection
// (`Class.forName(name).newInstance()`).  Gemmini's own `chipyard/` directory
// composes them with `chipyard.config.AbstractConfig`, which needs a chipyard
// checkout; these wrappers compose them with rocket-chip's own DefaultConfig
// instead, so the family needs none.
//
// The system bus is widened to 128 bits for the same reason chipyard's
// GemminiRocketConfig does: the default 16x16 8-bit systolic array moves 16
// bytes per beat, and the 8-byte default bus cannot carry it.
package gemminisweep

import org.chipsalliance.cde.config.Config
import freechips.rocketchip.subsystem.SystemBusKey

class WithGemminiSystemBusWidth(bits: Int) extends Config((site, here, up) => {
  case SystemBusKey => up(SystemBusKey, site).copy(beatBytes = bits / 8)
})

// The full default accelerator: 16x16 8-bit systolic array with its
// scratchpad, accumulator, DMA, TLB, reservation station and loop unrollers.
class GemminiRocketConfig extends Config(
  new gemmini.DefaultGemminiConfig ++
  new WithGemminiSystemBusWidth(128) ++
  new freechips.rocketchip.system.DefaultConfig)

// The lean variant: the same array without the loop-unroller extras, which is
// what chipyard's own CI builds.
class LeanGemminiRocketConfig extends Config(
  new gemmini.LeanGemminiConfig ++
  new WithGemminiSystemBusWidth(128) ++
  new freechips.rocketchip.system.DefaultConfig)
