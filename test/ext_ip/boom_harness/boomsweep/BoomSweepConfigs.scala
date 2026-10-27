// Configs the BOOM family elaborates.  BOOM itself ships none that can be
// used: every core mixin is `class WithNLargeBooms(n: Int = 1)`, and a Scala
// default argument does NOT produce a no-argument constructor, so the
// reflection-based config loader in rocket-chip's generator (it does
// `Class.forName(name).newInstance()` per `--config`) cannot instantiate one.
// Chipyard owns equivalent wrappers for the same reason; this file is the
// harness's own minimal copy, so the family needs no chipyard checkout.
package boomsweep

import org.chipsalliance.cde.config.Config

class SmallBoomV4Config extends Config(
  new boom.v4.common.WithNSmallBooms(1) ++
  new freechips.rocketchip.system.DefaultConfig)

class MediumBoomV4Config extends Config(
  new boom.v4.common.WithNMediumBooms(1) ++
  new freechips.rocketchip.system.DefaultConfig)

class LargeBoomV4Config extends Config(
  new boom.v4.common.WithNLargeBooms(1) ++
  new freechips.rocketchip.system.DefaultConfig)

// No V3 config: BOOM v3's common/ imports a chipyard-only `pmu` package, so
// the v3 tree is not compiled (see boom_setup.sh).
