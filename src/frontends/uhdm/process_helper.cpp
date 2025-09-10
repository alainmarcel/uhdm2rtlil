/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2024 The Yosys Authors
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

/*
 * Process and statement handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog processes
 * (always blocks) and statements.
 */

#include "uhdm2rtlil.h"
#include <algorithm>
#include <functional>
#include <set>


YOSYS_NAMESPACE_BEGIN

// ============================================================================
// Helper functions to reduce code duplication
// ============================================================================

// Helper to safely cast to assignment
const UHDM::assignment* UhdmImporter::cast_to_assignment(const UHDM::any* stmt) {
    if (!stmt || stmt->VpiType() != vpiAssignment) return nullptr;
    return any_cast<const assignment*>(stmt);
}

// Helper to check VPI type
bool UhdmImporter::is_vpi_type(const UHDM::any* obj, int vpi_type) {
    return obj && obj->VpiType() == vpi_type;
}

// Create a temporary wire
RTLIL::SigSpec UhdmImporter::create_temp_wire(int width) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, width);
    return wire;
}

// Create equality comparison cell
RTLIL::SigSpec UhdmImporter::create_eq_cell(const RTLIL::SigSpec& a, const RTLIL::SigSpec& b, const UHDM::any* src) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, 1);
    if (src) add_src_attribute(wire->attributes, src);
    RTLIL::SigSpec result = wire;
    RTLIL::Cell* cell = module->addEq(NEW_ID, a, b, result);
    if (src) add_src_attribute(cell->attributes, src);
    return result;
}

// Create AND cell
RTLIL::SigSpec UhdmImporter::create_and_cell(const RTLIL::SigSpec& a, const RTLIL::SigSpec& b, const UHDM::any* src) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, 1);
    if (src) add_src_attribute(wire->attributes, src);
    RTLIL::SigSpec result = wire;
    RTLIL::Cell* cell = module->addAnd(NEW_ID, a, b, result);
    if (src) add_src_attribute(cell->attributes, src);
    return result;
}

// Create OR cell
RTLIL::SigSpec UhdmImporter::create_or_cell(const RTLIL::SigSpec& a, const RTLIL::SigSpec& b, const UHDM::any* src) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, 1);
    if (src) add_src_attribute(wire->attributes, src);
    RTLIL::SigSpec result = wire;
    RTLIL::Cell* cell = module->addOr(NEW_ID, a, b, result);
    if (src) add_src_attribute(cell->attributes, src);
    return result;
}

// Create NOT cell
RTLIL::SigSpec UhdmImporter::create_not_cell(const RTLIL::SigSpec& a, const UHDM::any* src) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, 1);
    if (src) add_src_attribute(wire->attributes, src);
    RTLIL::SigSpec result = wire;
    RTLIL::Cell* cell = module->addNot(NEW_ID, a, result);
    if (src) add_src_attribute(cell->attributes, src);
    return result;
}

// Create MUX cell
RTLIL::SigSpec UhdmImporter::create_mux_cell(const RTLIL::SigSpec& sel, const RTLIL::SigSpec& b, const RTLIL::SigSpec& a, int width) {
    if (width == 0) width = std::max(a.size(), b.size());
    RTLIL::SigSpec result = create_temp_wire(width);
    module->addMux(NEW_ID, a, b, sel, result);
    return result;
}

UHDM::VectorOfany *UhdmImporter::begin_block_stmts(const any *stmt)
{
    UHDM::VectorOfany *stmts = nullptr;
    if (stmt->VpiType() == vpiBegin) {
        const UHDM::begin *begin_stmt = any_cast<const UHDM::begin *>(stmt);
        if (begin_stmt->Stmts() && !begin_stmt->Stmts()->empty()) {
            stmts = begin_stmt->Stmts();
        }
    } else {
        const UHDM::named_begin *begin_stmt = any_cast<const UHDM::named_begin *>(stmt);
        if (begin_stmt->Stmts() && !begin_stmt->Stmts()->empty()) {
            stmts = begin_stmt->Stmts();
        }
    }
    return stmts;
}

// Process assignment to get LHS and RHS
void UhdmImporter::process_assignment_lhs_rhs(const UHDM::assignment* assign, RTLIL::SigSpec& lhs, RTLIL::SigSpec& rhs) {
    if (!assign) return;
    
    auto lhs_expr = assign->Lhs();
    auto rhs_expr = assign->Rhs();
    
    if (lhs_expr) lhs = import_expression(any_cast<const expr*>(lhs_expr));
    if (rhs_expr) rhs = import_expression(any_cast<const expr*>(rhs_expr));
}


void UhdmImporter::extract_assigned_signals(const any* stmt, std::vector<AssignedSignal>& signals) {
    if (!stmt) return;
    
    switch (stmt->VpiType()) {
        case vpiAssignment:
        case vpiAssignStmt: {
            auto assign = any_cast<const assignment*>(stmt);
            if (auto lhs = assign->Lhs()) {
                if (auto lhs_expr = dynamic_cast<const expr*>(lhs)) {
                    AssignedSignal sig;
                    sig.lhs_expr = lhs_expr;
                    
                    log("extract_assigned_signals: LHS type is %d\n", lhs_expr->VpiType());
                    if (lhs_expr->VpiType() == vpiRefObj) {
                        auto ref = any_cast<const ref_obj*>(lhs_expr);
                        sig.name = std::string(ref->VpiName());
                        sig.is_part_select = false;
                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to '%s' (ref_obj)\n", ref->VpiName().data());
                    } else if (lhs_expr->VpiType() == vpiNetBit) {
                        auto net_bit = any_cast<const UHDM::net_bit*>(lhs_expr);
                        sig.name = std::string(net_bit->VpiName());
                        sig.is_part_select = false;
                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to '%s' (net_bit)\n", net_bit->VpiName().data());
                    } else if (lhs_expr->VpiType() == vpiIndexedPartSelect) {
                        // Handle indexed part selects like result[i*8 +: 8]
                        auto indexed_part_sel = any_cast<const indexed_part_select*>(lhs_expr);
                        sig.is_part_select = true;
                        
                        // Get the signal name
                        if (!indexed_part_sel->VpiName().empty()) {
                            sig.name = std::string(indexed_part_sel->VpiName());
                        }
                        
                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to indexed part select of '%s'\n", sig.name.c_str());
                    } else if (lhs_expr->VpiType() == vpiPartSelect) {
                        // Handle part selects like result[7:0]
                        auto part_sel = any_cast<const part_select*>(lhs_expr);
                        sig.is_part_select = true;
                        
                        if (auto parent = part_sel->VpiParent()) {
                            if (parent->VpiType() == vpiRefObj) {
                                auto ref = any_cast<const ref_obj*>(parent);
                                sig.name = std::string(ref->VpiName());
                            } else if (!parent->VpiName().empty()) {
                                sig.name = std::string(parent->VpiName());
                            }
                        } else if (!part_sel->VpiName().empty()) {
                            sig.name = std::string(part_sel->VpiName());
                        }
                        
                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to part select of '%s'\n", sig.name.c_str());
                    } else if (lhs_expr->VpiType() == vpiBitSelect) {
                        // Handle bit selects like result[0] or memory[addr]
                        auto bit_sel = any_cast<const bit_select*>(lhs_expr);
                        sig.is_part_select = true;
                        
                        // First try to get name from bit_select itself
                        if (!bit_sel->VpiName().empty()) {
                            sig.name = std::string(bit_sel->VpiName());
                        } else if (auto parent = bit_sel->VpiParent()) {
                            // Fall back to parent if bit_select doesn't have a name
                            if (parent->VpiType() == vpiRefObj) {
                                auto ref = any_cast<const ref_obj*>(parent);
                                sig.name = std::string(ref->VpiName());
                            } else if (!parent->VpiName().empty()) {
                                sig.name = std::string(parent->VpiName());
                            }
                        }
                        
                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to bit select of '%s'\n", sig.name.c_str());
                    }
                }
            }
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            UHDM::VectorOfany* stmts = begin_block_stmts(stmt);
            if (stmts) { 
                for (auto s : *stmts) {
                    extract_assigned_signals(s, signals);
                }
            }
            break;
        }
        case vpiCase: {
            auto case_st = any_cast<const UHDM::case_stmt*>(stmt);
            if (auto items = case_st->Case_items()) {
                for (auto item : *items) {
                    if (auto s = item->Stmt()) {
                        extract_assigned_signals(s, signals);
                    }
                }
            }
            break;
        }
        case vpiIf: {
            auto if_st = any_cast<const UHDM::if_stmt*>(stmt);
            if (auto then_stmt = if_st->VpiStmt()) {
                extract_assigned_signals(then_stmt, signals);
            }
            break;
        }
        case vpiIfElse: {
            auto if_else = any_cast<const UHDM::if_else*>(stmt);
            if (auto then_stmt = if_else->VpiStmt()) {
                extract_assigned_signals(then_stmt, signals);
            }
            if (auto else_stmt = if_else->VpiElseStmt()) {
                extract_assigned_signals(else_stmt, signals);
            }
            break;
        }
    }
}


// Extract signal names from a UHDM process statement
bool UhdmImporter::extract_signal_names_from_process(const UHDM::any* stmt, 
                                                   std::string& output_signal, std::string& input_signal,
                                                   std::string& clock_signal, std::string& reset_signal,
                                                   std::vector<int>& slice_offsets, std::vector<int>& slice_widths) {
    
    log("UHDM: Extracting signal names from process statement\n");
    
    // Handle event_control wrapper (for always_ff @(...))
    if (stmt->VpiType() == vpiEventControl) {
        const UHDM::event_control* event_ctrl = any_cast<const UHDM::event_control*>(stmt);
        if (auto controlled_stmt = event_ctrl->Stmt()) {
            // Extract the actual statement from event control
            stmt = controlled_stmt;
            log("UHDM: Unwrapped event_control, found inner statement type: %s (vpiType=%d)\n", 
                UhdmName(stmt->UhdmType()).c_str(), stmt->VpiType());
        }
    }
    
    // Handle begin block
    VectorOfany* stmts = begin_block_stmts(stmt);
    if (stmts) {
        // Get first statement from begin block
        stmt = stmts->at(0);
        log("UHDM: Unwrapped begin block, found inner statement type: %s (vpiType=%d)\n",
            UhdmName(stmt->UhdmType()).c_str(), stmt->VpiType());
    }
    
    // For simple_counter, we need to extract from the if statement structure
    if (stmt->VpiType() == vpiIf || stmt->VpiType() == vpiIfElse) {
        log("UHDM: Found if statement, VpiType=%d, UhdmType=%s\n", stmt->VpiType(), UhdmName(stmt->UhdmType()).c_str());
        
        // Check if this is an if_else or just if_stmt
        if (stmt->UhdmType() == uhdmif_else) {
            const UHDM::if_else* if_else_stmt = any_cast<const UHDM::if_else*>(stmt);
            
            // For simple always_ff patterns like: if (!rst_n) count <= 0; else count <= count + 1;
            // We look for assignments in the then/else branches
            
            // Check then statement for reset assignment
            if (auto then_stmt = if_else_stmt->VpiStmt()) {
                log("UHDM: Then statement type: %s (vpiType=%d)\n", UhdmName(then_stmt->UhdmType()).c_str(), then_stmt->VpiType());
                // Handle begin blocks
                if (then_stmt->VpiType() == vpiBegin || then_stmt->VpiType() == vpiNamedBegin) {
                    VectorOfany* stmts = begin_block_stmts(then_stmt);
                    if (stmts) {
                        // Look for assignment inside begin block
                        for (auto stmt : *stmts) {
                            if (stmt->VpiType() == vpiAssignment) {
                                then_stmt = stmt;
                                break;
                            }
                        }
                    }
                }
                
                if (then_stmt->VpiType() == vpiAssignment) {
                    const UHDM::assignment* assign = any_cast<const UHDM::assignment*>(then_stmt);
                    if (auto lhs = assign->Lhs()) {
                        if (lhs->VpiType() == vpiRefObj) {
                            const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(lhs);
                            output_signal = std::string(ref->VpiName());
                            log("UHDM: Found output signal from reset assignment: %s\n", output_signal.c_str());
                        } else if (lhs->VpiType() == vpiIndexedPartSelect) {
                            // For indexed part selects like result[i*8 +: 8], we need to extract the base signal
                            const UHDM::indexed_part_select* ips = any_cast<const UHDM::indexed_part_select*>(lhs);
                            // Try to get the base signal name
                            if (!ips->VpiDefName().empty()) {
                                output_signal = std::string(ips->VpiDefName());
                            } else if (!ips->VpiName().empty()) {
                                output_signal = std::string(ips->VpiName());
                            } else if (auto parent = ips->VpiParent()) {
                                if (!parent->VpiDefName().empty()) {
                                    output_signal = std::string(parent->VpiDefName());
                                } else if (!parent->VpiName().empty()) {
                                    output_signal = std::string(parent->VpiName());
                                }
                            }
                            log("UHDM: Found output signal from indexed part select: %s\n", output_signal.c_str());
                            
                            // Extract slice information from indexed part select
                            if (ips->Base_expr()) {
                                RTLIL::SigSpec base_expr = import_expression(ips->Base_expr());
                                if (base_expr.is_fully_const()) {
                                    int offset = base_expr.as_const().as_int();
                                    slice_offsets.push_back(offset);
                                    log("UHDM: Indexed part select offset: %d\n", offset);
                                }
                            }
                            if (ips->Width_expr()) {
                                RTLIL::SigSpec width_expr = import_expression(ips->Width_expr());
                                if (width_expr.is_fully_const()) {
                                    int width = width_expr.as_const().as_int();
                                    slice_widths.push_back(width);
                                    log("UHDM: Indexed part select width: %d\n", width);
                                }
                            }
                        }
                    }
                }
            }
            
            // Check else statement for normal assignment  
            if (auto else_stmt = if_else_stmt->VpiElseStmt()) {
                log("UHDM: Found else statement, type: %s (vpiType=%d)\n", 
                    UhdmName(else_stmt->UhdmType()).c_str(), else_stmt->VpiType());
                // Handle begin blocks
                if (else_stmt->VpiType() == vpiBegin || else_stmt->VpiType() == vpiNamedBegin) {
                    VectorOfany* stmts = begin_block_stmts(stmt);
                    if (stmts) {
                        // Look for assignment inside begin block
                        for (auto stmt : *stmts) {
                            if (stmt->VpiType() == vpiAssignment) {
                                else_stmt = stmt;
                                break;
                            }
                        }
                    }
                }
                
                if (else_stmt->VpiType() == vpiAssignment) {
                    const UHDM::assignment* assign = any_cast<const UHDM::assignment*>(else_stmt);
                    log("UHDM: Processing else assignment\n");
                    if (auto rhs = assign->Rhs()) {
                        log("UHDM: RHS type: %s (vpiType=%d)\n", UhdmName(rhs->UhdmType()).c_str(), rhs->VpiType());
                        // For simple ref like "unit_result"
                        if (rhs->VpiType() == vpiRefObj) {
                            const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(rhs);
                            input_signal = std::string(ref->VpiName());
                            log("UHDM: Found input signal from else assignment: %s\n", input_signal.c_str());
                        }
                        // For expressions like "count + 1", we want to extract "count" as input
                        else if (rhs->VpiType() == vpiOperation) {
                            const UHDM::operation* op = any_cast<const UHDM::operation*>(rhs);
                            if (auto operands = op->Operands()) {
                                for (auto operand : *operands) {
                                    if (operand->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(operand);
                                        input_signal = std::string(ref->VpiName());
                                        log("UHDM: Found input signal from operation: %s\n", input_signal.c_str());
                                        break;
                                    }
                                }
                            }
                        }
                    }
                } else if (else_stmt->VpiType() == vpiIfElse || else_stmt->VpiType() == vpiIf) {
                    // Handle else-if case
                    const UHDM::any* else_if_stmt = else_stmt;
                    if (else_if_stmt->UhdmType() == uhdmif_else) {
                        const UHDM::if_else* nested_if_else = any_cast<const UHDM::if_else*>(else_if_stmt);
                        // Check the then statement of the else-if
                        if (auto then_stmt = nested_if_else->VpiStmt()) {
                            if (then_stmt->VpiType() == vpiAssignment) {
                                const UHDM::assignment* assign = any_cast<const UHDM::assignment*>(then_stmt);
                                if (auto lhs = assign->Lhs()) {
                                    if (lhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(lhs);
                                        // Only update output_signal if it's empty (priority to first-level assignment)
                                        if (output_signal.empty()) {
                                            output_signal = std::string(ref->VpiName());
                                            log("UHDM: Found output signal from else-if assignment: %s\n", output_signal.c_str());
                                        }
                                    }
                                }
                                if (auto rhs = assign->Rhs()) {
                                    if (rhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(rhs);
                                        input_signal = std::string(ref->VpiName());
                                        log("UHDM: Found input signal from else-if assignment: %s\n", input_signal.c_str());
                                    }
                                }
                            }
                        }
                    } else if (else_if_stmt->VpiType() == vpiIf) {
                        const UHDM::if_stmt* nested_if = any_cast<const UHDM::if_stmt*>(else_if_stmt);
                        // Check the then statement of the else-if
                        if (auto then_stmt = nested_if->VpiStmt()) {
                            if (then_stmt->VpiType() == vpiAssignment) {
                                const UHDM::assignment* assign = any_cast<const UHDM::assignment*>(then_stmt);
                                if (auto lhs = assign->Lhs()) {
                                    if (lhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(lhs);
                                        // Only update output_signal if it's empty (priority to first-level assignment)
                                        if (output_signal.empty()) {
                                            output_signal = std::string(ref->VpiName());
                                            log("UHDM: Found output signal from else-if assignment: %s\n", output_signal.c_str());
                                        }
                                    }
                                }
                                if (auto rhs = assign->Rhs()) {
                                    if (rhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(rhs);
                                        input_signal = std::string(ref->VpiName());
                                        log("UHDM: Found input signal from else-if assignment: %s\n", input_signal.c_str());
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Extract reset signal from condition (!rst_n)
            if (auto condition = if_else_stmt->VpiCondition()) {
                if (condition->VpiType() == vpiOperation) {
                    const UHDM::operation* op = any_cast<const UHDM::operation*>(condition);
                    if (auto operands = op->Operands()) {
                        for (auto operand : *operands) {
                            if (operand->VpiType() == vpiRefObj) {
                                const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(operand);
                                reset_signal = std::string(ref->VpiName());
                                log("UHDM: Found reset signal from condition: %s\n", reset_signal.c_str());
                                break;
                            }
                        }
                    }
                }
            }
        } else {
            // Handle simple if_stmt without else
            log("UHDM: Processing simple if_stmt (no else clause)\n");
        }
    }
    
    // For clock signal, we need to look at the sensitivity list (this is tricky in UHDM)
    // For now, use a common default
    clock_signal = "clk";  
    
    // For simple_counter, count is both input and output, so allow this case
    if (!output_signal.empty() && input_signal.empty()) {
        input_signal = output_signal;  // count is both input and output
    }
    
    // Return true if we found at least an output signal
    bool success = !output_signal.empty();
    log("UHDM: Signal extraction %s: output=%s, input=%s, clock=%s, reset=%s\n",
        success ? "succeeded" : "failed",
        output_signal.c_str(), input_signal.c_str(), 
        clock_signal.c_str(), reset_signal.c_str());
    
    return success;
}

// Check if a statement contains complex constructs (for loops, memory writes, etc.)
bool UhdmImporter::contains_complex_constructs(const any* stmt) {
    if (!stmt) return false;
    
    int stmt_type = stmt->VpiType();
    
    // Check for complex statement types
    if (stmt_type == vpiFor || stmt_type == vpiForever || stmt_type == vpiWhile) {
        return true;
    }
     
    // Note: Memory writes (bit select assignments) are now allowed in simple if patterns
    // They will be handled specially during switch statement generation
    
    // Check for begin blocks (both regular and named)
    if (stmt_type == vpiBegin || stmt_type == vpiNamedBegin) {
        VectorOfany* stmts = begin_block_stmts(stmt);
        if (stmts) {
            for (auto sub_stmt : *stmts) {
                if (sub_stmt && contains_complex_constructs(sub_stmt)) {
                    return true;
                }
            }
        }
    } else if (stmt_type == vpiIf) {
        // Check for nested if statements
        const UHDM::if_stmt* if_stmt = any_cast<const UHDM::if_stmt*>(stmt);
        if (if_stmt) {
            if (if_stmt->VpiStmt() && contains_complex_constructs(if_stmt->VpiStmt())) {
                return true;
            }
        }
    } else if (stmt_type == vpiIfElse) {
        // Check for nested if statements
        const if_else* if_stmt = any_cast<const if_else*>(stmt);
        if (if_stmt) {
            if (if_stmt->VpiStmt() && contains_complex_constructs(if_stmt->VpiStmt())) {
                return true;
            }
            if (if_stmt->VpiElseStmt() && contains_complex_constructs(if_stmt->VpiElseStmt())) {
                return true;
            }
        }
    }
    
    return false;
}

// Extract just the signal names from assignments
void UhdmImporter::extract_assigned_signal_names(const any* stmt, std::set<std::string>& signal_names) {
    std::vector<AssignedSignal> signals;
    extract_assigned_signals(stmt, signals);
    for (const auto& sig : signals) {
        if (!sig.name.empty()) {
            signal_names.insert(sig.name);
        }
    }
}

// Helper function to check if an assignment is a memory write
bool UhdmImporter::is_memory_write(const assignment* assign, RTLIL::Module* module) {
    if (!assign || !module) return false;
    
    if (auto lhs = assign->Lhs()) {
        if (lhs->VpiType() == vpiBitSelect) {
            const bit_select* bit_sel = any_cast<const bit_select*>(lhs);
            std::string signal_name = std::string(bit_sel->VpiName());
            RTLIL::IdString mem_id = RTLIL::escape_id(signal_name);
            return module->memories.count(mem_id) > 0;
        }
    }
    return false;
}

// Helper function to scan a statement tree for memory writes
void UhdmImporter::scan_for_memory_writes(const any* stmt, std::set<std::string>& memory_names, RTLIL::Module* module) {
    if (!stmt || !module) return;
    
    switch (stmt->VpiType()) {
        case vpiAssignment:
        case vpiAssignStmt: {
            const assignment* assign = any_cast<const assignment*>(stmt);
            if (is_memory_write(assign, module)) {
                if (auto lhs = assign->Lhs()) {
                    if (lhs->VpiType() == vpiBitSelect) {
                        const bit_select* bit_sel = any_cast<const bit_select*>(lhs);
                        std::string signal_name = std::string(bit_sel->VpiName());
                        memory_names.insert(signal_name);
                    }
                }
            }
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            VectorOfany* stmts = begin_block_stmts(stmt);
            if (stmts) {
                for (auto sub_stmt : *stmts) {
                    scan_for_memory_writes(sub_stmt, memory_names, module);
                }
            }
            break;
        }
        case vpiIf: {
            const UHDM::if_stmt* if_stmt = any_cast<const UHDM::if_stmt*>(stmt);
            if (auto then_stmt = if_stmt->VpiStmt()) {
                scan_for_memory_writes(then_stmt, memory_names, module);
            }
            break;
        }
        case vpiIfElse: {
            const if_else* if_else_stmt = any_cast<const if_else*>(stmt);
            if (auto then_stmt = if_else_stmt->VpiStmt()) {
                scan_for_memory_writes(then_stmt, memory_names, module);
            }
            if (auto else_stmt = if_else_stmt->VpiElseStmt()) {
                scan_for_memory_writes(else_stmt, memory_names, module);
            }
            break;
        }
        case vpiCase: {
            const case_stmt* case_stmt_obj = any_cast<const case_stmt*>(stmt);
            if (case_stmt_obj->Case_items()) {
                for (auto case_item : *case_stmt_obj->Case_items()) {
                    if (auto case_item_stmt = case_item->Stmt()) {
                        scan_for_memory_writes(case_item_stmt, memory_names, module);
                    }
                }
            }
            break;
        }
    }
}

// Find assignment statement for a given LHS expression
const assignment* UhdmImporter::find_assignment_for_lhs(const any* stmt, const expr* lhs_expr) {
    if (!stmt || !lhs_expr) return nullptr;
    
    switch (stmt->VpiType()) {
        case vpiAssignment:
        case vpiAssignStmt: {
            auto assign = any_cast<const assignment*>(stmt);
            if (assign->Lhs() == lhs_expr) {
                return assign;
            }
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            VectorOfany* stmts = begin_block_stmts(stmt);
            if (stmts) {
                for (auto s : *stmts) {
                    if (auto result = find_assignment_for_lhs(s, lhs_expr)) {
                        return result;
                    }
                }
            }
            break;
        }
        case vpiIfElse:
        case vpiIf: {
            auto if_st = any_cast<const UHDM::if_stmt*>(stmt);
            if (auto result = find_assignment_for_lhs(if_st->VpiStmt(), lhs_expr)) {
                return result;
            }
            if (stmt->VpiType() == vpiIfElse) {
                auto if_else_st = any_cast<const UHDM::if_else*>(stmt);
                if (if_else_st->VpiElseStmt()) {
                    if (auto result = find_assignment_for_lhs(if_else_st->VpiElseStmt(), lhs_expr)) {
                        return result;
                    }
                }
            }
            break;
        }
    }
    
    return nullptr;
}

YOSYS_NAMESPACE_END