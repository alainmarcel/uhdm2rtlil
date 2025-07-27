/*
 * Expression handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog expressions
 * including operations, constants, and references.
 */

#include "uhdm2rtlil.h"
#include <uhdm/logic_var.h>
#include <uhdm/logic_net.h>
#include <uhdm/net.h>
#include <uhdm/port.h>
#include <uhdm/struct_typespec.h>
#include <uhdm/typespec_member.h>
#include <uhdm/vpi_visitor.h>
#include <uhdm/assignment.h>
#include <uhdm/uhdm_vpi_user.h>
#include <uhdm/uhdm_types.h>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Import any expression
RTLIL::SigSpec UhdmImporter::import_expression(const expr* uhdm_expr) {
    if (!uhdm_expr)
        return RTLIL::SigSpec();
    
    int obj_type = uhdm_expr->VpiType();
    
    switch (obj_type) {
        case vpiConstant:
            return import_constant(static_cast<const constant*>(uhdm_expr));
        case vpiOperation:
            return import_operation(static_cast<const operation*>(uhdm_expr));
        case vpiRefObj:
            return import_ref_obj(static_cast<const ref_obj*>(uhdm_expr));
        case vpiPartSelect:
            return import_part_select(static_cast<const part_select*>(uhdm_expr));
        case vpiBitSelect:
            return import_bit_select(static_cast<const bit_select*>(uhdm_expr));
        case vpiConcatOp:
            return import_concat(static_cast<const operation*>(uhdm_expr));
        case vpiAssignment:
            // This should not be called on assignment directly
            // Assignment is a statement, not an expression
            log_warning("vpiAssignment (type 3) passed to import_expression - assignments should be handled as statements, not expressions\n");
            return RTLIL::SigSpec();
        case vpiHierPath:
            return import_hier_path(static_cast<const hier_path*>(uhdm_expr), current_instance);
        case vpiIndexedPartSelect:
            return import_indexed_part_select(static_cast<const indexed_part_select*>(uhdm_expr));
        case vpiPort:
            // Handle port as expression - this happens when ports are referenced in connections
            {
                const UHDM::port* port = static_cast<const UHDM::port*>(static_cast<const any*>(uhdm_expr));
                std::string port_name = std::string(port->VpiName());
                log("    Handling port '%s' as expression\n", port_name.c_str());
                
                // Check if this port has a Low_conn which would be the actual net/wire
                if (port->Low_conn()) {
                    log("    Port has Low_conn, importing that instead\n");
                    return import_expression(static_cast<const expr*>(port->Low_conn()));
                }
                
                // Otherwise try to find the wire in the current module
                RTLIL::IdString wire_id = RTLIL::escape_id(port_name);
                if (module->wire(wire_id)) {
                    log("    Found wire '%s' for port\n", wire_id.c_str());
                    return RTLIL::SigSpec(module->wire(wire_id));
                }
                
                // Try looking in the name_map
                auto it = name_map.find(port_name);
                if (it != name_map.end()) {
                    log("    Found wire in name_map for port '%s'\n", port_name.c_str());
                    return RTLIL::SigSpec(it->second);
                }
                
                log_warning("Port '%s' not found as wire in module\n", port_name.c_str());
                return RTLIL::SigSpec();
            }
        default:
            log_warning("Unsupported expression type: %s\n", UhdmName(static_cast<UHDM_OBJECT_TYPE>(obj_type)).c_str());
            return RTLIL::SigSpec();
    }
}

// Import constant value
RTLIL::SigSpec UhdmImporter::import_constant(const constant* uhdm_const) {
    int const_type = uhdm_const->VpiConstType();
    std::string value = std::string(uhdm_const->VpiValue());
    int size = uhdm_const->VpiSize();
    
    log("UHDM: Importing constant: %s (type=%d, size=%d)\n", 
        value.c_str(), const_type, size);
    
    switch (const_type) {
        case vpiBinaryConst: {
            std::string bin_str;
            // Handle UHDM format: "BIN:value" or traditional "'b prefix"
            if (value.substr(0, 4) == "BIN:") {
                bin_str = value.substr(4);
            } else if (value.length() > 2 && value[1] == 'b') {
                // Remove 'b prefix
                bin_str = value.substr(2);
            } else {
                bin_str = value;
            }
            
            // Create constant with proper size
            RTLIL::Const const_val = RTLIL::Const::from_string(bin_str);
            if (size > 0 && const_val.size() != size) {
                // Resize to match specified size
                if (const_val.size() < size) {
                    const_val.bits().resize(size, RTLIL::State::S0);
                } else {
                    const_val.bits().resize(size);
                }
            }
            return RTLIL::SigSpec(const_val);
        }
        case vpiHexConst: {
            if (mode_debug)
                log("    vpiHexConst: value='%s', size=%d\n", value.c_str(), size);
            
            std::string hex_str;
            // Handle UHDM format: "HEX:value" or traditional "'h prefix"
            if (value.substr(0, 4) == "HEX:") {
                hex_str = value.substr(4);
            } else if (value.length() > 2 && value.substr(value.length()-2, 2).find('h') != std::string::npos) {
                // Remove 'h prefix
                hex_str = value.substr(2);
            } else {
                hex_str = value;
            }
            
            if (mode_debug)
                log("    Parsed hex_str='%s', creating constant with size=%d\n", hex_str.c_str(), size);
            
            // Create hex constant with proper bit width
            // Convert hex string to integer, then create constant with specified size
            try {
                uint64_t hex_val = std::stoull(hex_str, nullptr, 16);
                RTLIL::Const const_val(hex_val, size > 0 ? size : 32);
                return RTLIL::SigSpec(const_val);
            } catch (const std::exception& e) {
                log_warning("Failed to parse hex value '%s': %s\n", hex_str.c_str(), e.what());
                // Fallback to string parsing
                RTLIL::Const const_val = RTLIL::Const::from_string("'h" + hex_str);
                if (size > 0 && const_val.size() != size) {
                    const_val = const_val.extract(0, size);
                }
                return RTLIL::SigSpec(const_val);
            }
        }
        case vpiDecConst: {
            std::string dec_str = value.substr(4);
            int int_val = std::stoi(dec_str);
            return RTLIL::SigSpec(RTLIL::Const(int_val, size));
        }
        case vpiIntConst: {
            std::string int_str = value.substr(4);
            int int_val = std::stoi(int_str);
            return RTLIL::SigSpec(RTLIL::Const(int_val, 32));
        }
        case vpiUIntConst: {
            if (mode_debug)
                log("    vpiUIntConst: value='%s', size=%d\n", value.c_str(), size);
            try {
                // Handle UHDM format: "UINT:value"
                if (value.substr(0, 5) == "UINT:") {
                    std::string num_str = value.substr(5);
                    unsigned int uint_val = std::stoul(num_str);
                    return RTLIL::SigSpec(RTLIL::Const(uint_val, size));
                } else {
                    // Handle plain number format
                    unsigned int uint_val = std::stoul(value);
                    return RTLIL::SigSpec(RTLIL::Const(uint_val, size));
                }
            } catch (const std::exception& e) {
                log_warning("Failed to parse UInt constant '%s': %s\n", value.c_str(), e.what());
                return RTLIL::SigSpec(RTLIL::State::Sx);
            }
        }
        default:
            log_warning("Unsupported constant type: %d\n", const_type);
            return RTLIL::SigSpec(RTLIL::State::Sx);
    }
}

// Import operation
RTLIL::SigSpec UhdmImporter::import_operation(const operation* uhdm_op) {
    int op_type = uhdm_op->VpiOpType();
    
    if (mode_debug)
        log("    Importing operation: %d\n", op_type);
    
    // Get operands
    std::vector<RTLIL::SigSpec> operands;
    if (uhdm_op->Operands()) {
        for (auto operand : *uhdm_op->Operands()) {
            operands.push_back(import_expression(static_cast<const expr*>(operand)));
        }
    }
    
    switch (op_type) {
        case vpiNotOp:
            if (operands.size() == 1) {
                // Create a logic_not cell with unique naming using counter
                std::string op_src = get_src_attribute(uhdm_op);
                logic_not_counter++;
                std::string cell_name_str;
                if (!op_src.empty()) {
                    cell_name_str = "$logic_not$" + op_src;
                    if (!current_gen_scope.empty()) {
                        cell_name_str += "$" + current_gen_scope;
                    }
                    cell_name_str += "$" + std::to_string(logic_not_counter);
                } else {
                    cell_name_str = "$logic_not$auto";
                    if (!current_gen_scope.empty()) {
                        cell_name_str += "$" + current_gen_scope;
                    }
                    cell_name_str += "$" + std::to_string(logic_not_counter);
                }
                
                log("UHDM: import_operation creating logic_not cell with name: %s (gen_scope=%s)\n", 
                    cell_name_str.c_str(), current_gen_scope.c_str());
                RTLIL::IdString cell_name = RTLIL::escape_id(cell_name_str);
                RTLIL::Cell* not_cell = module->addCell(cell_name, ID($logic_not));
                not_cell->setParam(ID::A_SIGNED, 0);
                not_cell->setParam(ID::A_WIDTH, operands[0].size());
                not_cell->setParam(ID::Y_WIDTH, 1);
                add_src_attribute(not_cell->attributes, uhdm_op);
                
                // Create output wire with source-based name
                std::string wire_name_str = cell_name_str + "_Y";
                RTLIL::IdString wire_name = RTLIL::escape_id(wire_name_str);
                RTLIL::Wire* output_wire = module->addWire(wire_name, 1);
                add_src_attribute(output_wire->attributes, uhdm_op);

                not_cell->setPort(ID::A, operands[0]);
                not_cell->setPort(ID::Y, output_wire);
                
                return RTLIL::SigSpec(output_wire);
            }
            break;
        case vpiLogAndOp:
            if (operands.size() == 2)
                return module->And(NEW_ID, operands[0], operands[1]);
            break;
        case vpiLogOrOp:
            if (operands.size() == 2)
                return module->Or(NEW_ID, operands[0], operands[1]);
            break;
        case vpiBitAndOp:
            if (operands.size() == 2)
                return module->And(NEW_ID, operands[0], operands[1]);
            break;
        case vpiBitOrOp:
            if (operands.size() == 2)
                return module->Or(NEW_ID, operands[0], operands[1]);
            break;
        case vpiBitXorOp:
            if (operands.size() == 2)
                return module->Xor(NEW_ID, operands[0], operands[1]);
            break;
        case vpiBitNegOp:
            if (operands.size() == 1)
                return module->Not(NEW_ID, operands[0]);
            break;
        case vpiAddOp:
            if (operands.size() == 2)
                return module->Add(NEW_ID, operands[0], operands[1]);
            break;
        case vpiSubOp:
            if (operands.size() == 2)
                return module->Sub(NEW_ID, operands[0], operands[1]);
            break;
        case vpiMultOp:
            if (operands.size() == 2)
                return module->Mul(NEW_ID, operands[0], operands[1]);
            break;
        case vpiEqOp:
            if (operands.size() == 2)
                return module->Eq(NEW_ID, operands[0], operands[1]);
            break;
        case vpiNeqOp:
            if (operands.size() == 2)
                return module->Ne(NEW_ID, operands[0], operands[1]);
            break;
        case vpiLtOp:
            if (operands.size() == 2)
                return module->Lt(NEW_ID, operands[0], operands[1]);
            break;
        case vpiLeOp:
            if (operands.size() == 2)
                return module->Le(NEW_ID, operands[0], operands[1]);
            break;
        case vpiGtOp:
            if (operands.size() == 2)
                return module->Gt(NEW_ID, operands[0], operands[1]);
            break;
        case vpiGeOp:
            if (operands.size() == 2)
                return module->Ge(NEW_ID, operands[0], operands[1]);
            break;
        case vpiConditionOp:
            if (operands.size() == 3)
                return module->Mux(NEW_ID, operands[0], operands[2], operands[1]);
            break;
        default:
            log_warning("Unsupported operation type: %d\n", op_type);
            return RTLIL::SigSpec();
    }
    
    log_warning("Operation %d: incorrect number of operands (%d)\n", 
                op_type, (int)operands.size());
    return RTLIL::SigSpec();
}

// Import reference to object
RTLIL::SigSpec UhdmImporter::import_ref_obj(const ref_obj* uhdm_ref) {
    // Get the referenced object name
    std::string ref_name = std::string(uhdm_ref->VpiName());
    
    if (mode_debug)
        log("    Importing ref_obj: %s (current_gen_scope: %s)\n", ref_name.c_str(), current_gen_scope.c_str());
    
    // Check if this is a parameter reference
    RTLIL::IdString param_id = RTLIL::escape_id(ref_name);
    if (module->parameter_default_values.count(param_id)) {
        RTLIL::Const param_value = module->parameter_default_values.at(param_id);
        log("UHDM: Found parameter %s with value %s (bits=%d)\n", 
            ref_name.c_str(), param_value.as_string().c_str(), param_value.size());
        return RTLIL::SigSpec(param_value);
    }
    
    // If we're in a generate scope, first try the hierarchical name
    if (!current_gen_scope.empty()) {
        std::string hierarchical_name = current_gen_scope + "." + ref_name;
        if (name_map.count(hierarchical_name)) {
            RTLIL::Wire* wire = name_map[hierarchical_name];
            log("UHDM: Found hierarchical wire %s in name_map\n", hierarchical_name.c_str());
            return RTLIL::SigSpec(wire);
        }
    }
    
    // Look up in name map with simple name
    if (name_map.count(ref_name)) {
        RTLIL::Wire* wire = name_map[ref_name];
        return RTLIL::SigSpec(wire);
    }
    
    // Check if wire exists in current module
    if (module) {
        RTLIL::IdString wire_id = RTLIL::escape_id(ref_name);
        if (RTLIL::Wire* existing_wire = module->wire(wire_id)) {
            log("UHDM: Found existing wire %s in module\n", ref_name.c_str());
            // Add to name_map for future lookups
            name_map[ref_name] = existing_wire;
            return RTLIL::SigSpec(existing_wire);
        }
    }
    
    // If not found, create a new wire
    log_warning("Reference to unknown signal: %s\n", ref_name.c_str());
    return create_wire(ref_name, 1);
}

// Import part select (e.g., sig[7:0])
RTLIL::SigSpec UhdmImporter::import_part_select(const part_select* uhdm_part) {
    if (mode_debug)
        log("    Importing part select\n");
    
    RTLIL::SigSpec base = import_expression(static_cast<const expr*>(uhdm_part->VpiParent()));
    
    // Get range
    int left = -1, right = -1;
    if (auto left_expr = uhdm_part->Left_range()) {
        RTLIL::SigSpec left_sig = import_expression(left_expr);
        if (left_sig.is_fully_const())
            left = left_sig.as_const().as_int();
    }
    if (auto right_expr = uhdm_part->Right_range()) {
        RTLIL::SigSpec right_sig = import_expression(right_expr);
        if (right_sig.is_fully_const())
            right = right_sig.as_const().as_int();
    }
    
    if (left >= 0 && right >= 0) {
        int width = abs(left - right) + 1;
        int offset = std::min(left, right);
        return base.extract(offset, width);
    }
    
    return base;
}

// Import bit select (e.g., sig[3])
RTLIL::SigSpec UhdmImporter::import_bit_select(const bit_select* uhdm_bit) {
    if (mode_debug)
        log("    Importing bit select\n");
    
    RTLIL::SigSpec base = import_expression(static_cast<const expr*>(uhdm_bit->VpiParent()));
    RTLIL::SigSpec index = import_expression(uhdm_bit->VpiIndex());
    
    if (index.is_fully_const()) {
        int idx = index.as_const().as_int();
        return base.extract(idx, 1);
    }
    
    // Dynamic bit select - need to create a mux
    log_warning("Dynamic bit select not yet implemented\n");
    return base.extract(0, 1);
}

// Import indexed part select (e.g., data[i*8 +: 8])
RTLIL::SigSpec UhdmImporter::import_indexed_part_select(const indexed_part_select* uhdm_indexed) {
    log("    Importing indexed part select\n");
    
    // Get the parent object - this should contain the base signal
    const any* parent = uhdm_indexed->VpiParent();
    if (!parent) {
        log_warning("Indexed part select has no parent\n");
        return RTLIL::SigSpec();
    }
    
    log("      Parent type: %s\n", UhdmName(parent->UhdmType()).c_str());
    
    // Check if the indexed part select itself has the signal name
    std::string base_signal_name;
    if (!uhdm_indexed->VpiDefName().empty()) {
        base_signal_name = std::string(uhdm_indexed->VpiDefName());
        log("      IndexedPartSelect VpiDefName: %s\n", base_signal_name.c_str());
    } else if (!uhdm_indexed->VpiName().empty()) {
        base_signal_name = std::string(uhdm_indexed->VpiName());
        log("      IndexedPartSelect VpiName: %s\n", base_signal_name.c_str());
    }
    
    // If not found in the indexed part select, try the parent
    if (base_signal_name.empty()) {
        if (!parent->VpiDefName().empty()) {
            base_signal_name = std::string(parent->VpiDefName());
            log("      Parent VpiDefName: %s\n", base_signal_name.c_str());
        } else if (!parent->VpiName().empty()) {
            base_signal_name = std::string(parent->VpiName());
            log("      Parent VpiName: %s\n", base_signal_name.c_str());
        }
    }
    
    // Look up the wire in the current module
    RTLIL::SigSpec base;
    if (!base_signal_name.empty()) {
        RTLIL::IdString wire_id = RTLIL::escape_id(base_signal_name);
        if (module->wire(wire_id)) {
            base = RTLIL::SigSpec(module->wire(wire_id));
            log("      Found wire %s in module\n", wire_id.c_str());
        } else {
            // Try name_map
            auto it = name_map.find(base_signal_name);
            if (it != name_map.end()) {
                base = RTLIL::SigSpec(it->second);
                log("      Found wire in name_map\n");
            } else {
                log_warning("Base signal '%s' not found in module\n", base_signal_name.c_str());
                return RTLIL::SigSpec();
            }
        }
    } else {
        // If we can't get the name directly, try importing the parent as an expression
        base = import_expression(static_cast<const expr*>(parent));
    }
    
    log("      Base signal width: %d\n", base.size());
    
    // Get the base index expression
    RTLIL::SigSpec base_index = import_expression(uhdm_indexed->Base_expr());
    log("      Base index: %s\n", base_index.is_fully_const() ? 
        std::to_string(base_index.as_const().as_int()).c_str() : "non-const");
    
    // Get the width expression
    RTLIL::SigSpec width_expr = import_expression(uhdm_indexed->Width_expr());
    log("      Width: %s\n", width_expr.is_fully_const() ? 
        std::to_string(width_expr.as_const().as_int()).c_str() : "non-const");
    
    // Both base_index and width must be constant for RTLIL
    if (base_index.is_fully_const() && width_expr.is_fully_const()) {
        int offset = base_index.as_const().as_int();
        int width = width_expr.as_const().as_int();
        
        // Validate offset and width
        if (offset < 0 || width <= 0 || offset + width > base.size()) {
            log_warning("Invalid indexed part select: offset=%d, width=%d, base_size=%d\n",
                offset, width, base.size());
            return RTLIL::SigSpec();
        }
        
        // Handle +: and -: operators
        if (uhdm_indexed->VpiIndexedPartSelectType() == vpiPosIndexed) {
            // The +: operator means [offset +: width] = [offset+width-1:offset]
            return base.extract(offset, width);
        } else {
            // The -: operator means [offset -: width] = [offset:offset-width+1]
            return base.extract(offset - width + 1, width);
        }
    }
    
    log_warning("Indexed part select with non-constant index or width not supported\n");
    return RTLIL::SigSpec();
}

// Import concatenation (e.g., {a, b, c})
RTLIL::SigSpec UhdmImporter::import_concat(const operation* uhdm_concat) {
    if (mode_debug)
        log("    Importing concatenation\n");
    
    RTLIL::SigSpec result;
    
    if (uhdm_concat->Operands()) {
        for (auto operand : *uhdm_concat->Operands()) {
            RTLIL::SigSpec sig = import_expression(static_cast<const expr*>(operand));
            result.append(sig);
        }
    }
    
    return result;
}

// Import hierarchical path (e.g., bus.a, interface.signal)
RTLIL::SigSpec UhdmImporter::import_hier_path(const hier_path* uhdm_hier, const module_inst* inst) {
    if (mode_debug)
        log("    Importing hier_path\n");
    
    // Get the full path name first
    std::string path_name;
    std::string_view name_view = uhdm_hier->VpiName();
    if (!name_view.empty()) {
        path_name = std::string(name_view);
    }
    std::string_view full_name_view = uhdm_hier->VpiFullName();
    if (!full_name_view.empty()) {
        path_name = std::string(full_name_view);
    }
    
    if (mode_debug)
        log("    hier_path name: '%s'\n", path_name.c_str());
    
    // Check if this is a struct member access (e.g., bus1.a)
    size_t dot_pos = path_name.find('.');
    if (dot_pos != std::string::npos) {
        std::string base_name = path_name.substr(0, dot_pos);
        std::string member_name = path_name.substr(dot_pos + 1);
        
        if (mode_debug)
            log("    Detected struct member access: base='%s', member='%s'\n", base_name.c_str(), member_name.c_str());
        
        // Check if the base wire exists
        if (name_map.count(base_name)) {
            RTLIL::Wire* base_wire = name_map[base_name];
            
            // Look up the base wire in wire_map to get the UHDM object
            const any* base_uhdm_obj = nullptr;
            for (auto& pair : wire_map) {
                if (pair.second == base_wire) {
                    base_uhdm_obj = pair.first;
                    break;
                }
            }
            
            if (base_uhdm_obj) {
                // Get typespec of the base object
                const ref_typespec* base_ref_typespec = nullptr;
                const typespec* base_typespec = nullptr;
                
                if (auto logic_var = dynamic_cast<const UHDM::logic_var*>(base_uhdm_obj)) {
                    base_ref_typespec = logic_var->Typespec();
                } else if (auto logic_net = dynamic_cast<const UHDM::logic_net*>(base_uhdm_obj)) {
                    base_ref_typespec = logic_net->Typespec();
                } else if (auto net_obj = dynamic_cast<const UHDM::net*>(base_uhdm_obj)) {
                    base_ref_typespec = net_obj->Typespec();
                } else if (auto port_obj = dynamic_cast<const UHDM::port*>(base_uhdm_obj)) {
                    base_ref_typespec = port_obj->Typespec();
                }
                
                if (base_ref_typespec) {
                    base_typespec = base_ref_typespec->Actual_typespec();
                    
                    // Check if this is a packed struct typespec
                    if (base_typespec && base_typespec->UhdmType() == uhdmstruct_typespec) {
                        auto struct_typespec = static_cast<const UHDM::struct_typespec*>(base_typespec);
                        
                        if (mode_debug)
                            log("    Found struct typespec for base wire '%s'\n", base_name.c_str());
                        
                        // Find the member in the struct
                        if (struct_typespec->Members()) {
                            int bit_offset = 0;
                            int member_width = 0;
                            bool found_member = false;
                            
                            // Iterate through members in reverse order (MSB to LSB for packed structs)
                            auto members = struct_typespec->Members();
                            for (int i = members->size() - 1; i >= 0; i--) {
                                auto member_spec = (*members)[i];
                                std::string current_member_name = std::string(member_spec->VpiName());
                                
                                // Get width of this member
                                int current_member_width = 1;
                                if (auto member_ts = member_spec->Typespec()) {
                                    if (auto actual_ts = member_ts->Actual_typespec()) {
                                        current_member_width = get_width_from_typespec(actual_ts, inst);
                                    }
                                } else {
                                    // Try to get width directly from the member
                                    current_member_width = get_width(member_spec, inst);
                                }
                                
                                if (current_member_name == member_name) {
                                    member_width = current_member_width;
                                    found_member = true;
                                    break;
                                }
                                
                                bit_offset += current_member_width;
                            }
                            
                            if (found_member) {
                                if (mode_debug)
                                    log("    Found packed struct member: offset=%d, width=%d\n", bit_offset, member_width);
                                
                                // Return a bit slice of the base wire
                                return RTLIL::SigSpec(base_wire, bit_offset, member_width);
                            }
                        }
                    } else if (mode_debug) {
                        log("    Base wire typespec is not a struct (UhdmType=%s)\n", 
                            base_typespec ? UhdmName(base_typespec->UhdmType()).c_str() : "null");
                    }
                } else if (mode_debug) {
                    log("    Base wire has no typespec\n");
                }
            } else if (mode_debug) {
                log("    Could not find UHDM object for base wire '%s'\n", base_name.c_str());
            }
        }
    }
    
    // Check if wire already exists in name_map
    if (name_map.count(path_name)) {
        if (mode_debug)
            log("    Found wire in name_map: %s\n", name_map[path_name]->name.c_str());
        return RTLIL::SigSpec(name_map[path_name]);
    }
    
    // Use ExprEval to decode the hierarchical path to get the member
    ExprEval eval;
    bool invalidValue = false;
    
    // Get the member object
    any* member = eval.decodeHierPath(
        const_cast<hier_path*>(uhdm_hier), 
        invalidValue, 
        inst,  // Use the instance scope
        uhdm_hier,  // pexpr
        ExprEval::ReturnType::MEMBER,  // Get the member object
        false     // muteError
    );
    
    int width = 1;  // Default width
    
    if (!invalidValue && member) {
        if (mode_debug)
            log("    decodeHierPath returned member of type: %d\n", member->VpiType());
        
        // Get the typespec from the member
        const ref_typespec* member_ref_typespec = nullptr;
        const typespec* member_typespec = nullptr;
        
        // Check if member has a ref_typespec
        if (member->UhdmType() == uhdmlogic_var || member->UhdmType() == uhdmlogic_net ||
            member->UhdmType() == uhdmnet || member->UhdmType() == uhdmport) {
            
            // Cast to appropriate type to access Typespec()
            if (auto logic_var = dynamic_cast<const UHDM::logic_var*>(member)) {
                member_ref_typespec = logic_var->Typespec();
            } else if (auto logic_net = dynamic_cast<const UHDM::logic_net*>(member)) {
                member_ref_typespec = logic_net->Typespec();
            } else if (auto net_obj = dynamic_cast<const UHDM::net*>(member)) {
                member_ref_typespec = net_obj->Typespec();
            } else if (auto port_obj = dynamic_cast<const UHDM::port*>(member)) {
                member_ref_typespec = port_obj->Typespec();
            }
            
            if (member_ref_typespec) {
                if (mode_debug)
                    log("    Found ref_typespec on member\n");
                
                // Get the actual typespec from ref_typespec
                member_typespec = member_ref_typespec->Actual_typespec();
                if (mode_debug && member_typespec)
                    log("    Got actual typespec from ref_typespec\n");
                
                // Now use get_width_from_typespec
                if (member_typespec) {
                    width = get_width_from_typespec(member_typespec, inst);
                    if (width > 0) {
                        if (mode_debug)
                            log("    get_width_from_typespec returned width=%d\n", width);
                    }
                }
            }
        }
        
        // If we still don't have a valid width, try get_width on the member
        if (width <= 1) {
            int member_width = get_width(member, inst);
            if (member_width > 1) {
                width = member_width;
                if (mode_debug)
                    log("    get_width on member returned width=%d\n", width);
            }
        }
    } else {
        if (mode_debug)
            log("    ExprEval::decodeHierPath (MEMBER) returned invalid value or null\n");
        
        // Fallback: try to get width from the hier_path itself
        int hier_width = get_width(uhdm_hier, inst);
        if (hier_width > 0) {
            width = hier_width;
        }
    }
    
    // Create the wire with the determined width
    if (mode_debug)
        log("    Creating wire '%s' with width=%d\n", path_name.c_str(), width);
    
    RTLIL::Wire* wire = create_wire(path_name, width);
    return RTLIL::SigSpec(wire);
}

YOSYS_NAMESPACE_END