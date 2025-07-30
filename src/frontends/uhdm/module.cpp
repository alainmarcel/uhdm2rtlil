/*
 * Module-specific UHDM to RTLIL translation
 * 
 * This file handles the translation of module-level constructs including
 * ports, nets, and module instantiations.
 */

#include "uhdm2rtlil.h"
#include <uhdm/vpi_visitor.h>
#include <uhdm/gen_scope.h>
#include <cctype>
#include <uhdm/gen_scope_array.h>
#include <uhdm/uhdm_types.h>
YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Import a module port
void UhdmImporter::import_port(const port* uhdm_port) {
    std::string portname = std::string(uhdm_port->VpiName());
    int direction = uhdm_port->VpiDirection();
    
    // Handle empty port names
    if (portname.empty()) {
        log_warning("UHDM: Port has empty name, using default name 'unnamed_port'\n");
        portname = "unnamed_port";
    }
    
    if (mode_debug)
        log("  Importing port: %s (dir=%d)\n", portname.c_str(), direction);
    
    // Get port width
    int width = get_width(uhdm_port, current_instance);
    
    // Check if this is an interface port
    if (width == -1) {
        log("UHDM: Port '%s' is an interface type, creating placeholder\n", portname.c_str());
        // For interface ports, create a special wire that won't be used for connections
        // but serves as a placeholder for the port list
        RTLIL::Wire* w = module->addWire(RTLIL::escape_id(portname), 1);
        w->attributes[RTLIL::escape_id("interface_port")] = RTLIL::Const(1);
        
        // Add source attribute
        add_src_attribute(w->attributes, uhdm_port);
        
        // Set port direction
        if (direction == vpiInput)
            w->port_input = true;
        else if (direction == vpiOutput)
            w->port_output = true;
        else if (direction == vpiInout) {
            w->port_input = true;
            w->port_output = true;
        }
        
        w->port_id = module->ports.size() + 1;
        module->ports.push_back(w->name);
        
        // Store in maps
        wire_map[uhdm_port] = w;
        name_map[portname] = w;
        return;
    }
    
    RTLIL::Wire* w = create_wire(portname, width);
    
    // Add source attribute
    add_src_attribute(w->attributes, uhdm_port);
    
    // Set port direction
    if (direction == vpiInput)
        w->port_input = true;
    else if (direction == vpiOutput)
        w->port_output = true;
    else if (direction == vpiInout) {
        w->port_input = true;
        w->port_output = true;
    }
    
    w->port_id = module->ports.size() + 1;
    module->ports.push_back(w->name);
    
    // Store in maps
    wire_map[uhdm_port] = w;
    name_map[portname] = w;
}

// Import a net
void UhdmImporter::import_net(const net* uhdm_net, const UHDM::instance* inst) {
    std::string netname = std::string(uhdm_net->VpiName());
    
    // Handle empty net names
    if (netname.empty()) {
        log_warning("UHDM: Net has empty name, using default name 'unnamed_net'\n");
        netname = "unnamed_net";
    }
    
    if (mode_debug)
        log("  Importing net: %s\n", netname.c_str());
    
    // Skip if already created as port or net
    if (name_map.count(netname)) {
        log("UHDM: Net '%s' already exists in name_map, skipping\n", netname.c_str());
        return;
    }
    
    // Also check if wire already exists in module
    RTLIL::IdString wire_id = RTLIL::escape_id(netname);
    if (module->wire(wire_id)) {
        log("UHDM: Wire '%s' already exists in module, skipping net import\n", wire_id.c_str());
        return;
    }
    
    int width = get_width(uhdm_net, inst);
    RTLIL::Wire* w = create_wire(netname, width);
    add_src_attribute(w->attributes, uhdm_net);
    // Handle net type
    int net_type = uhdm_net->VpiNetType();
    if (net_type == vpiReg) {
        // Reg type - can be driven by procedural code
        w->attributes[ID::reg] = RTLIL::Const(1);
    }
    
    // Store in maps
    wire_map[uhdm_net] = w;
    name_map[netname] = w;
}

// Import a continuous assignment
void UhdmImporter::import_continuous_assign(const cont_assign* uhdm_assign) {
    if (mode_debug)
        log("  Importing continuous assignment\n");
    
    const expr* lhs_expr = uhdm_assign->Lhs();
    const expr* rhs_expr = uhdm_assign->Rhs();
    
    if (mode_debug && lhs_expr) {
        log("  LHS type: %s, VpiType: %d\n", 
            UHDM::UhdmName(lhs_expr->UhdmType()).c_str(), 
            lhs_expr->VpiType());
    }
    
    RTLIL::SigSpec lhs = import_expression(lhs_expr);
    RTLIL::SigSpec rhs = import_expression(rhs_expr);
    
    if (lhs.size() != rhs.size()) {
        if (rhs.size() == 1) {
            // Extend single bit to match LHS width
            rhs = {rhs, RTLIL::SigSpec(RTLIL::State::S0, lhs.size() - 1)};
        } else {
            log_warning("Assignment width mismatch: LHS=%d, RHS=%d\n", 
                       lhs.size(), rhs.size());
            
            // For now, just continue with the warning
            // TODO: Fix interface signal width inference
        }
    }
    
    module->connect(lhs, rhs);
}

// Import a parameter
void UhdmImporter::import_parameter(const any* uhdm_param) {
    if (!uhdm_param) return;
    
    std::string param_name = std::string(uhdm_param->VpiName());
    
    if (param_name.empty()) {
        log_warning("UHDM: Parameter has empty name, skipping\n");
        return;
    }
    
    if (mode_debug)
        log("  Importing parameter: %s\n", param_name.c_str());
    
    // Get the parameter value
    RTLIL::Const param_value;
    bool has_value = false;
    
    // Try to cast to parameter object
    if (auto param_obj = dynamic_cast<const UHDM::parameter*>(uhdm_param)) {
        // Check if parameter has an expression (its value)
        if (auto expr = param_obj->Expr()) {
            RTLIL::SigSpec value_spec = import_expression(expr);
            if (value_spec.is_fully_const()) {
                param_value = value_spec.as_const();
                has_value = true;
                log("UHDM: Parameter '%s' has value: %s\n", param_name.c_str(), 
                    param_value.as_string().c_str());
            } else {
                log_warning("UHDM: Parameter '%s' has non-constant value, defaulting to 0\n", 
                           param_name.c_str());
                param_value = RTLIL::Const(0, 32);
                has_value = true;
            }
        } else {
            log("UHDM: Parameter '%s' has no expression, defaulting to 0\n", param_name.c_str());
            param_value = RTLIL::Const(0, 32);
            has_value = true;
        }
    }
    
    if (has_value) {
        // Add parameter to module
        RTLIL::IdString param_id = RTLIL::escape_id(param_name);
        module->avail_parameters(param_id);
        module->parameter_default_values[param_id] = param_value;
        
        // Log successful parameter import
        log("UHDM: Added parameter '%s' to module with value %s\n", 
            param_name.c_str(), param_value.as_string().c_str());
    }
}

// Import a module instance
void UhdmImporter::import_instance(const module_inst* uhdm_inst) {
    log("UHDM: import_instance called for '%s' of type '%s'\n", 
        std::string(uhdm_inst->VpiName()).c_str(), 
        std::string(uhdm_inst->VpiDefName()).c_str());
    
    // Get the instance name - use full name if available for hierarchical names
    std::string inst_name;
    std::string full_name = std::string(uhdm_inst->VpiFullName());
    
    if (!full_name.empty()) {
        // Extract the hierarchical name relative to the current module
        // E.g., from "work@generate_test.gen_units[0].even_unit.adder_inst"
        // we want "gen_units[0].even_unit.adder_inst"
        
        // Find the module name in the full path
        std::string module_prefix = "work@" + module->name.substr(1); // Remove leading backslash
        size_t module_pos = full_name.find(module_prefix);
        
        if (module_pos != std::string::npos) {
            // Skip past module name and the dot
            size_t start_pos = module_pos + module_prefix.length();
            if (start_pos < full_name.length() && full_name[start_pos] == '.') {
                start_pos++;
            }
            inst_name = full_name.substr(start_pos);
        } else {
            // Fallback to simple name
            inst_name = std::string(uhdm_inst->VpiName());
        }
    } else {
        inst_name = std::string(uhdm_inst->VpiName());
    }
    
    std::string base_module_name = std::string(uhdm_inst->VpiDefName());
    
    // Strip work@ prefix if present
    if (base_module_name.find("work@") == 0) {
        base_module_name = base_module_name.substr(5);
    }
    
    // Collect parameters to build parameterized module name
    std::map<std::string, RTLIL::Const> params;
    if (uhdm_inst->Param_assigns()) {
        for (auto param : *uhdm_inst->Param_assigns()) {
            std::string param_name = std::string(param->Lhs()->VpiName());
            
            if (auto rhs = param->Rhs()) {
                RTLIL::SigSpec value = import_expression(static_cast<const expr*>(rhs));
                
                if (value.is_fully_const()) {
                    params[param_name] = value.as_const();
                }
            }
        }
    }
    
    // Build parameterized module name like Yosys does
    std::string module_name = base_module_name;
    if (!params.empty()) {
        module_name = "$paramod\\" + base_module_name;
        for (const auto& [pname, pval] : params) {
            module_name += "\\" + pname + "=";
            // Format parameter value
            if (pval.flags & RTLIL::CONST_FLAG_SIGNED) {
                module_name += "s";
            }
            module_name += std::to_string(pval.size()) + "'";
            // Add binary representation
            for (int i = pval.size() - 1; i >= 0; i--) {
                module_name += (pval[i] == RTLIL::State::S1) ? "1" : "0";
            }
        }
    }
    
    // Check if the module definition has interface ports
    // We need to look at the module being instantiated to see if it uses interfaces
    bool has_interface_ports = false;
    if (uhdm_design && uhdm_design->AllModules()) {
        for (const module_inst* mod_def : *uhdm_design->AllModules()) {
            std::string def_name = std::string(mod_def->VpiDefName());
            if (def_name.find("work@") == 0) {
                def_name = def_name.substr(5);
            }
            if (def_name == base_module_name) {
                has_interface_ports = module_has_interface_ports(mod_def);
                break;
            }
        }
    }
    
    // If the module has interface ports, add the interface suffix
    if (has_interface_ports) {
        // Find the interface information from the instance's port connections
        std::string interface_suffix = "$interfaces$";
        
        if (uhdm_inst->Ports()) {
            for (auto port : *uhdm_inst->Ports()) {
                if (port->High_conn()) {
                    const any* high_conn = port->High_conn();
                    if (high_conn->UhdmType() == uhdmref_obj) {
                        const ref_obj* ref = static_cast<const ref_obj*>(high_conn);
                        const any* actual = ref->Actual_group();
                        if (actual && actual->UhdmType() == uhdminterface_inst) {
                            const interface_inst* iface = static_cast<const interface_inst*>(actual);
                            std::string iface_type = std::string(iface->VpiDefName());
                            if (iface_type.find("work@") == 0) {
                                iface_type = iface_type.substr(5);
                            }
                            
                            // Build interface parameter suffix
                            std::string iface_param_suffix = "$paramod\\" + iface_type;
                            
                            // Add interface parameters
                            if (iface->Param_assigns()) {
                                for (auto param_assign : *iface->Param_assigns()) {
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
                                                
                                                iface_param_suffix += "\\" + param_name + "=s32'";
                                                for (int i = 31; i >= 0; i--) {
                                                    iface_param_suffix += ((param_value >> i) & 1) ? "1" : "0";
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            interface_suffix += iface_param_suffix;
                            break; // For now, only handle the first interface port
                        }
                    }
                }
            }
        }
        
        module_name += interface_suffix;
    }
    
    if (mode_debug)
        log("  Importing instance: %s of %s\n", inst_name.c_str(), module_name.c_str());
    
    // Check if the module definition exists
    RTLIL::IdString module_id = RTLIL::escape_id(module_name);
    if (!design->module(module_id)) {
        // Module doesn't exist - need to create it
        // For parameterized modules, we need the base module first
        RTLIL::IdString base_module_id = RTLIL::escape_id(base_module_name);
        if (!design->module(base_module_id)) {
            // Base module doesn't exist either - need to import it from UHDM
            if (uhdm_design && uhdm_design->AllModules()) {
                // Search for the module definition in AllModules
                for (const module_inst* mod_def : *uhdm_design->AllModules()) {
                    std::string def_name = std::string(mod_def->VpiDefName());
                    if (def_name.find("work@") == 0) {
                        def_name = def_name.substr(5);
                    }
                    if (def_name == base_module_name) {
                        log("UHDM: Found module definition for %s, importing it\n", base_module_name.c_str());
                        // Save current module context
                        RTLIL::Module* saved_module = module;
                        const module_inst* saved_instance = current_instance;
                        
                        // Save parent module's maps
                        auto saved_wire_map = wire_map;
                        auto saved_name_map = name_map;
                        
                        // Import the module definition
                        import_module(mod_def);
                        
                        // Restore context
                        module = saved_module;
                        current_instance = saved_instance;
                        
                        // Restore parent module's maps
                        wire_map = saved_wire_map;
                        name_map = saved_name_map;
                        break;
                    }
                }
            }
        }
        
        // Now create the parameterized version if needed
        if (!params.empty() && design->module(base_module_id)) {
            log("UHDM: Creating parameterized module %s\n", module_name.c_str());
            RTLIL::Module* base_mod = design->module(base_module_id);
            RTLIL::Module* param_mod = design->addModule(module_id);
            
            // Copy attributes from base module
            param_mod->attributes = base_mod->attributes;
            // Add hdlname attribute with the original module name
            param_mod->attributes[RTLIL::escape_id("hdlname")] = RTLIL::Const(base_module_name);
            param_mod->attributes[RTLIL::escape_id("dynports")] = RTLIL::Const(1);
            // Mark the module as parametric - this is crucial!
            param_mod->avail_parameters = base_mod->avail_parameters;
            if (param_mod->avail_parameters.empty()) {
                // If base module doesn't have parameters declared, add them
                for (const auto& [pname, pval] : params) {
                    param_mod->avail_parameters(RTLIL::escape_id(pname));
                }
            }
            
            param_mod->parameter_default_values = base_mod->parameter_default_values;
            
            // Update parameters
            for (const auto& [pname, pval] : params) {
                param_mod->parameter_default_values[RTLIL::escape_id(pname)] = pval;
            }
            
            // Copy and resize wires/ports based on WIDTH parameter
            int width = params.count("WIDTH") ? params.at("WIDTH").as_int() : 8;
            for (auto &wire_pair : base_mod->wires_) {
                RTLIL::Wire* base_wire = wire_pair.second;
                RTLIL::Wire* param_wire = param_mod->addWire(base_wire->name, width);
                param_wire->attributes = base_wire->attributes;
                param_wire->port_id = base_wire->port_id;
                param_wire->port_input = base_wire->port_input;
                param_wire->port_output = base_wire->port_output;
            }
            
            // Import the module contents from UHDM for this parameterized instance
            // This ensures cells are created with proper wire references
            if (uhdm_design && uhdm_design->AllModules()) {
                // Find the UHDM module definition
                for (const module_inst* mod_def : *uhdm_design->AllModules()) {
                    std::string def_name = std::string(mod_def->VpiDefName());
                    if (def_name.find("work@") == 0) {
                        def_name = def_name.substr(5);
                    }
                    if (def_name == base_module_name) {
                        // Save current module context
                        RTLIL::Module* saved_module = module;
                        const module_inst* saved_instance = current_instance;
                        
                        // Save parent module's maps
                        auto saved_wire_map = wire_map;
                        auto saved_name_map = name_map;
                        
                        // Set context to the parameterized module
                        module = param_mod;
                        current_instance = mod_def;
                        
                        // Clear wire and name maps for clean import
                        wire_map.clear();
                        name_map.clear();
                        
                        // Map the parameterized wires we already created
                        for (auto &wire_pair : param_mod->wires_) {
                            name_map[wire_pair.first.str().substr(1)] = wire_pair.second;
                        }
                        
                        // Import continuous assignments
                        if (mod_def->Cont_assigns()) {
                            for (auto cont_assign : *mod_def->Cont_assigns()) {
                                import_continuous_assign(cont_assign);
                            }
                        }
                        
                        // Import always blocks
                        if (mod_def->Process()) {
                            for (auto process : *mod_def->Process()) {
                                import_process(process);
                            }
                        }
                        
                        // Restore context
                        module = saved_module;
                        current_instance = saved_instance;
                        
                        // Restore the parent module's maps
                        wire_map = saved_wire_map;
                        name_map = saved_name_map;
                        
                        break;
                    }
                }
            }
            
            param_mod->fixup_ports();
        }
    }
    
    log("UHDM: Creating cell '%s' of type '%s'\n", inst_name.c_str(), module_id.c_str());
    RTLIL::Cell* cell = module->addCell(new_id(inst_name), module_id);
    
    // Add source attribute to cell
    add_src_attribute(cell->attributes, uhdm_inst);
    
    // Import port connections
    if (uhdm_inst->Ports()) {
        log("UHDM: Processing %d ports for instance\n", (int)uhdm_inst->Ports()->size());
        for (auto port : *uhdm_inst->Ports()) {
            std::string port_name = std::string(port->VpiName());
            
            // Get the actual connection (high_conn)
            if (port->High_conn()) {
                const any* high_conn = port->High_conn();
                log("    Port %s has High_conn of type %s\n", port_name.c_str(), UhdmName(high_conn->UhdmType()).c_str());
                
                // Check if this is an interface connection
                if (high_conn->UhdmType() == uhdmref_obj) {
                    const ref_obj* ref = static_cast<const ref_obj*>(high_conn);
                    const any* actual = ref->Actual_group();
                    
                    if (actual && actual->UhdmType() == uhdminterface_inst) {
                        const interface_inst* iface = static_cast<const interface_inst*>(actual);
                        std::string iface_name = std::string(iface->VpiName());
                        log("    Port %s is connected to interface %s\n", port_name.c_str(), iface_name.c_str());
                        
                        // For interface connections, we need to expand the interface signals
                        // and connect them individually as bus.a, bus.b, bus.c
                        if (iface->Variables()) {
                            for (auto var : *iface->Variables()) {
                                std::string var_name = std::string(var->VpiName());
                                std::string full_signal_name = iface_name + "." + var_name;
                                std::string port_signal_name = port_name + "." + var_name;
                                
                                if (name_map.count(full_signal_name)) {
                                    RTLIL::Wire* w = name_map[full_signal_name];
                                    cell->setPort(RTLIL::escape_id(port_signal_name), w);
                                    log("      Connected interface signal %s to port %s\n", full_signal_name.c_str(), port_signal_name.c_str());
                                }
                            }
                        }
                        continue;
                    }
                }
                
                // Try to handle as expression directly
                RTLIL::SigSpec actual_sig;
                try {
                    actual_sig = import_expression(static_cast<const expr*>(high_conn));
                } catch (...) {
                    log_warning("Failed to import port connection for %s\n", port_name.c_str());
                    actual_sig = RTLIL::SigSpec();
                }
                
                if (actual_sig.size() > 0) {
                    // Check if the target module has this port marked as an interface port
                    RTLIL::Module* target_module = design->module(cell->type);
                    if (!target_module) {
                        log("    Target module not found for cell type: %s\n", cell->type.c_str());
                    }
                    if (target_module) {
                        RTLIL::Wire* port_wire = target_module->wire(RTLIL::escape_id(port_name));
                        if (!port_wire) {
                            log("    Port wire not found for port: %s\n", port_name.c_str());
                        }
                        if (port_wire && port_wire->attributes.count(RTLIL::escape_id("interface_port"))) {
                            log("    Port %s is an interface port, creating connection wire\n", port_name.c_str());
                            
                            // For interface ports, we need to create a connection wire
                            // The wire name is based on the connected interface instance name
                            // Extract interface name from actual_sig if it's a simple wire reference
                            std::string interface_wire_name;
                            if (actual_sig.is_wire() && actual_sig.as_wire()) {
                                interface_wire_name = actual_sig.as_wire()->name.str();
                                if (interface_wire_name[0] == '\\') {
                                    interface_wire_name = interface_wire_name.substr(1);
                                }
                                interface_wire_name += "_1";
                            } else {
                                // Fallback: use instance name + port name
                                interface_wire_name = inst_name + "_" + port_name + "_1";
                            }
                            
                            // Create or get the interface connection wire
                            RTLIL::Wire* conn_wire = module->wire(RTLIL::escape_id(interface_wire_name));
                            if (!conn_wire) {
                                conn_wire = module->addWire(RTLIL::escape_id(interface_wire_name), 1);
                                conn_wire->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
                                log("    Created interface connection wire: %s\n", interface_wire_name.c_str());
                            }
                            
                            // Connect the cell port to this wire
                            cell->setPort(RTLIL::escape_id(port_name), conn_wire);
                            continue;
                        }
                    }
                    cell->setPort(RTLIL::escape_id(port_name), actual_sig);
                } else {
                    log_warning("Port %s has empty connection\n", port_name.c_str());
                }
                
                log("    Connected port %s to signal of width %d\n", port_name.c_str(), actual_sig.size());
            } else {
                log("    Port %s has no connection (High_conn)\n", port_name.c_str());
            }
        }
    } else {
        log("UHDM: No ports found for instance\n");
    }
    
    // Set parameters on the cell
    //for (const auto& [pname, pval] : params) {
    //    cell->setParam(RTLIL::escape_id(pname), pval);
    //}
}

// Create a wire with the given name and width
RTLIL::Wire* UhdmImporter::create_wire(const std::string& name, int width) {
    log("UHDM: Creating wire '%s' (width=%d, mode_keep_names=%s)\n", 
        name.c_str(), width, mode_keep_names ? "true" : "false");
    
    // First check if we already have this wire by base name
    RTLIL::IdString base_name = RTLIL::escape_id(name);
    if (module->wire(base_name)) {
        log("UHDM: Wire '%s' already exists, returning existing wire\n", base_name.c_str());
        return module->wire(base_name);
    }
    
    // Generate wire name (with uniquify if needed)
    RTLIL::IdString wire_name = new_id(name);
    
    // Double-check after name generation
    if (module->wire(wire_name)) {
        log("UHDM: Wire '%s' already exists after uniquify, returning existing wire\n", wire_name.c_str());
        return module->wire(wire_name);
    }
    
    log("UHDM: About to call module->addWire('%s', %d)\n", wire_name.c_str(), width);
    
    try {
        RTLIL::Wire* w = module->addWire(wire_name, width);
        log("UHDM: Successfully created wire '%s'\n", wire_name.c_str());
        
        // Check if this wire is being created for an interface connection
        // Interface connection wires typically have names like bus1_1, bus2_1, etc.
        // where bus1, bus2 are interface instance names
        std::string base_name = name;
        size_t underscore_pos = base_name.rfind('_');
        if (underscore_pos != std::string::npos && underscore_pos < base_name.length() - 1) {
            std::string suffix = base_name.substr(underscore_pos + 1);
            // Check if suffix is a number (typically "1")
            bool is_numeric = true;
            for (char c : suffix) {
                if (!std::isdigit(c)) {
                    is_numeric = false;
                    break;
                }
            }
            
            if (is_numeric) {
                // This might be an interface connection wire
                // Check if there's an interface cell with the base name
                std::string potential_interface = base_name.substr(0, underscore_pos);
                RTLIL::IdString interface_cell_name = RTLIL::escape_id(potential_interface);
                if (module->cell(interface_cell_name)) {
                    // Check if the cell type indicates it's an interface
                    // Look for the is_interface attribute on the module definition
                    RTLIL::Cell* interface_cell = module->cell(interface_cell_name);
                    RTLIL::Module* interface_module = design->module(interface_cell->type);
                    if (interface_module && interface_module->attributes.count(RTLIL::escape_id("is_interface"))) {
                        w->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
                        log("UHDM: Marked wire '%s' as interface connection\n", wire_name.c_str());
                    }
                }
            }
        }
        
        return w;
    } catch (const std::exception& e) {
        log_error("UHDM: Failed to create wire '%s': %s\n", wire_name.c_str(), e.what());
        return nullptr;
    }
}

// Generate a new unique ID
RTLIL::IdString UhdmImporter::new_id(const std::string& name) {
    std::string safe_name = name;
    
    // Handle empty names
    if (safe_name.empty()) {
        log_warning("UHDM: Creating ID for empty name, using default 'unnamed_object'\n");
        safe_name = "unnamed_object";
    }
    
    if (mode_keep_names) {
        return RTLIL::escape_id(safe_name);
    } else {
        return module->uniquify(RTLIL::escape_id(safe_name));
    }
}

// Get name from UHDM object
std::string UhdmImporter::get_name(const any* uhdm_obj) {
    // Simplified implementation for getting names
    return "unnamed";
}

// Get width from UHDM object
int UhdmImporter::get_width(const any* uhdm_obj, const UHDM::scope* inst) {
    if (!uhdm_obj) {
        log("UHDM: get_width called with null object\n");
        return 1;
    }
    
    try {
        log("UHDM: get_width analyzing object type\n");
        
        // Check if it's a port and try to get typespec
        if (auto port = dynamic_cast<const UHDM::port*>(uhdm_obj)) {
            log("UHDM: Found port object\n");
            if (auto typespec = port->Typespec()) {
                log("UHDM: Port has typespec, calling get_width_from_typespec\n");
                return get_width_from_typespec(typespec, inst);
            } else {
                log("UHDM: Port has no typespec\n");
            }
        }
        
        // Check if it's a net and try to get typespec
        if (auto net = dynamic_cast<const UHDM::net*>(uhdm_obj)) {
            log("UHDM: Found net object\n");
            if (auto typespec = net->Typespec()) {
                log("UHDM: Net has typespec, calling get_width_from_typespec\n");
                return get_width_from_typespec(typespec, inst);
            } else {
                log("UHDM: Net has no typespec\n");
            }
        }

        // Check if it's a net and try to get typespec
        if (auto variable = dynamic_cast<const UHDM::variables*>(uhdm_obj)) {
            log("UHDM: Found net object\n");
            if (auto typespec = variable->Typespec()) {
                log("UHDM: Net has typespec, calling get_width_from_typespec\n");
                return get_width_from_typespec(typespec, inst);
            } else {
                log("UHDM: Net has no typespec\n");
            }
        }

        if (auto variable = dynamic_cast<const UHDM::io_decl*>(uhdm_obj)) {
            log("UHDM: Found net object\n");
            if (auto typespec = variable->Typespec()) {
                log("UHDM: Net has typespec, calling get_width_from_typespec\n");
                return get_width_from_typespec(typespec, inst);
            } else {
                log("UHDM: Net has no typespec\n");
            }
        }
        
        log("UHDM: Object is neither port nor net, or no typespec found\n");
        
    } catch (...) {
        log("UHDM: Exception in get_width\n");
    }
    
    log("UHDM: Defaulting to width=1\n");
    return 1;
}

// Helper function to get width from typespec
int UhdmImporter::get_width_from_typespec(const UHDM::any* typespec, const UHDM::scope* inst) {
    if (!typespec) return 1;
    
    try {
        log("UHDM: Analyzing typespec for width determination\n");
        log("UHDM: Typespec UhdmType = %d\n", typespec->UhdmType());
        
        // Check if this is a ref_typespec and follow the reference
        if (typespec->UhdmType() == uhdmref_typespec) {
            log("UHDM: Found ref_typespec, following reference\n");
            if (auto ref_typespec = dynamic_cast<const UHDM::ref_typespec*>(typespec)) {
                if (auto actual = ref_typespec->Actual_typespec()) {
                    log("UHDM: Following to actual typespec (UhdmType = %s)\n", UhdmName(actual->UhdmType()).c_str());
                    // Check if the actual type is an interface
                    if (actual->UhdmType() == uhdminterface_typespec) {
                        log("UHDM: Found interface_typespec through reference\n");
                        return -1;  // Special value to indicate interface type
                    }
                    // Otherwise recurse to get the actual width
                    return get_width_from_typespec(actual, inst);
                } else {
                    // Try to resolve package type reference
                    std::string type_name = std::string(ref_typespec->VpiName());
                    log("UHDM: ref_typespec has no actual_typespec, checking package types for: %s\n", type_name.c_str());
                    
                    // Check if this is a package type reference
                    if (package_typespec_map.count(type_name)) {
                        const UHDM::typespec* pkg_typespec = package_typespec_map.at(type_name);
                        log("UHDM: Found package typespec for %s\n", type_name.c_str());
                        return get_width_from_typespec(pkg_typespec, inst);
                    }
                    
                    // Try with package:: prefix (in case of qualified name)
                    size_t colonPos = type_name.find("::");
                    if (colonPos != std::string::npos) {
                        if (package_typespec_map.count(type_name)) {
                            const UHDM::typespec* pkg_typespec = package_typespec_map.at(type_name);
                            log("UHDM: Found package typespec for qualified name %s\n", type_name.c_str());
                            return get_width_from_typespec(pkg_typespec, inst);
                        }
                    }
                }
            }
        }
        
        // Check if this is an interface typespec
        if (typespec->UhdmType() == uhdminterface_typespec) {
            log("UHDM: Found interface_typespec, interface ports don't have a simple width\n");
            // Interface ports are special - they don't have a width
            // They represent a bundle of signals
            return -1;  // Special value to indicate interface type
        }
        
        // Use UHDM::ExprEval to get the actual size of the typespec
        UHDM::ExprEval eval;
        bool invalidValue = false;
        
        // Call eval.size() like Surelog does
        // From Surelog: eval.size(typespec, invalidValue, context, nullptr, !sizeMode)
        uint64_t size = eval.size(typespec, invalidValue, inst, typespec, true);
        
        if (!invalidValue && size > 0) {
            log("UHDM: ExprEval returned size=%llu for typespec\n", (unsigned long long)size);
            return (int)size;
        } else {
            log("UHDM: ExprEval failed or returned invalid size, defaulting to 1\n");
        }
        
    } catch (const std::exception& e) {
        log("UHDM: Exception in get_width_from_typespec: %s\n", e.what());
    } catch (...) {
        log("UHDM: Unknown exception in get_width_from_typespec\n");
    }
    
    return 1;  // Default to 1 bit
}

// Get source attribute string from UHDM object
std::string UhdmImporter::get_src_attribute(const any* uhdm_obj) {
    if (!uhdm_obj) return "";
    
    try {
        // Get the file name
        std::string filename;
        if (!uhdm_obj->VpiFile().empty()) {
            std::string full_path = std::string(uhdm_obj->VpiFile());
            // Extract just the filename from the path
            size_t last_slash = full_path.find_last_of("/\\");
            if (last_slash != std::string::npos) {
                filename = full_path.substr(last_slash + 1);
            } else {
                filename = full_path;
            }
        } else {
            return "";  // No file info available
        }
        
        // Get line and column information
        int line = uhdm_obj->VpiLineNo();
        int col = uhdm_obj->VpiColumnNo();
        int end_line = uhdm_obj->VpiEndLineNo();
        int end_col = uhdm_obj->VpiEndColumnNo();
        
        // Format the source attribute string
        return filename + ":" + std::to_string(line) + "." + std::to_string(col) + 
               "-" + std::to_string(end_line) + "." + std::to_string(end_col);
               
    } catch (...) {
        // If UHDM API access fails, return empty string
        return "";
    }
}

// Add source attribute to RTLIL object
void UhdmImporter::add_src_attribute(dict<RTLIL::IdString, RTLIL::Const>& attributes, const any* uhdm_obj) {
    std::string src = get_src_attribute(uhdm_obj);
    if (!src.empty()) {
        attributes[ID::src] = RTLIL::Const(src);
    }
}

// Get unique cell name by checking if it already exists
RTLIL::IdString UhdmImporter::get_unique_cell_name(const std::string& base_name) {
    RTLIL::IdString cell_name = RTLIL::escape_id(base_name);
    int suffix = 1;
    while (module->cells_.count(cell_name)) {
        suffix++;
        std::string unique_name = base_name + "_" + std::to_string(suffix);
        cell_name = RTLIL::escape_id(unique_name);
    }
    return cell_name;
}

// Import generate scopes (generate blocks)
void UhdmImporter::import_generate_scopes(const module_inst* uhdm_module) {
    // Check for GenScopeArray which contains generate blocks
    if (uhdm_module->Gen_scope_arrays()) {
        log("UHDM: Found %d generate scope arrays\n", (int)uhdm_module->Gen_scope_arrays()->size());
        for (auto gen_array : *uhdm_module->Gen_scope_arrays()) {
            if (!gen_array) {
                log("UHDM: Skipping null generate scope array\n");
                continue;
            }
            // Check if VpiName() is valid before using it
            std::string_view name_view = gen_array->VpiName();
            if (name_view.empty()) {
                log("UHDM: Generate scope array has empty name, skipping\n");
                continue;
            }
            std::string gen_name = std::string(name_view);
            log("UHDM: Processing generate scope array: %s\n", gen_name.c_str());
            
            // Process each generate scope in the array
            if (gen_array->Gen_scopes()) {
                log("UHDM: Found %d generate scopes in array %s\n", (int)gen_array->Gen_scopes()->size(), gen_name.c_str());
                for (auto gen_scope : *gen_array->Gen_scopes()) {
                    if (!gen_scope) {
                        log("UHDM: Skipping null generate scope\n");
                        continue;
                    }
                    import_gen_scope(gen_scope);
                }
            } else {
                log("UHDM: No generate scopes found in array %s\n", gen_name.c_str());
            }
        }
    } else {
        log("UHDM: No generate scope arrays found in module\n");
    }
}

// Import a single generate scope
void UhdmImporter::import_gen_scope(const gen_scope* uhdm_scope) {
    if (!uhdm_scope) return;
    current_scope = uhdm_scope;
    std::string scope_name = std::string(uhdm_scope->VpiName());
    std::string full_name = std::string(uhdm_scope->VpiFullName());
    
    // If VpiName is empty, extract from full name
    if (scope_name.empty() && !full_name.empty()) {
        // Extract the part after the last dot
        size_t last_dot = full_name.rfind('.');
        if (last_dot != std::string::npos) {
            scope_name = full_name.substr(last_dot + 1);
        } else {
            // No dot found, use everything after @ if present
            size_t at_pos = full_name.rfind('@');
            if (at_pos != std::string::npos) {
                scope_name = full_name.substr(at_pos + 1);
            } else {
                scope_name = full_name;
            }
        }
    }
    
    log("UHDM: Importing generate scope: %s (full: %s)\n", scope_name.c_str(), full_name.c_str());
    
    // Import variables declared in the generate scope
    if (uhdm_scope->Variables()) {
        log("UHDM: Found %d variables in generate scope\n", (int)uhdm_scope->Variables()->size());
        for (auto var : *uhdm_scope->Variables()) {
            // Variables can be logic_var or other types, we need to handle them
            // For now, create a wire for each variable
            std::string var_name = std::string(var->VpiName());
            std::string hierarchical_name = scope_name + "." + var_name;
            int width = get_width(var, current_instance);
            
            // Check if we already have this wire with the hierarchical name
            if (!name_map.count(hierarchical_name)) {
                RTLIL::Wire* w = create_wire(hierarchical_name, width);
                wire_map[var] = w;
                name_map[var_name] = w;  // Map the simple name for local references
                name_map[hierarchical_name] = w;  // Also map the full hierarchical name
                log("UHDM: Created wire '%s' (width=%d) for generate scope variable\n", hierarchical_name.c_str(), width);
            }
        }
    }
    
    // Import module instances within the generate scope
    if (uhdm_scope->Modules()) {
        log("UHDM: Found %d module instances in generate scope '%s'\n", 
            (int)uhdm_scope->Modules()->size(), scope_name.c_str());
        
        // Save current generate scope for module instances
        std::string saved_gen_scope = current_gen_scope;
        current_gen_scope = scope_name;
        
        for (auto mod_inst : *uhdm_scope->Modules()) {
            // Just import the module instance
            // The module definition should already exist from the top-level import
            log("UHDM: Importing module instance '%s' of type '%s' in generate scope\n",
                std::string(mod_inst->VpiName()).c_str(), std::string(mod_inst->VpiDefName()).c_str());
            import_instance(mod_inst);
        }
        
        // Restore previous generate scope
        current_gen_scope = saved_gen_scope;
    }
    
    // Import processes (always blocks) within the generate scope
    if (uhdm_scope->Process()) {
        log("UHDM: Found %d processes in generate scope\n", (int)uhdm_scope->Process()->size());
        // Save current generate scope for process naming
        std::string saved_gen_scope = current_gen_scope;
        current_gen_scope = scope_name;
        for (auto process : *uhdm_scope->Process()) {
            try {
                import_process(process);
            } catch (const std::exception& e) {
                log_error("UHDM: Exception in process import within generate scope: %s\n", e.what());
            }
        }
        // Restore previous generate scope
        current_gen_scope = saved_gen_scope;
    }
    
    // Import continuous assignments within the generate scope
    if (uhdm_scope->Cont_assigns()) {
        log("UHDM: Found %d continuous assignments in generate scope\n", (int)uhdm_scope->Cont_assigns()->size());
        // Save current generate scope for process naming
        std::string saved_gen_scope = current_gen_scope;
        current_gen_scope = scope_name;
        for (auto cont_assign : *uhdm_scope->Cont_assigns()) {
            try {
                import_continuous_assign(cont_assign);
            } catch (const std::exception& e) {
                log_error("UHDM: Exception in continuous assignment import within generate scope: %s\n", e.what());
            }
        }
        // Restore previous generate scope
        current_gen_scope = saved_gen_scope;
    }
    
    // Recursively import nested generate scopes
    if (uhdm_scope->Gen_scope_arrays()) {
        log("UHDM: Found nested generate scope arrays\n");
        for (auto nested_array : *uhdm_scope->Gen_scope_arrays()) {
            if (nested_array->Gen_scopes()) {
                for (auto nested_scope : *nested_array->Gen_scopes()) {
                    import_gen_scope(nested_scope);
                }
            }
        }
    }
    current_scope = nullptr;
}

YOSYS_NAMESPACE_END