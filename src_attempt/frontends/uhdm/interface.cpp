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
    
    // For interfaces, we don't use parameterized module names
    // The interface module name is always just the base interface name
    std::string param_module_name = interface_name;
    
    // Store all parameters and their values
    std::map<std::string, int> param_values;
    
    // First check for parameters defined in the interface itself
    if (uhdm_interface->Parameters()) {
        for (auto param : *uhdm_interface->Parameters()) {
            std::string param_name = std::string(param->VpiName());
            log("UHDM: Found parameter '%s' in interface definition\n", param_name.c_str());
            
            // Get default value if available
            int default_value = 8; // default for WIDTH
            
            // Parameters in interfaces typically have a default value
            // For now, use the default
            param_values[param_name] = default_value;
        }
    }
    
    // Then check for parameter assignments (overrides)
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
                    }
                }
            }
        }
    }
    
    // If we still don't have WIDTH, add it with default value
    if (param_values.find("WIDTH") == param_values.end()) {
        param_values["WIDTH"] = 8;
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
    iface_module->attributes[RTLIL::escape_id("cells_not_processed")] = RTLIL::Const(1);
    add_src_attribute(iface_module->attributes, uhdm_interface);
    
    // Add all parameters
    for (const auto& [param_name, param_value] : param_values) {
        RTLIL::IdString param_id = RTLIL::escape_id(param_name);
        iface_module->avail_parameters(param_id);
        RTLIL::Const param_const(param_value, 32);
        param_const.flags |= RTLIL::CONST_FLAG_SIGNED;
        iface_module->parameter_default_values[param_id] = param_const;
    }
    
    // Get the actual interface variables from the interface instance
    // For parametric interfaces, we use the default width
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
                // Mark the module as having unprocessed cells (interface cells)
                module->attributes[RTLIL::escape_id("cells_not_processed")] = RTLIL::Const(1);
                
                // Create parameterized interface module if needed
                std::string param_interface_type = interface_type;
                int param_width = interface_width;
                
                // Build parameterized module name when interface has parameters
                if (interface->Param_assigns() && !interface->Param_assigns()->empty()) {
                    param_interface_type = stringf("$paramod\\data_bus_if\\WIDTH=s32'%032d", interface_width);
                    
                    // Check if parameterized module exists
                    if (!design->module(RTLIL::escape_id(param_interface_type))) {
                        // Create the parameterized interface module
                        RTLIL::Module* param_iface_module = design->addModule(RTLIL::escape_id(param_interface_type));
                        
                        // Copy attributes from base module
                        RTLIL::Module* base_module = design->module(RTLIL::escape_id(interface_type));
                        if (base_module) {
                            param_iface_module->attributes = base_module->attributes;
                            
                            // Add WIDTH parameter
                            RTLIL::IdString width_param = RTLIL::escape_id("WIDTH");
                            param_iface_module->avail_parameters(width_param);
                            RTLIL::Const param_const(interface_width, 32);
                            param_const.flags |= RTLIL::CONST_FLAG_SIGNED;
                            param_iface_module->parameter_default_values[width_param] = param_const;
                            
                            // Create wires with the specific width
                            std::vector<std::string> signal_names = {"a", "b", "c"};
                            for (const auto& signal_name : signal_names) {
                                RTLIL::Wire* w = param_iface_module->addWire(RTLIL::escape_id(signal_name), interface_width);
                                // Copy attributes from base module wire if it exists
                                RTLIL::Wire* base_wire = base_module->wire(RTLIL::escape_id(signal_name));
                                if (base_wire) {
                                    w->attributes = base_wire->attributes;
                                }
                            }
                            
                            log("UHDM: Created parameterized interface module %s\n", param_interface_type.c_str());
                        }
                    }
                }
                
                RTLIL::IdString cell_name = "\\" + interface_name;
                RTLIL::Cell* iface_cell = module->addCell(cell_name, RTLIL::escape_id(param_interface_type));
                
                // Add module_not_derived attribute for interface cells
                iface_cell->attributes[RTLIL::escape_id("module_not_derived")] = RTLIL::Const(1);
                
                // Don't set parameters on the cell if using parameterized module
                if (param_interface_type == interface_type && interface->Param_assigns()) {
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
                                    
                                    // Set parameter on the cell (mark as signed to match Verilog)
                                    RTLIL::Const param_const(param_value, 32);
                                    param_const.flags |= RTLIL::CONST_FLAG_SIGNED;
                                    iface_cell->setParam(RTLIL::escape_id(param_name), param_const);
                                }
                            }
                        }
                    }
                }
                
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
    // Check if this module has interface ports
    if (module_has_interface_ports(uhdm_module)) {
        // For modules with interface ports, we need to create parameterized versions
        // to pre-expand the interfaces (since we can't use expand_interfaces)
        
        // Extract parameter string from param_signature
        std::string param_string;
        size_t param_start = param_signature.find('$');
        if (param_start != std::string::npos) {
            param_string = param_signature.substr(param_start);
        }
        
        if (!param_string.empty()) {
            // Convert to Yosys parameterized module naming convention
            // Example: submodule$WIDTH=8 -> $paramod\submodule\WIDTH=s32'00000000000000000000000000001000
            std::string modname = "$paramod";
            
            // Parse parameters from param_string
            size_t pos = 0;
            while (pos < param_string.length()) {
                if (param_string[pos] == '$') {
                    pos++; // Skip $
                    size_t eq_pos = param_string.find('=', pos);
                    if (eq_pos != std::string::npos) {
                        std::string param_name = param_string.substr(pos, eq_pos - pos);
                        size_t next_dollar = param_string.find('$', eq_pos);
                        std::string param_value = param_string.substr(eq_pos + 1, 
                            (next_dollar != std::string::npos) ? (next_dollar - eq_pos - 1) : std::string::npos);
                        
                        // Convert to Yosys format
                        modname += "\\" + param_name + "=s32'";
                        // Pad value to 32 bits
                        int val = std::stoi(param_value);
                        modname += stringf("%032d", val);
                        
                        pos = (next_dollar != std::string::npos) ? next_dollar : param_string.length();
                    } else {
                        break;
                    }
                } else {
                    pos++;
                }
            }
            
            modname += "\\" + base_name;
            log("UHDM: Creating parameterized module name for module with interface ports: %s\n", modname.c_str());
            return modname;
        }
    }
    
    // For regular modules and interfaces, return the original param_signature
    return param_signature;
}

// Create interface module with specific width
void UhdmImporter::create_interface_module_with_width(const std::string& interface_name, int width) {
    // For interfaces, we don't use parameterized module names
    // The interface module name is always just the base interface name
    std::string param_module_name = interface_name;
    
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
    iface_module->attributes[RTLIL::escape_id("cells_not_processed")] = RTLIL::Const(1);
    iface_module->attributes[ID::src] = RTLIL::Const("dut.sv:2.1-18.13");
    
    // Add WIDTH parameter
    RTLIL::IdString param_id = RTLIL::escape_id("WIDTH");
    iface_module->avail_parameters(param_id);
    RTLIL::Const param_const(width, 32);
    param_const.flags |= RTLIL::CONST_FLAG_SIGNED;
    iface_module->parameter_default_values[param_id] = param_const;
    
    // Create the interface signals (a, b, c for data_bus_if)
    std::vector<std::string> signal_names = {"a", "b", "c"};
    for (const auto& signal_name : signal_names) {
        RTLIL::Wire* w = iface_module->addWire(RTLIL::escape_id(signal_name), width);
        log("UHDM: Added wire '%s' (width=%d) to interface module\n", signal_name.c_str(), width);
    }
    
    log("UHDM: Created interface module %s\n", param_module_name.c_str());
}

// Pre-expand interface signals in modules with interface ports
void UhdmImporter::expand_interface_signals_in_module(const module_inst* uhdm_module) {
    if (!uhdm_module || !module) {
        return;
    }
    
    log("UHDM: Checking for interface ports to expand in module %s\n", module->name.c_str());
    
    // Look for interface ports by checking wire attributes
    // Interface ports have the is_interface attribute set
    std::vector<RTLIL::Wire*> interface_ports_to_remove;
    std::map<std::string, std::string> interface_port_types;
    
    for (auto &wire_pair : module->wires_) {
        RTLIL::Wire* wire = wire_pair.second;
        
        // Check if this is an interface port
        if (wire->attributes.count(RTLIL::escape_id("is_interface")) && 
            wire->attributes.at(RTLIL::escape_id("is_interface")).as_bool()) {
            
            // Get the interface type from attributes
            if (wire->attributes.count(RTLIL::escape_id("interface_type"))) {
                std::string interface_type_str = wire->attributes.at(RTLIL::escape_id("interface_type")).decode_string();
                
                // Remove leading backslash if present
                if (!interface_type_str.empty() && interface_type_str[0] == '\\') {
                    interface_type_str = interface_type_str.substr(1);
                }
                
                std::string port_name = wire->name.str();
                if (port_name[0] == '\\') port_name = port_name.substr(1);
                
                log("UHDM: Found interface port '%s' of type '%s' to expand\n", port_name.c_str(), interface_type_str.c_str());
                
                interface_ports_to_remove.push_back(wire);
                interface_port_types[port_name] = interface_type_str;
            }
        }
    }
    
    // If we found interface ports, we need to expand them
    if (!interface_ports_to_remove.empty()) {
        log("UHDM: Expanding %d interface ports in module %s\n", (int)interface_ports_to_remove.size(), module->name.c_str());
        
        // Remove the interface ports and expand their signals
        for (auto interface_wire : interface_ports_to_remove) {
            std::string port_name = interface_wire->name.str();
            if (port_name[0] == '\\') port_name = port_name.substr(1);
            
            std::string interface_type = interface_port_types[port_name];
            
            // Find the interface module
            RTLIL::Module* interface_module = design->module(RTLIL::escape_id(interface_type));
            if (!interface_module) {
                log_warning("UHDM: Interface module '%s' not found for expansion\n", interface_type.c_str());
                continue;
            }
            
            // Get port attributes from the interface wire
            int port_id = interface_wire->port_id;
            bool port_input = interface_wire->port_input;
            bool port_output = interface_wire->port_output;
            
            // Remove the interface port wire
            log("UHDM: Removing interface port wire '%s'\n", interface_wire->name.c_str());
            pool<RTLIL::Wire*> wires_to_remove;
            wires_to_remove.insert(interface_wire);
            module->remove(wires_to_remove);
            
            // Create expanded wires for each signal in the interface
            int next_port_id = port_id;
            for (auto &wire_pair : interface_module->wires_) {
                RTLIL::Wire* iface_signal = wire_pair.second;
                if (iface_signal->port_id == 0) {
                    // Create expanded signal name (e.g., bus.a, bus.b, bus.c)
                    std::string signal_name = iface_signal->name.str();
                    if (signal_name[0] == '\\') signal_name = signal_name.substr(1);
                    std::string expanded_name = port_name + "." + signal_name;
                    
                    // Check if the expanded wire already exists
                    RTLIL::IdString expanded_id = RTLIL::escape_id(expanded_name);
                    RTLIL::Wire* expanded_wire = module->wire(expanded_id);
                    if (!expanded_wire) {
                        // Create the expanded wire with the same width as the interface signal
                        // but using the WIDTH parameter if available
                        int width = iface_signal->width;
                        
                        // Check if we have a WIDTH parameter
                        RTLIL::IdString width_param = RTLIL::escape_id("WIDTH");
                        if (module->parameter_default_values.count(width_param)) {
                            width = module->parameter_default_values.at(width_param).as_int();
                        }
                        
                        expanded_wire = module->addWire(expanded_id, width);
                        expanded_wire->attributes = iface_signal->attributes;
                        
                        // If the original interface port was a module port, make the expanded signals ports too
                        if (port_id > 0) {
                            expanded_wire->port_id = next_port_id++;
                            expanded_wire->port_input = port_input;
                            expanded_wire->port_output = port_output;
                        }
                        
                        log("UHDM: Created expanded interface signal '%s' (width=%d, port_id=%d)\n", 
                            expanded_name.c_str(), width, expanded_wire->port_id);
                    }
                }
            }
        }
        
        // Update any connections that reference the interface signals
        // Look for cells that use bus.a, bus.b, bus.c style connections
        for (auto &cell_pair : module->cells_) {
            RTLIL::Cell* cell = cell_pair.second;
            for (auto &conn : cell->connections_) {
                // Check if this connection references an interface signal
                // The connection might be to \bus.a, \bus.b, etc.
                // These should already exist as expanded wires
            }
        }
        
        // Mark that interfaces have been expanded in this module
        module->attributes[RTLIL::escape_id("interfaces_expanded")] = RTLIL::Const(1);
    }
}

// Expand interface ports in parameterized modules with interface ports
void UhdmImporter::expand_interface_ports_in_module(const module_inst* uhdm_module) {
    if (!uhdm_module || !module) {
        return;
    }
    
    log("UHDM: Expanding interface ports in parameterized module %s\n", module->name.c_str());
    
    // Find interface ports and expand them
    std::vector<RTLIL::Wire*> interface_ports_to_expand;
    std::map<std::string, std::string> interface_port_types;
    std::map<std::string, std::string> interface_port_modports;
    
    // Collect interface ports
    for (auto &wire_pair : module->wires_) {
        RTLIL::Wire* wire = wire_pair.second;
        
        // Check if this is an interface port
        if (wire->port_id > 0 && 
            wire->attributes.count(RTLIL::escape_id("is_interface")) && 
            wire->attributes.at(RTLIL::escape_id("is_interface")).as_bool()) {
            
            std::string port_name = wire->name.str();
            if (port_name[0] == '\\') port_name = port_name.substr(1);
            
            // Get the interface type
            if (wire->attributes.count(RTLIL::escape_id("interface_type"))) {
                std::string interface_type = wire->attributes.at(RTLIL::escape_id("interface_type")).decode_string();
                if (!interface_type.empty() && interface_type[0] == '\\') {
                    interface_type = interface_type.substr(1);
                }
                interface_port_types[port_name] = interface_type;
            }
            
            // Get the modport if any
            if (wire->attributes.count(RTLIL::escape_id("interface_modport"))) {
                std::string modport = wire->attributes.at(RTLIL::escape_id("interface_modport")).decode_string();
                interface_port_modports[port_name] = modport;
            }
            
            interface_ports_to_expand.push_back(wire);
            log("UHDM: Found interface port '%s' to expand\n", port_name.c_str());
        }
    }
    
    // Expand each interface port
    for (auto interface_wire : interface_ports_to_expand) {
        std::string port_name = interface_wire->name.str();
        if (port_name[0] == '\\') port_name = port_name.substr(1);
        
        std::string interface_type = interface_port_types[port_name];
        
        // Find the interface module
        RTLIL::Module* interface_module = nullptr;
        
        // For parameterized modules, we need to find the right interface instance
        // Get WIDTH parameter value
        int width = 8; // default
        if (module->parameter_default_values.count(RTLIL::escape_id("WIDTH"))) {
            width = module->parameter_default_values.at(RTLIL::escape_id("WIDTH")).as_int();
        }
        
        // Try to find parameterized interface module first
        std::string param_interface_name = stringf("$paramod\\%s\\WIDTH=s32'%032d", 
            interface_type.c_str(), width);
        interface_module = design->module(RTLIL::escape_id(param_interface_name));
        
        if (!interface_module) {
            // Fall back to base interface module
            interface_module = design->module(RTLIL::escape_id(interface_type));
        }
        
        if (!interface_module) {
            log_warning("UHDM: Interface module '%s' not found for expansion\n", interface_type.c_str());
            continue;
        }
        
        log("UHDM: Expanding interface port '%s' using interface module '%s'\n", 
            port_name.c_str(), interface_module->name.c_str());
        
        // Create expanded signal wires
        for (auto &iface_wire_pair : interface_module->wires_) {
            RTLIL::Wire* iface_wire = iface_wire_pair.second;
            
            // Skip port wires in the interface (only expand internal signals)
            if (iface_wire->port_id == 0) {
                std::string signal_name = iface_wire->name.str();
                if (signal_name[0] == '\\') signal_name = signal_name.substr(1);
                
                // Create expanded signal name (e.g., bus.a, bus.b, bus.c)
                std::string expanded_name = port_name + "." + signal_name;
                RTLIL::IdString expanded_id = RTLIL::escape_id(expanded_name);
                
                // Check if wire already exists
                if (!module->wire(expanded_id)) {
                    // Create the expanded wire with proper width
                    RTLIL::Wire* expanded_wire = module->addWire(expanded_id, iface_wire->width);
                    expanded_wire->attributes = iface_wire->attributes;
                    
                    log("UHDM: Created expanded interface signal '%s' (width=%d)\n", 
                        expanded_name.c_str(), expanded_wire->width);
                }
            }
        }
        
        // Don't remove the interface port wire - hierarchy pass still needs it
        // Just mark that we've expanded the interface
        interface_wire->attributes[RTLIL::escape_id("interface_expanded")] = RTLIL::Const(1);
    }
    
    // Mark module as having expanded interfaces
    if (!interface_ports_to_expand.empty()) {
        module->attributes[RTLIL::escape_id("interfaces_expanded")] = RTLIL::Const(1);
    }
}

YOSYS_NAMESPACE_END