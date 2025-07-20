/*
 * Module-specific UHDM to RTLIL translation
 * 
 * This file handles the translation of module-level constructs including
 * ports, nets, and module instantiations.
 */

#include "uhdm2rtlil.h"

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
    int width = get_width(uhdm_port);
    
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
void UhdmImporter::import_net(const net* uhdm_net) {
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
    
    int width = get_width(uhdm_net);
    RTLIL::Wire* w = create_wire(netname, width);
    
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
    
    RTLIL::SigSpec lhs = import_expression(uhdm_assign->Lhs());
    RTLIL::SigSpec rhs = import_expression(uhdm_assign->Rhs());
    
    if (lhs.size() != rhs.size()) {
        if (rhs.size() == 1) {
            // Extend single bit to match LHS width
            rhs = {rhs, RTLIL::SigSpec(RTLIL::State::S0, lhs.size() - 1)};
        } else {
            log_warning("Assignment width mismatch: LHS=%d, RHS=%d\n", 
                       lhs.size(), rhs.size());
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
    std::string inst_name = std::string(uhdm_inst->VpiName());
    std::string module_name = std::string(uhdm_inst->VpiDefName());
    
    if (mode_debug)
        log("  Importing instance: %s of %s\n", inst_name.c_str(), module_name.c_str());
    
    RTLIL::Cell* cell = module->addCell(new_id(inst_name), RTLIL::escape_id(module_name));
    
    // Import port connections
    if (uhdm_inst->Ports()) {
        for (auto port : *uhdm_inst->Ports()) {
            std::string port_name = std::string(port->VpiName());
            
            // Port connection handling would go here
            // For now, skip port connections as port->Actual() method doesn't exist
        }
    }
    
    // Import parameter assignments
    if (uhdm_inst->Param_assigns()) {
        for (auto param : *uhdm_inst->Param_assigns()) {
            std::string param_name = std::string(param->Lhs()->VpiName());
            
            if (auto rhs = param->Rhs()) {
                RTLIL::SigSpec value = import_expression(static_cast<const expr*>(rhs));
                
                // Convert to parameter value
                if (value.is_fully_const()) {
                    cell->setParam(RTLIL::escape_id(param_name), value.as_const());
                }
            }
        }
    }
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
int UhdmImporter::get_width(const any* uhdm_obj) {
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
                return get_width_from_typespec(typespec);
            } else {
                log("UHDM: Port has no typespec\n");
            }
        }
        
        // Check if it's a net and try to get typespec
        if (auto net = dynamic_cast<const UHDM::net*>(uhdm_obj)) {
            log("UHDM: Found net object\n");
            if (auto typespec = net->Typespec()) {
                log("UHDM: Net has typespec, calling get_width_from_typespec\n");
                return get_width_from_typespec(typespec);
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
int UhdmImporter::get_width_from_typespec(const UHDM::any* typespec) {
    if (!typespec) return 1;
    
    try {
        log("UHDM: Analyzing typespec for width determination\n");
        
        // Use UHDM::ExprEval to get the actual size of the typespec
        UHDM::ExprEval eval;
        bool invalidValue = false;
        
        // Call eval.size() like Surelog does
        // From Surelog: eval.size(typespec, invalidValue, context, nullptr, !sizeMode)
        uint64_t size = eval.size(typespec, invalidValue, nullptr, nullptr, true);
        
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

YOSYS_NAMESPACE_END