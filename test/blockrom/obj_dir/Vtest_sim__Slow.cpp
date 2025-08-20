// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtest_sim.h for the primary calling header

#include "Vtest_sim.h"
#include "Vtest_sim__Syms.h"

//==========

VL_CTOR_IMP(Vtest_sim) {
    Vtest_sim__Syms* __restrict vlSymsp = __VlSymsp = new Vtest_sim__Syms(this, name());
    Vtest_sim* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Reset internal values
    
    // Reset structure values
    _ctor_var_reset();
}

void Vtest_sim::__Vconfigure(Vtest_sim__Syms* vlSymsp, bool first) {
    if (false && first) {}  // Prevent unused
    this->__VlSymsp = vlSymsp;
    if (false && this->__VlSymsp) {}  // Prevent unused
    Verilated::timeunit(-12);
    Verilated::timeprecision(-12);
}

Vtest_sim::~Vtest_sim() {
    VL_DO_CLEAR(delete __VlSymsp, __VlSymsp = NULL);
}

void Vtest_sim::_initial__TOP__1(Vtest_sim__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim::_initial__TOP__1\n"); );
    Vtest_sim* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->test_sim__DOT__memory[0U] = 0x7aU;
    VL_WRITEF("memory[0] = 0x%02x, j = 0xf4b1ca8127865242\n",
              8,vlTOPp->test_sim__DOT__memory[0U]);
    vlTOPp->test_sim__DOT__memory[1U] = 0x83U;
    VL_WRITEF("memory[1] = 0x%02x, j = 0xcfa1a9d035a1131f\n",
              8,vlTOPp->test_sim__DOT__memory[1U]);
    vlTOPp->test_sim__DOT__memory[2U] = 0xb8U;
    VL_WRITEF("memory[2] = 0x%02x, j = 0x5afc1753eb20a218\n",
              8,vlTOPp->test_sim__DOT__memory[2U]);
    vlTOPp->test_sim__DOT__memory[3U] = 0xd1U;
    VL_WRITEF("memory[3] = 0x%02x, j = 0x7fc584bd42ae8645\n",
              8,vlTOPp->test_sim__DOT__memory[3U]);
    vlTOPp->test_sim__DOT__memory[4U] = 0x6bU;
    VL_WRITEF("memory[4] = 0x%02x, j = 0xb5d08daae96b1b27\n",
              8,vlTOPp->test_sim__DOT__memory[4U]);
    vlTOPp->test_sim__DOT__memory[5U] = 0x81U;
    VL_WRITEF("memory[5] = 0x%02x, j = 0xf1bc5ba7284efab5\n",
              8,vlTOPp->test_sim__DOT__memory[5U]);
    vlTOPp->test_sim__DOT__memory[6U] = 0xe6U;
    VL_WRITEF("memory[6] = 0x%02x, j = 0x34973898b4db6d9e\n",
              8,vlTOPp->test_sim__DOT__memory[6U]);
    vlTOPp->test_sim__DOT__memory[7U] = 0xd1U;
    VL_WRITEF("memory[7] = 0x%02x, j = 0xe2eed1b7308a1545\n",
              8,vlTOPp->test_sim__DOT__memory[7U]);
    VL_FINISH_MT("test_sim.sv", 20, "");
}

void Vtest_sim::_eval_initial(Vtest_sim__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim::_eval_initial\n"); );
    Vtest_sim* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->_initial__TOP__1(vlSymsp);
}

void Vtest_sim::final() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim::final\n"); );
    // Variables
    Vtest_sim__Syms* __restrict vlSymsp = this->__VlSymsp;
    Vtest_sim* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void Vtest_sim::_eval_settle(Vtest_sim__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim::_eval_settle\n"); );
    Vtest_sim* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void Vtest_sim::_ctor_var_reset() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim::_ctor_var_reset\n"); );
    // Body
    { int __Vi0=0; for (; __Vi0<8; ++__Vi0) {
            test_sim__DOT__memory[__Vi0] = VL_RAND_RESET_I(8);
    }}
}
