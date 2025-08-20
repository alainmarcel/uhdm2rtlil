#include "Vtest_sim.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtest_sim* top = new Vtest_sim;
    
    top->eval();
    
    delete top;
    return 0;
}