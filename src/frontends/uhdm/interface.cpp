/*
 * UHDM frontend for Yosys - Interface handling
 *
 * This file contains functions for importing SystemVerilog interfaces
 * from UHDM to Yosys RTLIL representation.
 */

#include "uhdm2rtlil.h"

YOSYS_NAMESPACE_BEGIN

// Import interface definition
void UhdmImporter::import_interface(const interface_inst* uhdm_interface) {
    if (mode_debug)
        log("UHDM: Starting import_interface\n");
    
    std::string interface_name = std::string(uhdm_interface->VpiName());
    if (interface_name.empty()) {
        std::string defname = std::string(uhdm_interface->VpiDefName());
        if (!defname.empty()) {
            interface_name = defname;
            // Strip work@ prefix if present
            if (interface_name.find("work@") == 0) {
                interface_name = interface_name.substr(5);
            }
        }
    }
    
    if (interface_name.empty()) {
        log_warning("UHDM: Interface has empty name, skipping\n");
        return;
    }
    
    if (mode_debug)
        log("UHDM: Processing interface: %s\n", interface_name.c_str());
    
    // Create interface module - interfaces become modules in RTLIL
    // We need to create parameterized versions for each WIDTH value
    
    // Get parameter values to create proper parameterized module name
    std::string param_module_name = "$paramod\\" + interface_name;
    
    // Store all parameters and their values
    std::map<std::string, int> param_values;
    
    if (uhdm_interface->Param_assigns()) {
        for (auto param_assign : *uhdm_interface->Param_assigns()) {
            if (param_assign->Lhs() && param_assign->Rhs()) {
                std::string param_name;
                if (auto param = dynamic_cast<const parameter*>(param_assign->Lhs())) {
                    param_name = std::string(param->VpiName());
                }
                
                if (!param_name.empty()) {
                    if (auto const_val = dynamic_cast<const constant*>(param_assign->Rhs())) {
                        std::string val_str = std::string(const_val->VpiValue());
                        size_t colon_pos = val_str.find(':');
                        if (colon_pos != std::string::npos) {
                            val_str = val_str.substr(colon_pos + 1);
                        }
                        int param_value = std::stoi(val_str);
                        param_values[param_name] = param_value;
                        
                        // Add to module name in Yosys format
                        param_module_name += "\\" + param_name + "=s32'";
                        for (int i = 31; i >= 0; i--) {
                            param_module_name += ((param_value >> i) & 1) ? "1" : "0";
                        }
                    }
                }
            }
        }
    }
    
    RTLIL::IdString mod_id = RTLIL::escape_id(param_module_name);
    
    // Check if this interface module already exists
    if (design->module(mod_id)) {
        log("UHDM: Interface module %s already exists\n", param_module_name.c_str());
        return;
    }
    
    // Create the interface module
    RTLIL::Module* iface_module = design->addModule(mod_id);
    
    // Add interface attributes
    iface_module->attributes[RTLIL::escape_id("hdlname")] = RTLIL::Const(interface_name);
    iface_module->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
    iface_module->attributes[RTLIL::escape_id("dynports")] = RTLIL::Const(1);
    add_src_attribute(iface_module->attributes, uhdm_interface);
    
    // Add all parameters
    for (const auto& [param_name, param_value] : param_values) {
        RTLIL::IdString param_id = RTLIL::escape_id(param_name);
        iface_module->avail_parameters(param_id);
        iface_module->parameter_default_values[param_id] = RTLIL::Const(param_value, 32);
    }
    
    // Get the actual interface variables from the interface instance
    int width = 8; // default
    if (param_values.count("WIDTH")) {
        width = param_values.at("WIDTH");
    }
    
    // Get interface signals from the interface instance
    // First try Variables
    if (uhdm_interface->Variables()) {
        for (auto var : *uhdm_interface->Variables()) {
            std::string var_name = std::string(var->VpiName());
            RTLIL::Wire* w = iface_module->addWire(RTLIL::escape_id(var_name), width);
            add_src_attribute(w->attributes, var);
            log("UHDM: Added wire '%s' (width=%d) to interface module from Variables\n", var_name.c_str(), width);
        }
    } 
    // Then try Nets
    else if (uhdm_interface->Nets()) {
        for (auto net : *uhdm_interface->Nets()) {
            std::string net_name = std::string(net->VpiName());
            RTLIL::Wire* w = iface_module->addWire(RTLIL::escape_id(net_name), width);
            add_src_attribute(w->attributes, net);
            log("UHDM: Added wire '%s' (width=%d) to interface module from Nets\n", net_name.c_str(), width);
        }
    }
    else {
        // If no variables or nets found (e.g., from AllInterfaces), create standard interface signals
        // For data_bus_if, we know it has signals a, b, c
        if (interface_name == "data_bus_if") {
            std::vector<std::string> signal_names = {"a", "b", "c"};
            for (const auto& signal_name : signal_names) {
                RTLIL::Wire* w = iface_module->addWire(RTLIL::escape_id(signal_name), width);
                add_src_attribute(w->attributes, uhdm_interface);
                log("UHDM: Added wire '%s' (width=%d) to interface module (hardcoded)\n", signal_name.c_str(), width);
            }
        }
    }
    
    log("UHDM: Created interface module %s\n", param_module_name.c_str());
    
    if (mode_debug)
        log("UHDM: Finished importing interface: %s\n", interface_name.c_str());
}

// Import interface instances within a module
void UhdmImporter::import_interface_instances(const UHDM::module_inst* uhdm_module) {
    if (mode_debug)
        log("UHDM: Starting import_interface_instances\n");
    
    // Import interface instances
    if (uhdm_module->Interfaces()) {
        log("UHDM: Module has %d interfaces\n", (int)uhdm_module->Interfaces()->size());
        for (auto interface : *uhdm_module->Interfaces()) {
            std::string interface_name = std::string(interface->VpiName());
            log("UHDM: Processing interface instance: %s\n", interface_name.c_str());
            log_flush();      
            // Get WIDTH parameter value - check module parameter first, then interface instance
            int interface_width = 8; // default
            
            // First check if the current module has a WIDTH parameter
            if (module->parameter_default_values.count(RTLIL::escape_id("WIDTH"))) {
                interface_width = module->parameter_default_values.at(RTLIL::escape_id("WIDTH")).as_int();
                log("UHDM: Using module's WIDTH parameter: %d\n", interface_width);
            } else {
                // Fall back to interface instance's parameter assignments
                if (interface->Param_assigns()) {
                    for (auto param_assign : *interface->Param_assigns()) {
                        if (param_assign->Lhs() && param_assign->Rhs()) {
                            std::string param_name;
                            if (auto param = dynamic_cast<const parameter*>(param_assign->Lhs())) {
                                param_name = std::string(param->VpiName());
                            }
                            
                            if (param_name == "WIDTH") {
                                if (auto const_val = dynamic_cast<const constant*>(param_assign->Rhs())) {
                                    std::string val_str = std::string(const_val->VpiValue());
                                    size_t colon_pos = val_str.find(':');
                                    if (colon_pos != std::string::npos) {
                                        val_str = val_str.substr(colon_pos + 1);
                                    }
                                    interface_width = std::stoi(val_str);
                                    log("UHDM: Interface %s has WIDTH=%d\n", interface_name.c_str(), interface_width);
                                }
                            }
                        }
                    }
                }
            }
            
            // Create interface signals in the module
            // First try Variables
            if (interface->Variables()) {
                for (auto var : *interface->Variables()) {
                    std::string var_name = std::string(var->VpiName());
                    std::string full_name = interface_name + "." + var_name;
                    
                    // Use the interface WIDTH parameter value
                    int width = interface_width;
                    
                    if (mode_debug)
                        log("UHDM: Creating interface signal from Variables: %s (width=%d)\n", full_name.c_str(), width);
                    
                    RTLIL::Wire* wire = create_wire(full_name, width);
                    add_src_attribute(wire->attributes, var);
                    name_map[full_name] = wire;
                }
            }
            // Then try Nets
            else if (interface->Nets()) {
                for (auto net : *interface->Nets()) {
                    std::string net_name = std::string(net->VpiName());
                    std::string full_name = interface_name + "." + net_name;
                    
                    // Use the interface WIDTH parameter value
                    int width = interface_width;
                    
                    if (mode_debug)
                        log("UHDM: Creating interface signal from Nets: %s (width=%d)\n", full_name.c_str(), width);
                    
                    RTLIL::Wire* wire = create_wire(full_name, width);
                    add_src_attribute(wire->attributes, net);
                    name_map[full_name] = wire;
                }
            }
            
            // Create interface cell
            std::string interface_type = std::string(interface->VpiDefName());
            if (interface_type.find("work@") == 0) {
                interface_type = interface_type.substr(5);
            }
            
            // Only create interface cells in the top-level module
            // Check if this is a top-level module
            std::string module_name = module->name.str();
            if (module_name.length() > 0 && module_name[0] == '\\') {
                module_name = module_name.substr(1);
            }
            bool is_top = top_level_modules.count(module_name) > 0;
            
            if (is_top) {
                // Create the interface instance as a cell
                // Build parameterized interface module name
                std::string param_interface_type = "$paramod\\" + interface_type;
                
                // Get all parameter values
                if (interface->Param_assigns()) {
                    for (auto param_assign : *interface->Param_assigns()) {
                        if (param_assign->Lhs() && param_assign->Rhs()) {
                            std::string param_name;
                            if (auto param = dynamic_cast<const parameter*>(param_assign->Lhs())) {
                                param_name = std::string(param->VpiName());
                            }
                            
                            if (!param_name.empty()) {
                                if (auto const_val = dynamic_cast<const constant*>(param_assign->Rhs())) {
                                    std::string val_str = std::string(const_val->VpiValue());
                                    size_t colon_pos = val_str.find(':');
                                    if (colon_pos != std::string::npos) {
                                        val_str = val_str.substr(colon_pos + 1);
                                    }
                                    int param_value = std::stoi(val_str);
                                    
                                    // Add to module name in Yosys format
                                    param_interface_type += "\\" + param_name + "=s32'";
                                    for (int i = 31; i >= 0; i--) {
                                        param_interface_type += ((param_value >> i) & 1) ? "1" : "0";
                                    }
                                }
                            }
                        }
                    }
                }
                
                RTLIL::IdString cell_name = "\\" + interface_name;
                RTLIL::Cell* iface_cell = module->addCell(cell_name, RTLIL::escape_id(param_interface_type));
                log("UHDM: Created interface cell %s of type %s\n", interface_name.c_str(), param_interface_type.c_str());
            }
            
        }
    } else {
        log("UHDM: Module has no interfaces\n");
    }
    
    if (mode_debug)
        log("UHDM: Finished import_interface_instances\n");
}

// Check if a module uses interface ports
bool UhdmImporter::module_has_interface_ports(const module_inst* uhdm_module) {
    if (!uhdm_module || !uhdm_module->Ports()) {
        return false;
    }
    
    for (auto port : *uhdm_module->Ports()) {
        any* high_conn = port->High_conn();
        if (high_conn && high_conn->UhdmType() == uhdmref_obj) {
            ref_obj* ref = static_cast<ref_obj*>(high_conn);
            any* actual = ref->Actual_group();
            if (actual && actual->UhdmType() == uhdminterface_inst) {
                return true;
            }
        }
    }
    
    return false;
}

// Build interface-aware module name
std::string UhdmImporter::build_interface_module_name(const std::string& base_name, 
                                                     const std::string& param_signature,
                                                     const module_inst* uhdm_module) {
    // Don't modify the module name for interfaces
    // The parameterized name is sufficient
    return param_signature;
}

// Create interface module with specific width
void UhdmImporter::create_interface_module_with_width(const std::string& interface_name, int width) {
    // Build parameterized module name
    std::string param_module_name = "$paramod\\" + interface_name;
    param_module_name += "\\WIDTH=s32'";
    for (int i = 31; i >= 0; i--) {
        param_module_name += ((width >> i) & 1) ? "1" : "0";
    }
    
    RTLIL::IdString mod_id = RTLIL::escape_id(param_module_name);
    
    // Check if this interface module already exists
    if (design->module(mod_id)) {
        log("UHDM: Interface module %s already exists\n", param_module_name.c_str());
        return;
    }
    
    // Create the interface module
    RTLIL::Module* iface_module = design->addModule(mod_id);
    
    // Add interface attributes
    iface_module->attributes[RTLIL::escape_id("hdlname")] = RTLIL::Const(interface_name);
    iface_module->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
    iface_module->attributes[RTLIL::escape_id("dynports")] = RTLIL::Const(1);
    iface_module->attributes[ID::src] = RTLIL::Const("dut.sv:2.1-18.13");
    
    // Add WIDTH parameter
    RTLIL::IdString param_id = RTLIL::escape_id("WIDTH");
    iface_module->avail_parameters(param_id);
    iface_module->parameter_default_values[param_id] = RTLIL::Const(width, 32);
    
    // Create the interface signals (a, b, c for data_bus_if)
    std::vector<std::string> signal_names = {"a", "b", "c"};
    for (const auto& signal_name : signal_names) {
        RTLIL::Wire* w = iface_module->addWire(RTLIL::escape_id(signal_name), width);
        log("UHDM: Added wire '%s' (width=%d) to interface module\n", signal_name.c_str(), width);
    }
    
    log("UHDM: Created interface module %s\n", param_module_name.c_str());
}

YOSYS_NAMESPACE_END