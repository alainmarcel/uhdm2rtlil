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
    
    // Collect parameters from the actual module instance
    std::map<std::string, RTLIL::Const> params;
    
    // Get the actual module instance that has parameter information
    if (ref_mod->Actual_group()) {
        if (auto actual_module = dynamic_cast<const module_inst*>(ref_mod->Actual_group())) {
            if (mode_debug) {
                log("  Found actual module instance with parameters\n");
            }
            
            // Extract parameters from Param_assigns
            if (actual_module->Param_assigns()) {
                for (auto param_assign : *actual_module->Param_assigns()) {
                    if (param_assign->Lhs() && param_assign->Rhs()) {
                        std::string param_name;
                        
                        // Get parameter name from LHS
                        if (auto param = dynamic_cast<const parameter*>(param_assign->Lhs())) {
                            param_name = std::string(param->VpiName());
                        }
                        
                        // Get parameter value from RHS
                        if (!param_name.empty()) {
                            if (auto const_val = dynamic_cast<const constant*>(param_assign->Rhs())) {
                                // Get the actual integer value
                                int value = 0;
                                if (const_val->VpiConstType() == vpiUIntConst || const_val->VpiConstType() == vpiIntConst) {
                                    // Use VpiDecompile which contains the actual value
                                    std::string val_str = std::string(const_val->VpiDecompile());
                                    if (!val_str.empty()) {
                                        value = std::stoi(val_str);
                                    }
                                }
                                
                                params[param_name] = RTLIL::Const(value, 32);
                                if (mode_debug) {
                                    log("    Found parameter %s = %d\n", param_name.c_str(), value);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    if (mode_debug)
        log("  Importing instance: %s of %s\n", inst_name.c_str(), base_module_name.c_str());
    
    // Create the cell with base module name
    RTLIL::Cell* cell = module->addCell(RTLIL::escape_id(inst_name), RTLIL::escape_id(base_module_name));
    
    // Add module_not_derived attribute
    cell->attributes[RTLIL::escape_id("module_not_derived")] = RTLIL::Const(1);
    
    // Add src attribute if available
    if (ref_mod->VpiLineNo()) {
        std::string src_attr = ref_mod->VpiFile().data();
        src_attr += ":" + std::to_string(ref_mod->VpiLineNo()) + ":" + std::to_string(ref_mod->VpiColumnNo());
        src_attr += "-" + std::to_string(ref_mod->VpiEndLineNo()) + ":" + std::to_string(ref_mod->VpiEndColumnNo());
        cell->attributes[RTLIL::escape_id("src")] = RTLIL::Const(src_attr);
    }
    
    // Set parameters on the cell
    for (const auto& [param_name, param_value] : params) {
        // Mark parameters as signed to match Verilog output
        RTLIL::Const signed_value = param_value;
        signed_value.flags |= RTLIL::CONST_FLAG_SIGNED;
        cell->setParam(RTLIL::escape_id(param_name), signed_value);
    }
    
    // Import port connections from ref_module and infer parameter widths
    int inferred_width = 1; // default
    
    if (ref_mod->Ports()) {
        for (auto port : *ref_mod->Ports()) {
            std::string port_name = std::string(port->VpiName());
            
            // Get the actual connection (high_conn)
            if (port->High_conn()) {
                // First, check if the target port is an interface port by looking at the module definition
                RTLIL::Module* target_module = design->module(RTLIL::escape_id(base_module_name));
                if (target_module) {
                    RTLIL::Wire* target_port = target_module->wire(RTLIL::escape_id(port_name));
                    if (target_port && target_port->attributes.count(RTLIL::escape_id("interface_port"))) {
                        if (mode_debug)
                            log("    Skipping interface port connection: %s (marked as interface_port)\n", port_name.c_str());
                        continue;
                    }
                }
                
                // Check if this is an interface port connection
                if (auto ref_obj = dynamic_cast<const UHDM::ref_obj*>(port->High_conn())) {
                    // This is an interface connection
                    std::string interface_name = std::string(ref_obj->VpiName());
                    
                    // Create or get the dummy wire for this interface
                    std::string dummy_wire_name = "$dummywireforinterface\\" + interface_name;
                    RTLIL::Wire* dummy_wire = module->wire(RTLIL::escape_id(dummy_wire_name));
                    if (!dummy_wire) {
                        dummy_wire = module->addWire(RTLIL::escape_id(dummy_wire_name), 1);
                        dummy_wire->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
                        if (mode_debug)
                            log("    Created dummy wire %s for interface connection\n", dummy_wire_name.c_str());
                    }
                    
                    // Connect the port to the dummy wire
                    cell->setPort(RTLIL::escape_id(port_name), dummy_wire);
                    
                    if (mode_debug)
                        log("    Connected interface port %s to %s\n", port_name.c_str(), dummy_wire_name.c_str());
                } else {
                    // Regular port connection
                    RTLIL::SigSpec actual_sig = import_expression(static_cast<const expr*>(port->High_conn()));
                    cell->setPort(RTLIL::escape_id(port_name), actual_sig);
                    
                    if (mode_debug)
                        log("    Connected port %s (width=%d)\n", port_name.c_str(), actual_sig.size());
                }
            }
        }
    }
}

YOSYS_NAMESPACE_END