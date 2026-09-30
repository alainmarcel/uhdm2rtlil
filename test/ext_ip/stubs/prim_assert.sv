// Synthesis-style stand-in for lowRISC's `prim_assert.sv`.
//
// 14 caliptra-ss files (src/ast/rtl/*, src/pwrmgr/rtl/*, src/tlul/rtl/
// tlul_adapter_dmi.sv ...) are vendored from OpenTitan and open with
// `include "prim_assert.sv"`, but the header itself was NOT vendored -- it is
// not anywhere in the repository.  A real build gets it from the lowrisc_ip
// dependency; the sweep has only the caliptra-ss checkout, so read_slang
// stopped at the missing include ("'prim_assert.sv': No such file or
// directory") and the module was recorded as a design read_slang cannot read.
// Surelog merely warns and carries on, which is worse: it reads the module with
// every `ASSERT* macro unresolved and says nothing.
//
// The upstream header reduces every macro to nothing when the design is
// compiled for synthesis (`SYNTHESIS`, which this sweep defines) -- and the
// sweep additionally passes read_slang `--ignore-assertions` -- so no-op
// definitions are what a synthesis build of these files compiles.  Only the
// macros those files actually use are defined, with the upstream arity, so a
// file that reaches for anything else still fails loudly instead of silently
// compiling something different from what the reference tools see.
`ifndef PRIM_ASSERT_SV
`define PRIM_ASSERT_SV

`define ASSERT_DEFAULT_CLK clk_i
`define ASSERT_DEFAULT_RST !rst_ni

`define ASSERT(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
`define ASSERT_I(__name, __prop)
`define ASSERT_INIT(__name, __prop)
`define ASSERT_INIT_NET(__name, __prop)
`define ASSERT_FINAL(__name, __prop)
`define ASSERT_NEVER(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
`define ASSERT_KNOWN(__name, __sig, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
`define ASSERT_KNOWN_IF(__name, __sig, __enable, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
`define ASSERT_IF(__name, __prop, __enable, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
`define ASSERT_PULSE(__name, __sig, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
`define ASSUME(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
`define ASSUME_I(__name, __prop)
`define COVER(__name, __prop, __clk = `ASSERT_DEFAULT_CLK, __rst = `ASSERT_DEFAULT_RST)
`define ASSERT_PRIM_FSM_ERROR_TRIGGER_ERR(NAME_, HIER_, ERR_, GATE_ = 0, MAX_CYCLES_ = 2, CLK_ = clk_i, RST_ = !rst_ni)
`define ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ERR(NAME_, REG_TOP_HIER_, ERR_, GATE_ = 0, MAX_CYCLES_ = 7, CLK_ = clk_i, RST_ = !rst_ni)
`define ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ALERT(NAME_, REG_TOP_HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = 7)
`define ASSERT_PRIM_COUNT_ERROR_TRIGGER_ALERT(NAME_, HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = 7, ERR_NAME_ = err_o)
`define ASSERT_PRIM_DOUBLE_LFSR_ERROR_TRIGGER_ALERT(NAME_, HIER_, ALERT_, GATE_ = 0, MAX_CYCLES_ = 7, ERR_NAME_ = err_o)

`endif // PRIM_ASSERT_SV
