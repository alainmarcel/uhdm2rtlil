/*
 * Module instance handling via ref_module
 */

#include "uhdm2rtlil.h"

YOSYS_NAMESPACE_BEGIN

// Import a module instance from ref_module
void UhdmImporter::import_ref_module(const ref_module* ref_mod) {
    if (!ref_mod) return;
    
    // Get instance name from ref_module
    std::string inst_name = std::string(ref_mod->VpiName());
    
    // Get module name from ref_module
    std::string base_module_name = std::string(ref_mod->VpiDefName());
    
    // Strip work@ prefix if present
    if (base_module_name.find("work@") == 0) {
        base_module_name = base_module_name.substr(5);
    }
    
    // Collect parameters from the ref_module
    std::map<std::string, RTLIL::Const> params;
    
    // Check if the ref_module has an actual_group that contains parameters
    if (ref_mod->Actual_group()) {
        if (mode_debug) {
            log("  Found actual_group, investigating for parameters\n");
            log("  Actual_group UhdmType: %d\n", ref_mod->Actual_group()->UhdmType());
            log("  Actual_group VpiType: %d\n", ref_mod->Actual_group()->VpiType());
        }
        
        // Try to cast to different UHDM types to find parameters
        // actual_group might contain param_assign objects
        try {
            if (auto actual_group = ref_mod->Actual_group()) {
                // Check if it's a param_assign or contains param_assigns
                if (mode_debug) {
                    log("  Investigating actual_group for param_assigns...\n");
                }
            }
        } catch (...) {
            if (mode_debug)
                log("  Exception while investigating actual_group\n");
        }
    }
    
    // For now, create a debug log to see what's happening
    if (mode_debug) {
        log("  Instance: %s, Module: %s, Has Actual_group: %s\n", 
            inst_name.c_str(), base_module_name.c_str(), 
            ref_mod->Actual_group() ? "yes" : "no");
    }
    
    // Try to infer parameter values from connected signal widths
    // Store port connections for later processing
    std::vector<std::pair<std::string, const any*>> port_connections;
    
    // We'll generate the module name after inferring parameters
    std::string module_name = base_module_name;
    
    if (mode_debug)
        log("  Importing instance: %s of %s\n", inst_name.c_str(), module_name.c_str());
    
    RTLIL::Cell* cell = module->addCell(new_id(inst_name), RTLIL::escape_id(module_name));
    
    // Import port connections from ref_module and infer parameter widths
    int inferred_width = 1; // default
    
    if (ref_mod->Ports()) {
        for (auto port : *ref_mod->Ports()) {
            std::string port_name = std::string(port->VpiName());
            
            // Get the actual connection (high_conn)
            if (port->High_conn()) {
                RTLIL::SigSpec actual_sig = import_expression(static_cast<const expr*>(port->High_conn()));
                cell->setPort(RTLIL::escape_id(port_name), actual_sig);
                
                // Infer width from the first port
                if (inferred_width == 1) {
                    inferred_width = actual_sig.size();
                }
                
                if (mode_debug)
                    log("    Connected port %s (width=%d)\n", port_name.c_str(), actual_sig.size());
            }
        }
    }
    
    // Store parameterization info for later processing 
    if (inferred_width > 1) {
        cell->setParam(RTLIL::escape_id("WIDTH"), RTLIL::Const(inferred_width, 32));
        if (mode_debug)
            log("    Set WIDTH parameter to %d (will create parameterized module later)\n", inferred_width);
    }
}

YOSYS_NAMESPACE_END