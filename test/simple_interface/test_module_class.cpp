#include "kernel/yosys.h"
#include "frontends/ast/ast.h"

USING_YOSYS_NAMESPACE

int main(int argc, char **argv) {
    // Initialize Yosys
    Yosys::yosys_setup();

    // Create a design
    Design *design = new Design;

    // Load Verilog with AST frontend
    run_pass("read_verilog -sv dut.sv", design);

    // Check module types
    for (auto &it : design->modules_) {
        Module *mod = it.second;
        log("Module %s:\n", mod->name.c_str());
        log("  Type: %s\n", typeid(*mod).name());
        
        // Check if it's an AstModule
        if (dynamic_cast<AST::AstModule*>(mod)) {
            log("  Is AstModule: YES\n");
        } else {
            log("  Is AstModule: NO\n");
        }
        
        // Check attributes
        if (mod->has_attribute(ID::dynports)) {
            log("  Has dynports: YES\n");
        }
        if (!mod->avail_parameters.empty()) {
            log("  Has parameters: YES (%d)\n", (int)mod->avail_parameters.size());
        }
    }
    
    // Try hierarchy pass
    log("\nRunning hierarchy pass...\n");
    run_pass("hierarchy -check -top simple_interface", design);
    
    log("\nModules after hierarchy:\n");
    for (auto &it : design->modules_) {
        log("  %s\n", it.first.c_str());
    }

    delete design;
    Yosys::yosys_shutdown();
    return 0;
}