/*
 * Module-specific UHDM to RTLIL translation
 * 
 * This file handles the translation of module-level constructs including
 * ports, nets, and module instantiations.
 */

#include "uhdm2rtlil.h"

YOSYS_NAMESPACE_BEGIN
PRIVATE_NAMESPACE_BEGIN

using namespace UHDM;

// Import a module port
void UhdmImporter::import_port(const port* uhdm_port) {
    std::string portname = uhdm_port->VpiName();
    int direction = uhdm_port->VpiDirection();
    
    if (mode_debug)
        log("  Importing port: %s (dir=%d)\n", portname.c_str(), direction);
    
    // Get port width
    int width = 1;
    if (auto port_ref = uhdm_port->Expr()) {
        width = get_width(port_ref);
    }
    
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
    std::string netname = uhdm_net->VpiName();
    
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
    std::string inst_name = uhdm_inst->VpiName();
    std::string module_name = uhdm_inst->VpiDefName();
    
    if (mode_debug)
        log("  Importing instance: %s of %s\n", inst_name.c_str(), module_name.c_str());
    
    RTLIL::Cell* cell = module->addCell(new_id(inst_name), RTLIL::escape_id(module_name));
    
    // Import port connections
    if (uhdm_inst->Ports()) {
        for (auto port : *uhdm_inst->Ports()) {
            std::string port_name = port->VpiName();
            
            if (auto actual = port->Actual()) {
                RTLIL::SigSpec sig = import_expression(actual);
                
                // Determine if this is input or output
                // For now, assume all connections are bidirectional
                cell->setPort(RTLIL::escape_id(port_name), sig);
            }
        }
    }
    
    // Import parameter assignments
    if (uhdm_inst->Param_assigns()) {
        for (auto param : *uhdm_inst->Param_assigns()) {
            std::string param_name = param->Lhs()->VpiName();
            
            if (auto rhs = param->Rhs()) {
                RTLIL::SigSpec value = import_expression(rhs);
                
                // Convert to parameter value
                if (value.is_fully_const()) {
                    cell->setParam(RTLIL::escape_id(param_name), value.as_const());
                }
            }
        }\n    }
}

// Create a wire with the given name and width
RTLIL::Wire* UhdmImporter::create_wire(const std::string& name, int width) {
    RTLIL::IdString wire_name = new_id(name);
    RTLIL::Wire* w = module->addWire(wire_name, width);
    return w;
}

// Generate a new unique ID
RTLIL::IdString UhdmImporter::new_id(const std::string& name) {
    if (mode_keep_names) {
        return RTLIL::escape_id(name);
    } else {
        return module->uniquify(RTLIL::escape_id(name));
    }
}

// Get name from UHDM object
std::string UhdmImporter::get_name(const any* uhdm_obj) {
    if (auto named = dynamic_cast<const vpi_tree_context*>(uhdm_obj)) {
        return named->VpiName();
    }
    return "";
}

// Get width from UHDM object
int UhdmImporter::get_width(const any* uhdm_obj) {
    // Default to 1 bit
    int width = 1;
    
    if (auto typed = dynamic_cast<const expr*>(uhdm_obj)) {
        if (typed->VpiSize() > 0) {
            width = typed->VpiSize();
        }
    }
    
    return width;
}

PRIVATE_NAMESPACE_END
YOSYS_NAMESPACE_END