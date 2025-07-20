/*
 * Expression handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog expressions
 * including operations, constants, and references.
 */

#include "uhdm2rtlil.h"

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
        default:
            log_warning("Unsupported expression type: %d\n", obj_type);
            return RTLIL::SigSpec();
    }
}

// Import constant value
RTLIL::SigSpec UhdmImporter::import_constant(const constant* uhdm_const) {
    int const_type = uhdm_const->VpiConstType();
    std::string value = std::string(uhdm_const->VpiValue());
    int size = uhdm_const->VpiSize();
    
    if (mode_debug)
        log("    Importing constant: %s (type=%d, size=%d)\n", 
            value.c_str(), const_type, size);
    
    switch (const_type) {
        case vpiBinaryConst: {
            // Remove 'b prefix
            std::string bin_str = value.substr(2);
            return RTLIL::SigSpec(RTLIL::Const::from_string(bin_str));
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
            
            RTLIL::Const const_val = RTLIL::Const::from_string(hex_str);
            return RTLIL::SigSpec(const_val);
        }
        case vpiDecConst: {
            int int_val = std::stoi(value);
            return RTLIL::SigSpec(RTLIL::Const(int_val, size));
        }
        case vpiIntConst: {
            int int_val = std::stoi(value);
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
                // Create a logic_not cell like the Verilog frontend
                RTLIL::Cell* not_cell = module->addCell(NEW_ID, ID($logic_not));
                not_cell->setParam(ID::A_SIGNED, 0);
                not_cell->setParam(ID::A_WIDTH, operands[0].size());
                not_cell->setParam(ID::Y_WIDTH, 1);
                
                RTLIL::Wire* output_wire = module->addWire(NEW_ID, 1);
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
        log("    Importing ref_obj: %s\n", ref_name.c_str());
    
    // Look up in name map
    if (name_map.count(ref_name)) {
        RTLIL::Wire* wire = name_map[ref_name];
        return RTLIL::SigSpec(wire);
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

YOSYS_NAMESPACE_END