// Verilated -*- C++ -*-
// DESCRIPTION: main() calling loop, created with Verilator --main

#include "verilated.h"
#include "Vtest_sim2.h"

//======================

Vtest_sim2* topp;

// Requires -DVL_TIME_STAMP64
vluint64_t main_time = 0;
vluint64_t vl_time_stamp64() { return main_time; }

int main(int argc, char** argv, char**) {
    // Setup defaults and parse command line
    Verilated::debug(0);
    Verilated::commandArgs(argc, argv);
    // Construct the Verilated model, from Vtop.h generated from Verilating
    topp = new Vtest_sim2("top");
    // Evaluate initials
    topp->eval();  // Evaluate
    // Simulate until $finish
    while (!Verilated::gotFinish()) {
        // Evaluate model
        topp->eval();
        // Advance time
        ++main_time;
    }
    
    if (!Verilated::gotFinish()) {
        VL_DEBUG_IF(VL_PRINTF("+ Exiting without $finish; no events left\n"););
    }
    
    // Final model cleanup
    topp->final();
    VL_DO_DANGLING(delete topp, topp);
    exit(0);
}
