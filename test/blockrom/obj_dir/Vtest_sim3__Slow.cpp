// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtest_sim3.h for the primary calling header

#include "Vtest_sim3.h"
#include "Vtest_sim3__Syms.h"

//==========

VL_CTOR_IMP(Vtest_sim3) {
    Vtest_sim3__Syms* __restrict vlSymsp = __VlSymsp = new Vtest_sim3__Syms(this, name());
    Vtest_sim3* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Reset internal values
    
    // Reset structure values
    _ctor_var_reset();
}

void Vtest_sim3::__Vconfigure(Vtest_sim3__Syms* vlSymsp, bool first) {
    if (false && first) {}  // Prevent unused
    this->__VlSymsp = vlSymsp;
    if (false && this->__VlSymsp) {}  // Prevent unused
    Verilated::timeunit(-12);
    Verilated::timeprecision(-12);
}

Vtest_sim3::~Vtest_sim3() {
    VL_DO_CLEAR(delete __VlSymsp, __VlSymsp = NULL);
}

void Vtest_sim3::_initial__TOP__1(Vtest_sim3__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim3::_initial__TOP__1\n"); );
    Vtest_sim3* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    VL_WRITEF("j after assignment = 0x27865242\n");
    vlTOPp->test_sim3__DOT__memory[0U] = 0x7aU;
    VL_WRITEF("memory[0] = 0x%02x (j = 0x27865242)\n",
              8,vlTOPp->test_sim3__DOT__memory[0U]);
    vlTOPp->test_sim3__DOT__memory[1U] = 0xc2U;
    VL_WRITEF("memory[1] = 0x%02x (j = 0x69842a2a)\n",
              8,vlTOPp->test_sim3__DOT__memory[1U]);
    vlTOPp->test_sim3__DOT__memory[2U] = 0x63U;
    VL_WRITEF("memory[2] = 0x%02x (j = 0xb982b27f)\n",
              8,vlTOPp->test_sim3__DOT__memory[2U]);
    vlTOPp->test_sim3__DOT__memory[3U] = 0xbeU;
    VL_WRITEF("memory[3] = 0x%02x (j = 0x11892a56)\n",
              8,vlTOPp->test_sim3__DOT__memory[3U]);
    vlTOPp->test_sim3__DOT__memory[4U] = 0x5bU;
    VL_WRITEF("memory[4] = 0x%02x (j = 0x998832d7)\n",
              8,vlTOPp->test_sim3__DOT__memory[4U]);
    vlTOPp->test_sim3__DOT__memory[5U] = 0x4aU;
    VL_WRITEF("memory[5] = 0x%02x (j = 0x3181aa52)\n",
              8,vlTOPp->test_sim3__DOT__memory[5U]);
    vlTOPp->test_sim3__DOT__memory[6U] = 0x6cU;
    VL_WRITEF("memory[6] = 0x%02x (j = 0xa182b25c)\n",
              8,vlTOPp->test_sim3__DOT__memory[6U]);
    vlTOPp->test_sim3__DOT__memory[7U] = 0x46U;
    VL_WRITEF("memory[7] = 0x%02x (j = 0x4f88aa7e)\n",
              8,vlTOPp->test_sim3__DOT__memory[7U]);
    VL_FINISH_MT("test_sim3.sv", 19, "");
}

void Vtest_sim3::_eval_initial(Vtest_sim3__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim3::_eval_initial\n"); );
    Vtest_sim3* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->_initial__TOP__1(vlSymsp);
}

void Vtest_sim3::final() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim3::final\n"); );
    // Variables
    Vtest_sim3__Syms* __restrict vlSymsp = this->__VlSymsp;
    Vtest_sim3* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void Vtest_sim3::_eval_settle(Vtest_sim3__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim3::_eval_settle\n"); );
    Vtest_sim3* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void Vtest_sim3::_ctor_var_reset() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim3::_ctor_var_reset\n"); );
    // Body
    { int __Vi0=0; for (; __Vi0<8; ++__Vi0) {
            test_sim3__DOT__memory[__Vi0] = VL_RAND_RESET_I(8);
    }}
}
