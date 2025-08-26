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
#include <uhdm/integer_typespec.h>
#include <uhdm/range.h>
#include <uhdm/sys_func_call.h>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Helper function to extract RTLIL::Const from UHDM Value string
RTLIL::Const UhdmImporter::extract_const_from_value(const std::string& value_str) {
    if (value_str.empty()) {
        return RTLIL::Const();
    }
    
    // Handle different value formats from UHDM
    if (value_str.substr(0, 4) == "INT:") {
        int int_val = std::stoi(value_str.substr(4));
        // Return as 32-bit integer by default
        return RTLIL::Const(int_val, 32);
    } else if (value_str.substr(0, 5) == "UINT:") {
        unsigned long long uint_val = std::stoull(value_str.substr(5));
        // Determine width based on value
        int width = 32;
        if (uint_val > UINT32_MAX) {
            width = 64;
        }
        return RTLIL::Const(uint_val, width);
    } else if (value_str.substr(0, 4) == "BIN:") {
        std::string bin_str = value_str.substr(4);
        return RTLIL::Const::from_string(bin_str);
    } else if (value_str.substr(0, 4) == "HEX:") {
        std::string hex_str = value_str.substr(4);
        unsigned long long hex_val = std::stoull(hex_str, nullptr, 16);
        // Determine width from hex string length
        int width = hex_str.length() * 4;
        return RTLIL::Const(hex_val, width);
    } else if (value_str.substr(0, 7) == "STRING:") {
        // Handle string constants - convert to binary representation
        std::string str_val = value_str.substr(7);
        std::vector<RTLIL::State> bits;
        // Convert string to bits (LSB first as per Verilog convention)
        for (size_t i = 0; i < str_val.length(); i++) {
            unsigned char ch = str_val[i];
            for (int j = 0; j < 8; j++) {
                bits.push_back((ch & (1 << j)) ? RTLIL::State::S1 : RTLIL::State::S0);
            }
        }
        return RTLIL::Const(bits);
    } else {
        // Try to parse as integer directly
        try {
            int int_val = std::stoi(value_str);
            return RTLIL::Const(int_val, 32);
        } catch (...) {
            // Return empty const if parsing fails
            return RTLIL::Const();
        }
    }
}

// Import any expression
RTLIL::SigSpec UhdmImporter::import_expression(const expr* uhdm_expr) {
    if (!uhdm_expr)
        return RTLIL::SigSpec();
    
    int obj_type = uhdm_expr->VpiType();
    
    if (mode_debug) {
        log("  import_expression: VpiType=%d, UhdmType=%s\n", 
            obj_type, UHDM::UhdmName(uhdm_expr->UhdmType()).c_str());
    }
    
    switch (obj_type) {
        case vpiConstant:
            return import_constant(any_cast<const constant*>(uhdm_expr));
        case vpiOperation:
            return import_operation(any_cast<const operation*>(uhdm_expr), current_scope ? current_scope : current_instance);
        case vpiRefObj:
            return import_ref_obj(any_cast<const ref_obj*>(uhdm_expr), current_scope ? current_scope : current_instance);
        case vpiPartSelect:
            return import_part_select(any_cast<const part_select*>(uhdm_expr), current_scope ? current_scope : current_instance);
        case vpiBitSelect:
            return import_bit_select(any_cast<const bit_select*>(uhdm_expr), current_scope ? current_scope : current_instance);
        case vpiConcatOp:
            return import_concat(any_cast<const operation*>(uhdm_expr), current_scope ? current_scope : current_instance);
        case vpiAssignment:
            // This should not be called on assignment directly
            // Assignment is a statement, not an expression
            log_warning("vpiAssignment (type 3) passed to import_expression - assignments should be handled as statements, not expressions\n");
            return RTLIL::SigSpec();
        case vpiHierPath:
            return import_hier_path(any_cast<const hier_path*>(uhdm_expr), current_scope ? current_scope : current_instance);
        case vpiIndexedPartSelect:
            return import_indexed_part_select(any_cast<const indexed_part_select*>(uhdm_expr), current_scope ? current_scope : current_instance);
        case vpiPort:
            // Handle port as expression - this happens when ports are referenced in connections
            {
                const UHDM::port* port = any_cast<const UHDM::port*>(any_cast<const any*>(uhdm_expr));
                std::string port_name = std::string(port->VpiName());
                log("    Handling port '%s' as expression\n", port_name.c_str());
                
                // Check if this port has a Low_conn which would be the actual net/wire
                if (port->Low_conn()) {
                    log("    Port has Low_conn, importing that instead\n");
                    return import_expression(any_cast<const expr*>(port->Low_conn()));
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
        case vpiNet:  // Handle logic_net
            {
                const logic_net* net = any_cast<const logic_net*>(uhdm_expr);
                std::string net_name = std::string(net->VpiName());
                if (mode_debug)
                    log("    Handling logic_net '%s' as expression\n", net_name.c_str());
                
                // Look up the wire
                if (name_map.count(net_name)) {
                    return RTLIL::SigSpec(name_map.at(net_name));
                } else {
                    RTLIL::IdString wire_id = RTLIL::escape_id(net_name);
                    if (module->wire(wire_id)) {
                        return RTLIL::SigSpec(module->wire(wire_id));
                    }
                }
                
                log_warning("Logic_net '%s' not found as wire in module\n", net_name.c_str());
                return RTLIL::SigSpec();
            }
        case vpiSysFuncCall:
            // Handle system function calls like $signed, $unsigned, etc.
            {
                const sys_func_call* func_call = any_cast<const sys_func_call*>(uhdm_expr);
                if (!func_call) {
                    log_warning("Failed to cast expression to sys_func_call\n");
                    return RTLIL::SigSpec();
                }
                
                std::string func_name = std::string(func_call->VpiName());
                
                // Get the arguments
                std::vector<RTLIL::SigSpec> args;
                if (func_call->Tf_call_args()) {
                    for (auto arg : *func_call->Tf_call_args()) {
                        RTLIL::SigSpec arg_sig = import_expression(any_cast<const expr*>(arg));
                        args.push_back(arg_sig);
                    }
                }
                
                // Handle specific system functions
                if (func_name == "$signed" && args.size() == 1) {
                    // $signed just returns the argument with signed interpretation
                    // The signedness will be handled by the operation that uses it
                    return args[0];
                } else if (func_name == "$unsigned" && args.size() == 1) {
                    // $unsigned just returns the argument with unsigned interpretation
                    return args[0];
                } else {
                    log_warning("Unhandled system function call: %s with %d arguments\n", 
                               func_name.c_str(), (int)args.size());
                    // Return first argument if available, otherwise empty
                    return args.empty() ? RTLIL::SigSpec() : args[0];
                }
            }
            break;
        default:
            log_warning("Unsupported expression type: %s\n", UhdmName(uhdm_expr->UhdmType()).c_str());
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
            
            // Handle unbased unsized literals (size == -1)
            if (size == -1) {
                // For unbased unsized literals like 'x, 'z, '0, '1
                // These should be handled as special cases
                if (bin_str == "X" || bin_str == "x") {
                    // Return a single X that will be extended as needed
                    return RTLIL::SigSpec(RTLIL::State::Sx);
                } else if (bin_str == "Z" || bin_str == "z") {
                    // Return a single Z that will be extended as needed
                    return RTLIL::SigSpec(RTLIL::State::Sz);
                } else if (bin_str == "0") {
                    // Return a single 0 that will be extended as needed
                    return RTLIL::SigSpec(RTLIL::State::S0);
                } else if (bin_str == "1") {
                    // Return a single 1 that will be extended as needed
                    return RTLIL::SigSpec(RTLIL::State::S1);
                }
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
            try {
                // Use stoll to handle larger integers
                long long int_val = std::stoll(dec_str);
                return RTLIL::SigSpec(RTLIL::Const(int_val, size));
            } catch (const std::exception& e) {
                log_error("Failed to parse decimal constant: value='%s', substr='%s', error=%s\n", 
                         value.c_str(), dec_str.c_str(), e.what());
            }
        }
        case vpiIntConst: {
            std::string int_str = value.substr(4);
            try {
                // Use stoll to handle larger integers, then create appropriate constant
                long long int_val = std::stoll(int_str);
                // Create a constant with the appropriate bit width
                // For vpiIntConst, we typically use 32 bits but if the value is larger,
                // we need to determine the actual required width
                int width = 32;
                if (int_val > INT32_MAX || int_val < INT32_MIN) {
                    // Calculate required width for the value
                    width = 64; // Use 64 bits for large values
                }
                return RTLIL::SigSpec(RTLIL::Const(int_val, width));
            } catch (const std::exception& e) {
                log_error("Failed to parse integer constant: value='%s', substr='%s', error=%s\n", 
                         value.c_str(), int_str.c_str(), e.what());
            }
        }
        case vpiUIntConst: {
            if (mode_debug)
                log("    vpiUIntConst: value='%s', size=%d\n", value.c_str(), size);
            try {
                // Handle UHDM format: "UINT:value"
                if (value.substr(0, 5) == "UINT:") {
                    std::string num_str = value.substr(5);
                    // Use stoull to handle large values like 18446744073709551615 (0xFFFFFFFFFFFFFFFF)
                    unsigned long long uint_val = std::stoull(num_str);
                    return RTLIL::SigSpec(RTLIL::Const(uint_val, size));
                } else {
                    // Handle plain number format
                    unsigned long long uint_val = std::stoull(value);
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
RTLIL::SigSpec UhdmImporter::import_operation(const operation* uhdm_op, const UHDM::scope* inst) {
    // Try to reduce it first
    ExprEval eval;
    bool invalidValue = false;
    expr* res = eval.reduceExpr(uhdm_op, invalidValue, inst, uhdm_op->VpiParent(), true);
    if (res && res->UhdmType() == uhdmconstant) {
        return import_constant(dynamic_cast<const UHDM::constant*>(res));
    }

    int op_type = uhdm_op->VpiOpType();
    
    if (mode_debug)
        log("    Importing operation: %d\n", op_type);
    
    // Get operands
    std::vector<RTLIL::SigSpec> operands;
    if (uhdm_op->Operands()) {
        if (op_type == vpiConditionOp) { 
            log("UHDM: ConditionOp (type=%d) has %d operands\n", op_type, (int)uhdm_op->Operands()->size());
        }
        for (auto operand : *uhdm_op->Operands()) {
            RTLIL::SigSpec op_sig = import_expression(any_cast<const expr*>(operand));
            if (op_type == vpiConditionOp) {
                log("UHDM: ConditionOp operand %d has size %d\n", (int)operands.size(), op_sig.size());
            }
            // Debug: Check for empty operands in comparison operations
            if ((op_type == vpiEqOp || op_type == vpiNeqOp || op_type == vpiLtOp || 
                 op_type == vpiLeOp || op_type == vpiGtOp || op_type == vpiGeOp) && 
                op_sig.size() == 0) {
                log_warning("Empty operand detected in comparison operation (type=%d)\n", op_type);
                // Try to get more information about the operand
                const expr* expr_operand = any_cast<const expr*>(operand);
                if (expr_operand) {
                    log_warning("  Operand type: %s\n", UhdmName(expr_operand->UhdmType()).c_str());
                    if (!expr_operand->VpiName().empty()) {
                        log_warning("  Operand name: %s\n", std::string(expr_operand->VpiName()).c_str());
                    }
                }
            }
            operands.push_back(op_sig);
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
                return module->LogicAnd(NEW_ID, operands[0], operands[1]);
            break;
        case vpiLogOrOp:
            if (operands.size() == 2)
                return module->LogicOr(NEW_ID, operands[0], operands[1]);
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
        case vpiBitXNorOp:  // Both vpiBitXNorOp and vpiBitXnorOp are the same
            if (operands.size() == 2)
                return module->Xnor(NEW_ID, operands[0], operands[1]);
            break;
        case vpiUnaryAndOp:
            if (operands.size() == 1)
                return module->ReduceAnd(NEW_ID, operands[0]);
            break;
        case vpiUnaryOrOp:
            if (operands.size() == 1)
                return module->ReduceOr(NEW_ID, operands[0]);
            break;
        case vpiUnaryXorOp:
            if (operands.size() == 1)
                return module->ReduceXor(NEW_ID, operands[0]);
            break;
        case vpiUnaryNandOp:
            if (operands.size() == 1) {
                // Unary NAND is NOT(REDUCE_AND)
                RTLIL::SigSpec and_result = module->ReduceAnd(NEW_ID, operands[0]);
                return module->Not(NEW_ID, and_result);
            } else if (operands.size() == 2) {
                // Binary NAND (when UHDM uses unary op for binary ~&)
                RTLIL::SigSpec and_result = module->And(NEW_ID, operands[0], operands[1]);
                return module->Not(NEW_ID, and_result);
            }
            break;
        case vpiUnaryNorOp:
            if (operands.size() == 1) {
                // Unary NOR is NOT(REDUCE_OR)
                RTLIL::SigSpec or_result = module->ReduceOr(NEW_ID, operands[0]);
                return module->Not(NEW_ID, or_result);
            } else if (operands.size() == 2) {
                // Binary NOR (when UHDM uses unary op for binary ~|)
                RTLIL::SigSpec or_result = module->Or(NEW_ID, operands[0], operands[1]);
                return module->Not(NEW_ID, or_result);
            }
            break;
        case vpiUnaryXNorOp:
            if (operands.size() == 1) {
                // Unary XNOR is NOT(REDUCE_XOR)
                RTLIL::SigSpec xor_result = module->ReduceXor(NEW_ID, operands[0]);
                return module->Not(NEW_ID, xor_result);
            }
            break;
        case vpiAddOp:
            if (operands.size() == 2) {
                // For addition, create an add cell
                int result_width = std::max(operands[0].size(), operands[1].size()) + 1;
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);
                
                // Check if operands are signed
                bool is_signed = false;
                for (const auto& operand : operands) {
                    if (operand.is_wire()) {
                        RTLIL::Wire* wire = operand.as_wire();
                        if (wire && wire->is_signed) {
                            is_signed = true;
                            break;
                        }
                    }
                }
                
                module->addAdd(NEW_ID, operands[0], operands[1], result, is_signed);
                return result;
            }
            break;
        case vpiSubOp:
            if (operands.size() == 2) {
                // For subtraction, create a sub cell
                int result_width = std::max(operands[0].size(), operands[1].size()) + 1;
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);
                
                // Check if operands are signed
                bool is_signed = false;
                for (const auto& operand : operands) {
                    if (operand.is_wire()) {
                        RTLIL::Wire* wire = operand.as_wire();
                        if (wire && wire->is_signed) {
                            is_signed = true;
                            break;
                        }
                    }
                }
                
                module->addSub(NEW_ID, operands[0], operands[1], result, is_signed);
                return result;
            }
            break;
        case vpiMultOp:
            if (operands.size() == 2) {
                // For multiplication, the result width should be the sum of operand widths
                int result_width = operands[0].size() + operands[1].size();
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);
                
                // Check if operands are signed by checking if they come from signed wires
                bool is_signed = false;
                
                // Check if all operands come from signed wires
                for (const auto& operand : operands) {
                    // Check if the operand is a wire
                    if (operand.is_wire()) {
                        RTLIL::Wire* wire = operand.as_wire();
                        if (wire && wire->is_signed) {
                            is_signed = true;
                            break;  // If any operand is signed, treat the operation as signed
                        }
                    }
                }
                
                module->addMul(NEW_ID, operands[0], operands[1], result, is_signed);
                return result;
            }
            break;
        case vpiPowerOp:
            if (operands.size() == 2) {
                // Power operation: base ** exponent
                // Result width is typically the same as the base operand
                int result_width = operands[0].size();
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);
                
                // Check if operands are signed
                bool is_signed = false;
                if (operands[0].is_wire()) {
                    RTLIL::Wire* wire = operands[0].as_wire();
                    if (wire && wire->is_signed) {
                        is_signed = true;
                    }
                }
                
                // Use Pow cell for power operation
                module->addPow(NEW_ID, operands[0], operands[1], result, is_signed);
                return result;
            }
            break;
        case vpiEqOp:
            if (operands.size() == 2)
                return module->Eq(NEW_ID, operands[0], operands[1]);
            break;
        case vpiCaseEqOp:
            // Case equality (===) - use $eqx which properly handles X and Z values
            if (operands.size() == 2)
                return module->Eqx(NEW_ID, operands[0], operands[1]);
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
            if (operands.size() == 3) {
                // For conditional operator: condition ? true_val : false_val
                // operands[0] is the condition
                // operands[1] is the true value
                // operands[2] is the false value
                // Mux takes (name, selector, false_val, true_val)
                
                log("UHDM: ConditionOp - operand sizes: cond=%d, true=%d, false=%d\n",
                    operands[0].size(), operands[1].size(), operands[2].size());
                
                // Ensure the condition is 1-bit
                RTLIL::SigSpec cond = operands[0];
                if (cond.size() > 1) {
                    log("UHDM: Reducing %d-bit condition to 1-bit\n", cond.size());
                    // Reduce multi-bit condition to single bit using ReduceBool
                    cond = module->ReduceBool(NEW_ID, cond);
                }
                
                // Match operand widths for the mux output
                int max_width = std::max(operands[1].size(), operands[2].size());
                RTLIL::SigSpec true_val = operands[1];
                RTLIL::SigSpec false_val = operands[2];
                
                // Extend operands to match widths if needed
                if (true_val.size() < max_width) {
                    true_val = RTLIL::SigSpec(true_val);
                    true_val.extend_u0(max_width);
                }
                if (false_val.size() < max_width) {
                    false_val = RTLIL::SigSpec(false_val);
                    false_val.extend_u0(max_width);
                }
                
                log("UHDM: Creating Mux with selector size=%d, true_val size=%d, false_val size=%d\n",
                    cond.size(), true_val.size(), false_val.size());
                
                // Mux signature: Mux(name, sig_a, sig_b, sig_s)
                // sig_a = value when selector is 0 (false value)
                // sig_b = value when selector is 1 (true value)
                // sig_s = selector
                return module->Mux(NEW_ID, false_val, true_val, cond);
            }
            break;
        case vpiCastOp:
            // Cast operation like 3'('x) or 64'(value)
            log("    Processing cast operation\n");
            if (operands.size() == 1) {
                // Get the target width from the typespec
                int target_width = 0;
                if (uhdm_op->Typespec()) {
                    const ref_typespec* ref_ts = uhdm_op->Typespec();
                    const typespec* ts = ref_ts->Actual_typespec();
                    // For integer typespec, get the actual value
                    if (ts->VpiType() == vpiIntegerTypespec) {
                        const integer_typespec* its = any_cast<const integer_typespec*>(ts);
                        // Get the actual value from VpiValue()
                        std::string val_str = std::string(its->VpiValue());
                        if (!val_str.empty()) {
                            RTLIL::Const width_const = extract_const_from_value(val_str);
                            if (width_const.size() > 0) {
                                target_width = width_const.as_int();
                            }
                        }
                    }
                }
                
                if (target_width > 0) {
                    // Handle the cast based on operand type
                    RTLIL::SigSpec operand = operands[0];
                    
                    // If operand is a constant, handle it directly
                    if (operand.is_fully_const()) {
                        RTLIL::Const const_val = operand.as_const();
                        
                        // For small constants that are all the same value, expand to target width
                        // This handles cases like 3'('x), 3'('z), 3'('0), 3'('1)
                        if (const_val.size() <= target_width) {
                            // Check if all bits are the same value
                            bool all_x = true;
                            bool all_z = true;
                            bool all_0 = true;
                            bool all_1 = true;
                            for (auto bit : const_val.bits()) {
                                if (bit != RTLIL::State::Sx) all_x = false;
                                if (bit != RTLIL::State::Sz) all_z = false;
                                if (bit != RTLIL::State::S0) all_0 = false;
                                if (bit != RTLIL::State::S1) all_1 = false;
                            }
                            
                            // If all bits are X, expand to full width with X
                            if (all_x) {
                                return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::Sx, target_width));
                            }
                            // If all bits are Z, expand to full width with Z
                            if (all_z) {
                                return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::Sz, target_width));
                            }
                            // If all bits are 0, expand to full width with 0
                            if (all_0) {
                                return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::S0, target_width));
                            }
                            // If all bits are 1, expand to full width with 1
                            if (all_1) {
                                return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::S1, target_width));
                            }
                        }
                        
                        // For other constants, resize appropriately
                        if (const_val.size() < target_width) {
                            // Zero-extend
                            const_val.bits().resize(target_width, RTLIL::State::S0);
                        } else if (const_val.size() > target_width) {
                            // Truncate
                            const_val.bits().resize(target_width);
                        }
                        return RTLIL::SigSpec(const_val);
                    }
                    
                    // For non-constant operands, use $pos to cast/resize
                    RTLIL::SigSpec result = module->addWire(NEW_ID, target_width);
                    module->addPos(NEW_ID, operand, result);
                    return result;
                }
            }
            log_warning("Unsupported cast operation\n");
            return RTLIL::SigSpec();
        default:
            log_warning("Unsupported operation type: %d\n", op_type);
            return RTLIL::SigSpec();
    }
    
    log_warning("Operation %d: incorrect number of operands (%d)\n", 
                op_type, (int)operands.size());
    return RTLIL::SigSpec();
}

// Import reference to object
RTLIL::SigSpec UhdmImporter::import_ref_obj(const ref_obj* uhdm_ref, const UHDM::scope* inst) {
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
    
    // Check if this ref_obj has VpiActual property pointing to an interface
    if (uhdm_ref->Actual_group()) {
        const UHDM::any* actual = uhdm_ref->Actual_group();
        if (mode_debug) {
            log("    ref_obj has VpiActual of type: %s\n", UhdmName(actual->UhdmType()).c_str());
        }
        
        // Check if the actual is an interface_inst
        if (actual->UhdmType() == uhdminterface_inst) {
            // This is a reference to an interface instance
            // Create the interface connection wire with proper naming
            std::string interface_wire_name = "$dummywireforinterface\\" + ref_name;
            log("UHDM: Reference to interface instance %s via VpiActual, creating connection wire %s\n", 
                ref_name.c_str(), interface_wire_name.c_str());
            return create_wire(interface_wire_name, 1);
        }
    }
    
    // Check if this is a reference to an interface instance
    // Interface instances would have been created as cells in the module
    RTLIL::IdString potential_interface_name = RTLIL::escape_id(ref_name);
    if (module && module->cell(potential_interface_name)) {
        RTLIL::Cell* potential_interface_cell = module->cell(potential_interface_name);
        // Check if the cell type indicates it's an interface
        RTLIL::Module* cell_module = design->module(potential_interface_cell->type);
        if (cell_module && cell_module->attributes.count(RTLIL::escape_id("is_interface"))) {
            // This is a reference to an interface instance
            // Create the interface connection wire with proper naming
            std::string interface_wire_name = "$dummywireforinterface\\" + ref_name;
            log("UHDM: Reference to interface instance %s, creating connection wire %s\n", 
                ref_name.c_str(), interface_wire_name.c_str());
            return create_wire(interface_wire_name, 1);
        }
    }
    
    // If not found, create a new wire
    log_warning("Reference to unknown signal: %s\n", ref_name.c_str());
    return create_wire(ref_name, 1);
}

// Import part select (e.g., sig[7:0])
RTLIL::SigSpec UhdmImporter::import_part_select(const part_select* uhdm_part, const UHDM::scope* inst) {
    if (mode_debug)
        log("    Importing part select\n");
    
    // Get the parent object - this should contain the base signal
    const any* parent = uhdm_part->VpiParent();
    if (!parent) {
        log_warning("Part select has no parent\n");
        return RTLIL::SigSpec();
    }
    
    log("      Parent type: %s\n", UhdmName(parent->UhdmType()).c_str());
    
    // Check if the indexed part select itself has the signal name
    std::string base_signal_name;
    if (!uhdm_part->VpiDefName().empty()) {
        base_signal_name = std::string(uhdm_part->VpiDefName());
        log("      PartSelect VpiDefName: %s\n", base_signal_name.c_str());
    } else if (!uhdm_part->VpiName().empty()) {
        base_signal_name = std::string(uhdm_part->VpiName());
        log("      PartSelect VpiName: %s\n", base_signal_name.c_str());
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
        base = import_expression(any_cast<const expr*>(parent));
    }
    
    log("      Base signal width: %d\n", base.size());


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
RTLIL::SigSpec UhdmImporter::import_bit_select(const bit_select* uhdm_bit, const UHDM::scope* inst) {
    if (mode_debug)
        log("    Importing bit select\n");
    
    // Get the signal name directly from the bit_select
    std::string signal_name = std::string(uhdm_bit->VpiName());
    
    if (mode_debug)
        log("    Bit select signal name: '%s'\n", signal_name.c_str());
    
    // Check if this is a memory access
    RTLIL::IdString mem_id = RTLIL::escape_id(signal_name);
    if (module->memories.count(mem_id) > 0) {
        if (mode_debug)
            log("    This is a memory access - creating $memrd cell\n");
        
        // Get memory info
        RTLIL::Memory* memory = module->memories.at(mem_id);
        
        // Get the address expression
        RTLIL::SigSpec addr = import_expression(uhdm_bit->VpiIndex());
        
        // Create a unique name for the cell
        RTLIL::IdString cell_id = new_id("memrd_" + signal_name);
        std::string cell_name = cell_id.str();
        
        // Create $memrd cell
        RTLIL::Cell* memrd_cell = module->addCell(cell_id, ID($memrd));
        memrd_cell->setParam(ID::MEMID, RTLIL::Const(mem_id.str()));
        memrd_cell->setParam(ID::ABITS, GetSize(addr));
        memrd_cell->setParam(ID::WIDTH, memory->width);
        memrd_cell->setParam(ID::CLK_ENABLE, RTLIL::Const(0));
        memrd_cell->setParam(ID::CLK_POLARITY, RTLIL::Const(0));
        memrd_cell->setParam(ID::TRANSPARENT, RTLIL::Const(0));
        
        // Create data output wire - need to create a new unique ID
        RTLIL::IdString data_wire_id = new_id("memrd_" + signal_name + "_DATA");
        RTLIL::Wire* data_wire = module->addWire(data_wire_id, memory->width);
        
        if (mode_debug) {
            log("    Created memrd cell: %s\n", cell_name.c_str());
            log("    Created data wire: %s\n", data_wire_id.c_str());
        }
        
        // Connect ports
        memrd_cell->setPort(ID::CLK, RTLIL::SigSpec(RTLIL::State::Sx, 1));
        memrd_cell->setPort(ID::EN, RTLIL::SigSpec(RTLIL::State::S1, 1));
        memrd_cell->setPort(ID::ADDR, addr);
        memrd_cell->setPort(ID::DATA, data_wire);
        
        // Add source attribute
        add_src_attribute(memrd_cell->attributes, uhdm_bit);
        
        return RTLIL::SigSpec(data_wire);
    }
    
    // Regular bit select on a wire
    RTLIL::Wire* wire = nullptr;
    if (name_map.count(signal_name)) {
        wire = name_map.at(signal_name);
    } else {
        // Try with escaped name
        RTLIL::IdString wire_id = RTLIL::escape_id(signal_name);
        wire = module->wire(wire_id);
    }
    
    // If wire not found, check if this is a shift register array element
    if (!wire) {
        // Get the index
        RTLIL::SigSpec index = import_expression(uhdm_bit->VpiIndex());
        if (index.is_fully_const()) {
            int idx = index.as_const().as_int();
            // Try to find the wire with the array index in the name
            std::string indexed_name = stringf("\\%s[%d]", signal_name.c_str(), idx);
            wire = module->wire(indexed_name);
            if (wire) {
                if (mode_debug)
                    log("    Found shift register element: %s\n", indexed_name.c_str());
                // Return the whole wire since it represents M[idx]
                return RTLIL::SigSpec(wire);
            }
        }
    }
    
    if (!wire) {
        log_error("Could not find wire '%s' for bit select\n", signal_name.c_str());
    }
    
    RTLIL::SigSpec base(wire);
    RTLIL::SigSpec index = import_expression(uhdm_bit->VpiIndex());
    
    if (index.is_fully_const()) {
        int idx = index.as_const().as_int();
        if (mode_debug)
            log("    Bit select index: %d\n", idx);
        
        // Check if the wire has reversed bit ordering
        if (wire && (wire->upto || wire->start_offset != 0)) {
            // Convert from HDL index to RTLIL index
            int rtlil_idx = wire->from_hdl_index(idx);
            if (rtlil_idx == INT_MIN) {
                log_error("Bit select index %d is out of range for wire '%s'\n", idx, signal_name.c_str());
            }
            if (mode_debug)
                log("    Converted HDL index %d to RTLIL index %d (upto=%d, start_offset=%d)\n", 
                    idx, rtlil_idx, wire->upto ? 1 : 0, wire->start_offset);
            return base.extract(rtlil_idx, 1);
        } else {
            // Standard bit ordering
            return base.extract(idx, 1);
        }
    }
    
    // Dynamic bit select - create a $shiftx cell
    if (mode_debug)
        log("    Creating $shiftx for dynamic bit select\n");
    
    // Create output wire for the result
    RTLIL::Wire* result_wire = module->addWire(NEW_ID, 1);
    
    // Create $shiftx cell
    RTLIL::Cell* shiftx_cell = module->addCell(NEW_ID, ID($shiftx));
    shiftx_cell->setParam(ID::A_SIGNED, 0);
    shiftx_cell->setParam(ID::B_SIGNED, 0);
    shiftx_cell->setParam(ID::A_WIDTH, base.size());
    shiftx_cell->setParam(ID::B_WIDTH, index.size());
    shiftx_cell->setParam(ID::Y_WIDTH, 1);
    
    shiftx_cell->setPort(ID::A, base);
    shiftx_cell->setPort(ID::B, index);
    shiftx_cell->setPort(ID::Y, result_wire);
    
    // Add source attribute
    add_src_attribute(shiftx_cell->attributes, uhdm_bit);
    
    return RTLIL::SigSpec(result_wire);
}

// Import indexed part select (e.g., data[i*8 +: 8])
RTLIL::SigSpec UhdmImporter::import_indexed_part_select(const indexed_part_select* uhdm_indexed, const UHDM::scope* inst) {
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
        base = import_expression(any_cast<const expr*>(parent));
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
    
    log_warning("Indexed part select with non-constant index or widthimport_expressioncurrent not supported\n");
    return RTLIL::SigSpec();
}

// Import concatenation (e.g., {a, b, c})
RTLIL::SigSpec UhdmImporter::import_concat(const operation* uhdm_concat, const UHDM::scope* inst) {
    if (mode_debug)
        log("    Importing concatenation\n");
    
    RTLIL::SigSpec result;
    
    if (uhdm_concat->Operands()) {
        for (auto operand : *uhdm_concat->Operands()) {
            RTLIL::SigSpec sig = import_expression(any_cast<const expr*>(operand));
            result.append(sig);
        }
    }
    
    return result;
}

// Import hierarchical path (e.g., bus.a, interface.signal)
RTLIL::SigSpec UhdmImporter::import_hier_path(const hier_path* uhdm_hier, const scope* inst) {
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
    
    // Check if this is a struct member access (e.g., bus1.a or in_struct.base.data)
    size_t dot_pos = path_name.find('.');
    if (dot_pos != std::string::npos) {
        // For nested struct members like in_struct.base.data, we need special handling
        // Count number of dots to determine if it's nested
        size_t dot_count = std::count(path_name.begin(), path_name.end(), '.');
        
        if (mode_debug)
            log("    hier_path has %zu dots\n", dot_count);
        
        if (dot_count > 1) {
            // Nested struct member access
            // Find the last dot to separate the final member from the rest
            size_t last_dot = path_name.rfind('.');
            std::string base_path = path_name.substr(0, last_dot);  // e.g., "in_struct.base"
            std::string final_member = path_name.substr(last_dot + 1);  // e.g., "data"
            
            if (mode_debug)
                log("    Detected nested struct member access: base_path='%s', final_member='%s'\n", 
                    base_path.c_str(), final_member.c_str());
            
            // First, find the first-level struct and member
            size_t first_dot = path_name.find('.');
            std::string struct_name = path_name.substr(0, first_dot);  // e.g., "in_struct"
            std::string first_member = base_path.substr(first_dot + 1);  // e.g., "base"
            
            if (mode_debug)
                log("    Looking for struct wire '%s' in name_map\n", struct_name.c_str());
            
            if (name_map.count(struct_name)) {
                RTLIL::Wire* struct_wire = name_map[struct_name];
                
                if (mode_debug)
                    log("    Found struct wire '%s' with width %d\n", struct_name.c_str(), struct_wire->width);
                
                // Get UHDM object for the struct
                const any* struct_uhdm_obj = nullptr;
                for (auto& pair : wire_map) {
                    if (pair.second == struct_wire) {
                        struct_uhdm_obj = pair.first;
                        if (mode_debug)
                            log("    Found UHDM object for struct wire (type=%d)\n", struct_uhdm_obj->UhdmType());
                        break;
                    }
                }
                
                if (struct_uhdm_obj) {
                    // Get struct typespec
                    const ref_typespec* struct_ref_typespec = nullptr;
                    if (auto logic_var = dynamic_cast<const UHDM::logic_var*>(struct_uhdm_obj)) {
                        struct_ref_typespec = logic_var->Typespec();
                    } else if (auto logic_net = dynamic_cast<const UHDM::logic_net*>(struct_uhdm_obj)) {
                        struct_ref_typespec = logic_net->Typespec();
                    }
                    
                    if (struct_ref_typespec) {
                        const typespec* struct_typespec = struct_ref_typespec->Actual_typespec();
                        if (struct_typespec && struct_typespec->UhdmType() == uhdmstruct_typespec) {
                            auto st_spec = any_cast<const UHDM::struct_typespec*>(struct_typespec);
                            
                            if (mode_debug)
                                log("    Found struct_typespec\n");
                            
                            // Find the first-level member
                            if (st_spec->Members()) {
                                int first_member_offset = 0;
                                const typespec* first_member_typespec = nullptr;
                                bool found_first_member = false;
                                
                                // Iterate through members in reverse order
                                auto members = st_spec->Members();
                                for (int i = members->size() - 1; i >= 0; i--) {
                                    auto member_spec = (*members)[i];
                                    std::string member_name = std::string(member_spec->VpiName());
                                    
                                    int member_width = 1;
                                    if (auto member_ts = member_spec->Typespec()) {
                                        if (auto actual_ts = member_ts->Actual_typespec()) {
                                            member_width = get_width_from_typespec(actual_ts, inst);
                                            if (member_name == first_member) {
                                                first_member_typespec = actual_ts;
                                            }
                                        }
                                    }
                                    
                                    if (member_name == first_member) {
                                        found_first_member = true;
                                        break;
                                    }
                                    
                                    first_member_offset += member_width;
                                }
                                
                                if (found_first_member && first_member_typespec && 
                                    first_member_typespec->UhdmType() == uhdmstruct_typespec) {
                                    // Now find the second-level member
                                    auto nested_st_spec = any_cast<const UHDM::struct_typespec*>(first_member_typespec);
                                    if (nested_st_spec->Members()) {
                                        int second_member_offset = 0;
                                        int second_member_width = 0;
                                        bool found_second_member = false;
                                        
                                        auto nested_members = nested_st_spec->Members();
                                        for (int i = nested_members->size() - 1; i >= 0; i--) {
                                            auto member_spec = (*nested_members)[i];
                                            std::string member_name = std::string(member_spec->VpiName());
                                            
                                            int member_width = 1;
                                            if (auto member_ts = member_spec->Typespec()) {
                                                if (auto actual_ts = member_ts->Actual_typespec()) {
                                                    member_width = get_width_from_typespec(actual_ts, inst);
                                                }
                                            }
                                            
                                            if (member_name == final_member) {
                                                second_member_width = member_width;
                                                found_second_member = true;
                                                break;
                                            }
                                            
                                            second_member_offset += member_width;
                                        }
                                        
                                        if (found_second_member) {
                                            if (mode_debug)
                                                log("    Found nested struct member: total_offset=%d, width=%d\n", 
                                                    first_member_offset + second_member_offset, second_member_width);
                                            
                                            // Return bit slice from the struct wire
                                            return RTLIL::SigSpec(struct_wire, 
                                                                first_member_offset + second_member_offset, 
                                                                second_member_width);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else if (mode_debug) {
                log("    Struct wire '%s' not found in name_map\n", struct_name.c_str());
                log("    Available wires in name_map:\n");
                for (auto& pair : name_map) {
                    log("      %s (width=%d)\n", pair.first.c_str(), pair.second->width);
                }
            }
            
            // If we couldn't resolve it as nested struct member, fall through to create wire
        } else {
            // Single-level struct member access
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
                        auto struct_typespec = any_cast<const UHDM::struct_typespec*>(base_typespec);
                        
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
        }  // End of single-level struct member handling
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
    
    // Check if this is a struct member access - if so, don't create a new wire
    if (dot_pos != std::string::npos) {
        // This is a struct member reference but we couldn't resolve it above
        // Try to calculate the offset dynamically from the struct typespec
        std::string struct_name = path_name.substr(0, path_name.find('.'));
        
        if (name_map.count(struct_name)) {
            RTLIL::Wire* struct_wire = name_map[struct_name];
            
            // Find the UHDM object for the struct wire
            const any* struct_uhdm_obj = nullptr;
            for (auto& pair : wire_map) {
                if (pair.second == struct_wire) {
                    struct_uhdm_obj = pair.first;
                    break;
                }
            }
            
            if (struct_uhdm_obj) {
                // Get the typespec
                const ref_typespec* ref_ts = nullptr;
                if (auto logic_net = dynamic_cast<const UHDM::logic_net*>(struct_uhdm_obj)) {
                    ref_ts = logic_net->Typespec();
                } else if (auto net_obj = dynamic_cast<const UHDM::net*>(struct_uhdm_obj)) {
                    ref_ts = net_obj->Typespec();
                }
                
                if (ref_ts && ref_ts->Actual_typespec()) {
                    const typespec* ts = ref_ts->Actual_typespec();
                    
                    // Calculate bit offset for struct member access
                    std::string remaining_path = path_name.substr(struct_name.length() + 1);
                    int bit_offset = 0;
                    int member_width = 0;
                    
                    if (calculate_struct_member_offset(ts, remaining_path, inst, bit_offset, member_width)) {
                        if (mode_debug)
                            log("    Calculated struct member '%s' offset=%d, width=%d\n", 
                                path_name.c_str(), bit_offset, member_width);
                        return RTLIL::SigSpec(struct_wire, bit_offset, member_width);
                    }
                }
            }
        }
        
        // Log a warning and return an unconnected signal
        log_warning("UHDM: Could not resolve struct member access '%s'\n", path_name.c_str());
        return RTLIL::SigSpec(RTLIL::State::Sx, width);
    }
    
    // Create the wire with the determined width
    if (mode_debug)
        log("    Creating wire '%s' with width=%d\n", path_name.c_str(), width);
    
    RTLIL::Wire* wire = create_wire(path_name, width);
    return RTLIL::SigSpec(wire);
}

// Calculate bit offset and width for struct member access
bool UhdmImporter::calculate_struct_member_offset(const typespec* ts, const std::string& member_path, 
                                                 const scope* inst, int& bit_offset, int& member_width) {
    if (!ts || member_path.empty()) {
        return false;
    }
    
    // log("UHDM: calculate_struct_member_offset for path '%s'\n", member_path.c_str());
    
    // Split the member path by dots for nested access
    std::vector<std::string> path_parts;
    size_t start = 0;
    size_t dot_pos = member_path.find('.');
    while (dot_pos != std::string::npos) {
        path_parts.push_back(member_path.substr(start, dot_pos - start));
        start = dot_pos + 1;
        dot_pos = member_path.find('.', start);
    }
    path_parts.push_back(member_path.substr(start));
    
    // Start with the given typespec
    const typespec* current_ts = ts;
    bit_offset = 0;
    member_width = 0;
    
    // Process each part of the path
    for (const auto& member_name : path_parts) {
        if (!current_ts || current_ts->UhdmType() != uhdmstruct_typespec) {
            return false;
        }
        
        auto struct_ts = any_cast<const struct_typespec*>(current_ts);
        if (!struct_ts->Members()) {
            return false;
        }
        
        // Calculate offset within this struct
        int offset_in_struct = 0;
        bool found = false;
        const typespec* member_ts = nullptr;
        
        // Iterate through members in reverse order (MSB to LSB for packed structs)
        auto members = struct_ts->Members();
        for (int i = members->size() - 1; i >= 0; i--) {
            auto member = (*members)[i];
            std::string current_member_name = std::string(member->VpiName());
            
            if (current_member_name == member_name) {
                // Found the member
                if (auto ref_ts = member->Typespec()) {
                    if (auto actual_ts = ref_ts->Actual_typespec()) {
                        member_ts = actual_ts;
                        member_width = get_width_from_typespec(actual_ts, inst);
                        // log("UHDM:   Found target member '%s' width=%d at offset_in_struct=%d\n", 
                        //     current_member_name.c_str(), member_width, offset_in_struct);
                    }
                }
                found = true;
                break;
            }
            
            // Add width of this member to offset
            if (auto ref_ts = member->Typespec()) {
                if (auto actual_ts = ref_ts->Actual_typespec()) {
                    int width = get_width_from_typespec(actual_ts, inst);
                    // log("UHDM:   Member '%s' width=%d, offset_in_struct=%d\n", 
                    //     current_member_name.c_str(), width, offset_in_struct);
                    offset_in_struct += width;
                }
            }
        }
        
        if (!found) {
            return false;
        }
        
        // Add the offset within this struct to the total offset
        bit_offset += offset_in_struct;
        
        // For the next iteration, use the member's typespec
        current_ts = member_ts;
    }
    
    return member_width > 0;
}

YOSYS_NAMESPACE_END