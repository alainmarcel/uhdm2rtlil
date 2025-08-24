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
#include <uhdm/ExprEval.h>
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
        
        // Add interface-specific attributes
        w->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
        
        // Get the interface type information from the port's typespec
        if (uhdm_port->Typespec()) {
            const UHDM::ref_typespec* ref_typespec = uhdm_port->Typespec();
            const UHDM::typespec* typespec = nullptr;
            
            // Get actual typespec from ref_typespec
            if (ref_typespec && ref_typespec->Actual_typespec()) {
                typespec = ref_typespec->Actual_typespec();
            }
            
            // Get interface type name
            if (typespec && typespec->UhdmType() == uhdminterface_typespec) {
                const UHDM::interface_typespec* iface_ts = any_cast<const UHDM::interface_typespec*>(typespec);
                std::string interface_type;
                std::string modport_name;
                
                // Check if this is a modport (has vpiIsModPort)
                if (iface_ts->VpiIsModPort()) {
                    // This is a modport, so get the modport name
                    modport_name = std::string(iface_ts->VpiName());
                    
                    // The parent should be the actual interface typespec
                    if (iface_ts->VpiParent() && iface_ts->VpiParent()->UhdmType() == uhdminterface_typespec) {
                        const UHDM::interface_typespec* parent_iface_ts = 
                            any_cast<const UHDM::interface_typespec*>(iface_ts->VpiParent());
                        interface_type = std::string(parent_iface_ts->VpiName());
                    } 
                } else {
                    // This is the interface itself
                    interface_type = std::string(iface_ts->VpiName());
                }

                if (interface_type.empty())
                {
                    const UHDM::any *lowconn = uhdm_port->Low_conn();
                    if (lowconn && lowconn->UhdmType() == uhdmref_obj)
                    {
                        const ref_obj *ref = (const ref_obj *)lowconn;
                        const any *actual = ref->Actual_group();
                        if (actual && actual->UhdmType() == uhdmmodport)
                        {
                            modport *mod = (modport *)actual;
                            const any *inst = mod->VpiParent();
                            interface_type = std::string(inst->VpiDefName());
                        }
                    }
                }

                // If we still don't have interface type, try other sources
                if (interface_type.empty()) {
                    if (ref_typespec && !ref_typespec->VpiDefName().empty()) {
                        interface_type = std::string(ref_typespec->VpiDefName());
                    } else if (!iface_ts->VpiDefName().empty()) {
                        interface_type = std::string(iface_ts->VpiDefName());
                    }
                }
                
                if (!interface_type.empty()) {
                    // Remove work@ prefix if present
                    if (interface_type.find("work@") == 0) {
                        interface_type = interface_type.substr(5);
                    }
                    
                    // Check if we need to use a parameterized interface name
                    std::string final_interface_type = interface_type;
                    
                    // Try to determine the WIDTH parameter from the context
                    // First check if the parent module has a WIDTH parameter
                    if (module->parameter_default_values.count(RTLIL::escape_id("WIDTH"))) {
                        // Build the parameterized interface name
                        std::string param_interface_name = RTLIL::escape_id("$paramod") + RTLIL::escape_id(interface_type);
                        param_interface_name +=  RTLIL::escape_id("WIDTH=");
                        RTLIL::Const width_val = module->parameter_default_values.at(RTLIL::escape_id("WIDTH"));
                        //if (width_val.flags & RTLIL::CONST_FLAG_SIGNED) {
                            param_interface_name += "s";
                        //}
                        param_interface_name += std::to_string(width_val.size()) + "'";
                        // Add binary representation
                        for (int i = width_val.size() - 1; i >= 0; i--) {
                            param_interface_name += (width_val[i] == RTLIL::State::S1) ? "1" : "0";
                        }
                        
                        // Check if this parameterized interface module exists
                        //if (design->module(RTLIL::escape_id(param_interface_name))) {
                            final_interface_type = param_interface_name;
                            log("UHDM: Using parameterized interface name: %s\n", final_interface_type.c_str());
                        //}
                    }
                    
                    w->attributes[RTLIL::escape_id("interface_type")] = RTLIL::Const( final_interface_type);
                }
                
                // Set modport name
                if (!modport_name.empty()) {
                    w->attributes[RTLIL::escape_id("interface_modport")] = RTLIL::Const(modport_name);
                }
            }
        }
        
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
    
    // Check if this port has reversed bit ordering
    bool upto = false;
    int start_offset = 0;
    int left = -1, right = -1;
    
    // Try to get range information from the port's typespec
    if (uhdm_port->Typespec()) {
        auto ref_typespec = uhdm_port->Typespec();
        if (ref_typespec && ref_typespec->Actual_typespec()) {
            auto typespec = ref_typespec->Actual_typespec();
            if (typespec && typespec->UhdmType() == uhdmlogic_typespec) {
                auto logic_typespec = any_cast<const UHDM::logic_typespec*>(typespec);
                if (logic_typespec->Ranges() && !logic_typespec->Ranges()->empty()) {
                    auto range = (*logic_typespec->Ranges())[0];
                    if (range->Left_expr() && range->Right_expr()) {
                        RTLIL::SigSpec left_spec = import_expression(range->Left_expr());
                        RTLIL::SigSpec right_spec = import_expression(range->Right_expr());
                        
                        if (left_spec.is_fully_const() && right_spec.is_fully_const()) {
                            left = left_spec.as_int();
                            right = right_spec.as_int();
                            
                            // Check if range is reversed (e.g., [0:7] instead of [7:0])
                            if (left < right) {
                                upto = true;
                                start_offset = left;
                                log("UHDM: Port '%s' has reversed bit ordering [%d:%d]\n", portname.c_str(), left, right);
                            } else {
                                start_offset = right;
                                log("UHDM: Port '%s' has normal bit ordering [%d:%d]\n", portname.c_str(), left, right);
                            }
                        }
                    }
                }
            }
        }
    }
    
    RTLIL::Wire* w = create_wire(portname, width, upto, start_offset);
    
    // Add source attribute
    add_src_attribute(w->attributes, uhdm_port);
    
    // Check if port is signed
    if (auto ref_typespec = uhdm_port->Typespec()) {
        // Check if typespec indicates signed
        bool is_signed = false;
        const UHDM::typespec* actual_typespec = nullptr;
        
        if (ref_typespec->Actual_typespec()) {
            actual_typespec = ref_typespec->Actual_typespec();
        }
        
        if (actual_typespec) {
            switch (actual_typespec->UhdmType()) {
                case uhdmlogic_typespec:
                    if (auto logic_ts = dynamic_cast<const UHDM::logic_typespec*>(actual_typespec)) {
                        is_signed = logic_ts->VpiSigned();
                    }
                    break;
                case uhdmint_typespec:
                case uhdminteger_typespec:
                case uhdmbyte_typespec:
                case uhdmshort_int_typespec:
                case uhdmlong_int_typespec:
                    is_signed = true;  // These are signed by default
                    break;
                default:
                    // Other typespec types are not handled
                    break;
            }
            
            if (is_signed) {
                log("UHDM: Port '%s' is signed\n", portname.c_str());
                w->is_signed = true;
            }
        }
    }
    
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
        log_flush();
        return;
    }
    
    // Also check if wire already exists in module
    RTLIL::IdString wire_id = RTLIL::escape_id(netname);
    if (module->wire(wire_id)) {
        log("UHDM: Wire '%s' already exists in module, skipping net import\n", wire_id.c_str());
        log_flush();
        return;
    }
    
    // Also skip if this is a memory that was already created
    if (module->memories.count(wire_id) > 0) {
        log("UHDM: Net '%s' already exists as memory, skipping net import\n", netname.c_str());
        log_flush();
        return;
    }
    
    // Check if this net should be imported as a memory
    if (is_memory_array(uhdm_net)) {
        log("UHDM: Net '%s' has both packed and unpacked dimensions - creating memory\n", netname.c_str());
        
        // Get packed dimension (width) from typespec
        int width = 1;
        if (uhdm_net->Typespec()) {
            auto ref_typespec = uhdm_net->Typespec();
            const UHDM::typespec* typespec = nullptr;
            
            if (ref_typespec && ref_typespec->Actual_typespec()) {
                typespec = ref_typespec->Actual_typespec();
            }
            if (typespec && typespec->UhdmType() == uhdmlogic_typespec) {
                auto logic_typespec = any_cast<const UHDM::logic_typespec*>(typespec);
                width = get_width_from_typespec(logic_typespec, inst);
            }
        }
        
        // Get unpacked dimension (size) from net ranges
        // Note: regular nets don't have unpacked dimensions - this shouldn't happen
        // but we'll default to size 1
        int size = 1;
        log_warning("UHDM: Net '%s' detected as memory but regular nets don't have unpacked dimensions\n", netname.c_str());
        
        // Create RTLIL memory object
        RTLIL::IdString mem_id = RTLIL::escape_id(netname);
        RTLIL::Memory* memory = new RTLIL::Memory;
        memory->name = mem_id;
        memory->width = width;
        memory->size = size;
        memory->start_offset = 0;
        
        // Add source attribute
        add_src_attribute(memory->attributes, uhdm_net);
        
        // Add memory to module
        module->memories[mem_id] = memory;
        
        if (mode_debug)
            log("    Created memory: %s (width=%d, size=%d)\n", mem_id.c_str(), width, size);
        
        // Don't create a wire for memory arrays
        return;
    }
    
    // Normal net - create as wire
    int width = get_width(uhdm_net, inst);
    
    // Check if this net has reversed bit ordering
    bool upto = false;
    int start_offset = 0;
    int left = -1, right = -1;
    
    // Try to get range information from the net's typespec
    if (uhdm_net->Typespec()) {
        auto ref_typespec = uhdm_net->Typespec();
        if (ref_typespec && ref_typespec->Actual_typespec()) {
            auto typespec = ref_typespec->Actual_typespec();
            if (typespec && typespec->UhdmType() == uhdmlogic_typespec) {
                auto logic_typespec = any_cast<const UHDM::logic_typespec*>(typespec);
                if (logic_typespec->Ranges() && !logic_typespec->Ranges()->empty()) {
                    auto range = (*logic_typespec->Ranges())[0];
                    if (range->Left_expr() && range->Right_expr()) {
                        RTLIL::SigSpec left_spec = import_expression(range->Left_expr());
                        RTLIL::SigSpec right_spec = import_expression(range->Right_expr());
                        
                        if (left_spec.is_fully_const() && right_spec.is_fully_const()) {
                            left = left_spec.as_int();
                            right = right_spec.as_int();
                            
                            // Check if range is reversed (e.g., [0:7] instead of [7:0])
                            if (left < right) {
                                upto = true;
                                start_offset = left;
                                log("UHDM: Net '%s' has reversed bit ordering [%d:%d]\n", netname.c_str(), left, right);
                            } else {
                                start_offset = right;
                                log("UHDM: Net '%s' has normal bit ordering [%d:%d]\n", netname.c_str(), left, right);
                            }
                        }
                    }
                }
            }
        }
    }
    
    RTLIL::Wire* w = create_wire(netname, width, upto, start_offset);
    add_src_attribute(w->attributes, uhdm_net);
    
    // Check if net is signed
    if (auto ref_typespec = uhdm_net->Typespec()) {
        // Check if typespec indicates signed
        bool is_signed = false;
        const UHDM::typespec* actual_typespec = nullptr;
        
        if (ref_typespec->Actual_typespec()) {
            actual_typespec = ref_typespec->Actual_typespec();
        }
        
        if (actual_typespec) {
            switch (actual_typespec->UhdmType()) {
                case uhdmlogic_typespec:
                    if (auto logic_ts = dynamic_cast<const UHDM::logic_typespec*>(actual_typespec)) {
                        is_signed = logic_ts->VpiSigned();
                    }
                    break;
                case uhdmint_typespec:
                case uhdminteger_typespec:
                case uhdmbyte_typespec:
                case uhdmshort_int_typespec:
                case uhdmlong_int_typespec:
                    is_signed = true;  // These are signed by default
                    break;
                default:
                    // Other typespec types are not handled
                    break;
            }
            
            if (is_signed) {
                log("UHDM: Net '%s' is signed\n", netname.c_str());
                w->is_signed = true;
            }
        }
    }
    
    // Add wiretype attribute for struct types
    log("UHDM: Checking for struct type on net '%s' (UhdmType=%d)\n", netname.c_str(), uhdm_net->UhdmType());
    
    // Check if net has a typespec (works for both logic_net and regular net)
    const ref_typespec* ref_ts = nullptr;
    
    if (uhdm_net->UhdmType() == uhdmlogic_net) {
        auto logic_net = any_cast<const UHDM::logic_net*>(uhdm_net);
        ref_ts = logic_net->Typespec();
        log("UHDM: Net is a logic_net\n");
    } else if (uhdm_net->Typespec()) {
        // Regular net with typespec
        ref_ts = uhdm_net->Typespec();
        log("UHDM: Net has typespec\n");
    }
    
    if (ref_ts) {
        log("UHDM: Found ref_typespec\n");
        if (auto actual_typespec = ref_ts->Actual_typespec()) {
            log("UHDM: Found actual_typespec (UhdmType=%d)\n", actual_typespec->UhdmType());
            if (actual_typespec->UhdmType() == uhdmstruct_typespec) {
                log("UHDM: typespec is a struct_typespec\n");
                // Get the struct type name
                std::string type_name;
                if (!ref_ts->VpiName().empty()) {
                    type_name = ref_ts->VpiName();
                } else if (!actual_typespec->VpiName().empty()) {
                    type_name = actual_typespec->VpiName();
                }
                
                if (!type_name.empty()) {
                    w->attributes[RTLIL::escape_id("wiretype")] = RTLIL::escape_id(type_name);
                    log("UHDM: Added wiretype attribute '\\%s' to wire '%s'\n", type_name.c_str(), w->name.c_str());
                } else {
                    log("UHDM: Could not get type name for struct\n");
                }
            }
        }
    }
    
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
    
    // Check if this is a net declaration assignment (initialization)
    bool is_net_decl_assign = uhdm_assign->VpiNetDeclAssign();
    
    const expr* lhs_expr = uhdm_assign->Lhs();
    const expr* rhs_expr = uhdm_assign->Rhs();
    
    if (mode_debug && lhs_expr) {
        log("  LHS type: %s, VpiType: %d, NetDeclAssign: %d\n", 
            UHDM::UhdmName(lhs_expr->UhdmType()).c_str(), 
            lhs_expr->VpiType(),
            is_net_decl_assign);
    }
    
    RTLIL::SigSpec lhs = import_expression(lhs_expr);
    RTLIL::SigSpec rhs = import_expression(rhs_expr);
    
    // Handle size mismatch
    if (lhs.size() != rhs.size()) {
        if (rhs.size() == 1) {
            // Extend single bit to match LHS width by replicating the bit
            // This handles unbased unsized literals like 'x, 'z, '0, '1 correctly
            if (rhs.is_fully_const()) {
                RTLIL::State bit_val = rhs.as_const().bits()[0];
                rhs = RTLIL::SigSpec(RTLIL::Const(bit_val, lhs.size()));
            } else {
                // For non-constant single bits, zero-extend
                rhs = {rhs, RTLIL::SigSpec(RTLIL::State::S0, lhs.size() - 1)};
            }
        } else if (rhs.size() < lhs.size()) {
            // Zero-extend RHS to match LHS width
            log_debug("Extending RHS from %d to %d bits\n", rhs.size(), lhs.size());
            RTLIL::SigSpec extended = module->addWire(NEW_ID, lhs.size());
            module->addPos(NEW_ID, rhs, extended);
            rhs = extended;
        } else {
            // Truncate RHS to match LHS width
            log_debug("Truncating RHS from %d to %d bits\n", rhs.size(), lhs.size());
            rhs = rhs.extract(0, lhs.size());
        }
    }
    
    if (is_net_decl_assign) {
        // Check if the RHS is a constant expression
        bool is_constant = rhs.is_fully_const();
        
        if (is_constant) {
            // This is a constant initialization, create an init process
            // Get the source location for the process name
            int line_num = uhdm_assign->VpiLineNo();
            int col_num = uhdm_assign->VpiColumnNo();
            int end_line = uhdm_assign->VpiEndLineNo();
            int end_col = uhdm_assign->VpiEndColumnNo();
            
            // Create process name based on line number
            std::string proc_name = stringf("$proc$dut.sv:%d$%d", line_num, autoidx++);
            
            // Create an init process for this initialization
            RTLIL::Process *proc = module->addProcess(RTLIL::escape_id(proc_name));
            proc->attributes[ID::src] = stringf("dut.sv:%d.%d-%d.%d", 
                line_num, col_num, end_line, end_col);
            
            // Create a temporary wire for the assignment
            RTLIL::Wire *temp_wire = module->addWire(NEW_ID, lhs.size());
            
            // Add the assignment to the root case
            proc->root_case.actions.push_back(RTLIL::SigSig(temp_wire, rhs));
            
            // Add sync always (empty) - this matches Verilog frontend behavior
            RTLIL::SyncRule *sync_always = new RTLIL::SyncRule;
            sync_always->type = RTLIL::STa; // Always sync type
            proc->syncs.push_back(sync_always);
            
            // Create the init sync and add the action
            RTLIL::SyncRule *sync_init = new RTLIL::SyncRule;
            sync_init->type = RTLIL::STi; // Init sync type
            sync_init->actions.push_back(RTLIL::SigSig(lhs, temp_wire));
            proc->syncs.push_back(sync_init);
            
            if (mode_debug)
                log("  Created init process %s for net declaration assignment with constant value\n", proc_name.c_str());
        } else {
            // Non-constant expression in net declaration, treat as continuous assignment
            module->connect(lhs, rhs);
            
            if (mode_debug)
                log("  Created continuous assignment for net declaration with non-constant expression\n");
        }
    } else {
        // Regular continuous assignment
        module->connect(lhs, rhs);
    }
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
                RTLIL::SigSpec value = import_expression(any_cast<const expr*>(rhs));
                
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
    
    // If the module has interface ports, add the interfaces_replaced_in_module attribute
    // but don't modify the module name
    if (has_interface_ports) {
        // We'll add the attribute later when creating the module
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
                
                // For interface ports, keep width as 1
                int wire_width = width;
                if (base_wire->attributes.count(RTLIL::escape_id("is_interface"))) {
                    wire_width = 1;
                }
                
                RTLIL::Wire* param_wire = param_mod->addWire(base_wire->name, wire_width);
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
                            
                            // Check if this is an interface port that needs interface_type attribute
                            RTLIL::Wire* param_wire = wire_pair.second;
                            if (param_wire->attributes.count(RTLIL::escape_id("is_interface")) &&
                                !param_wire->attributes.count(RTLIL::escape_id("interface_type"))) {
                                // Find the corresponding port in the module definition
                                if (mod_def->Ports()) {
                                    for (auto port : *mod_def->Ports()) {
                                        std::string port_name = std::string(port->VpiName());
                                        if (RTLIL::escape_id(port_name) == param_wire->name.str()) {
                                            // Found the port, check if it has interface typespec
                                            if (port->Typespec()) {
                                                const UHDM::ref_typespec* ref_typespec = port->Typespec();
                                                const UHDM::typespec* typespec = nullptr;
                                                
                                                if (ref_typespec && ref_typespec->Actual_typespec()) {
                                                    typespec = ref_typespec->Actual_typespec();
                                                }
                                                
                                                if (typespec && typespec->UhdmType() == uhdminterface_typespec) {
                                                    const UHDM::interface_typespec* iface_ts = any_cast<const UHDM::interface_typespec*>(typespec);
                                                    
                                                    std::string interface_type;
                                                    std::string modport_name;
                                                    
                                                    // Check if this is a modport
                                                    if (iface_ts->VpiIsModPort()) {
                                                        modport_name = std::string(iface_ts->VpiName());
                                                        
                                                        // The parent should be the actual interface typespec
                                                        if (iface_ts->VpiParent() && iface_ts->VpiParent()->UhdmType() == uhdminterface_typespec) {
                                                            const UHDM::interface_typespec* parent_iface_ts = 
                                                                any_cast<const UHDM::interface_typespec*>(iface_ts->VpiParent());
                                                            interface_type = std::string(parent_iface_ts->VpiName());
                                                        }
                                                    } else {
                                                        interface_type = std::string(iface_ts->VpiName());
                                                    }
                                                    
                                                    if (!interface_type.empty()) {
                                                        if (interface_type.find("work@") == 0) {
                                                            interface_type = interface_type.substr(5);
                                                        }
                                                        
                                                        // Check if we need to use a parameterized interface name
                                                        // The parameterized module has WIDTH parameter, so we should check if
                                                        // a parameterized interface with the same WIDTH exists
                                                        std::string final_interface_type = interface_type;
                                                        if (param_mod->parameter_default_values.count(RTLIL::escape_id("WIDTH"))) {
                                                            // Build the parameterized interface name
                                                            std::string param_interface_name = "$paramod\\" + interface_type;
                                                            param_interface_name += "\\WIDTH=";
                                                            RTLIL::Const width_val = param_mod->parameter_default_values.at(RTLIL::escape_id("WIDTH"));
                                                            if (width_val.flags & RTLIL::CONST_FLAG_SIGNED) {
                                                                param_interface_name += "s";
                                                            }
                                                            param_interface_name += std::to_string(width_val.size()) + "'";
                                                            // Add binary representation
                                                            for (int i = width_val.size() - 1; i >= 0; i--) {
                                                                param_interface_name += (width_val[i] == RTLIL::State::S1) ? "1" : "0";
                                                            }
                                                            
                                                            // Check if this parameterized interface module exists
                                                            if (design->module(RTLIL::escape_id(param_interface_name))) {
                                                                final_interface_type = param_interface_name;
                                                                log("UHDM: Using parameterized interface name: %s\n", final_interface_type.c_str());
                                                            }
                                                        }
                                                        
                                                        param_wire->attributes[RTLIL::escape_id("interface_type")] = RTLIL::Const("\\" + final_interface_type);
                                                        log("UHDM: Added interface_type attribute '%s' to parameterized module wire '%s'\n", 
                                                            final_interface_type.c_str(), param_wire->name.c_str());
                                                    }
                                                    
                                                    if (!modport_name.empty()) {
                                                        param_wire->attributes[RTLIL::escape_id("interface_modport")] = RTLIL::Const(modport_name);
                                                    }
                                                }
                                            }
                                            break;
                                        }
                                    }
                                }
                            }
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
                    const ref_obj* ref = any_cast<const ref_obj*>(high_conn);
                    const any* actual = ref->Actual_group();
                    
                    if (actual && actual->UhdmType() == uhdminterface_inst) {
                        const interface_inst* iface = any_cast<const interface_inst*>(actual);
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
                    actual_sig = import_expression(any_cast<const expr*>(high_conn));
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
                            // The wire name should follow Yosys convention: $dummywireforinterface\<interface_name>
                            std::string interface_wire_name;
                            if (actual_sig.is_wire() && actual_sig.as_wire()) {
                                std::string interface_name = actual_sig.as_wire()->name.str();
                                if (interface_name[0] == '\\') {
                                    interface_name = interface_name.substr(1);
                                }
                                interface_wire_name = "$dummywireforinterface\\" + interface_name;
                            } else {
                                // Fallback: use instance name + port name
                                interface_wire_name = "$dummywireforinterface\\" + inst_name + "_" + port_name;
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
RTLIL::Wire* UhdmImporter::create_wire(const std::string& name, int width, bool upto, int start_offset) {
    log("UHDM: Creating wire '%s' (width=%d, upto=%d, start_offset=%d, mode_keep_names=%s)\n", 
        name.c_str(), width, upto ? 1 : 0, start_offset, mode_keep_names ? "true" : "false");
    
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
        w->upto = upto;
        w->start_offset = start_offset;
        log("UHDM: Successfully created wire '%s' (upto=%d, start_offset=%d)\n", wire_name.c_str(), w->upto ? 1 : 0, w->start_offset);
        
        // Check if this wire is being created for an interface connection
        // Interface connection wires have names like $dummywireforinterface\bus1
        std::string base_name = name;
        if (base_name.find("$dummywireforinterface\\") == 0) {
            // This is an interface connection wire
            w->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
            log("UHDM: Marked wire '%s' as interface connection\n", wire_name.c_str());
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
        
        // Check if it's a hier_path (hierarchical reference like in_struct.base.data)
        if (auto hier = dynamic_cast<const UHDM::hier_path*>(uhdm_obj)) {
            log("UHDM: Found hier_path object\n");
            
            // Use ExprEval to get the typespec of the hier_path
            ExprEval eval;
            bool invalidValue = false;
            
            // Get the typespec using decodeHierPath
            any* typespec_obj = eval.decodeHierPath(
                const_cast<hier_path*>(hier), 
                invalidValue, 
                inst,  // Use the instance scope
                hier,  // pexpr
                ExprEval::ReturnType::TYPESPEC,  // Get the typespec
                false     // muteError
            );
            
            if (!invalidValue && typespec_obj) {
                log("UHDM: decodeHierPath returned typespec\n");
                
                // Get the size from the typespec
                // From Surelog: eval.size(typespec, invalidValue, context, nullptr, !sizeMode)
                uint64_t size = eval.size(typespec_obj, invalidValue, inst, typespec_obj, true, false);
                if (!invalidValue && size > 0) {
                    log("UHDM: ExprEval::size returned %lu\n", (unsigned long)size);
                    return size;
                } else {
                    log("UHDM: ExprEval::size failed or returned 0\n");
                }
            } else {
                log("UHDM: decodeHierPath failed to return typespec\n");
            }
        }
        
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