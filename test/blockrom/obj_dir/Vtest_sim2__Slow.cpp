// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtest_sim2.h for the primary calling header

#include "Vtest_sim2.h"
#include "Vtest_sim2__Syms.h"

//==========

VL_CTOR_IMP(Vtest_sim2) {
    Vtest_sim2__Syms* __restrict vlSymsp = __VlSymsp = new Vtest_sim2__Syms(this, name());
    Vtest_sim2* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Reset internal values
    
    // Reset structure values
    _ctor_var_reset();
}

void Vtest_sim2::__Vconfigure(Vtest_sim2__Syms* vlSymsp, bool first) {
    if (false && first) {}  // Prevent unused
    this->__VlSymsp = vlSymsp;
    if (false && this->__VlSymsp) {}  // Prevent unused
    Verilated::timeunit(-12);
    Verilated::timeprecision(-12);
}

Vtest_sim2::~Vtest_sim2() {
    VL_DO_CLEAR(delete __VlSymsp, __VlSymsp = NULL);
}

void Vtest_sim2::_initial__TOP__1(Vtest_sim2__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim2::_initial__TOP__1\n"); );
    Vtest_sim2* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    VL_WRITEF("j after assignment = 0x27865242\n");
    VL_FINISH_MT("test_sim2.sv", 7, "");
}

void Vtest_sim2::_eval_initial(Vtest_sim2__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim2::_eval_initial\n"); );
    Vtest_sim2* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
    // Body
    vlTOPp->_initial__TOP__1(vlSymsp);
}

void Vtest_sim2::final() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim2::final\n"); );
    // Variables
    Vtest_sim2__Syms* __restrict vlSymsp = this->__VlSymsp;
    Vtest_sim2* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void Vtest_sim2::_eval_settle(Vtest_sim2__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim2::_eval_settle\n"); );
    Vtest_sim2* const __restrict vlTOPp VL_ATTR_UNUSED = vlSymsp->TOPp;
}

void Vtest_sim2::_ctor_var_reset() {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtest_sim2::_ctor_var_reset\n"); );
}
