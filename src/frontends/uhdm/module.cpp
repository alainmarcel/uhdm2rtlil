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
    int width = 1;
    // Get width from port typespec or range
    width = 1; // Default width
    
    RTLIL::Wire* w = create_wire(portname, width);
    
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
    
    // Skip if already created as port
    if (name_map.count(netname))
        return;
    
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
    RTLIL::IdString wire_name = new_id(name);
    RTLIL::Wire* w = module->addWire(wire_name, width);
    return w;
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
    // Default to 1 bit
    int width = 1;
    
    // Simplified width calculation
    // In real implementation, would check typespec, ranges, etc.
    width = 1;
    
    return width;
}

YOSYS_NAMESPACE_END