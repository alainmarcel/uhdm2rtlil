/*
 * Expression handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog expressions
 * including operations, constants, and references.
 */

#include "uhdm2rtlil.h"

YOSYS_NAMESPACE_BEGIN
PRIVATE_NAMESPACE_BEGIN

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
        case vpiConcat:
            return import_concat(static_cast<const concat*>(uhdm_expr));
        default:
            log_warning("Unsupported expression type: %d\n", obj_type);
            return RTLIL::SigSpec();
    }
}

// Import constant value
RTLIL::SigSpec UhdmImporter::import_constant(const constant* uhdm_const) {
    int const_type = uhdm_const->VpiConstType();
    std::string value = uhdm_const->VpiValue();
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
            // Remove 'h prefix
            std::string hex_str = value.substr(2);
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
        default:
            log_warning("Unsupported constant type: %d\n", const_type);
            return RTLIL::SigSpec(RTLIL::State::Sx);
    }
}

// Import operation
RTLIL::SigSpec UhdmImporter::import_operation(const operation* uhdm_op) {
    int op_type = uhdm_op->VpiOpType();\n    \n    if (mode_debug)\n        log(\"    Importing operation: %d\\n\", op_type);\n    \n    // Get operands\n    std::vector<RTLIL::SigSpec> operands;\n    if (uhdm_op->Operands()) {\n        for (auto operand : *uhdm_op->Operands()) {\n            operands.push_back(import_expression(operand));\n        }\n    }\n    \n    switch (op_type) {\n        case vpiNotOp:\n            if (operands.size() == 1)\n                return module->Not(NEW_ID, operands[0]);\n            break;\n        case vpiAndOp:\n            if (operands.size() == 2)\n                return module->And(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiOrOp:\n            if (operands.size() == 2)\n                return module->Or(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiXorOp:\n            if (operands.size() == 2)\n                return module->Xor(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiAddOp:\n            if (operands.size() == 2)\n                return module->Add(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiSubOp:\n            if (operands.size() == 2)\n                return module->Sub(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiMultOp:\n            if (operands.size() == 2)\n                return module->Mul(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiEqOp:\n            if (operands.size() == 2)\n                return module->Eq(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiNeqOp:\n            if (operands.size() == 2)\n                return module->Ne(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiLtOp:\n            if (operands.size() == 2)\n                return module->Lt(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiLeOp:\n            if (operands.size() == 2)\n                return module->Le(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiGtOp:\n            if (operands.size() == 2)\n                return module->Gt(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiGeOp:\n            if (operands.size() == 2)\n                return module->Ge(NEW_ID, operands[0], operands[1]);\n            break;\n        case vpiConditionOp:\n            if (operands.size() == 3)\n                return module->Mux(NEW_ID, operands[0], operands[2], operands[1]);\n            break;\n        default:\n            log_warning(\"Unsupported operation type: %d\\n\", op_type);\n            return RTLIL::SigSpec();\n    }\n    \n    log_warning(\"Operation %d: incorrect number of operands (%d)\\n\", \n                op_type, (int)operands.size());\n    return RTLIL::SigSpec();\n}\n\n// Import reference to object\nRTLIL::SigSpec UhdmImporter::import_ref_obj(const ref_obj* uhdm_ref) {\n    if (auto actual = uhdm_ref->Actual()) {\n        std::string ref_name = get_name(actual);\n        \n        if (mode_debug)\n            log(\"    Importing reference: %s\\n\", ref_name.c_str());\n        \n        // Look up in name map\n        if (name_map.count(ref_name)) {\n            return name_map[ref_name];\n        }\n        \n        log_warning(\"Reference to unknown object: %s\\n\", ref_name.c_str());\n        return RTLIL::SigSpec();\n    }\n    \n    return RTLIL::SigSpec();\n}\n\n// Import part select (e.g., sig[7:0])\nRTLIL::SigSpec UhdmImporter::import_part_select(const part_select* uhdm_part) {\n    if (mode_debug)\n        log(\"    Importing part select\\n\");\n    \n    RTLIL::SigSpec base = import_expression(uhdm_part->Parent());\n    \n    // Get range\n    int left = -1, right = -1;\n    if (auto left_expr = uhdm_part->Left_range()) {\n        RTLIL::SigSpec left_sig = import_expression(left_expr);\n        if (left_sig.is_fully_const())\n            left = left_sig.as_const().as_int();\n    }\n    if (auto right_expr = uhdm_part->Right_range()) {\n        RTLIL::SigSpec right_sig = import_expression(right_expr);\n        if (right_sig.is_fully_const())\n            right = right_sig.as_const().as_int();\n    }\n    \n    if (left >= 0 && right >= 0) {\n        int width = abs(left - right) + 1;\n        int offset = std::min(left, right);\n        return base.extract(offset, width);\n    }\n    \n    return base;\n}\n\n// Import bit select (e.g., sig[3])\nRTLIL::SigSpec UhdmImporter::import_bit_select(const bit_select* uhdm_bit) {\n    if (mode_debug)\n        log(\"    Importing bit select\\n\");\n    \n    RTLIL::SigSpec base = import_expression(uhdm_bit->Parent());\n    RTLIL::SigSpec index = import_expression(uhdm_bit->Index());\n    \n    if (index.is_fully_const()) {\n        int idx = index.as_const().as_int();\n        return base.extract(idx, 1);\n    }\n    \n    // Dynamic bit select - need to create a mux\n    log_warning(\"Dynamic bit select not yet implemented\\n\");\n    return base.extract(0, 1);\n}\n\n// Import concatenation (e.g., {a, b, c})\nRTLIL::SigSpec UhdmImporter::import_concat(const concat* uhdm_concat) {\n    if (mode_debug)\n        log(\"    Importing concatenation\\n\");\n    \n    RTLIL::SigSpec result;\n    \n    if (uhdm_concat->Operands()) {\n        for (auto operand : *uhdm_concat->Operands()) {\n            RTLIL::SigSpec sig = import_expression(operand);\n            result.append(sig);\n        }\n    }\n    \n    return result;\n}\n\nPRIVATE_NAMESPACE_END\nYOSYS_NAMESPACE_END