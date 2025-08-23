/*
 * Primitive Gate UHDM to RTLIL translation
 * 
 * This file handles the translation of Verilog primitive gates
 * (and, or, not, nand, nor, xor, xnor, buf, bufif0, bufif1, notif0, notif1)
 * from UHDM to Yosys RTLIL format.
 */

#include "uhdm2rtlil.h"
#include <uhdm/gate.h>
#include <uhdm/gate_array.h>
#include <uhdm/prim_term.h>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Import primitive gates from a module
void UhdmImporter::import_primitives(const module_inst* uhdm_module) {
    if (!uhdm_module) return;
    
    // Check if the module has a Primitives() method
    // Based on UHDM structure, primitive gates are typically stored as part of module's children
    // We need to check the UHDM API for the exact method name
    
    // For now, log that we're looking for primitives
    if (mode_debug)
        log("UHDM: Checking for primitive gates in module\n");
}

// Import primitive gate arrays from a module
void UhdmImporter::import_primitive_arrays(const module_inst* uhdm_module) {
    if (!uhdm_module) return;
    
    // Check for Primitive_arrays() which should contain gate arrays
    if (uhdm_module->Primitive_arrays()) {
        log("UHDM: Found %d primitive arrays\n", (int)uhdm_module->Primitive_arrays()->size());
        for (auto prim_array : *uhdm_module->Primitive_arrays()) {
            if (auto gate_array = dynamic_cast<const UHDM::gate_array*>(prim_array)) {
                import_gate_array(gate_array);
            }
        }
    }
}

// Import a single gate
void UhdmImporter::import_gate(const gate* uhdm_gate, const std::string& instance_name) {
    if (!uhdm_gate) return;
    
    // Get gate type
    int prim_type = uhdm_gate->VpiPrimType();
    std::string gate_type_str;
    RTLIL::IdString cell_type;
    
    // Map UHDM primitive types to Yosys cell types
    switch (prim_type) {
        case vpiAndPrim:
            gate_type_str = "AND";
            cell_type = ID($_AND_);
            break;
        case vpiNandPrim:
            gate_type_str = "NAND";
            cell_type = ID($_NAND_);
            break;
        case vpiOrPrim:
            gate_type_str = "OR";
            cell_type = ID($_OR_);
            break;
        case vpiNorPrim:
            gate_type_str = "NOR";
            cell_type = ID($_NOR_);
            break;
        case vpiXorPrim:
            gate_type_str = "XOR";
            cell_type = ID($_XOR_);
            break;
        case vpiXnorPrim:
            gate_type_str = "XNOR";
            cell_type = ID($_XNOR_);
            break;
        case vpiNotPrim:
            gate_type_str = "NOT";
            cell_type = ID($_NOT_);
            break;
        case vpiBufPrim:
            gate_type_str = "BUF";
            cell_type = ID($_BUF_);
            break;
        default:
            log_warning("UHDM: Unsupported primitive type %d\n", prim_type);
            return;
    }
    
    // Get instance name (use provided name or gate's VpiName)
    std::string inst_name = instance_name.empty() ? std::string(uhdm_gate->VpiName()) : instance_name;
    if (inst_name.empty()) {
        inst_name = gate_type_str + "_gate";
    }
    
    log("UHDM: Importing %s gate '%s'\n", gate_type_str.c_str(), inst_name.c_str());
    
    // Get terminals (ports)
    if (!uhdm_gate->Prim_terms()) {
        log_error("UHDM: Gate has no terminals\n");
        return;
    }
    
    // Primitive gates have: output first, then inputs
    // For NOT/BUF: 1 output, 1 input
    // For others: 1 output, 2 inputs
    auto terms = *uhdm_gate->Prim_terms();
    if (terms.size() < 2) {
        log_error("UHDM: Gate has insufficient terminals (%d)\n", (int)terms.size());
        return;
    }
    
    // Get output signal (first terminal)
    RTLIL::SigSpec output_sig;
    if (auto out_expr = terms[0]->Expr()) {
        output_sig = import_expression(out_expr);
    } else {
        log_error("UHDM: Gate output terminal has no expression\n");
        return;
    }
    
    // Create the cell
    RTLIL::Cell* cell = module->addCell(get_unique_cell_name(inst_name), cell_type);
    add_src_attribute(cell->attributes, uhdm_gate);
    
    // Connect output
    cell->setPort(ID::Y, output_sig);
    
    // Handle different gate types
    if (prim_type == vpiNotPrim || prim_type == vpiBufPrim) {
        // Single input gates
        if (terms.size() < 2) {
            log_error("UHDM: Single-input gate has no input terminal\n");
            return;
        }
        
        RTLIL::SigSpec input_sig;
        if (auto in_expr = terms[1]->Expr()) {
            input_sig = import_expression(in_expr);
        } else {
            log_error("UHDM: Gate input terminal has no expression\n");
            return;
        }
        
        cell->setPort(ID::A, input_sig);
    } else {
        // Two input gates
        if (terms.size() < 3) {
            log_error("UHDM: Two-input gate has insufficient inputs\n");
            return;
        }
        
        RTLIL::SigSpec input_a, input_b;
        if (auto in_expr = terms[1]->Expr()) {
            input_a = import_expression(in_expr);
        } else {
            log_error("UHDM: Gate input A terminal has no expression\n");
            return;
        }
        
        if (auto in_expr = terms[2]->Expr()) {
            input_b = import_expression(in_expr);
        } else {
            log_error("UHDM: Gate input B terminal has no expression\n");
            return;
        }
        
        cell->setPort(ID::A, input_a);
        cell->setPort(ID::B, input_b);
    }
    
    log("UHDM: Successfully imported %s gate\n", gate_type_str.c_str());
}

// Import a gate array
void UhdmImporter::import_gate_array(const gate_array* uhdm_gate_array) {
    if (!uhdm_gate_array) return;
    
    std::string array_name = std::string(uhdm_gate_array->VpiName());
    log("UHDM: Importing gate array '%s'\n", array_name.c_str());
    
    // Get array bounds from Ranges()
    int array_left = 0;
    int array_right = 0;
    int array_size = 0;
    
    if (uhdm_gate_array->Ranges() && !uhdm_gate_array->Ranges()->empty()) {
        auto range = (*uhdm_gate_array->Ranges())[0];
        if (range->Left_expr() && range->Right_expr()) {
            // Get the left and right bounds
            if (auto left_const = dynamic_cast<const constant*>(range->Left_expr())) {
                // Import the constant to get its value
                RTLIL::SigSpec left_spec = import_constant(left_const);
                if (left_spec.is_fully_const()) {
                    array_left = left_spec.as_const().as_int();
                }
            }
            if (auto right_const = dynamic_cast<const constant*>(range->Right_expr())) {
                // Import the constant to get its value
                RTLIL::SigSpec right_spec = import_constant(right_const);
                if (right_spec.is_fully_const()) {
                    array_right = right_spec.as_const().as_int();
                }
            }
            // Calculate size
            array_size = std::abs(array_left - array_right) + 1;
        }
    } else {
        // Use VpiSize if available
        array_size = uhdm_gate_array->VpiSize();
        if (array_size == 0) {
            log_error("UHDM: Gate array has no size information\n");
            return;
        }
    }
    
    log("UHDM: Gate array has %d elements (range [%d:%d])\n", array_size, array_left, array_right);
    
    // Get the primitive template
    if (!uhdm_gate_array->Primitives() || uhdm_gate_array->Primitives()->empty()) {
        log_error("UHDM: Gate array has no primitive template\n");
        return;
    }
    
    // The first primitive is the template for the array
    auto prim_template = (*uhdm_gate_array->Primitives())[0];
    auto gate_template = dynamic_cast<const gate*>(prim_template);
    if (!gate_template) {
        log_error("UHDM: Primitive is not a gate\n");
        return;
    }
    
    // Import each gate in the array
    // Determine if array is ascending or descending
    bool descending = (array_left > array_right);
    
    for (int i = 0; i < array_size; i++) {
        int array_index;
        int bit_index;
        
        if (descending) {
            // For [3:0], array_index goes 3,2,1,0 and bit_index matches
            array_index = array_left - i;
            bit_index = array_index;
        } else {
            // For [0:3], array_index goes 0,1,2,3 and bit_index matches
            array_index = array_left + i;
            bit_index = array_index;
        }
        
        // Generate instance name with array index
        std::string inst_name = array_name + "[" + std::to_string(array_index) + "]";
        
        // For each array element, we need to create a gate with bit-selected connections
        import_gate_array_element(gate_template, inst_name, bit_index);
    }
}

// Import a single element of a gate array
void UhdmImporter::import_gate_array_element(const gate* gate_template, const std::string& instance_name, int bit_index) {
    if (!gate_template) return;
    
    // Get gate type
    int prim_type = gate_template->VpiPrimType();
    std::string gate_type_str;
    RTLIL::IdString cell_type;
    
    // Map UHDM primitive types to Yosys cell types
    switch (prim_type) {
        case vpiAndPrim:
            gate_type_str = "AND";
            cell_type = ID($_AND_);
            break;
        case vpiNandPrim:
            gate_type_str = "NAND";
            cell_type = ID($_NAND_);
            break;
        case vpiOrPrim:
            gate_type_str = "OR";
            cell_type = ID($_OR_);
            break;
        case vpiNorPrim:
            gate_type_str = "NOR";
            cell_type = ID($_NOR_);
            break;
        case vpiXorPrim:
            gate_type_str = "XOR";
            cell_type = ID($_XOR_);
            break;
        case vpiXnorPrim:
            gate_type_str = "XNOR";
            cell_type = ID($_XNOR_);
            break;
        case vpiNotPrim:
            gate_type_str = "NOT";
            cell_type = ID($_NOT_);
            break;
        case vpiBufPrim:
            gate_type_str = "BUF";
            cell_type = ID($_BUF_);
            break;
        default:
            log_warning("UHDM: Unsupported primitive type %d\n", prim_type);
            return;
    }
    
    log("UHDM: Creating %s gate '%s' (bit %d)\n", gate_type_str.c_str(), instance_name.c_str(), bit_index);
    
    // Get terminals (ports)
    if (!gate_template->Prim_terms()) {
        log_error("UHDM: Gate has no terminals\n");
        return;
    }
    
    // Create the cell
    RTLIL::Cell* cell = module->addCell(get_unique_cell_name(instance_name), cell_type);
    add_src_attribute(cell->attributes, gate_template);
    
    // Process terminals - first is output, rest are inputs
    auto terms = *gate_template->Prim_terms();
    if (terms.size() < 2) {
        log_error("UHDM: Gate has insufficient terminals (%d)\n", (int)terms.size());
        return;
    }
    
    // Get output signal (first terminal) with bit selection
    RTLIL::SigSpec output_sig;
    if (auto out_expr = terms[0]->Expr()) {
        RTLIL::SigSpec full_sig = import_expression(out_expr);
        // Select the specific bit for this array element
        if (full_sig.size() > 1 && bit_index < full_sig.size()) {
            output_sig = full_sig[bit_index];
        } else {
            output_sig = full_sig;
        }
    } else {
        log_error("UHDM: Gate output terminal has no expression\n");
        return;
    }
    
    // Connect output
    cell->setPort(ID::Y, output_sig);
    
    // Handle different gate types
    if (prim_type == vpiNotPrim || prim_type == vpiBufPrim) {
        // Single input gates
        if (terms.size() < 2) {
            log_error("UHDM: Single-input gate has no input terminal\n");
            return;
        }
        
        RTLIL::SigSpec input_sig;
        if (auto in_expr = terms[1]->Expr()) {
            RTLIL::SigSpec full_sig = import_expression(in_expr);
            // Select the specific bit for this array element
            if (full_sig.size() > 1 && bit_index < full_sig.size()) {
                input_sig = full_sig[bit_index];
            } else {
                input_sig = full_sig;
            }
        } else {
            log_error("UHDM: Gate input terminal has no expression\n");
            return;
        }
        
        cell->setPort(ID::A, input_sig);
    } else {
        // Two input gates
        if (terms.size() < 3) {
            log_error("UHDM: Two-input gate has insufficient inputs\n");
            return;
        }
        
        RTLIL::SigSpec input_a, input_b;
        if (auto in_expr = terms[1]->Expr()) {
            RTLIL::SigSpec full_sig = import_expression(in_expr);
            // Select the specific bit for this array element
            if (full_sig.size() > 1 && bit_index < full_sig.size()) {
                input_a = full_sig[bit_index];
            } else {
                input_a = full_sig;
            }
        } else {
            log_error("UHDM: Gate input A terminal has no expression\n");
            return;
        }
        
        if (auto in_expr = terms[2]->Expr()) {
            RTLIL::SigSpec full_sig = import_expression(in_expr);
            // Select the specific bit for this array element
            if (full_sig.size() > 1 && bit_index < full_sig.size()) {
                input_b = full_sig[bit_index];
            } else {
                input_b = full_sig;
            }
        } else {
            log_error("UHDM: Gate input B terminal has no expression\n");
            return;
        }
        
        cell->setPort(ID::A, input_a);
        cell->setPort(ID::B, input_b);
    }
    
    log("UHDM: Successfully created %s gate element\n", gate_type_str.c_str());
}

YOSYS_NAMESPACE_END