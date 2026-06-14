/*
 * Expression handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog expressions
 * including operations, constants, and references.
 */

#include "uhdm2rtlil.h"
#include <uhdm/logic_var.h>
#include <uhdm/struct_var.h>
#include <uhdm/union_var.h>
#include <uhdm/integer_var.h>
#include <uhdm/ref_var.h>
#include <uhdm/logic_net.h>
#include <uhdm/logic_typespec.h>
#include <uhdm/net.h>
#include <uhdm/port.h>
#include <uhdm/struct_typespec.h>
#include <uhdm/union_typespec.h>
#include <uhdm/typespec_member.h>
#include <uhdm/vpi_visitor.h>
#include <uhdm/assignment.h>
#include <uhdm/uhdm_vpi_user.h>
#include <uhdm/parameter.h>
#include <uhdm/param_assign.h>
#include <uhdm/return_stmt.h>
#include <uhdm/struct_net.h>
#include <uhdm/uhdm_types.h>
#include <uhdm/integer_typespec.h>
#include <uhdm/int_typespec.h>
#include <uhdm/short_int_typespec.h>
#include <uhdm/long_int_typespec.h>
#include <uhdm/byte_typespec.h>
#include <uhdm/bit_typespec.h>
#include <uhdm/range.h>
#include <uhdm/sys_func_call.h>
#include <uhdm/func_call.h>
#include <uhdm/method_func_call.h>
#include <uhdm/function.h>
#include <uhdm/case_stmt.h>
#include <uhdm/case_item.h>
#include <uhdm/io_decl.h>
#include <uhdm/begin.h>
#include <uhdm/named_begin.h>
#include <uhdm/if_else.h>
#include <uhdm/var_select.h>
#include <uhdm/array_net.h>
#include <uhdm/packed_array_typespec.h>
#include <uhdm/packed_array_var.h>
#include <uhdm/bit_select.h>
#include <uhdm/part_select.h>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Helper function to generate consistent source-location-based cell names
std::string UhdmImporter::generate_cell_name(const UHDM::any* uhdm_obj, const std::string& cell_type) {
    std::string cell_name;
    if (uhdm_obj && !uhdm_obj->VpiFile().empty()) {
        // Extract just the filename from the full path
        std::string_view full_path = uhdm_obj->VpiFile();
        size_t pos = full_path.find_last_of("/\\");
        std::string filename = (pos != std::string::npos) ? 
            std::string(full_path.substr(pos + 1)) : std::string(full_path);
        
        cell_name = stringf("$%s$%s:%d$%d", cell_type.c_str(), filename.c_str(), 
            uhdm_obj->VpiLineNo(), incr_autoidx());
    } else {
        cell_name = stringf("$%s$expression.cpp:%d$%d", cell_type.c_str(), __LINE__, incr_autoidx());
    }
    return cell_name;
}

// Helper function to process a statement into a case rule for function process generation
void UhdmImporter::process_stmt_to_case(const any* stmt, RTLIL::CaseRule* case_rule,
                                        RTLIL::Wire* result_wire,
                                        std::map<std::string, RTLIL::SigSpec>& input_mapping,
                                        const std::string& func_name,
                                        int& temp_counter,
                                        const std::string& func_call_context,
                                        const std::map<std::string, int>& local_var_widths) {
    if (!stmt || !case_rule) return;
    
    if (mode_debug) {
        log("  process_stmt_to_case: func=%s, stmt type=%d\n", func_name.c_str(), stmt->UhdmType());
    }
    
    int type = stmt->UhdmType();
    switch(type) {
    case uhdmbegin: {
        // Handle begin-end block with scope support for local variables
        const begin* bg = any_cast<const begin*>(stmt);
        if (bg) {
            // Save and shadow variables declared in this block
            std::map<std::string, RTLIL::SigSpec> saved_mappings;
            std::set<std::string> block_local_vars;

            if (bg->Variables()) {
                for (auto var : *bg->Variables()) {
                    std::string var_name = std::string(var->VpiName());
                    int width = get_width(var, current_instance);
                    if (width <= 0) width = 1;

                    // Save old mapping if it exists
                    auto it = input_mapping.find(var_name);
                    if (it != input_mapping.end()) {
                        saved_mappings[var_name] = it->second;
                    }
                    block_local_vars.insert(var_name);

                    // Create a wire for this local variable and shadow in input_mapping
                    std::string local_wire_name = stringf("$%s$blk_%s_%d",
                        func_call_context.c_str(), var_name.c_str(), incr_autoidx());
                    RTLIL::Wire* local_wire = module->addWire(RTLIL::escape_id(local_wire_name), width);
                    input_mapping[var_name] = RTLIL::SigSpec(local_wire);

                    if (mode_debug) {
                        log("    Created block-local variable %s (width=%d)\n", var_name.c_str(), width);
                    }
                }
            }

            if (bg->Stmts()) {
                for (auto s : *bg->Stmts()) {
                    process_stmt_to_case(s, case_rule, result_wire, input_mapping, func_name, temp_counter, func_call_context, local_var_widths);
                }
            }

            // Restore shadowed variables
            for (auto& [name, sig] : saved_mappings) {
                input_mapping[name] = sig;
            }
            // Remove variables that only existed in this block scope
            for (const auto& var_name : block_local_vars) {
                if (saved_mappings.find(var_name) == saved_mappings.end()) {
                    input_mapping.erase(var_name);
                }
            }
        }
        break;
    }

    case uhdmnamed_begin: {
        // Handle named begin-end block with scope support for local variables
        const named_begin* nbg = any_cast<const named_begin*>(stmt);
        if (nbg) {
            // Save and shadow variables declared in this block
            std::map<std::string, RTLIL::SigSpec> saved_mappings;
            std::set<std::string> block_local_vars;
            std::string block_name = nbg->VpiName().empty() ? "blk" : std::string(nbg->VpiName());

            if (nbg->Variables()) {
                for (auto var : *nbg->Variables()) {
                    std::string var_name = std::string(var->VpiName());
                    int width = get_width(var, current_instance);
                    if (width <= 0) width = 1;

                    // Save old mapping if it exists
                    auto it = input_mapping.find(var_name);
                    if (it != input_mapping.end()) {
                        saved_mappings[var_name] = it->second;
                    }
                    block_local_vars.insert(var_name);

                    // Create a wire for this local variable and shadow in input_mapping
                    std::string local_wire_name = stringf("$%s$%s_%s_%d",
                        func_call_context.c_str(), block_name.c_str(), var_name.c_str(), incr_autoidx());
                    RTLIL::Wire* local_wire = module->addWire(RTLIL::escape_id(local_wire_name), width);
                    input_mapping[var_name] = RTLIL::SigSpec(local_wire);

                    if (mode_debug) {
                        log("    Created block-local variable %s in named block %s (width=%d)\n",
                            var_name.c_str(), block_name.c_str(), width);
                    }
                }
            }

            if (nbg->Stmts()) {
                for (auto s : *nbg->Stmts()) {
                    process_stmt_to_case(s, case_rule, result_wire, input_mapping, func_name, temp_counter, func_call_context, local_var_widths);
                }
            }

            // Restore shadowed variables
            for (auto& [name, sig] : saved_mappings) {
                input_mapping[name] = sig;
            }
            // Remove variables that only existed in this block scope
            for (const auto& var_name : block_local_vars) {
                if (saved_mappings.find(var_name) == saved_mappings.end()) {
                    input_mapping.erase(var_name);
                }
            }
        }
        break;
    }
    
    case uhdmcase_stmt: {
        // Handle case statement as a switch
        const case_stmt* cs = any_cast<const case_stmt*>(stmt);
        if (!cs) break;
        
        // Get the case expression
        RTLIL::SigSpec case_expr;
        if (cs->VpiCondition()) {
            case_expr = import_expression(any_cast<const expr*>(cs->VpiCondition()), &input_mapping);
        }
        
        // Create a switch rule with source location
        RTLIL::SwitchRule* sw = new RTLIL::SwitchRule;
        sw->signal = case_expr;
        
        // Add source location attribute using existing helper
        add_src_attribute(sw->attributes, cs);
        
        case_rule->switches.push_back(sw);
        
        if (cs->Case_items()) {
            for (auto item : *cs->Case_items()) {
                const case_item* ci = any_cast<const case_item*>(item);
                if (!ci) continue;
                
                RTLIL::CaseRule* item_case = new RTLIL::CaseRule;
                
                // Add source location attribute for the case item
                add_src_attribute(item_case->attributes, ci);
                
                // Get the case value
                if (ci->VpiExprs() && !ci->VpiExprs()->empty()) {
                    // Regular case item
                    RTLIL::SigSpec case_value = import_expression(any_cast<const expr*>(ci->VpiExprs()->at(0)), &input_mapping);
                    // Ensure case value has same width as case expression
                    if (case_value.size() < case_expr.size()) {
                        case_value.extend_u0(case_expr.size());
                    } else if (case_value.size() > case_expr.size()) {
                        case_value = case_value.extract(0, case_expr.size());
                    }
                    item_case->compare.push_back(case_value);
                } // else default case (empty compare list)
                
                // For nested case statements, create intermediate wires and chaining assignments
                // Check if the case body contains another case statement
                bool has_nested_case = false;
                if (ci->Stmt()) {
                    const any* inner_stmt = ci->Stmt();
                    if (inner_stmt->UhdmType() == uhdmcase_stmt || 
                        inner_stmt->UhdmType() == uhdmif_else ||
                        (inner_stmt->UhdmType() == uhdmbegin && 
                         static_cast<const begin*>(inner_stmt)->Stmts() &&
                         !static_cast<const begin*>(inner_stmt)->Stmts()->empty())) {
                        has_nested_case = true;
                    }
                }
                
                // Always add empty action first (matching Verilog frontend)
                item_case->actions.push_back(RTLIL::SigSig(RTLIL::SigSpec(), RTLIL::SigSpec()));
                
                if (has_nested_case) {
                    // Create intermediate result wire for this case branch using autoidx
                    int wire_idx = incr_autoidx();
                    std::string intermediate_wire_name = stringf("$%d\\%s.$result$%d", 
                        wire_idx, func_call_context.c_str(), wire_idx);
                    RTLIL::Wire* intermediate_wire = module->addWire(RTLIL::escape_id(intermediate_wire_name), result_wire->width);
                    
                    // Add source attribute to the intermediate wire
                    add_src_attribute(intermediate_wire->attributes, ci);
                    
                    // Add assignment from intermediate wire to result
                    item_case->actions.push_back(RTLIL::SigSig(result_wire, intermediate_wire));
                    
                    // Process the case body with the intermediate wire as the target
                    process_stmt_to_case(ci->Stmt(), item_case, intermediate_wire, input_mapping, func_name, temp_counter, func_call_context, local_var_widths);
                } else {
                    // Simple case - process directly without intermediate wire
                    if (ci->Stmt()) {
                        process_stmt_to_case(ci->Stmt(), item_case, result_wire, input_mapping, func_name, temp_counter, func_call_context, local_var_widths);
                    }
                }
                
                sw->cases.push_back(item_case);
            }
        }
        
        // Add a default case if one doesn't exist (matching Verilog frontend behavior)
        // Check if we already have a default case (one with empty compare list)
        bool has_default = false;
        for (auto case_item : sw->cases) {
            if (case_item->compare.empty()) {
                has_default = true;
                break;
            }
        }
        
        if (!has_default) {
            // Add default case that preserves current values
            RTLIL::CaseRule* default_case = new RTLIL::CaseRule;
            // Empty compare list means default case
            // Add empty action (matching Verilog frontend)
            default_case->actions.push_back(RTLIL::SigSig(RTLIL::SigSpec(), RTLIL::SigSpec()));
            
            // For functions, we need to preserve the current result value and any local variables
            // The result wire should maintain its current value in the default case
            default_case->actions.push_back(RTLIL::SigSig(result_wire, result_wire));
            
            // Also preserve any local variables (like 'i' in for loops)
            // Find local variables by looking for wires with "local_" in their name
            for (auto &wire_pair : module->wires_) {
                std::string wire_name = wire_pair.second->name.str();
                if (wire_name.find("$" + std::string(func_call_context) + "$local_") != std::string::npos) {
                    // This is a local variable for this function, preserve its value
                    default_case->actions.push_back(RTLIL::SigSig(wire_pair.second, wire_pair.second));
                }
            }
            
            sw->cases.push_back(default_case);
        }
        break;
    }
    
    case uhdmif_else: {
        // Handle if-else statement as a switch
        const if_else* ie = any_cast<const if_else*>(stmt);
        if (ie) {
            // Get condition
            RTLIL::SigSpec cond;
            if (ie->VpiCondition()) {
                cond = import_expression(any_cast<const expr*>(ie->VpiCondition()), &input_mapping);
            }
            
            // Create a switch rule for the if-else with source location
            RTLIL::SwitchRule* sw = new RTLIL::SwitchRule;
            sw->signal = cond;
            
            // Add source location attribute
            add_src_attribute(sw->attributes, ie);
            
            case_rule->switches.push_back(sw);
            
            // If branch (when condition is true)
            if (ie->VpiStmt()) {
                RTLIL::CaseRule* if_case = new RTLIL::CaseRule;
                
                // Add source location for the if branch
                const any* if_stmt = ie->VpiStmt();
                if (if_stmt) {
                    add_src_attribute(if_case->attributes, if_stmt);
                }
                
                // Make sure the compare value has same width as condition
                RTLIL::SigSpec true_val(1, cond.size());
                if_case->compare.push_back(true_val); // Match 1'b1 with proper width
                
                // Add empty action first
                if_case->actions.push_back(RTLIL::SigSig(RTLIL::SigSpec(), RTLIL::SigSpec()));
                
                // Check if if branch contains nested structures
                bool has_nested = false;
                if (if_stmt && (if_stmt->UhdmType() == uhdmif_else || 
                                if_stmt->UhdmType() == uhdmcase_stmt ||
                                if_stmt->UhdmType() == uhdmfor_stmt)) {
                    has_nested = true;
                    
                    // Also check for begin blocks that contain for loops
                } else if (if_stmt && if_stmt->UhdmType() == uhdmbegin) {
                    const begin* bg = any_cast<const begin*>(if_stmt);
                    if (bg && bg->Stmts()) {
                        for (auto s : *bg->Stmts()) {
                            if (s->UhdmType() == uhdmfor_stmt) {
                                has_nested = true;
                                break;
                            }
                        }
                    }
                }
                
                if (has_nested) {
                    // Create intermediate wire for nested structure using autoidx
                    int wire_idx = incr_autoidx();
                    std::string intermediate_wire_name = stringf("$%d\\%s.$result$%d", 
                        wire_idx, func_call_context.c_str(), wire_idx);
                    RTLIL::Wire* intermediate_wire = module->addWire(RTLIL::escape_id(intermediate_wire_name), result_wire->width);
                    
                    // Add source attribute to the intermediate wire
                    add_src_attribute(intermediate_wire->attributes, ie);
                    
                    // Add assignment from intermediate wire to result
                    if_case->actions.push_back(RTLIL::SigSig(result_wire, intermediate_wire));
                    
                    // Process with intermediate wire
                    process_stmt_to_case(ie->VpiStmt(), if_case, intermediate_wire, input_mapping, func_name, temp_counter, func_call_context, local_var_widths);
                } else {
                    // Process directly
                    process_stmt_to_case(ie->VpiStmt(), if_case, result_wire, input_mapping, func_name, temp_counter, func_call_context, local_var_widths);
                }
                
                sw->cases.push_back(if_case);
            }
            
            // Else branch (default case)
            if (ie->VpiElseStmt()) {
                RTLIL::CaseRule* else_case = new RTLIL::CaseRule;
                
                // Add source location for the else branch
                const any* else_stmt = ie->VpiElseStmt();
                if (else_stmt) {
                    add_src_attribute(else_case->attributes, else_stmt);
                }
                
                // Empty compare list makes it the default
                // Add empty action first
                else_case->actions.push_back(RTLIL::SigSig(RTLIL::SigSpec(), RTLIL::SigSpec()));
                
                // Check if else branch contains nested structures
                bool has_nested = false;
                if (else_stmt && (else_stmt->UhdmType() == uhdmif_else || 
                                  else_stmt->UhdmType() == uhdmcase_stmt)) {
                    has_nested = true;
                }
                
                if (has_nested) {
                    // Create intermediate wire for nested structure using autoidx
                    int wire_idx = incr_autoidx();
                    std::string intermediate_wire_name = stringf("$%d\\%s.$result$%d", 
                        wire_idx, func_call_context.c_str(), wire_idx);
                    RTLIL::Wire* intermediate_wire = module->addWire(RTLIL::escape_id(intermediate_wire_name), result_wire->width);
                    
                    // Add source attribute to the intermediate wire
                    if (else_stmt) {
                        add_src_attribute(intermediate_wire->attributes, else_stmt);
                    }
                    
                    // Add assignment from intermediate wire to result
                    else_case->actions.push_back(RTLIL::SigSig(result_wire, intermediate_wire));
                    
                    // Process with intermediate wire
                    process_stmt_to_case(ie->VpiElseStmt(), else_case, intermediate_wire, input_mapping, func_name, temp_counter, func_call_context, local_var_widths);
                } else {
                    // Process directly
                    process_stmt_to_case(ie->VpiElseStmt(), else_case, result_wire, input_mapping, func_name, temp_counter, func_call_context, local_var_widths);
                }
                
                sw->cases.push_back(else_case);
            }
        }
        break;
    }

    case uhdmif_stmt: {
        // Handle if-without-else as a one-armed switch.
        const if_stmt* is = any_cast<const if_stmt*>(stmt);
        if (is) {
            RTLIL::SigSpec cond;
            if (is->VpiCondition()) {
                cond = import_expression(any_cast<const expr*>(is->VpiCondition()), &input_mapping);
            }

            // Optimization: constant-false condition — body is dead code, skip entirely.
            if (cond.is_fully_const() && cond.is_fully_zero())
                break;

            RTLIL::SwitchRule* sw = new RTLIL::SwitchRule;
            sw->signal = cond;
            add_src_attribute(sw->attributes, is);
            case_rule->switches.push_back(sw);

            if (is->VpiStmt()) {
                RTLIL::CaseRule* if_case = new RTLIL::CaseRule;
                add_src_attribute(if_case->attributes, is->VpiStmt());
                if_case->compare.push_back(RTLIL::SigSpec(1, cond.size()));
                if_case->actions.push_back(RTLIL::SigSig(RTLIL::SigSpec(), RTLIL::SigSpec()));

                const any* if_body = is->VpiStmt();
                bool has_nested = (if_body->UhdmType() == uhdmif_else ||
                                   if_body->UhdmType() == uhdmif_stmt ||
                                   if_body->UhdmType() == uhdmcase_stmt ||
                                   if_body->UhdmType() == uhdmfor_stmt);
                if (!has_nested && if_body->UhdmType() == uhdmbegin) {
                    const begin* bg = any_cast<const begin*>(if_body);
                    if (bg && bg->Stmts()) {
                        for (auto s : *bg->Stmts()) {
                            if (s->UhdmType() == uhdmfor_stmt) { has_nested = true; break; }
                        }
                    }
                }

                if (has_nested) {
                    int wire_idx = incr_autoidx();
                    std::string iw_name = stringf("$%d\\%s.$result$%d",
                        wire_idx, func_call_context.c_str(), wire_idx);
                    RTLIL::Wire* iw = module->addWire(RTLIL::escape_id(iw_name), result_wire->width);
                    add_src_attribute(iw->attributes, is);
                    if_case->actions.push_back(RTLIL::SigSig(result_wire, iw));
                    process_stmt_to_case(is->VpiStmt(), if_case, iw, input_mapping,
                                         func_name, temp_counter, func_call_context, local_var_widths);
                } else {
                    process_stmt_to_case(is->VpiStmt(), if_case, result_wire, input_mapping,
                                         func_name, temp_counter, func_call_context, local_var_widths);
                }
                sw->cases.push_back(if_case);
            }

            // No else branch — add empty default so the switch has a catch-all.
            RTLIL::CaseRule* default_case = new RTLIL::CaseRule;
            default_case->actions.push_back(RTLIL::SigSig(RTLIL::SigSpec(), RTLIL::SigSpec()));
            sw->cases.push_back(default_case);
        }
        break;
    }

    case uhdmassignment: {
        // Handle assignment
        const assignment* assign = any_cast<const assignment*>(stmt);
        if (assign && assign->Lhs() && assign->Rhs()) {
            if (mode_debug) {
                log("  process_stmt_to_case: Processing assignment\n");
                if (assign->Lhs()->UhdmType() == uhdmref_obj) {
                    const ref_obj* lhs_ref = any_cast<const ref_obj*>(assign->Lhs());
                    if (lhs_ref) {
                        log("    LHS is ref_obj: %s\n", std::string(lhs_ref->VpiName()).c_str());
                    }
                }
            }
            RTLIL::SigSpec lhs_sig;
            RTLIL::SigSpec rhs_sig = import_expression(any_cast<const expr*>(assign->Rhs()), &input_mapping);

            // For accumulative assignments in loops, we need special handling
            // The issue is that result = result + expr creates conflicting assignments
            // when unrolled. We need to skip creating individual assignments and
            // only keep the final accumulated value.
            
            // Check if we're in a loop iteration and this is an accumulative assignment
            bool skip_assignment = false;
            if (loop_values.count("__in_loop_iteration__") && 
                assign->Lhs()->UhdmType() == uhdmref_obj &&
                assign->Rhs() && assign->Rhs()->UhdmType() == uhdmoperation) {
                const ref_obj* lhs_ref = any_cast<const ref_obj*>(assign->Lhs());
                if (lhs_ref) {
                    std::string lhs_name = std::string(lhs_ref->VpiName());
                    // Check if this variable is mapped in input_mapping (meaning it could be a return variable)
                    // and if RHS is an accumulative operation
                    auto it = input_mapping.find(lhs_name);
                    if (it != input_mapping.end() && it->second == result_wire) {
                        // This is a return variable being accumulated
                        const operation* rhs_op = any_cast<const operation*>(assign->Rhs());
                        if (rhs_op && rhs_op->VpiOpType() == vpiAddOp) {
                            // This is likely an accumulative pattern
                            // The hardware cells are created by import_expression
                            // but we skip the assignment itself
                            skip_assignment = true;
                            if (mode_debug) {
                                log("UHDM: Skipping accumulative assignment to return variable '%s' in loop iteration\n",
                                    lhs_name.c_str());
                            }
                        }
                    }
                }
            }
            
            // Check if LHS is the function name (return value)
            if (assign->Lhs()->UhdmType() == uhdmref_obj) {
                const ref_obj* lhs_ref = any_cast<const ref_obj*>(assign->Lhs());
                if (lhs_ref) {
                    std::string lhs_name = std::string(lhs_ref->VpiName());
                    // Check input_mapping first - this handles function params, return variable,
                    // and block-local variables that may shadow the function name
                    auto it = input_mapping.find(lhs_name);
                    if (it != input_mapping.end()) {
                        lhs_sig = it->second;
                        if (mode_debug) {
                            log("UHDM: Assignment to mapped variable %s\n", lhs_name.c_str());
                        }
                    } else if (lhs_name == func_name) {
                        // Direct assignment to function name - use result wire
                        // (only if not shadowed by a block-local variable in input_mapping)
                        lhs_sig = result_wire;
                        if (mode_debug) {
                            log("UHDM: Direct assignment to function %s, using result wire\n", func_name.c_str());
                        }
                    } else {
                        // Create a function-scoped temporary wire for local variable
                        std::string local_var_name = stringf("$%s$local_%s",
                            func_call_context.c_str(), lhs_name.c_str());
                        RTLIL::Wire* temp_wire = module->wire(RTLIL::escape_id(local_var_name));
                        if (!temp_wire) {
                            int wire_width = rhs_sig.size();
                            auto width_it = local_var_widths.find(lhs_name);
                            if (width_it != local_var_widths.end()) {
                                wire_width = width_it->second;
                                if (mode_debug) {
                                    log("UHDM: Using declared width %d for local variable %s\n",
                                        wire_width, lhs_name.c_str());
                                }
                            } else {
                                if (wire_width > 64) {
                                    log_warning("Large width %d for local variable %s, using 64\n",
                                        wire_width, lhs_name.c_str());
                                    wire_width = 64;
                                }
                            }
                            temp_wire = module->addWire(RTLIL::escape_id(local_var_name), wire_width);
                        }
                        lhs_sig = temp_wire;
                        input_mapping[lhs_name] = lhs_sig;
                    }
                }
            } else if (assign->Lhs()->UhdmType() == uhdmpart_select) {
                // Handle part select assignment: func3[A:B] = inp[A:B]
                const part_select* ps = any_cast<const part_select*>(assign->Lhs());
                std::string base_name = std::string(ps->VpiName());

                int left_val = -1, right_val = -1;
                if (ps->Left_range()) {
                    RTLIL::SigSpec s = import_expression(
                        any_cast<const expr*>(ps->Left_range()), &input_mapping);
                    if (s.is_fully_const()) left_val = s.as_int();
                }
                if (ps->Right_range()) {
                    RTLIL::SigSpec s = import_expression(
                        any_cast<const expr*>(ps->Right_range()), &input_mapping);
                    if (s.is_fully_const()) right_val = s.as_int();
                }

                if (left_val >= 0 && right_val >= 0) {
                    int width = std::abs(left_val - right_val) + 1;
                    int offset = std::min(left_val, right_val);

                    RTLIL::SigSpec base_spec;
                    if (base_name == func_name) {
                        base_spec = RTLIL::SigSpec(result_wire);
                    } else {
                        auto it = input_mapping.find(base_name);
                        if (it != input_mapping.end())
                            base_spec = it->second;
                    }

                    if (base_spec.size() > 0 && offset + width <= base_spec.size()) {
                        lhs_sig = base_spec.extract(offset, width);
                        if (mode_debug)
                            log("  process_stmt_to_case: part-select LHS %s[%d:%d] → offset=%d width=%d\n",
                                base_name.c_str(), left_val, right_val, offset, width);
                    } else {
                        log_warning("Part-select LHS %s[%d:%d] out of bounds (base_size=%d)\n",
                                    base_name.c_str(), left_val, right_val, base_spec.size());
                    }
                } else {
                    log_warning("Part-select LHS %s has non-constant range\n", base_name.c_str());
                }
            } else if (assign->Lhs()->UhdmType() == uhdmbit_select) {
                // Handle bit select assignment
                const bit_select* bs = any_cast<const bit_select*>(assign->Lhs());
                std::string base_name = std::string(bs->VpiName());

                // For packed multi-dim arrays (`logic [N-1:0][M-1:0] x;`
                // or `logic4 [N-1:0] x;`), `x[i]` refers to an
                // element_width-bit slice, not a single bit.  Detect
                // this by inspecting the bit_select's Actual_group.
                int element_width = 1;
                if (auto actual = bs->Actual_group()) {
                    if (auto pav = dynamic_cast<const UHDM::packed_array_var*>(actual)) {
                        if (auto ts = pav->Typespec()) {
                            if (auto a = ts->Actual_typespec()) {
                                if (a->UhdmType() == uhdmlogic_typespec) {
                                    auto lt = dynamic_cast<const UHDM::logic_typespec*>(a);
                                    if (lt && lt->Elem_typespec() &&
                                        lt->Elem_typespec()->Actual_typespec()) {
                                        // Typespec encodes the full type;
                                        // element type is Elem_typespec.
                                        element_width = get_width_from_typespec(
                                            lt->Elem_typespec()->Actual_typespec(),
                                            current_instance);
                                    } else {
                                        // Typespec is just the element type
                                        // (outer ranges live on pav->Ranges()).
                                        element_width = get_width_from_typespec(
                                            a, current_instance);
                                    }
                                }
                            }
                        }
                    }
                }
                if (element_width <= 0) element_width = 1;

                if (base_name == func_name) {
                    // Assigning to a bit of the return value
                    RTLIL::SigSpec index_sig;
                    if (bs->VpiIndex()) {
                        index_sig = import_expression(any_cast<const expr*>(bs->VpiIndex()), &input_mapping);
                        if (mode_debug) {
                            log("      Bit select index for %s: is_const=%d, value=%s\n",
                                base_name.c_str(), index_sig.is_fully_const(),
                                index_sig.is_fully_const() ? std::to_string(index_sig.as_int()).c_str() : "non-const");
                        }
                    }

                    if (index_sig.is_fully_const()) {
                        int idx = index_sig.as_int();

                        // Use the result_wire for assignments to the function name
                        RTLIL::Wire* target_wire = result_wire;
                        int offset = idx * element_width;
                        if (offset >= 0 && offset + element_width <= target_wire->width) {
                            lhs_sig = RTLIL::SigSpec(target_wire, offset, element_width);
                        }
                    } else {
                        log("UHDM: Warning - non-constant bit select index in function %s\n", func_name.c_str());
                    }
                } else {
                    // Handle bit select on other variables
                    auto it = input_mapping.find(base_name);
                    if (it != input_mapping.end()) {
                        RTLIL::SigSpec index_sig;
                        if (bs->VpiIndex()) {
                            index_sig = import_expression(any_cast<const expr*>(bs->VpiIndex()), &input_mapping);
                        }

                        if (index_sig.is_fully_const()) {
                            int idx = index_sig.as_int();
                            RTLIL::SigSpec base_sig = it->second;
                            int offset = idx * element_width;
                            if (offset >= 0 && offset + element_width <= base_sig.size()) {
                                lhs_sig = base_sig.extract(offset, element_width);
                            }

                            // If the base variable has a const-folded value
                            // recorded in the function context (a constant
                            // arg that's been mutated), update it in place
                            // so subsequent reads of `inp` (e.g. `result =
                            // num * inp`) see the post-write value rather
                            // than the original arg.  Without this,
                            // operation2 in various/const_arg_loop.sv
                            // returns `num * original_inp` instead of
                            // `num * (inp with bit flipped)`.
                            FunctionCallContext* ctx = getCurrentFunctionContext();
                            if (ctx && ctx->const_wire_values.count(base_name) &&
                                rhs_sig.is_fully_const() &&
                                element_width == 1) {
                                RTLIL::Const& cur = ctx->const_wire_values[base_name];
                                if (idx >= 0 && idx < (int)cur.size()) {
                                    RTLIL::Const new_val = cur;
                                    new_val.set(idx,
                                        rhs_sig.as_const().is_fully_zero()
                                            ? RTLIL::State::S0
                                            : RTLIL::State::S1);
                                    ctx->const_wire_values[base_name] = new_val;
                                }
                            }
                        }
                    }
                }
            }
            
            // Add the assignment action
            if (lhs_sig.size() > 0) {
                // Truncate or extend RHS to match LHS width
                if (rhs_sig.size() != lhs_sig.size()) {
                    if (rhs_sig.size() > lhs_sig.size()) {
                        // Truncate to match LHS
                        rhs_sig = rhs_sig.extract(0, lhs_sig.size());
                    } else {
                        // Extend to match LHS
                        rhs_sig.extend_u0(lhs_sig.size());
                    }
                }
                // Only create the assignment if we're not skipping it
                if (!skip_assignment) {
                    case_rule->actions.push_back(RTLIL::SigSig(lhs_sig, rhs_sig));
                }
            }
        }
        break;
    }
    
    case uhdmfor_stmt: {
        // Handle for loops - need to unroll at compile time for synthesis
        const for_stmt* fs = any_cast<const for_stmt*>(stmt);
        log("UHDM: Processing for loop in function %s\n", func_name.c_str());
        if (fs) {
                // Get loop components
                const any* init_stmt = nullptr;
                const any* condition = fs->VpiCondition();
                const any* inc_stmt = nullptr;
                const any* loop_body = fs->VpiStmt();
                
                // Get init statement
                if (fs->VpiForInitStmts() && !fs->VpiForInitStmts()->empty()) {
                    init_stmt = fs->VpiForInitStmts()->at(0);
                } else if (fs->VpiForInitStmt()) {
                    init_stmt = fs->VpiForInitStmt();
                }
                
                // Get increment statement
                if (fs->VpiForIncStmts() && !fs->VpiForIncStmts()->empty()) {
                    inc_stmt = fs->VpiForIncStmts()->at(0);
                } else if (fs->VpiForIncStmt()) {
                    inc_stmt = fs->VpiForIncStmt();
                }
                
                if (!init_stmt || !condition || !inc_stmt || !loop_body) {
                    log("UHDM: Warning - incomplete for loop structure in function %s (init:%p, cond:%p, inc:%p, body:%p)\n",
                        func_name.c_str(), init_stmt, condition, inc_stmt, loop_body);
                    break;
                }

                // Try to extract loop bounds for unrolling
                bool can_unroll = false;
                std::string loop_var_name;
                int64_t start_value = 0;
                int64_t end_value = 0;
                int64_t increment = 1;
                bool inclusive = false;
                
                if (mode_debug) {
                    log("    Attempting to unroll for loop in function %s\n", func_name.c_str());
                    log("      init_stmt type: %d\n", init_stmt ? init_stmt->UhdmType() : -1);
                    log("      condition type: %d\n", condition ? condition->UhdmType() : -1);
                    log("      inc_stmt type: %d\n", inc_stmt ? inc_stmt->UhdmType() : -1);
                }
                
                // Extract initialization: i = start_value
                if (init_stmt->UhdmType() == uhdmassignment) {
                    const assignment* init_assign = any_cast<const assignment*>(init_stmt);
                    if (init_assign->Lhs()) {
                        // Handle both ref_obj and ref_var (integer variables use ref_var)
                        if (init_assign->Lhs()->UhdmType() == uhdmref_obj) {
                            const ref_obj* ref = any_cast<const ref_obj*>(init_assign->Lhs());
                            loop_var_name = ref->VpiName();
                        } else if (init_assign->Lhs()->UhdmType() == uhdmref_var) {
                            const ref_var* ref = any_cast<const ref_var*>(init_assign->Lhs());
                            loop_var_name = ref->VpiName();
                        }
                        
                        if (!loop_var_name.empty() && init_assign->Rhs() && init_assign->Rhs()->UhdmType() == uhdmconstant) {
                            const constant* const_val = any_cast<const constant*>(init_assign->Rhs());
                            RTLIL::SigSpec init_spec = import_constant(const_val);
                            if (init_spec.is_fully_const()) {
                                start_value = init_spec.as_const().as_int();
                                can_unroll = true;
                            }
                        }
                    }
                }
                
                // Extract condition: i < end_value or i <= end_value
                if (can_unroll && condition->UhdmType() == uhdmoperation) {
                    const operation* cond_op = any_cast<const operation*>(condition);
                    int op_type = cond_op->VpiOpType();
                    
                    if (op_type == vpiLeOp) {
                        inclusive = true;
                    } else if (op_type == vpiLtOp) {
                        inclusive = false;
                    } else {
                        can_unroll = false;
                    }
                    
                    if (can_unroll && cond_op->Operands() && cond_op->Operands()->size() == 2) {
                        auto operands = cond_op->Operands();
                        const any* left_op = operands->at(0);
                        const any* right_op = operands->at(1);
                        
                        // Check that left operand is our loop variable
                        // Handle both ref_obj and ref_var (integer variables use ref_var)
                        bool is_loop_var = false;
                        if (left_op->UhdmType() == uhdmref_obj) {
                            const ref_obj* ref = any_cast<const ref_obj*>(left_op);
                            is_loop_var = (std::string(ref->VpiName()) == loop_var_name);
                        } else if (left_op->UhdmType() == uhdmref_var) {
                            const ref_var* ref = any_cast<const ref_var*>(left_op);
                            is_loop_var = (std::string(ref->VpiName()) == loop_var_name);
                        }
                        
                        if (is_loop_var) {
                            // Get the end value
                            if (right_op->UhdmType() == uhdmref_obj) {
                                // It's a parameter reference, resolve it
                                const ref_obj* param_ref = any_cast<const ref_obj*>(right_op);
                                RTLIL::SigSpec param_value = import_ref_obj(param_ref, nullptr, &input_mapping);
                                
                                if (param_value.is_fully_const()) {
                                    end_value = param_value.as_const().as_int();
                                } else {
                                    can_unroll = false;
                                }
                            } else if (right_op->UhdmType() == uhdmconstant) {
                                const constant* const_val = any_cast<const constant*>(right_op);
                                RTLIL::SigSpec const_spec = import_constant(const_val);
                                if (const_spec.is_fully_const()) {
                                    end_value = const_spec.as_const().as_int();
                                } else {
                                    can_unroll = false;
                                }
                            } else if (right_op->UhdmType() == uhdmoperation) {
                                // Handle operations like WIDTH/2 using expression evaluator
                                const operation* op = any_cast<const operation*>(right_op);
                                log("UHDM: Evaluating operation for loop end value in function %s\n", func_name.c_str());
                                
                                // Use ExprEval to reduce the expression to a constant
                                ExprEval eval;
                                bool invalidValue = false;
                                if (mode_debug) {
                                    log("DEBUG: Attempting to reduce operation type %d\n", op->VpiOpType());
                                }
                                // Pass the current instance context for proper parameter resolution
                                expr* res = eval.reduceExpr(op, invalidValue, current_instance, op->VpiParent(), true);
                                
                                if (mode_debug) {
                                    log("DEBUG: reduceExpr result: res=%p, invalidValue=%d\n", res, invalidValue);
                                    if (res) {
                                        log("DEBUG: Result type: %d\n", res->UhdmType());
                                    }
                                }
                                
                                if (res && res->UhdmType() == uhdmconstant) {
                                    const constant* const_val = dynamic_cast<const UHDM::constant*>(res);
                                    RTLIL::SigSpec const_spec = import_constant(const_val);
                                    if (const_spec.is_fully_const()) {
                                        end_value = const_spec.as_const().as_int();
                                        log("UHDM: Operation evaluated to constant: %lld\n", (long long)end_value);
                                        if (mode_debug) {
                                            log("DEBUG: Evaluated operation for end value: %lld\n", (long long)end_value);
                                        }
                                    } else {
                                        can_unroll = false;
                                        log("UHDM: Operation could not be reduced to constant\n");
                                    }
                                } else {
                                    can_unroll = false;
                                    log("UHDM: Operation result not constant, cannot unroll\n");
                                    if (mode_debug) {
                                        log("DEBUG: Operation result not constant (invalidValue=%d)\n", invalidValue);
                                    }
                                }
                            } else {
                                can_unroll = false;
                            }
                        }
                    }
                }
                
                // Extract increment: i++ or i = i + 1
                if (can_unroll && inc_stmt->UhdmType() == uhdmoperation) {
                    const operation* inc_op = any_cast<const operation*>(inc_stmt);
                    if (inc_op->VpiOpType() == vpiPostIncOp) { 
                        increment = 1;
                    } else if (inc_op->VpiOpType() == vpiAddOp) {
                        // Check for i = i + 1 pattern
                        increment = 1; // Simplified for now
                    }
                } else if (can_unroll && inc_stmt->UhdmType() == uhdmassignment) {
                    // Handle i = i + 1 style increment
                    const assignment* inc_assign = any_cast<const assignment*>(inc_stmt);
                    if (inc_assign->Rhs() && inc_assign->Rhs()->UhdmType() == uhdmoperation) {
                        const operation* add_op = any_cast<const operation*>(inc_assign->Rhs());
                        if (add_op->VpiOpType() == vpiAddOp) {
                            increment = 1; // Simplified assumption
                        }
                    }
                }
                
                if (mode_debug) {
                    log("DEBUG: Loop unroll check: can_unroll=%d, start=%lld, end=%lld, increment=%lld\n",
                        can_unroll, (long long)start_value, (long long)end_value, (long long)increment);
                }
                
                if (can_unroll) {
                    // Unroll the loop
                    int64_t loop_end = inclusive ? end_value : end_value - 1;
                    
                    log("UHDM: Unrolling for loop: %s from %lld to %lld in function %s\n", 
                        loop_var_name.c_str(), (long long)start_value, (long long)loop_end, func_name.c_str());
                    
                    if (mode_debug) {
                        log("    Unrolling for loop: %s from %lld to %lld\n", 
                            loop_var_name.c_str(), (long long)start_value, (long long)loop_end);
                    }
                    
                    // Store loop variable in loop_values for substitution during expression import
                    // For accumulative loops, we need to detect if this is an accumulative pattern
                    // and handle it specially
                    
                    // Check if the loop body contains an accumulative assignment pattern
                    bool is_accumulative = false;
                    std::string accumulator_var;
                    
                    // Check if the loop body contains an accumulative assignment pattern
                    // The loop body might be a begin block containing the assignment
                    const any* check_stmt = loop_body;
                    
                    // If it's a begin block, look at the first statement inside
                    if (check_stmt && check_stmt->UhdmType() == uhdmbegin) {
                        const begin* bg = any_cast<const begin*>(check_stmt);
                        if (bg && bg->Stmts() && !bg->Stmts()->empty()) {
                            check_stmt = bg->Stmts()->at(0);
                        }
                    }
                    
                    if (check_stmt && check_stmt->UhdmType() == uhdmassignment) {
                        const assignment* assign = any_cast<const assignment*>(check_stmt);
                        if (assign && assign->Lhs() && assign->Lhs()->UhdmType() == uhdmref_obj) {
                            const ref_obj* lhs_ref = any_cast<const ref_obj*>(assign->Lhs());
                            if (lhs_ref) {
                                accumulator_var = std::string(lhs_ref->VpiName());
                                // Detect any `var = f(var, ...)` pattern (not just
                                // `var = var + x`): for the loop body to chain
                                // across iterations, the RHS must read the LHS.
                                // Walk the RHS recursively looking for a ref_obj
                                // whose name matches accumulator_var.
                                auto it = input_mapping.find(accumulator_var);
                                if (it != input_mapping.end() && assign->Rhs()) {
                                    std::function<bool(const UHDM::any*)> reads_var =
                                        [&](const UHDM::any* e) -> bool {
                                        if (!e) return false;
                                        if (e->UhdmType() == uhdmref_obj) {
                                            auto r = any_cast<const ref_obj*>(e);
                                            return std::string(r->VpiName()) == accumulator_var;
                                        }
                                        if (e->UhdmType() == uhdmoperation) {
                                            auto op = any_cast<const operation*>(e);
                                            if (op->Operands())
                                                for (auto o : *op->Operands())
                                                    if (reads_var(o)) return true;
                                        }
                                        return false;
                                    };
                                    if (reads_var(assign->Rhs())) {
                                        is_accumulative = true;
                                        log("UHDM: Detected accumulative loop for variable '%s'\n", accumulator_var.c_str());
                                    }
                                }
                            }
                        }
                    }

                    // Track the current accumulated value for chaining
                    RTLIL::SigSpec current_accumulator;
                    if (is_accumulative) {
                        // Initialise the chain with the LATEST value already
                        // assigned to the accumulator wire in this case_rule —
                        // i.e. the source of the most recent
                        // `$0\<var> = <rhs>` action above this loop.  Using
                        // the wire itself (`input_mapping[var]`) would create
                        // a combinational loop: each iter's mul reads $0\num
                        // and writes it, and the loop pass collapses the
                        // unconditional assigns to the last one — which then
                        // depends on $0\num through the chain.
                        //
                        // The prior code used `SigSpec(S0, ...)` which only
                        // worked when the var was pre-initialised to 0 just
                        // above the loop (the textbook `accum=0; for ... accum+=x` pattern).
                        // For `num = input_arg; for ... num = num*2;` we need
                        // the actual prior RHS (the input wire `\a`), not
                        // zero and not the wire being assigned.
                        auto it = input_mapping.find(accumulator_var);
                        if (it != input_mapping.end()) {
                            RTLIL::SigSpec target = it->second;
                            RTLIL::SigSpec latest;
                            for (const auto& act : case_rule->actions) {
                                if (act.first == target) latest = act.second;
                            }
                            if (latest.size() > 0)
                                current_accumulator = latest;
                            else
                                current_accumulator =
                                    RTLIL::SigSpec(RTLIL::State::S0, target.size());
                            loop_accumulators[accumulator_var] = current_accumulator;
                        }
                    }
                    
                    for (int64_t i = start_value; i <= loop_end; i += increment) {
                        // Set the loop variable value - use loop_values for substitution
                        loop_values[loop_var_name] = i;
                        
                        bool is_last_iteration = (i + increment > loop_end);
                        
                        if (mode_debug) {
                            log("      Iteration %lld (last=%d)\n", (long long)i, is_last_iteration);
                        }
                        
                        // For accumulative loops, update the accumulator mapping for this iteration
                        if (is_accumulative && !current_accumulator.empty()) {
                            loop_accumulators[accumulator_var] = current_accumulator;
                        }
                        
                        // Mark whether we should skip assignments (for all but last iteration)
                        if (!is_last_iteration && is_accumulative) {
                            loop_values["__in_loop_iteration__"] = 1;
                        }
                        
                        // Process the loop body with the current iteration value
                        if (mode_debug) {
                            log("      Processing loop body for iteration %lld\n", (long long)i);
                        }
                        
                        // Save the current state of input_mapping for the accumulator
                        RTLIL::SigSpec saved_accumulator_mapping;
                        if (is_accumulative) {
                            auto it = input_mapping.find(accumulator_var);
                            if (it != input_mapping.end()) {
                                saved_accumulator_mapping = it->second;
                                // Temporarily map the accumulator to its current accumulated value
                                it->second = current_accumulator;
                            }
                        }
                        
                        process_stmt_to_case(loop_body, case_rule, result_wire, input_mapping, func_name, temp_counter, func_call_context, local_var_widths);
                        
                        // After processing, get the output of this iteration for chaining
                        if (is_accumulative) {
                            // Get the assignment from the loop body (might be inside a begin block)
                            const any* assign_stmt = loop_body;
                            if (assign_stmt && assign_stmt->UhdmType() == uhdmbegin) {
                                const begin* bg = any_cast<const begin*>(assign_stmt);
                                if (bg && bg->Stmts() && !bg->Stmts()->empty()) {
                                    assign_stmt = bg->Stmts()->at(0);
                                }
                            }
                            
                            if (assign_stmt && assign_stmt->UhdmType() == uhdmassignment) {
                                const assignment* assign = any_cast<const assignment*>(assign_stmt);
                                if (assign && assign->Rhs()) {
                                    // Import the RHS expression to get the output wire
                                    RTLIL::SigSpec iter_result = import_expression(any_cast<const expr*>(assign->Rhs()), &input_mapping);
                                    if (!iter_result.empty()) {
                                        current_accumulator = iter_result;
                                        log("UHDM: Updated accumulator to iteration %lld result\n", (long long)i);
                                    }
                                }
                            }
                        }
                        
                        // Restore the original mapping
                        if (is_accumulative && !saved_accumulator_mapping.empty()) {
                            input_mapping[accumulator_var] = saved_accumulator_mapping;
                        }
                        
                        // Clear the loop iteration marker
                        loop_values.erase("__in_loop_iteration__");
                    }
                    
                    // After the loop, create the final assignment from accumulated value to result
                    if (is_accumulative && !current_accumulator.empty()) {
                        auto it = input_mapping.find(accumulator_var);
                        if (it != input_mapping.end()) {
                            case_rule->actions.push_back(RTLIL::SigSig(it->second, current_accumulator));
                            log("UHDM: Created final accumulator assignment for '%s'\n", accumulator_var.c_str());
                        }
                        // Clear the accumulator tracking
                        loop_accumulators.erase(accumulator_var);
                    }
                    
                    // Clear loop variable after loop
                    loop_values.erase(loop_var_name);
                    
                    // Loop has been unrolled into the case rule
                } else {
                    log("UHDM: Warning - for loop in function %s cannot be unrolled (can_unroll=%d, loop_var=%s, start=%lld, end=%lld)\n", 
                        func_name.c_str(), can_unroll, loop_var_name.c_str(), (long long)start_value, (long long)end_value);
                }
        }
        break;
    }
    
    case uhdmreturn_stmt: {
        // `return <expr>;` — evaluate the return expression and write it to
        // the function's result wire.  Without this case, return statements
        // were silently dropped, so the result wire kept its zero
        // initialisation (the `$1\$result = 0` line in the IL) and any
        // function reached only via `return X` returned 0 — observed in
        // simple_package's `increment_data(bus_in.data)`.
        const return_stmt* ret = any_cast<const return_stmt*>(stmt);
        if (ret && ret->VpiCondition() && result_wire) {
            RTLIL::SigSpec rhs_sig = import_expression(ret->VpiCondition(), &input_mapping);
            RTLIL::SigSpec lhs_sig = RTLIL::SigSpec(result_wire);
            if (rhs_sig.size() < lhs_sig.size()) {
                rhs_sig.extend_u0(lhs_sig.size(), false);
            } else if (rhs_sig.size() > lhs_sig.size()) {
                rhs_sig = rhs_sig.extract(0, lhs_sig.size());
            }
            case_rule->actions.push_back(RTLIL::SigSig(lhs_sig, rhs_sig));
            if (mode_debug)
                log("UHDM: return_stmt assigned to result wire %s\n", result_wire->name.c_str());
        }
        break;
    }

    default:
        // Other statement types - ignore for now
        break;
    }
}

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
RTLIL::SigSpec UhdmImporter::import_expression(const expr* uhdm_expr, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    if (!uhdm_expr)
        return RTLIL::SigSpec();
    
    int obj_type = uhdm_expr->VpiType();
    
    if (mode_debug) {
        log("  import_expression: VpiType=%d, UhdmType=%s\n", 
            obj_type, UHDM::UhdmName(uhdm_expr->UhdmType()).c_str());
    }
    
    if (obj_type == vpiHierPath) {
        log("  import_expression: Processing vpiHierPath\n");
    }
    
    switch (obj_type) {
        case vpiConstant:
            return import_constant(any_cast<const constant*>(uhdm_expr));
        case vpiOperation:
            return import_operation(any_cast<const operation*>(uhdm_expr), current_scope ? current_scope : current_instance, input_mapping);
        case vpiRefObj:
            return import_ref_obj(any_cast<const ref_obj*>(uhdm_expr), current_scope ? current_scope : current_instance, input_mapping);
        case vpiPartSelect:
            return import_part_select(any_cast<const part_select*>(uhdm_expr), current_scope ? current_scope : current_instance, input_mapping);
        case vpiBitSelect:
            return import_bit_select(any_cast<const bit_select*>(uhdm_expr), current_scope ? current_scope : current_instance, input_mapping);
        case vpiAssignment:
            // This should not be called on assignment directly
            // Assignment is a statement, not an expression
            log_warning("vpiAssignment (type 3) passed to import_expression - assignments should be handled as statements, not expressions\n");
            return RTLIL::SigSpec();
        case vpiHierPath:
            return import_hier_path(any_cast<const hier_path*>(uhdm_expr), current_scope ? current_scope : current_instance, input_mapping);
        case vpiIndexedPartSelect:
            return import_indexed_part_select(any_cast<const indexed_part_select*>(uhdm_expr), current_scope ? current_scope : current_instance, input_mapping);
        case vpiVarSelect:
            // Handle variable array selection: array[index] or array[index][part_select]
            {
                const var_select* vs = any_cast<const var_select*>(uhdm_expr);
                std::string base_name = std::string(vs->VpiName());
                log("  import_expression: vpiVarSelect base='%s'\n", base_name.c_str());

                // Get the indices from Exprs()
                auto exprs = vs->Exprs();
                if (!exprs || exprs->empty()) {
                    log_warning("vpiVarSelect '%s' has no index expressions\n", base_name.c_str());
                    return RTLIL::SigSpec();
                }

                // Memory read with a (possibly dynamic) address and optional
                // part-select: `mem[addr]` / `mem[addr][hi:lo]`.  Create a
                // $memrd at the address and slice the requested bits — this is
                // the read side of byte-enable RAMs (memories/implicit_en).
                {
                    RTLIL::IdString mem_id = RTLIL::escape_id(base_name);
                    if (module->memories.count(mem_id)) {
                        RTLIL::Memory* memory = module->memories.at(mem_id);
                        const expr* addr_expr = nullptr;
                        int psel_lo = 0, psel_hi = 0;
                        bool have_psel = parse_mem_partial_select(vs, addr_expr, psel_lo, psel_hi);
                        if (!addr_expr && !exprs->empty())
                            addr_expr = (*exprs)[0];   // plain `mem[addr]` read (no slice)
                        if (addr_expr) {
                            RTLIL::SigSpec addr = import_expression(addr_expr, input_mapping);
                            RTLIL::Cell* memrd_cell = module->addCell(new_id("memrd_" + base_name), ID($memrd));
                            memrd_cell->setParam(ID::MEMID, RTLIL::Const(mem_id.str()));
                            memrd_cell->setParam(ID::ABITS, GetSize(addr));
                            memrd_cell->setParam(ID::WIDTH, memory->width);
                            memrd_cell->setParam(ID::CLK_ENABLE, RTLIL::Const(0));
                            memrd_cell->setParam(ID::CLK_POLARITY, RTLIL::Const(0));
                            memrd_cell->setParam(ID::TRANSPARENT, RTLIL::Const(0));
                            RTLIL::Wire* data_wire = module->addWire(new_id("memrd_" + base_name + "_DATA"), memory->width);
                            memrd_cell->setPort(ID::CLK, RTLIL::SigSpec(RTLIL::State::Sx, 1));
                            memrd_cell->setPort(ID::EN, RTLIL::SigSpec(RTLIL::State::S1, 1));
                            memrd_cell->setPort(ID::ADDR, addr);
                            memrd_cell->setPort(ID::DATA, data_wire);
                            add_src_attribute(memrd_cell->attributes, vs);
                            RTLIL::SigSpec rd(data_wire);
                            if (have_psel && psel_lo >= 0 && psel_hi < rd.size())
                                return rd.extract(psel_lo, psel_hi - psel_lo + 1);
                            return rd;
                        }
                    }
                }

                // 2D unpacked array element access (`n[i][j]`).  When both
                // indices are const and the base wire carries the
                // `unpacked_*` metadata that `import_module` stamped on
                // multi-dim unpacked arrays, compute the flat offset
                // ourselves and slice the base wire — Surelog flattens
                // these into a single var_select with two `Index` entries
                // rather than a nested ref_obj+bit_select chain.
                if (exprs->size() == 2 &&
                    (*exprs)[0]->VpiType() != vpiPartSelect &&
                    (*exprs)[1]->VpiType() != vpiPartSelect &&
                    (*exprs)[1]->VpiType() != vpiBitSelect) {
                    RTLIL::SigSpec i0 = import_expression((*exprs)[0], input_mapping);
                    RTLIL::SigSpec i1 = import_expression((*exprs)[1], input_mapping);
                    if (i0.is_fully_const() && i1.is_fully_const()) {
                        RTLIL::IdString wire_id = RTLIL::escape_id(base_name);
                        if (RTLIL::Wire* base_wire = module->wire(wire_id)) {
                            auto& a = base_wire->attributes;
                            auto have = [&](const char* k){
                                return a.count(RTLIL::escape_id(k)) > 0;
                            };
                            if (have("unpacked_elem_width") &&
                                have("unpacked_outer_low") &&
                                have("unpacked_inner_low") &&
                                have("unpacked_inner_size")) {
                                int elem_w     = a.at(RTLIL::escape_id("unpacked_elem_width")).as_int();
                                int outer_low  = a.at(RTLIL::escape_id("unpacked_outer_low")).as_int();
                                int inner_low  = a.at(RTLIL::escape_id("unpacked_inner_low")).as_int();
                                int inner_size = a.at(RTLIL::escape_id("unpacked_inner_size")).as_int();
                                int oi = i0.as_int(), ii = i1.as_int();
                                int off = ((oi - outer_low) * inner_size + (ii - inner_low)) * elem_w;
                                if (off >= 0 && off + elem_w <= base_wire->width) {
                                    log("  vpiVarSelect: 2D %s[%d][%d] → %s[%d+:%d]\n",
                                        base_name.c_str(), oi, ii,
                                        base_wire->name.c_str(), off, elem_w);
                                    return RTLIL::SigSpec(base_wire).extract(off, elem_w);
                                }
                            }
                        }
                    }
                }

                // First expression should be the array index
                const expr* first_idx = (*exprs)[0];
                RTLIL::SigSpec idx_sig = import_expression(first_idx, input_mapping);

                if (!idx_sig.is_fully_const()) {
                    log_warning("vpiVarSelect '%s': non-constant array index\n", base_name.c_str());
                    return RTLIL::SigSpec();
                }

                int array_idx = idx_sig.as_const().as_int();
                std::string element_name = base_name + "[" + std::to_string(array_idx) + "]";
                log("  vpiVarSelect: resolved to element '%s'\n", element_name.c_str());

                // Find the wire for this array element
                RTLIL::Wire* element_wire = nullptr;

                // Try with generate scope prefix
                std::string gen_scope = get_current_gen_scope();
                if (!gen_scope.empty()) {
                    std::string hier_name = gen_scope + "." + element_name;
                    if (name_map.count(hier_name))
                        element_wire = name_map[hier_name];
                }

                // Try direct name
                if (!element_wire && name_map.count(element_name))
                    element_wire = name_map[element_name];

                // Try escaped RTLIL name
                if (!element_wire) {
                    RTLIL::IdString wire_id = RTLIL::escape_id(element_name);
                    element_wire = module->wire(wire_id);
                }

                if (!element_wire) {
                    log_warning("vpiVarSelect: wire '%s' not found\n", element_name.c_str());
                    return RTLIL::SigSpec();
                }

                RTLIL::SigSpec result(element_wire);

                // If there's a second expression (part_select), apply it
                if (exprs->size() > 1) {
                    const expr* second_idx = (*exprs)[1];
                    if (second_idx->VpiType() == vpiPartSelect) {
                        const part_select* ps = any_cast<const part_select*>(second_idx);
                        const expr* left_range = ps->Left_range();
                        const expr* right_range = ps->Right_range();

                        RTLIL::SigSpec left_sig = import_expression(left_range, input_mapping);
                        RTLIL::SigSpec right_sig = import_expression(right_range, input_mapping);

                        if (left_sig.is_fully_const() && right_sig.is_fully_const()) {
                            int left_val = left_sig.as_const().as_int();
                            int right_val = right_sig.as_const().as_int();
                            int width = std::abs(left_val - right_val) + 1;
                            int offset = std::min(left_val, right_val);

                            log("  vpiVarSelect: part select [%d:%d] on %d-bit wire\n",
                                left_val, right_val, element_wire->width);

                            if (offset + width <= element_wire->width) {
                                result = result.extract(offset, width);
                            } else {
                                log_warning("vpiVarSelect: part select [%d:%d] out of range for %d-bit wire '%s'\n",
                                    left_val, right_val, element_wire->width, element_name.c_str());
                            }
                        } else {
                            log_warning("vpiVarSelect: non-constant part select on '%s'\n", element_name.c_str());
                        }
                    } else if (second_idx->VpiType() == vpiBitSelect) {
                        // Single bit select
                        RTLIL::SigSpec bit_sig = import_expression(second_idx, input_mapping);
                        if (bit_sig.is_fully_const()) {
                            int bit_idx = bit_sig.as_const().as_int();
                            if (bit_idx < element_wire->width) {
                                result = result.extract(bit_idx, 1);
                            }
                        }
                    }
                }

                log("  vpiVarSelect: result size=%d\n", result.size());
                return result;
            }
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
                
                // If we're in a generate scope, try hierarchical lookups first
                std::string gen_scope = get_current_gen_scope();
                if (!gen_scope.empty()) {
                    // First try the full hierarchical name
                    std::string hierarchical_name = gen_scope + "." + net_name;
                    if (mode_debug)
                        log("    Looking for hierarchical wire: %s (gen_scope=%s, net=%s)\n", 
                            hierarchical_name.c_str(), gen_scope.c_str(), net_name.c_str());
                    if (name_map.count(hierarchical_name)) {
                        RTLIL::Wire* wire = name_map[hierarchical_name];
                        if (mode_debug)
                            log("    Found hierarchical wire %s in name_map\n", hierarchical_name.c_str());
                        return RTLIL::SigSpec(wire);
                    }
                    
                    // If not found, try parent scopes
                    for (int i = gen_scope_stack.size() - 1; i >= 0; i--) {
                        std::string parent_path;
                        for (int j = 0; j <= i; j++) {
                            if (j > 0) parent_path += ".";
                            parent_path += gen_scope_stack[j];
                        }
                        std::string parent_hierarchical = parent_path + "." + net_name;
                        if (name_map.count(parent_hierarchical)) {
                            RTLIL::Wire* wire = name_map[parent_hierarchical];
                            if (mode_debug)
                                log("    Found wire %s in parent scope %s\n", net_name.c_str(), parent_path.c_str());
                            return RTLIL::SigSpec(wire);
                        }
                    }
                }
                
                // Look up the wire without generate scope prefix
                if (name_map.count(net_name)) {
                    return RTLIL::SigSpec(name_map.at(net_name));
                } else {
                    RTLIL::IdString wire_id = RTLIL::escape_id(net_name);
                    if (module->wire(wire_id)) {
                        return RTLIL::SigSpec(module->wire(wire_id));
                    }
                }
                
                log_warning("Logic_net '%s' not found as wire in module (generate scope: %s)\n", 
                           net_name.c_str(), gen_scope.empty() ? "none" : gen_scope.c_str());
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
                        log_debug("UHDM: sys_func_call %s argument size: %d\n", func_name.c_str(), arg_sig.size());
                        if (arg_sig.size() == 0) {
                            log_warning("Empty argument in sys_func_call %s\n", func_name.c_str());
                        }
                        args.push_back(arg_sig);
                    }
                }
                
                // Handle specific system functions
                // Formal-verification sampling functions: `$past(e)`,
                // `$stable(e)`, `$rose(e)`, `$fell(e)`, `$changed(e)`.
                // These reach back to the previous clock cycle and must
                // be lowered into a DFF that stores the previous value
                // plus a tiny piece of combinational logic comparing
                // it against the current value.  Requires a clock —
                // taken from the enclosing always_ff (`current_ff_clock_sig`).
                if ((func_name == "$past" || func_name == "$stable" ||
                     func_name == "$rose" || func_name == "$fell" ||
                     func_name == "$changed") &&
                    args.size() == 1 && !current_ff_clock_sig.empty()) {
                    int w = args[0].size();
                    if (w <= 0) w = 1;
                    // Past register: D = arg, Q = past_wire, posedge clk.
                    std::string past_name = "$past$" +
                        std::to_string(func_call->VpiLineNo()) + "$" +
                        std::to_string(incr_autoidx());
                    RTLIL::Wire* past_wire = module->addWire(
                        RTLIL::escape_id(past_name), w);
                    add_src_attribute(past_wire->attributes, func_call);
                    RTLIL::Cell* dff = module->addCell(NEW_ID, ID($dff));
                    dff->setParam(ID::WIDTH, RTLIL::Const(w));
                    dff->setParam(ID::CLK_POLARITY, RTLIL::Const(1, 1));
                    dff->setPort(ID::CLK, current_ff_clock_sig);
                    dff->setPort(ID::D, args[0]);
                    dff->setPort(ID::Q, RTLIL::SigSpec(past_wire));
                    add_src_attribute(dff->attributes, func_call);

                    if (func_name == "$past") {
                        return RTLIL::SigSpec(past_wire);
                    }

                    // For 1-bit signals, $rose/$fell/$changed/$stable have
                    // simple definitions; for multi-bit, fall back to the
                    // comparison-based form.
                    RTLIL::SigSpec curr = args[0];
                    RTLIL::SigSpec prev(past_wire);
                    RTLIL::Wire* y = module->addWire(NEW_ID, 1);
                    if (func_name == "$stable") {
                        // x == past_x
                        module->addEq(NEW_ID, curr, prev, RTLIL::SigSpec(y));
                    } else if (func_name == "$changed") {
                        // x != past_x
                        module->addNe(NEW_ID, curr, prev, RTLIL::SigSpec(y));
                    } else if (func_name == "$rose") {
                        // x[0] && !past_x[0]
                        RTLIL::SigSpec nprev = module->Not(NEW_ID,
                            prev.extract(0, 1));
                        module->addAnd(NEW_ID, curr.extract(0, 1),
                                       nprev, RTLIL::SigSpec(y));
                    } else { // $fell
                        // !x[0] && past_x[0]
                        RTLIL::SigSpec ncurr = module->Not(NEW_ID,
                            curr.extract(0, 1));
                        module->addAnd(NEW_ID, ncurr,
                                       prev.extract(0, 1), RTLIL::SigSpec(y));
                    }
                    return RTLIL::SigSpec(y);
                }

                if (func_name == "$signed" && args.size() == 1) {
                    // Wrap the argument in a signed intermediate wire so
                    // downstream resize/extend paths (assignment widening,
                    // arithmetic cell A/B_SIGNED) pick up the signedness
                    // from `rhs.as_wire()->is_signed`.  Without the wire
                    // the SigSpec carries no signedness tag and a
                    // concat-LHS sync assignment like
                    //   {y[31:20], y[10:1], ...} <= $signed({x, 1'b0});
                    // zero-extends instead of sign-extends
                    // (yosys/tests/functional/picorv32.v decoded_imm_j).
                    if (args[0].is_wire() && args[0].as_wire()->is_signed) {
                        log_debug("UHDM: $signed argument already signed wire, passing through (size %d)\n",
                                  args[0].size());
                        return args[0];
                    }
                    RTLIL::Wire* signed_w =
                        module->addWire(NEW_ID, args[0].size());
                    signed_w->is_signed = true;
                    module->connect(RTLIL::SigSpec(signed_w), args[0]);
                    log_debug("UHDM: $signed wrapped %d-bit arg in signed intermediate\n",
                              args[0].size());
                    return RTLIL::SigSpec(signed_w);
                } else if (func_name == "$unsigned" && args.size() == 1) {
                    // $unsigned just returns the argument with unsigned interpretation
                    return args[0];
                } else if (func_name == "$floor" && args.size() == 1) {
                    // $floor for integer arguments is identity (integer division already truncates)
                    return args[0];
                } else if (func_name == "$ceil" && args.size() == 1) {
                    // $ceil for integer arguments is identity
                    return args[0];
                } else if ((func_name == "$bits" || func_name == "$size" ||
                            func_name == "$high" || func_name == "$low" ||
                            func_name == "$left" || func_name == "$right" ||
                            func_name == "$dimensions" ||
                            func_name == "$unpacked_dimensions" ||
                            func_name == "$increment") &&
                           !args.empty() && func_call->Tf_call_args() &&
                           !func_call->Tf_call_args()->empty()) {
                    // SV array/range query system functions.
                    //   $bits          — total bit width of the argument.
                    //   $size(a, d)    — size of dimension d (default 1, outermost).
                    //   $left/$right   — declared L/R index of the dimension.
                    //   $high/$low     — max/min of L,R for the dimension.
                    //   $increment     — +1 if L<R (ascending), -1 if L>=R.
                    //   $dimensions    — number of dimensions (1 for atomic types).
                    //   $unpacked_dimensions — same, but only the unpacked
                    //                          (outermost) dims.
                    int total_bits = args[0].size();
                    int unpacked_dim_count = 0;  // populated for array_net path

                    auto first_arg = func_call->Tf_call_args()->at(0);

                    // Walk a typespec to extract its dimensions in outer→inner
                    // order.  For multi-range packed types (logic [a:b][c:d])
                    // the ranges are dim 1, dim 2, …; nested Elem_typespec
                    // contributes additional dims.
                    struct DimInfo { int left, right; };
                    auto append_typespec_dims = [&](auto& self, const UHDM::any* ts,
                                                    std::vector<DimInfo>& out) -> void {
                        while (ts) {
                            if (auto lts = dynamic_cast<const UHDM::logic_typespec*>(ts)) {
                                if (auto ranges = lts->Ranges()) {
                                    for (auto r : *ranges) {
                                        RTLIL::SigSpec ls = import_expression(
                                            any_cast<const UHDM::expr*>(r->Left_expr()));
                                        RTLIL::SigSpec rs = import_expression(
                                            any_cast<const UHDM::expr*>(r->Right_expr()));
                                        if (ls.is_fully_const() && rs.is_fully_const()) {
                                            out.push_back({ls.as_const().as_int(),
                                                           rs.as_const().as_int()});
                                        }
                                    }
                                }
                                if (lts->Elem_typespec() &&
                                    lts->Elem_typespec()->Actual_typespec()) {
                                    ts = lts->Elem_typespec()->Actual_typespec();
                                    continue;
                                }
                            }
                            // struct/union/scalar: no further dims to walk.
                            break;
                        }
                    };

                    // Append the array_net's *unpacked* dimensions (outer,
                    // declaration order) to `out`.  Used for the
                    // `wire [3:0] z[7:2][2:9]` form: SV LRM says the array
                    // dims come BEFORE the packed dims in the dim numbering
                    // (`$size(z, 1)` is the outermost unpacked dim).
                    auto append_array_net_dims = [&](const UHDM::array_net* an,
                                                     std::vector<DimInfo>& out) -> int {
                        int n = 0;
                        if (!an->Ranges()) return 0;
                        for (auto r : *an->Ranges()) {
                            if (!r->Left_expr() || !r->Right_expr()) continue;
                            RTLIL::SigSpec ls = import_expression(
                                any_cast<const UHDM::expr*>(r->Left_expr()));
                            RTLIL::SigSpec rs = import_expression(
                                any_cast<const UHDM::expr*>(r->Right_expr()));
                            if (ls.is_fully_const() && rs.is_fully_const()) {
                                out.push_back({ls.as_const().as_int(),
                                               rs.as_const().as_int()});
                                n++;
                            }
                        }
                        return n;
                    };

                    // Resolve the leaf typespec for a UHDM expression.  For
                    // hier_path we follow Path_elems to the final element;
                    // for ref_obj we use Actual_group; for bit_select we
                    // follow the parent and remember to strip one dim.
                    int strip_outer_dims = 0;
                    const UHDM::any* leaf_ts = nullptr;
                    std::vector<DimInfo> dims;  // declared early so the
                    // array_net branch below can populate the *unpacked*
                    // dims directly; packed dims are added later from the
                    // leaf typespec.

                    // Helper: resolve a bare name (e.g. "z") to its
                    // array_net or net in the current module instance.
                    auto find_array_net_by_name =
                        [&](const std::string& name) -> const UHDM::any* {
                        if (!current_instance) return nullptr;
                        if (auto m = dynamic_cast<const UHDM::module_inst*>(current_instance)) {
                            if (m->Array_nets()) {
                                for (auto an : *m->Array_nets()) {
                                    if (std::string(an->VpiName()) == name)
                                        return an;
                                }
                            }
                            if (m->Nets()) {
                                for (auto n : *m->Nets()) {
                                    if (std::string(n->VpiName()) == name)
                                        return n;
                                }
                            }
                        }
                        return nullptr;
                    };

                    std::function<void(const UHDM::any*)> resolve_leaf;
                    resolve_leaf = [&](const UHDM::any* expr) {
                        if (!expr) return;
                        // `z[3][3]` is a single `var_select` with two
                        // indices in its `Exprs()` list — each index
                        // strips one outer dim.  We treat it as N nested
                        // bit_selects on the named array_net.
                        if (auto vs = dynamic_cast<const UHDM::var_select*>(expr)) {
                            int n_idx = vs->Exprs() ? (int)vs->Exprs()->size() : 0;
                            strip_outer_dims += n_idx;
                            std::string bname = std::string(vs->VpiName());
                            if (!bname.empty()) {
                                if (auto an = find_array_net_by_name(bname)) {
                                    resolve_leaf(an);
                                    return;
                                }
                            }
                            if (vs->Actual_group()) {
                                resolve_leaf(vs->Actual_group());
                                return;
                            }
                            return;
                        }
                        if (auto bs = dynamic_cast<const UHDM::bit_select*>(expr)) {
                            ++strip_outer_dims;
                            // Bit-selects on hier_path have the parent path
                            // in VpiParent; on a plain ref the parent is the
                            // base wire.  When neither is available (a bare
                            // `z[3]` argument to a sys_func_call), look the
                            // base name up directly in the module's
                            // Array_nets / Nets.
                            if (bs->Actual_group()) {
                                resolve_leaf(bs->Actual_group());
                                return;
                            }
                            std::string bname = std::string(bs->VpiName());
                            if (!bname.empty()) {
                                if (auto an = find_array_net_by_name(bname)) {
                                    resolve_leaf(an);
                                    return;
                                }
                            }
                            if (bs->VpiParent())
                                resolve_leaf(bs->VpiParent());
                            return;
                        }
                        // array_net argument (already-resolved): handle
                        // directly without going through ref_obj.
                        if (auto an = dynamic_cast<const UHDM::array_net*>(expr)) {
                            int elem_w = 1;
                            if (an->Nets() && !an->Nets()->empty()) {
                                if (auto en = (*an->Nets())[0]) {
                                    if (en->Typespec() && en->Typespec()->Actual_typespec()) {
                                        leaf_ts = en->Typespec()->Actual_typespec();
                                        elem_w = get_width_from_typespec(
                                            leaf_ts, current_instance);
                                    }
                                }
                            }
                            int count = 1;
                            if (an->Ranges() && !an->Ranges()->empty()) {
                                for (auto r : *an->Ranges()) {
                                    RTLIL::SigSpec ls = import_expression(
                                        any_cast<const UHDM::expr*>(r->Left_expr()));
                                    RTLIL::SigSpec rs = import_expression(
                                        any_cast<const UHDM::expr*>(r->Right_expr()));
                                    if (ls.is_fully_const() && rs.is_fully_const())
                                        count *= std::abs(ls.as_int() - rs.as_int()) + 1;
                                }
                            } else {
                                count = (int)an->VpiSize();
                            }
                            if (count > 0 && elem_w > 0)
                                total_bits = count * elem_w;
                            unpacked_dim_count = append_array_net_dims(an, dims);
                            return;
                        }
                        if (auto hp = dynamic_cast<const UHDM::hier_path*>(expr)) {
                            // Use the last Path_elems entry — it's the leaf
                            // ref_obj/bit_select that names the actual member.
                            if (hp->Path_elems() && !hp->Path_elems()->empty()) {
                                resolve_leaf(hp->Path_elems()->back());
                                return;
                            }
                        }
                        if (auto ref = dynamic_cast<const UHDM::ref_obj*>(expr)) {
                            if (ref->Actual_group()) {
                                if (auto v = dynamic_cast<const UHDM::variables*>(ref->Actual_group())) {
                                    if (v->Typespec() && v->Typespec()->Actual_typespec())
                                        leaf_ts = v->Typespec()->Actual_typespec();
                                } else if (auto an = dynamic_cast<const UHDM::array_net*>(ref->Actual_group())) {
                                    // Unpacked array net (`wire [3:0] z [N1][N2]`).
                                    // `array_net->Ranges()` carries the
                                    // unpacked dims (outer → inner), and
                                    // `array_net->Nets()[0]->Typespec()` is
                                    // the element typespec (packed dims).
                                    // Populate `dims` with unpacked dims
                                    // first, then defer the packed-dim walk
                                    // to the leaf typespec below.
                                    // Also compute `total_bits = product *
                                    // elem_w` for `$bits`.
                                    int elem_w = 1;
                                    if (an->Nets() && !an->Nets()->empty()) {
                                        if (auto en = (*an->Nets())[0]) {
                                            if (en->Typespec() && en->Typespec()->Actual_typespec()) {
                                                leaf_ts = en->Typespec()->Actual_typespec();
                                                elem_w = get_width_from_typespec(
                                                    leaf_ts, current_instance);
                                            }
                                        }
                                    }
                                    int count = 1;
                                    if (an->Ranges() && !an->Ranges()->empty()) {
                                        for (auto r : *an->Ranges()) {
                                            RTLIL::SigSpec ls = import_expression(
                                                any_cast<const UHDM::expr*>(r->Left_expr()));
                                            RTLIL::SigSpec rs = import_expression(
                                                any_cast<const UHDM::expr*>(r->Right_expr()));
                                            if (ls.is_fully_const() && rs.is_fully_const())
                                                count *= std::abs(ls.as_int() - rs.as_int()) + 1;
                                        }
                                    } else {
                                        count = (int)an->VpiSize();
                                    }
                                    if (count > 0 && elem_w > 0)
                                        total_bits = count * elem_w;
                                    // Defer dims population until after
                                    // resolve_leaf returns — we'll grab
                                    // `an` from a side variable.  Easiest:
                                    // populate `dims` here, set a flag so
                                    // the post-resolve_leaf code skips the
                                    // typespec walk for the unpacked part.
                                    unpacked_dim_count = append_array_net_dims(an, dims);
                                    return;
                                } else if (auto n = dynamic_cast<const UHDM::net*>(ref->Actual_group())) {
                                    if (n->Typespec() && n->Typespec()->Actual_typespec())
                                        leaf_ts = n->Typespec()->Actual_typespec();
                                }
                            }
                            return;
                        }
                    };
                    resolve_leaf(first_arg);

                    // Try ExprEval::decodeHierPath as a fallback for hier
                    // paths whose Path_elems leaf doesn't carry typespec
                    // info directly (struct/union member access).
                    if (!leaf_ts) {
                        if (auto hp = dynamic_cast<const UHDM::hier_path*>(first_arg)) {
                            UHDM::ExprEval eval;
                            bool inv = false;
                            UHDM::any* member = eval.decodeHierPath(
                                const_cast<UHDM::hier_path*>(hp), inv,
                                current_instance, hp,
                                UHDM::ExprEval::ReturnType::MEMBER, false);
                            if (!inv && member) {
                                const UHDM::ref_typespec* mrt = nullptr;
                                if (auto v = dynamic_cast<const UHDM::variables*>(member))
                                    mrt = v->Typespec();
                                else if (auto n = dynamic_cast<const UHDM::net*>(member))
                                    mrt = n->Typespec();
                                if (mrt && mrt->Actual_typespec())
                                    leaf_ts = mrt->Actual_typespec();
                            }
                        }
                    }

                    if (leaf_ts) append_typespec_dims(append_typespec_dims, leaf_ts, dims);
                    // Strip one outer dim per surrounding bit_select.  For
                    // a 2-D unpacked array (e.g. `z[7:2][2:9]`) accessed
                    // via `z[3]`, the bit_select strips the outermost
                    // unpacked dim (leaving 1 unpacked + 1 packed).
                    while (strip_outer_dims > 0 && !dims.empty()) {
                        dims.erase(dims.begin());
                        if (unpacked_dim_count > 0) --unpacked_dim_count;
                        --strip_outer_dims;
                    }

                    // Pick the dimension index from the optional 2nd arg.
                    // The arg can be a constant expression like `(1+1)`
                    // which `import_expression` doesn't fold at module
                    // scope (folding is gated on loop/function/genscope
                    // contexts).  Fall back to `ExprEval::reduceExpr` on
                    // the raw UHDM expr to evaluate such literals.
                    int dim_index = 1;
                    if (args.size() >= 2) {
                        if (args[1].is_fully_const()) {
                            dim_index = args[1].as_const().as_int();
                        } else if (func_call->Tf_call_args()->size() >= 2) {
                            auto dim_arg = (*func_call->Tf_call_args())[1];
                            if (auto e = dynamic_cast<const UHDM::expr*>(dim_arg)) {
                                UHDM::ExprEval ev;
                                bool inv = false;
                                UHDM::expr* res = ev.reduceExpr(
                                    const_cast<UHDM::expr*>(e), inv,
                                    current_instance, e->VpiParent(), true);
                                if (res && res->UhdmType() == uhdmconstant) {
                                    auto c = dynamic_cast<const UHDM::constant*>(res);
                                    RTLIL::SigSpec s = import_constant(c);
                                    if (s.is_fully_const())
                                        dim_index = s.as_const().as_int();
                                }
                            }
                        }
                    }

                    auto dim_size = [](const DimInfo& d) {
                        return std::abs(d.left - d.right) + 1;
                    };

                    int result = 0;
                    if (func_name == "$bits") {
                        result = total_bits;
                    } else if (func_name == "$dimensions") {
                        // Atomic types and structs report 1 dimension.
                        result = dims.empty() ? 1 : (int)dims.size();
                    } else if (func_name == "$unpacked_dimensions") {
                        // SV LRM: only the unpacked (outermost) dims.
                        result = unpacked_dim_count;
                    } else if (dims.empty()) {
                        // Atomic / struct: treat as a single dim covering all
                        // bits with range [bits-1:0] (descending).
                        DimInfo whole{total_bits ? total_bits - 1 : 0, 0};
                        if (func_name == "$size")          result = total_bits;
                        else if (func_name == "$left")     result = whole.left;
                        else if (func_name == "$right")    result = whole.right;
                        else if (func_name == "$high")     result = whole.left;
                        else if (func_name == "$low")      result = whole.right;
                        // SV LRM §20.7: $increment is +1 if the dim is
                        // descending (left > right) OR scalar (left == right);
                        // -1 if ascending.  An atomic / struct's implicit
                        // range is [bits-1:0] — descending or scalar — so
                        // +1.  The previous code returned -1 here, which
                        // contradicts yosys/tests/sat/sizebits.sv line 119.
                        else if (func_name == "$increment") result = 1;
                    } else if (dim_index >= 1 && dim_index <= (int)dims.size()) {
                        const DimInfo& d = dims[dim_index - 1];
                        if (func_name == "$size")          result = dim_size(d);
                        else if (func_name == "$left")     result = d.left;
                        else if (func_name == "$right")    result = d.right;
                        else if (func_name == "$high")     result = std::max(d.left, d.right);
                        else if (func_name == "$low")      result = std::min(d.left, d.right);
                        // SV LRM §20.7: descending (left > right) → +1;
                        // ascending (left < right) → -1; equal → +1.
                        // The original `(left < right) ? 1 : -1` had the
                        // mapping inverted.
                        else if (func_name == "$increment") result = (d.left < d.right) ? -1 : 1;
                    } else {
                        log_warning("UHDM: %s with dim=%d out of range (%d dims)\n",
                                    func_name.c_str(), dim_index, (int)dims.size());
                    }
                    log_debug("UHDM: %s returning %d (dims=%d, strip=%d)\n",
                              func_name.c_str(), result, (int)dims.size(), strip_outer_dims);
                    return RTLIL::SigSpec(RTLIL::Const(result, 32));
                } else {
                    log_warning("Unhandled system function call: %s with %d arguments\n",
                               func_name.c_str(), (int)args.size());
                    // Return first argument if available, otherwise empty
                    return args.empty() ? RTLIL::SigSpec() : args[0];
                }
            }
            break;
        case vpiFuncCall:
            // Handle user-defined function calls by inlining the function logic
            {
                const func_call* fc = any_cast<const func_call*>(uhdm_expr);
                if (!fc) {
                    log_warning("Failed to cast expression to func_call\n");
                    return RTLIL::SigSpec();
                }

                std::string func_name = std::string(fc->VpiName());
                log("UHDM: Processing function call: %s\n", func_name.c_str());

                // Get the function definition.  Surelog binds the
                // `Function()` pointer at parse time and doesn't always
                // honour the local shadowing rules for generate-block
                // functions, so when we're inside a gen_scope first
                // check its own `Task_funcs()` for a same-named callee
                // and prefer that over the parent-module binding.
                const function* func_def = nullptr;
                if (current_scope &&
                    current_scope->UhdmType() == uhdmgen_scope) {
                    auto gs = any_cast<const UHDM::gen_scope*>(current_scope);
                    if (gs->Task_funcs()) {
                        for (auto tf : *gs->Task_funcs()) {
                            if (tf->UhdmType() == uhdmfunction &&
                                std::string(tf->VpiName()) == func_name) {
                                func_def = any_cast<const function*>(tf);
                                break;
                            }
                        }
                    }
                }
                if (!func_def) func_def = fc->Function();
                log("UHDM: func_def pointer: %p\n", (void*)func_def);
                if (!func_def) {
                    log_warning("Function definition not found for %s\n", func_name.c_str());
                    return RTLIL::SigSpec();
                }

                if (mode_debug) {
                    log("UHDM: Function definition found for %s\n", func_name.c_str());
                    if (func_def->Stmt()) {
                        log("UHDM: Function has statement body\n");
                    } else {
                        log("UHDM: Function has no statement body!\n");
                    }
                }

                // Get function return width
                // Use current_scope (gen_scope) if available, since it has the correct
                // local parameter values (e.g., WIDTH_A=6 inside a generate block).
                // Fall back to current_instance for top-level functions.
                int ret_width = 1;
                if (func_def->Return()) {
                    const UHDM::scope* width_inst = current_scope ? current_scope : current_instance;
                    ret_width = get_width(func_def->Return(), width_inst);
                }

                // Collect arguments first
                std::vector<RTLIL::SigSpec> args;
                std::vector<std::string> arg_names;
                if (fc->Tf_call_args()) {
                    for (auto arg : *fc->Tf_call_args()) {
                        // Pass input_mapping to resolve nested function parameters
                        RTLIL::SigSpec arg_sig = import_expression(any_cast<const expr*>(arg), input_mapping);
                        args.push_back(arg_sig);
                    }
                }

                // Check if all arguments are constants - if they are, we can evaluate at compile time
                // This applies to both initial blocks and continuous assignments
                bool all_const = true;
                std::vector<RTLIL::Const> const_args;

                for (const auto& arg : args) {
                    if (arg.is_fully_const()) {
                        const_args.push_back(arg.as_const());
                    } else {
                        all_const = false;
                        break;
                    }
                }

                if (all_const) {
                    // Evaluate function at compile time for optimization.
                    // Clear side-effect map so this top-level call starts fresh.
                    const_eval_module_writes.clear();
                    log("UHDM: Evaluating function %s at compile time (all arguments are constant)\n", func_name.c_str());
                    std::map<std::string, RTLIL::Const> output_params;
                    RTLIL::Const result = evaluate_function_call(func_def, const_args, output_params);

                    // Apply any module-level bit-select side effects collected during
                    // compile-time evaluation (e.g. "out6[exp] = base & 1").
                    for (auto& [sig_name, bit_vals] : const_eval_module_writes) {
                        RTLIL::IdString wid = RTLIL::escape_id(sig_name);
                        RTLIL::Wire* tw = module->wire(wid);
                        if (!tw && name_map.count(sig_name))
                            tw = name_map.at(sig_name);
                        if (tw) {
                            for (int bi = 0; bi < (int)bit_vals.size(); bi++) {
                                if (bit_vals[bi] < 0) continue; // unset
                                RTLIL::SigSpec tgt(RTLIL::SigBit(tw, bi));
                                RTLIL::SigSpec val(bit_vals[bi] ? RTLIL::State::S1
                                                                 : RTLIL::State::S0);
                                module->connect(tgt, val);
                            }
                        }
                    }
                    const_eval_module_writes.clear();

                    // Return the constant result
                    return RTLIL::SigSpec(result);
                }

                // For initial blocks with non-constant arguments, check if function returns a value
                if (in_initial_block && !all_const) {
                    // If not all constant, check if function returns a value
                    bool has_return = false;
                    scan_for_direct_return_assignment(func_def->Stmt(), func_name, has_return);

                    if (!has_return) {
                        // Function doesn't assign to its return value
                        // Still generate process for output parameters, but return 0 for the return value
                        log("UHDM: Function %s in initial block doesn't assign to its return value\n", func_name.c_str());

                        // Process function for output parameters (result wire created internally)

                        // Generate process to handle output parameters
                        log("UHDM: Processing function %s with context-aware method\n", func_name.c_str());
                        process_function_with_context(func_def, args, fc, nullptr);

                        // But return a constant 0 for the function's return value in initial block
                        return RTLIL::SigSpec(0, ret_width);
                    }

                    log("UHDM: Function %s in initial block has non-constant arguments, generating process\n", func_name.c_str());
                }

                // If we're in a combinational always block, inline the function
                // instead of creating a separate process (avoids feedback loops)
                if (current_comb_process) {
                    log("UHDM: Inlining function %s into combinational process\n", func_name.c_str());
                    return import_func_call_comb(fc, current_comb_process);
                }

                // Top-level value-returning call (e.g. `assign out = f(...)`)
                // with NO output/inout params: route through the combinational
                // SSA inliner (import_func_call_comb), which stages function-local
                // blocking temps via func_mapping exactly like always_comb
                // inlining.  The legacy process_function_with_context path maps
                // every local to ONE shared `$<ctx>$local_<var>` wire, so a
                // sequential temp chain — function_arith: temp=a+b; temp=temp-c;
                // temp=temp<<1; temp=temp|(a&b); func=temp^c — read the FINAL
                // value at every step.  Functions with output args (the legacy
                // path writes them back to the caller) or nested calls
                // (input_mapping set) keep process_function_with_context.
                if (!input_mapping) {
                    bool has_output_param = false;
                    if (auto ios = func_def->Io_decls()) {
                        for (auto io_any : *ios) {
                            if (auto io = any_cast<const UHDM::io_decl*>(io_any)) {
                                int d = io->VpiDirection();
                                if (d == vpiOutput || d == vpiInout) {
                                    has_output_param = true;
                                    break;
                                }
                            }
                        }
                    }
                    // Only STRAIGHT-LINE bodies (no case/if/loop) are safe to
                    // route here: import_func_call_comb stages sequential
                    // blocking temps via func_mapping but does NOT capture a
                    // control-flow-muxed return value (case/if assignments go
                    // through import_case_stmt_comb and update wires, leaving
                    // func_mapping[func_name] = Sx).  Control-flow functions keep
                    // the proven process_function_with_context path.
                    std::function<bool(const UHDM::any*)> is_straight_line =
                        [&](const UHDM::any* s) -> bool {
                            if (!s) return true;
                            int t = s->VpiType();
                            if (t == vpiCase || t == vpiIf || t == vpiIfElse ||
                                t == vpiFor || t == vpiWhile || t == vpiDoWhile ||
                                t == vpiRepeat || t == vpiForever)
                                return false;
                            // A part/bit/indexed-select LHS (e.g. a partial
                            // return `func3[A:B] = ...`) is not captured by
                            // func_mapping's whole-name tracking — keep those on
                            // the legacy path.
                            if (t == vpiAssignment || t == vpiAssignStmt) {
                                auto a = any_cast<const UHDM::assignment*>(s);
                                if (!a) return true;
                                if (a->Lhs() && a->Lhs()->VpiType() != vpiRefObj)
                                    return false;
                                // A nested function call in the RHS reads its
                                // args from current_comb_values, not the
                                // enclosing func_mapping, so the callee sees the
                                // wrong values (const_fold_func: help=flip(inp)
                                // read the module input, not help's parameter).
                                std::function<bool(const UHDM::any*)> has_call =
                                    [&](const UHDM::any* e) -> bool {
                                        if (!e) return false;
                                        int et = e->VpiType();
                                        if (et == vpiFuncCall || et == vpiSysFuncCall)
                                            return true;
                                        if (et == vpiOperation) {
                                            auto op = any_cast<const UHDM::operation*>(e);
                                            if (op && op->Operands())
                                                for (auto o : *op->Operands())
                                                    if (has_call(o)) return true;
                                        }
                                        return false;
                                    };
                                if (has_call(a->Rhs())) return false;
                                return true;
                            }
                            if (t == vpiBegin || t == vpiNamedBegin) {
                                if (auto stmts = begin_block_stmts(s))
                                    for (auto cs : *stmts)
                                        if (!is_straight_line(cs)) return false;
                            }
                            return true;
                        };
                    // Generate-scope functions (and hierarchical/shadowed calls)
                    // resolve names through the gen-scope; import_func_call_comb
                    // doesn't carry that context, so restrict the reroute to
                    // plain module-scope calls.
                    bool in_gen_scope = !gen_scope_stack.empty() ||
                        (current_scope && current_scope->UhdmType() == uhdmgen_scope);
                    // import_func_call_comb maps each actual straight into
                    // func_mapping without extending it to the formal's width
                    // (func_width_scope: 1-bit signed actual into a 5-bit
                    // formal).  Only reroute when every actual already matches
                    // its formal width.
                    bool args_match = true;
                    if (auto ios = func_def->Io_decls()) {
                        int ai = 0;
                        for (auto io_any : *ios) {
                            auto io = any_cast<const UHDM::io_decl*>(io_any);
                            if (!io || io->VpiDirection() != vpiInput) continue;
                            int pw = get_width(io, current_instance);
                            if (ai < (int)args.size() && args[ai].size() != pw) {
                                args_match = false;
                                break;
                            }
                            ai++;
                        }
                    }
                    // Only reroute in true continuous-assign / module-level
                    // context.  Inside an always_ff (esp. the async-reset sync
                    // path, where current_comb_process is null) or an initial
                    // block, the temp-process inliner does not integrate with
                    // the procedural assignment lowering (simple_package:
                    // internal_bus.data <= increment_data(...) zeroed the
                    // struct).  always_comb already takes the
                    // current_comb_process branch above.
                    if (!has_output_param && !in_gen_scope && !in_always_ff_context &&
                        !in_initial_block && args_match &&
                        is_straight_line(func_def->Stmt())) {
                        log("UHDM: Inlining function %s via import_func_call_comb (no enclosing process)\n",
                            func_name.c_str());
                        RTLIL::Process* tmp_proc = module->addProcess(NEW_ID);
                        RTLIL::SyncRule* sta = new RTLIL::SyncRule();
                        sta->type = RTLIL::SyncType::STa;
                        sta->signal = RTLIL::SigSpec();
                        tmp_proc->syncs.push_back(sta);
                        RTLIL::Process* saved_proc = current_comb_process;
                        current_comb_process = tmp_proc;
                        RTLIL::SigSpec r = import_func_call_comb(fc, tmp_proc);
                        current_comb_process = saved_proc;
                        return r;
                    }
                }

                // Use the new context-aware function processing
                FunctionCallContext* parent_ctx = nullptr;

                // If we're inside a function (input_mapping is not null), we should track the parent context
                // For now, we'll pass nullptr but this will be enhanced to get proper parent context
                if (input_mapping) {
                    // TODO: Get parent context from the call stack
                    parent_ctx = nullptr;
                }

                // Process the function using the new context-aware method
                log("UHDM: Processing function %s with context-aware method (return width=%d, %d arguments)\n",
                    func_name.c_str(), ret_width, (int)args.size());
                return process_function_with_context(func_def, args, fc, parent_ctx);
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

    // If VpiConstType is 0 (undefined), infer the type from the value string prefix
    if (const_type == 0 && !value.empty()) {
        if (value.substr(0, 5) == "UINT:") const_type = vpiUIntConst;
        else if (value.substr(0, 4) == "INT:") const_type = vpiIntConst;
        else if (value.substr(0, 4) == "BIN:") const_type = vpiBinaryConst;
        else if (value.substr(0, 4) == "HEX:") const_type = vpiHexConst;
        else if (value.substr(0, 4) == "DEC:") const_type = vpiDecConst;
        else if (value.substr(0, 7) == "STRING:") const_type = vpiStringConst;
        if (const_type != 0)
            log("UHDM: Inferred constant type %d from value prefix\n", const_type);
    }

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
            // Per SV LRM, '0/'1/'x/'z self-replicate to fill the context width.
            // If expression_context_width is set (propagated from the LHS), use it
            // so operations like '1 << 8 produce a full-width shifted result rather
            // than a 1-bit result that then gets zero-extended.
            if (size == -1) {
                int fill_width = (expression_context_width > 0) ? expression_context_width : 1;
                if (bin_str == "X" || bin_str == "x") {
                    return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::Sx, fill_width));
                } else if (bin_str == "Z" || bin_str == "z") {
                    return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::Sz, fill_width));
                } else if (bin_str == "0") {
                    return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::S0, fill_width));
                } else if (bin_str == "1") {
                    return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::S1, fill_width));
                }
            }
            
            // Create constant with proper size
            RTLIL::Const const_val = RTLIL::Const::from_string(bin_str);
            if (size > 0 && const_val.size() != size) {
                if (const_val.size() < size) {
                    // Check if sign extension is needed via the constant's typespec.
                    // Surelog may fold a function call like func1(1'b1) → BIN:1 vpiSize:2
                    // where the typespec still has VpiSigned:1 from the signed parameter.
                    bool is_signed = false;
                    if (uhdm_const->Typespec()) {
                        const UHDM::typespec* actual_ts = uhdm_const->Typespec()->Actual_typespec();
                        if (actual_ts && actual_ts->UhdmType() == uhdmlogic_typespec) {
                            auto logic_ts = dynamic_cast<const UHDM::logic_typespec*>(actual_ts);
                            if (logic_ts && logic_ts->VpiSigned())
                                is_signed = true;
                        }
                    }
                    RTLIL::SigSpec sig(const_val);
                    sig.extend_u0(size, is_signed);
                    return sig;
                } else {
                    const_val.resize(size, RTLIL::State::S0);
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
                int width = (size > 0) ? size : 32;
                return RTLIL::SigSpec(RTLIL::Const(int_val, width));
            } catch (const std::exception& e) {
                log_error("Failed to parse decimal constant: value='%s', substr='%s', error=%s\n",
                         value.c_str(), dec_str.c_str(), e.what());
            }
        }
        case vpiIntConst: {
            std::string int_str = value.substr(4);
            try {
                long long int_val = std::stoll(int_str);
                // Handle sizes larger than 64 bits (e.g. logic [127:0] b = -1).
                // Surelog stores the constant at the destination width (e.g. 128) but with
                // the value of the source type (e.g. -1 for a 32-bit integer or 2-bit bit).
                // We must: (a) recover the source type width & signedness from the typespec,
                // (b) truncate int_val to that width, (c) then extend to `size` bits.
                if (size > 64) {
                    bool is_signed_type = false;
                    int type_width = 64; // fallback: treat the 64-bit C value as-is
                    if (uhdm_const->Typespec()) {
                        auto ts = uhdm_const->Typespec()->Actual_typespec();
                        if (ts) {
                            int tw = get_width_from_typespec(ts, current_instance);
                            if (tw > 0 && tw <= 64) type_width = tw;
                            // Determine signedness from typespec (each class has VpiSigned)
                            switch (ts->UhdmType()) {
                                case uhdminteger_typespec: {
                                    auto its = any_cast<const integer_typespec*>(ts);
                                    if (its) is_signed_type = its->VpiSigned();
                                    break;
                                }
                                case uhdmint_typespec: {
                                    auto its = any_cast<const int_typespec*>(ts);
                                    if (its) is_signed_type = its->VpiSigned();
                                    break;
                                }
                                case uhdmshort_int_typespec: {
                                    auto its = any_cast<const short_int_typespec*>(ts);
                                    if (its) is_signed_type = its->VpiSigned();
                                    break;
                                }
                                case uhdmlong_int_typespec: {
                                    auto its = any_cast<const long_int_typespec*>(ts);
                                    if (its) is_signed_type = its->VpiSigned();
                                    break;
                                }
                                case uhdmbyte_typespec: {
                                    auto its = any_cast<const byte_typespec*>(ts);
                                    if (its) is_signed_type = its->VpiSigned();
                                    break;
                                }
                                case uhdmlogic_typespec: {
                                    auto lts = any_cast<const logic_typespec*>(ts);
                                    if (lts) is_signed_type = lts->VpiSigned();
                                    break;
                                }
                                case uhdmbit_typespec: {
                                    auto bts = any_cast<const bit_typespec*>(ts);
                                    if (bts) is_signed_type = bts->VpiSigned();
                                    break;
                                }
                                default:
                                    is_signed_type = false;
                                    break;
                            }
                        }
                    }
                    // Truncate int_val to type_width bits (handles 2-bit, 8-bit, 32-bit, etc.)
                    long long type_val;
                    if (type_width < 64) {
                        long long mask = (1LL << type_width) - 1;
                        type_val = int_val & mask;
                        if (is_signed_type) {
                            // Re-sign-extend to restore sign within type_width bits
                            long long sign = 1LL << (type_width - 1);
                            if (type_val & sign) type_val |= ~mask;
                        }
                    } else {
                        type_val = int_val;
                    }
                    RTLIL::Const base(type_val, type_width);
                    RTLIL::State fill = (is_signed_type && type_val < 0)
                                       ? RTLIL::State::S1 : RTLIL::State::S0;
                    auto bv = base.to_bits();
                    bv.resize(size, fill);
                    return RTLIL::SigSpec(RTLIL::Const(bv));
                }
                // Use VpiSize when available and reasonable, else default to 32
                int width = (size > 0 && size <= 64) ? size : 32;
                if (int_val > INT32_MAX || int_val < INT32_MIN) {
                    width = 64;
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
        case vpiRealConst: {
            // Real-valued constant — convert to integer per LRM real-to-int rules
            // (round to nearest, ties away from zero) at the context width.
            std::string real_str;
            if (value.substr(0, 5) == "REAL:") real_str = value.substr(5);
            else real_str = value;
            double d = 0.0;
            try { d = std::stod(real_str); }
            catch (const std::exception&) { return RTLIL::SigSpec(RTLIL::State::Sx); }
            int width = (expression_context_width > 0) ? expression_context_width : 32;
            // round-half-away-from-zero
            double rounded = (d >= 0.0) ? std::floor(d + 0.5) : std::ceil(d - 0.5);
            long long ival = (long long)rounded;
            return RTLIL::SigSpec(RTLIL::Const(ival, width));
        }
        case vpiStringConst: {
            // Handle string constants like "FOO" (format: "STRING:FOO")
            std::string str_val;
            if (value.substr(0, 7) == "STRING:") {
                str_val = value.substr(7);
            } else {
                str_val = value;
            }

            if (mode_debug)
                log("    vpiStringConst: value='%s', str='%s', size=%d\n", value.c_str(), str_val.c_str(), size);

            // Convert string to bits: each character is 8 bits, big-endian (first char = MSB)
            int bit_width = str_val.size() * 8;
            if (size > 0 && size != bit_width) {
                bit_width = size;
            }

            RTLIL::Const const_val(0, bit_width);
            for (int i = 0; i < (int)str_val.size(); i++) {
                unsigned char c = str_val[str_val.size() - 1 - i];
                for (int j = 0; j < 8; j++) {
                    int bit_idx = i * 8 + j;
                    if (bit_idx < bit_width) {
                        const_val.set(bit_idx, (c & (1 << j)) ? RTLIL::State::S1 : RTLIL::State::S0);
                    }
                }
            }

            return RTLIL::SigSpec(const_val);
        }
        default:
            log_warning("Unsupported constant type: %d\n", const_type);
            return RTLIL::SigSpec(RTLIL::State::Sx);
    }
}

// Check if any operand comes from a signed wire
static bool check_operands_signed(const std::vector<RTLIL::SigSpec>& operands) {
    for (const auto& operand : operands) {
        if (operand.is_wire()) {
            RTLIL::Wire* wire = operand.as_wire();
            if (wire && wire->is_signed)
                return true;
        }
    }
    return false;
}

bool UhdmImporter::operands_all_signed(const UHDM::operation* op) {
    if (!op || !op->Operands() || op->Operands()->empty())
        return false;
    for (auto o : *op->Operands()) {
        auto e = any_cast<const expr*>(o);
        if (!e || !is_expr_signed(e))
            return false;
    }
    return true;
}

// Mark the output wire of a SigSpec as signed
static void mark_result_signed(RTLIL::SigSpec& result) {
    if (result.is_wire()) {
        result.as_wire()->is_signed = true;
    }
}

// LRM (IEEE 1800 Table 11-21) self-determined bit-length of an expression.
// Returns 0 when it cannot be determined structurally (caller leaves the
// imported width untouched).  Crucially, arithmetic (+ - * / %) and bitwise
// (& | ^ ~^) ops use max(L, R) here — NOT the full-precision sum that
// import_operation falls back to without an assignment context.  This is what
// the Verilog frontend uses for self-determined positions like a part-select
// index, so `dout[ctrl*sel +: 16]` truncates the index to max(width(ctrl),
// width(sel)) rather than width(ctrl)+width(sel).
int UhdmImporter::self_determined_width(const UHDM::any* node) {
    if (!node)
        return 0;
    if (node->VpiType() == vpiOperation) {
        const operation* op = any_cast<const operation*>(node);
        std::vector<const UHDM::any*> ops;
        if (op->Operands())
            for (auto o : *op->Operands())
                ops.push_back(o);
        auto W = [&](size_t i) -> int {
            return i < ops.size() ? self_determined_width(ops[i]) : 0;
        };
        switch (op->VpiOpType()) {
            // Arithmetic and bitwise binary: max(L, R).
            case vpiAddOp: case vpiSubOp: case vpiMultOp: case vpiDivOp:
            case vpiModOp: case vpiBitAndOp: case vpiBitOrOp:
            case vpiBitXorOp: case vpiBitXnorOp:
                return std::max(W(0), W(1));
            // Unary arithmetic / bitwise negation: width of the operand.
            case vpiMinusOp: case vpiPlusOp: case vpiBitNegOp:
                return W(0);
            // Shifts: width of the left (shifted) operand.
            case vpiLShiftOp: case vpiRShiftOp:
            case vpiArithLShiftOp: case vpiArithRShiftOp:
                return W(0);
            // Conditional: max of the two result operands (1=then, 2=else).
            case vpiConditionOp:
                return std::max(W(1), W(2));
            case vpiConcatOp: {
                int s = 0;
                for (auto o : ops)
                    s += self_determined_width(o);
                return s;
            }
            // Comparisons, logical, reductions: 1 bit.
            case vpiEqOp: case vpiNeqOp: case vpiLtOp: case vpiLeOp:
            case vpiGtOp: case vpiGeOp: case vpiLogAndOp: case vpiLogOrOp:
            case vpiNotOp: case vpiUnaryAndOp: case vpiUnaryNandOp:
            case vpiUnaryOrOp: case vpiUnaryNorOp: case vpiUnaryXorOp:
            case vpiUnaryXNorOp:
                return 1;
            default:
                return 0;  // unknown form -> "don't truncate"
        }
    }
    // Leaf (ref / net / var / constant / select): width of the imported value.
    // For these, import_expression resolves to an existing wire or a Const and
    // creates no new logic, so this is side-effect-free.
    if (auto e = dynamic_cast<const UHDM::expr*>(node))
        return import_expression(e).size();
    return 0;
}

// Import operation
RTLIL::SigSpec UhdmImporter::import_operation(const operation* uhdm_op, const UHDM::scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    int op_type = uhdm_op->VpiOpType();

    // Handle side-effect operations before reduceExpr (which doesn't understand them)
    if (op_type == vpiPostIncOp || op_type == vpiPreIncOp ||
        op_type == vpiPostDecOp || op_type == vpiPreDecOp) {
        // Inc/dec as expression: emit side-effect and return value
        // Pre-increment/decrement: return NEW value (after modification)
        // Post-increment/decrement: return OLD value (before modification)
        if (uhdm_op->Operands() && !uhdm_op->Operands()->empty()) {
            const expr* operand = any_cast<const expr*>((*uhdm_op->Operands())[0]);
            // Import with value tracking for the cell input (current value)
            RTLIL::SigSpec cell_input = import_expression(operand, input_mapping);
            // Import without value tracking for the side-effect target (actual wire)
            RTLIL::SigSpec target_wire = import_expression(operand, nullptr);
            if (cell_input.size() == 0) return RTLIL::SigSpec();

            RTLIL::SigSpec one = RTLIL::SigSpec(RTLIL::Const(1, cell_input.size()));
            RTLIL::SigSpec result = module->addWire(NEW_ID, cell_input.size());

            if (op_type == vpiPostIncOp || op_type == vpiPreIncOp) {
                module->addAdd(NEW_ID, cell_input, one, result, false);
            } else {
                module->addSub(NEW_ID, cell_input, one, result, false);
            }

            // Emit side-effect: target_wire = result (always updates variable)
            if (current_comb_process) {
                emit_comb_assign(target_wire, result, current_comb_process);
            }

            // Pre: return new value; Post: return old value
            bool is_pre = (op_type == vpiPreIncOp || op_type == vpiPreDecOp);
            return is_pre ? result : cell_input;
        }
        return RTLIL::SigSpec();
    }

    if (op_type == vpiAssignmentOp) {
        // Assignment-as-expression: (y = expr)
        // operand[0] = target ref, operand[1] = value expr
        if (uhdm_op->Operands() && uhdm_op->Operands()->size() >= 2) {
            // Import target without value tracking (need actual wire for side-effect LHS)
            RTLIL::SigSpec target = import_expression(any_cast<const expr*>((*uhdm_op->Operands())[0]), nullptr);
            // Import value with value tracking (need current values for correct computation)
            RTLIL::SigSpec value = import_expression(any_cast<const expr*>((*uhdm_op->Operands())[1]), input_mapping);

            if (target.size() == 0 || value.size() == 0) return RTLIL::SigSpec();

            // Size match
            if (value.size() != target.size()) {
                if (value.size() < target.size())
                    value.extend_u0(target.size());
                else
                    value = value.extract(0, target.size());
            }

            // Emit side-effect: target = value
            if (current_comb_process) {
                emit_comb_assign(target, value, current_comb_process);
            }

            return value;
        }
        return RTLIL::SigSpec();
    }

    if (op_type == vpiAssignmentPatternOp) {
        // Struct/array aggregate: '{field: val, field: val, ...}
        // Surelog stores the value expressions directly as operands (hier_path, ref_obj, etc.),
        // in struct field definition order (first field = MSB for packed structs).
        // Same concatenation order as vpiConcatOp: first operand at MSB —
        // UNLESS the operation has `vpiReordered:1` set, which means
        // Surelog already reordered the operands into LSB-first order
        // (post-substitution path in the elaborated TopModules).
        if (uhdm_op->Operands()) {
            std::vector<RTLIL::SigSpec> field_sigs;
            for (auto operand : *uhdm_op->Operands()) {
                const expr* field_expr = any_cast<const expr*>(operand);
                if (!field_expr) continue;
                RTLIL::SigSpec val = import_expression(field_expr, input_mapping);
                if (mode_debug)
                    log("UHDM: AssignmentPatternOp field size=%d\n", val.size());
                field_sigs.push_back(val);
            }
            RTLIL::SigSpec result;
            if (uhdm_op->VpiReordered()) {
                // Already LSB-first — append in source order.
                for (auto& s : field_sigs) result.append(s);
            } else {
                // First field at MSB — iterate in reverse and append.
                for (int i = (int)field_sigs.size() - 1; i >= 0; i--)
                    result.append(field_sigs[i]);
            }
            return result;
        }
        return RTLIL::SigSpec();
    }

    // Try to reduce it first (for non-side-effect operations). We skip
    // `vpiCastOp` here: Surelog's reduceExpr folds `8'(4'(signed'(...)))`
    // into a single constant but applies plain zero-extension at the
    // final widen — losing the explicit `signed'`/`unsigned'` cast and
    // producing the wrong bits (static_cast_simple).  Our own cast
    // handler below tracks signedness through the chain correctly.
    if (op_type != vpiCastOp) {
        ExprEval eval;
        bool invalidValue = false;
        expr* res = eval.reduceExpr(uhdm_op, invalidValue, inst, uhdm_op->VpiParent(), true);
        if (res && res->UhdmType() == uhdmconstant) {
            return import_constant(dynamic_cast<const UHDM::constant*>(res));
        }
    }
    
    if (mode_debug)
        log("    Importing operation: %d\n", op_type);
    
    // Get operands
    std::vector<RTLIL::SigSpec> operands;
    // Track operands that are intrinsically unsigned regardless of the
    // operation's signedness — a concatenation (and replication) is ALWAYS
    // unsigned in Verilog, so when widened inside a signed op (e.g.
    // `signed_int - {a,b}`) it must be ZERO-extended, not sign-extended.
    std::vector<bool> operand_is_unsigned;
    // Concatenation / replication operands are SELF-DETERMINED in Verilog
    // (LRM §11.8.1): the surrounding assignment's context width must NOT widen
    // them.  Without clearing it, `tmp = {1'b0, ~B}` with a 9-bit `tmp` widens
    // `~B` to 9 bits — turning the value into `~{1'b0, B}`, whose explicit MSB
    // flips from 0 to 1 (alu's NOT/shift flag bits: CF/SF wrong).
    int saved_ctx_for_concat_operands = expression_context_width;
    // Context signedness this operator was asked to produce (LRM §11.8.1).
    const bool ctx_unsigned_entry = expression_context_unsigned;
    bool saved_ctx_unsigned = expression_context_unsigned;
    if (op_type == vpiConcatOp || op_type == vpiMultiConcatOp) {
        expression_context_width = 0;
        // A concat starts a fresh self-determined context: its operands follow
        // their own signedness (`{a+b}` keeps the signed `a+b`), so reset.
        expression_context_unsigned = false;
    } else if (op_type == vpiAddOp || op_type == vpiSubOp ||
               op_type == vpiMultOp || op_type == vpiDivOp ||
               op_type == vpiModOp || op_type == vpiBitAndOp ||
               op_type == vpiBitOrOp || op_type == vpiBitXorOp ||
               op_type == vpiConditionOp) {
        // A context-determined arithmetic/bitwise operator is unsigned iff its
        // context already is, or any operand is unsigned — and it pushes that
        // unsigned-ness down so a signed sub-expression zero-extends.
        if (ctx_unsigned_entry || !is_expr_signed(uhdm_op))
            expression_context_unsigned = true;
    } else if (op_type == vpiEqOp || op_type == vpiNeqOp ||
               op_type == vpiLtOp || op_type == vpiLeOp ||
               op_type == vpiGtOp || op_type == vpiGeOp) {
        // A comparison's RESULT is unsigned 1-bit, but its operands are sized
        // and extended together using their JOINT signedness (both signed →
        // signed).  Propagate unsigned-ness to the operands when they aren't
        // both signed, so `(a+b) != 3'd0` (signedexpr) zero-extends the inner
        // signed add for an unsigned compare.
        // The 1-bit RESULT width must NOT propagate into the operands — they
        // are sized to max(operand widths) among themselves.  Without this,
        // `a+b != 3'd0` (zu is 1-bit) collapsed the `a+b` to a 1-bit add.
        expression_context_width = 0;
        bool ops_all_signed = false;
        if (uhdm_op->Operands() && uhdm_op->Operands()->size() == 2) {
            auto& uops = *uhdm_op->Operands();
            auto e0 = any_cast<const expr*>(uops[0]);
            auto e1 = any_cast<const expr*>(uops[1]);
            ops_all_signed = e0 && e1 && is_expr_signed(e0) && is_expr_signed(e1);
        }
        if (ctx_unsigned_entry || !ops_all_signed)
            expression_context_unsigned = true;
    }
    if (uhdm_op->Operands()) {
        if (op_type == vpiConditionOp) {
            log("UHDM: ConditionOp (type=%d) has %d operands\n", op_type, (int)uhdm_op->Operands()->size());
        }
        for (auto operand : *uhdm_op->Operands()) {
            int oty = operand->VpiType() == vpiOperation
                ? any_cast<const operation*>(operand)->VpiOpType() : -1;
            operand_is_unsigned.push_back(
                oty == vpiConcatOp || oty == vpiMultiConcatOp);
            RTLIL::SigSpec op_sig = import_expression(any_cast<const expr*>(operand), input_mapping);
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
    expression_context_width = saved_ctx_for_concat_operands;
    expression_context_unsigned = saved_ctx_unsigned;

    // Check if all operands are constant - if so, we can evaluate the operation
    // But only do this when we're in a function context with loop variables
    bool all_const = true;
    for (const auto& op : operands) {
        if (!op.is_fully_const()) {
            all_const = false;
            break;
        }
    }
    
    // If all operands are constant AND we are in a loop-unrolling, function body,
    // or generate-scope context (where parameters resolve to iteration-specific
    // constants), fold the operation to a constant right here.
    // This is essential for:
    //  - Recursive functions: `exp - 1` where exp==3 folds to 2 so the next
    //    recursive call can track `exp==2` and terminate.
    //  - Generate-scope indexed part-selects: `PP[(i-1)*(i+2*M)/2 +: M+i]`
    //    where `i` is the generate loop parameter (a constant for each iteration).
    //  - Module marked with `\dynports` (set when port widths reference an
    //    interface parameter via `bus.PARAM`): we resolved the param to a
    //    constant in `import_hier_path`, but the surrounding `range`
    //    expression (`bus.DATA_WIDTH - 1`) still needs to fold so that
    //    `get_width_from_typespec` can read it as a literal range.
    if (all_const && operands.size() > 0 &&
        (!loop_values.empty() || getCurrentFunctionContext() != nullptr ||
         !gen_scope_stack.empty() ||
         (module && module->attributes.count(ID::dynports)))) {
        RTLIL::Const result;
        bool can_evaluate = true;
        
        switch (op_type) {
            case vpiAddOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_add(operands[0].as_const(), operands[1].as_const(), false, false, -1);
                }
                break;
            case vpiSubOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_sub(operands[0].as_const(), operands[1].as_const(), false, false, -1);
                }
                break;
            case vpiMultOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_mul(operands[0].as_const(), operands[1].as_const(), false, false, -1);
                }
                break;
            case vpiDivOp:
                if (operands.size() == 2 && operands[1].as_const().as_int() != 0) {
                    result = RTLIL::const_div(operands[0].as_const(), operands[1].as_const(), false, false, 32);
                }
                break;
            case vpiModOp:
                if (operands.size() == 2 && operands[1].as_const().as_int() != 0) {
                    result = RTLIL::const_mod(operands[0].as_const(), operands[1].as_const(), false, false, 32);
                }
                break;
            case vpiLShiftOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_shl(operands[0].as_const(), operands[1].as_const(), false, false, -1);
                }
                break;
            case vpiRShiftOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_shr(operands[0].as_const(), operands[1].as_const(), false, false, -1);
                }
                break;
            case vpiBitAndOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_and(operands[0].as_const(), operands[1].as_const(), false, false, -1);
                }
                break;
            case vpiBitOrOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_or(operands[0].as_const(), operands[1].as_const(), false, false, -1);
                }
                break;
            case vpiBitXorOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_xor(operands[0].as_const(), operands[1].as_const(), false, false, -1);
                }
                break;
            case vpiBitNegOp:
                if (operands.size() == 1) {
                    result = RTLIL::const_not(operands[0].as_const(), RTLIL::Const(), false, false, -1);
                }
                break;
            case vpiUnaryAndOp:
                if (operands.size() == 1) {
                    result = operands[0].as_const().is_fully_ones() ? RTLIL::Const(1, 1) : RTLIL::Const(0, 1);
                }
                break;
            case vpiUnaryOrOp:
                if (operands.size() == 1) {
                    result = operands[0].as_const().is_fully_zero() ? RTLIL::Const(0, 1) : RTLIL::Const(1, 1);
                }
                break;
            case vpiUnaryXorOp:
                if (operands.size() == 1) {
                    int popcount = 0;
                    RTLIL::Const op_const = operands[0].as_const();
                    for (auto bit : op_const)
                        if (bit == RTLIL::State::S1) popcount++;
                    result = RTLIL::Const(popcount & 1, 1);
                }
                break;
            case vpiEqOp:
                if (operands.size() == 2) {
                    result = operands[0].as_const() == operands[1].as_const() ? RTLIL::Const(1, 1) : RTLIL::Const(0, 1);
                }
                break;
            case vpiNeqOp:
                if (operands.size() == 2) {
                    result = operands[0].as_const() != operands[1].as_const() ? RTLIL::Const(1, 1) : RTLIL::Const(0, 1);
                }
                break;
            case vpiLtOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_lt(operands[0].as_const(), operands[1].as_const(), false, false, 1);
                }
                break;
            case vpiLeOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_le(operands[0].as_const(), operands[1].as_const(), false, false, 1);
                }
                break;
            case vpiGtOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_gt(operands[0].as_const(), operands[1].as_const(), false, false, 1);
                }
                break;
            case vpiGeOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_ge(operands[0].as_const(), operands[1].as_const(), false, false, 1);
                }
                break;
            case vpiMultiConcatOp:
                if (operands.size() == 2) {
                    int rep_count = operands[0].as_const().as_int();
                    RTLIL::Const inner = operands[1].as_const();
                    RTLIL::Const rep_result;
                    for (int i = 0; i < rep_count; i++) {
                        rep_result.append(inner);
                    }
                    result = rep_result;
                }
                break;
            case vpiConcatOp:
                if (operands.size() >= 1) {
                    RTLIL::Const concat_result;
                    for (int i = operands.size() - 1; i >= 0; i--) {
                        RTLIL::Const op_const = operands[i].as_const();
                        concat_result.append(op_const);
                    }
                    result = concat_result;
                }
                break;
            default:
                can_evaluate = false;
                break;
        }
        
        if (can_evaluate && result.size() > 0) {
            if (mode_debug) {
                log("    Evaluated constant operation type %d to value %s\n", op_type, result.as_string().c_str());
            }
            return RTLIL::SigSpec(result);
        }
    }
    
    switch (op_type) {
        case vpiPlusOp:
            // Unary plus is a value no-op, but it must PRESERVE the operand's
            // signedness so a wider assignment context sign-extends a signed
            // operand (`y[7:0] = +s1`, s1 signed[3:0] = -1 -> 0xFF).  It was
            // unhandled and fell through to the default below, which returned
            // an empty SigSpec — `+s1` produced 0/x instead of the value
            // (operators test mode 68, caught by the SAT miter, NOT equiv_induct).
            if (operands.size() == 1)
                return operands[0];
            break;
        case vpiMinusOp:
            // Unary minus operation
            if (operands.size() == 1) {
                log_debug("UHDM: Found vpiMinusOp (unary minus) with operand size %d\n", operands[0].size());
                if (operands[0].size() == 0) {
                    log_warning("vpiMinusOp has empty operand!\n");
                    return RTLIL::SigSpec();
                }
                // Negate at the CONTEXT width (SV context-determined sizing):
                // the operand is extended to the result width FIRST, then
                // negated — `y[7:0] = -u1` (u1 unsigned[3:0]=5) is 0-extend to
                // 0x05 then negate = 0xFB, NOT the 4-bit negate 0x0B zero-
                // extended (operators mode 65).  A_SIGNED follows the operand's
                // own signedness so the extension is sign- vs zero-correct (a
                // signed operand / `$signed(...)` wrapper sign-extends).
                int result_width = expression_context_width > 0 ? expression_context_width : operands[0].size();
                bool is_signed = operands[0].is_wire() && operands[0].as_wire()->is_signed;
                RTLIL::Wire* result_wire = module->addWire(NEW_ID, result_width);
                // Unary minus follows the operand's signedness (SV LRM §11.4.3);
                // flag the result so any further widening sign-extends correctly.
                result_wire->is_signed = is_signed;
                RTLIL::SigSpec result(result_wire);

                std::string cell_name = generate_cell_name(uhdm_op, "neg");
                auto c = module->addNeg(RTLIL::escape_id(cell_name), operands[0], result, is_signed);
                add_src_attribute(c->attributes, uhdm_op);
                return result;
            }
            break;
        case vpiNotOp:
            if (operands.size() == 1) {
                // Create a logic_not cell with unique naming using counter
                std::string op_src = get_src_attribute(uhdm_op);
                logic_not_counter++;
                std::string cell_name_str;
                if (!op_src.empty()) {
                    cell_name_str = "$logic_not$" + op_src;
                    std::string gen_scope = get_current_gen_scope();
                    if (!gen_scope.empty()) {
                        cell_name_str += "$" + gen_scope;
                    }
                    cell_name_str += "$" + std::to_string(logic_not_counter);
                } else {
                    cell_name_str = "$logic_not$auto";
                    std::string gen_scope = get_current_gen_scope();
                    if (!gen_scope.empty()) {
                        cell_name_str += "$" + gen_scope;
                    }
                    cell_name_str += "$" + std::to_string(logic_not_counter);
                }
                
                log("UHDM: import_operation creating logic_not cell with name: %s (gen_scope=%s)\n", 
                    cell_name_str.c_str(), get_current_gen_scope().c_str());
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
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "logic_and");
                    return module->LogicAnd(RTLIL::escape_id(cell_name), operands[0], operands[1]);
                }
            break;
        case vpiLogOrOp:
            if (operands.size() == 2)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "logic_or");
                    return module->LogicOr(RTLIL::escape_id(cell_name), operands[0], operands[1]);
                }
            break;
        case vpiBitAndOp:
            if (operands.size() == 2)
                {
                    bool is_signed = check_operands_signed(operands) && !ctx_unsigned_entry;
                    std::string cell_name = generate_cell_name(uhdm_op, "and");
                    RTLIL::SigSpec result = module->And(RTLIL::escape_id(cell_name), operands[0], operands[1], is_signed);
                    if (auto c = module->cell(RTLIL::escape_id(cell_name)))
                        add_src_attribute(c->attributes, uhdm_op);
                    if (is_signed) mark_result_signed(result);
                    return result;
                }
            break;
        case vpiBitOrOp:
            if (operands.size() == 2)
                {
                    bool is_signed = check_operands_signed(operands) && !ctx_unsigned_entry;
                    std::string cell_name = generate_cell_name(uhdm_op, "or");
                    RTLIL::SigSpec result = module->Or(RTLIL::escape_id(cell_name), operands[0], operands[1], is_signed);
                    if (auto c = module->cell(RTLIL::escape_id(cell_name)))
                        add_src_attribute(c->attributes, uhdm_op);
                    if (is_signed) mark_result_signed(result);
                    return result;
                }
            break;
        case vpiBitXorOp:
            if (operands.size() == 2)
                {
                    bool is_signed = check_operands_signed(operands) && !ctx_unsigned_entry;
                    std::string cell_name = generate_cell_name(uhdm_op, "xor");
                    RTLIL::SigSpec result = module->Xor(RTLIL::escape_id(cell_name), operands[0], operands[1], is_signed);
                    if (auto c = module->cell(RTLIL::escape_id(cell_name)))
                        add_src_attribute(c->attributes, uhdm_op);
                    if (is_signed) mark_result_signed(result);
                    return result;
                }
            break;
        case vpiBitNegOp:
            if (operands.size() == 1)
                {
                    // SV LRM §11.8 context-determined sizing: a bitwise
                    // unary `~` inherits its width from the enclosing
                    // context, so its operand must be extended to that
                    // context width BEFORE the NOT is applied.  Without
                    // this, `reg1 & ~a[0]` (reg1=8b, a[0]=1b) yielded a
                    // 1-bit `$not` whose result was zero-extended for
                    // the AND — masking everything but bit 0.  The
                    // Yosys Verilog frontend extends a[0] to 8 bits
                    // inside the NOT so `~a[0]` is `8'b1111_111X̄`,
                    // masking only bit 0.
                    bool is_signed = check_operands_signed(operands) && !ctx_unsigned_entry;
                    RTLIL::SigSpec op = operands[0];
                    if (expression_context_width > op.size()) {
                        op.extend_u0(expression_context_width, is_signed);
                    }
                    std::string cell_name = generate_cell_name(uhdm_op, "not");
                    RTLIL::SigSpec result = module->Not(RTLIL::escape_id(cell_name), op, is_signed);
                    if (auto c = module->cell(RTLIL::escape_id(cell_name)))
                        add_src_attribute(c->attributes, uhdm_op);
                    if (is_signed) mark_result_signed(result);
                    return result;
                }
            break;
        case vpiBitXNorOp:  // Both vpiBitXNorOp and vpiBitXnorOp are the same
            if (operands.size() == 2)
                {
                    bool is_signed = check_operands_signed(operands) && !ctx_unsigned_entry;
                    std::string cell_name = generate_cell_name(uhdm_op, "xnor");
                    RTLIL::SigSpec result = module->Xnor(RTLIL::escape_id(cell_name), operands[0], operands[1], is_signed);
                    if (auto c = module->cell(RTLIL::escape_id(cell_name)))
                        add_src_attribute(c->attributes, uhdm_op);
                    if (is_signed) mark_result_signed(result);
                    return result;
                }
            break;
        case vpiUnaryAndOp:
            if (operands.size() == 1)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "reduce_and");
                    return module->ReduceAnd(RTLIL::escape_id(cell_name), operands[0]);
                }
            break;
        case vpiUnaryOrOp:
            if (operands.size() == 1)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "reduce_or");
                    return module->ReduceOr(RTLIL::escape_id(cell_name), operands[0]);
                }
            break;
        case vpiUnaryXorOp:
            if (operands.size() == 1)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "reduce_xor");
                    return module->ReduceXor(RTLIL::escape_id(cell_name), operands[0]);
                }
            break;
        case vpiUnaryNandOp:
            if (operands.size() == 1) {
                // Unary NAND is NOT(REDUCE_AND)
                std::string and_cell_name = generate_cell_name(uhdm_op, "reduce_and");
                RTLIL::SigSpec and_result = module->ReduceAnd(RTLIL::escape_id(and_cell_name), operands[0]);
                std::string not_cell_name = generate_cell_name(uhdm_op, "not");
                return module->Not(RTLIL::escape_id(not_cell_name), and_result);
            } else if (operands.size() == 2) {
                // Binary NAND (when UHDM uses unary op for binary ~&)
                std::string and_cell_name = generate_cell_name(uhdm_op, "and");
                RTLIL::SigSpec and_result = module->And(RTLIL::escape_id(and_cell_name), operands[0], operands[1]);
                std::string not_cell_name = generate_cell_name(uhdm_op, "not");
                return module->Not(RTLIL::escape_id(not_cell_name), and_result);
            }
            break;
        case vpiUnaryNorOp:
            if (operands.size() == 1) {
                // Unary NOR is NOT(REDUCE_OR)
                std::string or_cell_name = generate_cell_name(uhdm_op, "reduce_or");
                RTLIL::SigSpec or_result = module->ReduceOr(RTLIL::escape_id(or_cell_name), operands[0]);
                std::string not_cell_name = generate_cell_name(uhdm_op, "not");
                return module->Not(RTLIL::escape_id(not_cell_name), or_result);
            } else if (operands.size() == 2) {
                // Binary NOR (when UHDM uses unary op for binary ~|)
                std::string or_cell_name = generate_cell_name(uhdm_op, "or");
                RTLIL::SigSpec or_result = module->Or(RTLIL::escape_id(or_cell_name), operands[0], operands[1]);
                std::string not_cell_name = generate_cell_name(uhdm_op, "not");
                return module->Not(RTLIL::escape_id(not_cell_name), or_result);
            }
            break;
        case vpiUnaryXNorOp:
            if (operands.size() == 1) {
                // Unary XNOR is NOT(REDUCE_XOR)
                std::string xor_cell_name = generate_cell_name(uhdm_op, "reduce_xor");
                RTLIL::SigSpec xor_result = module->ReduceXor(RTLIL::escape_id(xor_cell_name), operands[0]);
                std::string not_cell_name = generate_cell_name(uhdm_op, "not");
                return module->Not(RTLIL::escape_id(not_cell_name), xor_result);
            }
            break;
        case vpiAddOp:
            if (operands.size() == 2) {
                // For addition, create an add cell.  Per Verilog semantics in
                // an assignment context the result width is the LHS width.
                // Use that as the cap so a stray 64-bit constant operand
                // (Surelog emits unsized literals at width 64) doesn't blow
                // up the cell into a 64-bit add whose upper half then
                // pollutes the destination wire with X.
                int result_width = std::max(operands[0].size(), operands[1].size());
                if (expression_context_width > 0)
                    result_width = expression_context_width;
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);

                // SV LRM §11.8.1: when ANY operand is unsigned, the
                // entire expression — and therefore every operand's
                // extension — is unsigned.  The previous "any signed
                // wire → signed" rule was the opposite of the spec
                // and broke `signed_int + unsigned_concat` (e.g.
                // yosys/tests/simple/forloops.v `x = k + {a,b}`):
                // k was sign-extended to 4 bits but `{a,b}` (concat
                // — always unsigned per LRM) was also sign-extended,
                // turning the high bit `a` into the carry.
                // Now: signed only when EVERY operand is signed.
                // Non-wire operands (concats, slices, derived
                // SigSpecs) are unsigned unless they were tagged as
                // fully-const-signed.
                bool is_signed = true;
                for (const auto& operand : operands) {
                    bool op_signed = false;
                    if (operand.is_wire()) {
                        op_signed = operand.as_wire()->is_signed;
                    } else if (operand.is_fully_const()) {
                        op_signed = (operand.as_const().flags &
                                     RTLIL::CONST_FLAG_SIGNED) != 0;
                    }
                    if (!op_signed) { is_signed = false; break; }
                }
                // An unsigned context forces unsigned extension even when both
                // operands are signed — `(a+b) + 3'd0` (signedexpr): the inner
                // signed add is zero-extended, not sign-extended.
                if (ctx_unsigned_entry) is_signed = false;

                // Truncate / extend each operand to result_width so the
                // cell's A_WIDTH/B_WIDTH match Y_WIDTH cleanly.  Preserves
                // sign-extension for signed operands.
                auto resize_operand = [&](RTLIL::SigSpec op, bool op_unsigned) {
                    if (op.size() == result_width) return op;
                    if (op.size() > result_width)
                        return op.extract(0, result_width);
                    bool sgn = is_signed;
                    if (op.is_wire() && !op.as_wire()->is_signed) sgn = false;
                    // A concatenation/replication operand is always unsigned —
                    // zero-extend it even inside a signed add/subtract.
                    if (op_unsigned) sgn = false;
                    op.extend_u0(result_width, sgn);
                    return op;
                };
                RTLIL::SigSpec a = resize_operand(operands[0],
                    operand_is_unsigned.size() > 0 && operand_is_unsigned[0]);
                RTLIL::SigSpec b = resize_operand(operands[1],
                    operand_is_unsigned.size() > 1 && operand_is_unsigned[1]);

                std::string cell_name = generate_cell_name(uhdm_op, "add");
                auto c = module->addAdd(RTLIL::escape_id(cell_name), a, b, result, is_signed);
                add_src_attribute(c->attributes, uhdm_op);
                return result;
            }
            break;
        case vpiSubOp:
            if (operands.size() == 2) {
                // For subtraction, create a sub cell
                // Use context width from LHS if available (Verilog context-determined sizing)
                int result_width = std::max(operands[0].size(), operands[1].size());
                if (expression_context_width > result_width)
                    result_width = expression_context_width;
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);

                // SV §11.8.1: signed subtract only when BOTH operands are signed;
                // a mixed `u1 - s2` / `s1 - u2` is UNSIGNED (operands treated as
                // unsigned) — was wrongly signed (operators mode 45/46).
                bool is_signed = operands_all_signed(uhdm_op);

                // Extend each operand to result_width so the cell's
                // A_WIDTH / B_WIDTH match Y_WIDTH cleanly (matches the
                // vpiAddOp branch).  Without this, a wider LHS would
                // produce a sub cell with A/B at operand width and the
                // upper bits would be silently zero-padded — losing the
                // borrow when LHS > operand width (exposed by
                // `add_sub_bind_if`'s `result0[8:0] <= a0[7:0] - b0[7:0]`).
                auto resize_operand = [&](RTLIL::SigSpec op, bool op_unsigned) {
                    if (op.size() == result_width) return op;
                    if (op.size() > result_width)
                        return op.extract(0, result_width);
                    bool sgn = is_signed;
                    if (op.is_wire() && !op.as_wire()->is_signed) sgn = false;
                    // A concatenation/replication operand is always unsigned —
                    // zero-extend it even inside a signed add/subtract.
                    if (op_unsigned) sgn = false;
                    op.extend_u0(result_width, sgn);
                    return op;
                };
                RTLIL::SigSpec a = resize_operand(operands[0],
                    operand_is_unsigned.size() > 0 && operand_is_unsigned[0]);
                RTLIL::SigSpec b = resize_operand(operands[1],
                    operand_is_unsigned.size() > 1 && operand_is_unsigned[1]);

                std::string cell_name = generate_cell_name(uhdm_op, "sub");
                auto c = module->addSub(RTLIL::escape_id(cell_name), a, b, result, is_signed);
                add_src_attribute(c->attributes, uhdm_op);
                return result;
            }
            break;
        case vpiDivOp:
            if (operands.size() == 2) {
                // SV: signed division only when BOTH operands are signed; a
                // mixed `u1 / s2` is unsigned (operators mode 53/54).
                int result_width = expression_context_width > 0
                    ? std::max({operands[0].size(), expression_context_width})
                    : operands[0].size();
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);
                bool is_signed = operands_all_signed(uhdm_op);
                std::string cell_name = generate_cell_name(uhdm_op, "div");
                auto c = module->addDiv(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                add_src_attribute(c->attributes, uhdm_op);
                return result;
            }
            break;
        case vpiModOp:
            if (operands.size() == 2) {
                // Modulo had NO runtime handler — it fell through to the switch
                // default and returned an empty SigSpec, so `a % b` with variable
                // operands collapsed to 0 (operators modes 56-59).  Mirror the
                // division handler; signed only when BOTH operands are signed.
                int result_width = expression_context_width > 0
                    ? std::max({operands[0].size(), expression_context_width})
                    : operands[0].size();
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);
                bool is_signed = operands_all_signed(uhdm_op);
                std::string cell_name = generate_cell_name(uhdm_op, "mod");
                auto c = module->addMod(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                add_src_attribute(c->attributes, uhdm_op);
                return result;
            }
            break;
        case vpiMultOp:
            if (operands.size() == 2) {
                // SV §11.6.1: arithmetic result width = max(L, R, context).
                // Use the LHS context when known (cont_assign / sync mem
                // write propagate it); otherwise fall back to the sum of
                // operand widths to preserve full precision — needed when
                // the LHS is wider than max(L,R) but the context didn't
                // reach this path (e.g., M[0]<=rA*rB before mem-write
                // context propagation, or non-assignment expressions).
                int result_width;
                if (expression_context_width > 0) {
                    result_width = std::max(operands[0].size(), operands[1].size());
                    if (expression_context_width > result_width)
                        result_width = expression_context_width;
                } else {
                    result_width = operands[0].size() + operands[1].size();
                }
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);

                // SV §11.8.1: signed multiply only when BOTH operands are signed;
                // a mixed `u1 * s2` is UNSIGNED (operands treated as unsigned) —
                // was wrongly signed (operators mode 49/50: 0xe7 vs 0x37).
                bool is_signed = operands_all_signed(uhdm_op);

                std::string cell_name = generate_cell_name(uhdm_op, "mul");
                auto c = module->addMul(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                add_src_attribute(c->attributes, uhdm_op);
                return result;
            }
            break;
        case vpiPowerOp:
            if (operands.size() == 2) {
                // Power operation: base ** exponent.  Result width is the
                // context width (SV context-determined sizing) — using the bare
                // base width truncated `4'd2 ** u1` (= 2**5 = 32) to 4 bits = 0
                // before it reached the 8-bit LHS (operators modes 60/62).
                int result_width = expression_context_width > 0 ? expression_context_width : operands[0].size();
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);

                // $pow signedness follows the base operand (the exponent only
                // scales it); a signed base sign-extends.
                bool is_signed = operands[0].is_wire() && operands[0].as_wire()->is_signed;

                // Use Pow cell for power operation
                std::string cell_name = generate_cell_name(uhdm_op, "pow");
                auto c = module->addPow(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                add_src_attribute(c->attributes, uhdm_op);
                return result;
            }
            break;
        // `<<<` (arithmetic left shift) is identical to `<<` for synthesis
        // (no sign extension on a left shift).
        case vpiArithLShiftOp:
        case vpiLShiftOp:
            if (operands.size() == 2) {
                // Left shift operation: a << b
                // Result width: use context width if set (avoids clipping bits for e.g. offset = idx << 2),
                // otherwise fall back to the operand width (self-determined Verilog semantics).
                int result_width = expression_context_width > 0 ? expression_context_width : operands[0].size();
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);
                
                // Check if operands are signed
                bool is_signed = false;
                if (operands[0].is_wire()) {
                    RTLIL::Wire* wire = operands[0].as_wire();
                    if (wire && wire->is_signed) {
                        is_signed = true;
                    }
                }
                
                // Use Shl cell for left shift operation
                std::string cell_name = generate_cell_name(uhdm_op, "shl");
                auto c = module->addShl(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                add_src_attribute(c->attributes, uhdm_op);
                return result;
            }
            break;
        // `>>>` (arithmetic right shift): sign-extends when the left operand
        // is signed (the $signed() wrapper marks its result wire), else
        // behaves like `>>`.  vpiArithRShiftOp (42) was previously unhandled
        // and fell through to a 0 result, so `$signed(x) >>> n` became 0
        // (picorv32 SRAI/SRA produced 0).  Shares the vpiRShiftOp handler,
        // which already selects $sshr vs $shr from operand signedness.
        case vpiArithRShiftOp:
        case vpiRShiftOp:
            if (operands.size() == 2) {
                // Right shift operation: a >> b
                // Result width: use the context width when set (SV
                // context-determined sizing), so the shift cell widens the
                // shifted operand to the LHS width and the signed `$sshr`
                // SIGN-extends it (and `$shr` zero-extends) internally —
                // matching the Verilog frontend, which emits Y_WIDTH = context.
                // Using the bare operand width left e.g. `y[7:0] <= s1 >>> u2`
                // (s1 signed[3:0]) as a 4-bit $sshr that was then ZERO-extended
                // to 8 bits at the assignment, dropping the sign (operators
                // test: y rtl=0xf8 vs nl=0x08).
                int result_width = expression_context_width > 0 ? expression_context_width : operands[0].size();
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);
                
                // Check if the shifted (left) operand is signed.
                bool is_signed = operands[0].is_wire() && operands[0].as_wire()->is_signed;

                // Pick the cell by SHIFT KIND, not just signedness:
                //   `>>>` (arithmetic) of a SIGNED operand fills vacated bits
                //         with the sign bit  -> $sshr.
                //   `>>`  (logical) ALWAYS zero-fills                 -> $shr,
                //         but a signed operand is still sign-extended to the
                //         result width first (A_SIGNED=1) — matching Verilog
                //         (`s1 >> u2` => $shr A_SIGNED=1, Y_WIDTH=context).
                // Previously BOTH `>>` and `>>>` used $sshr for a signed
                // operand, so a logical `>>` of a signed value kept the sign
                // bits (operators modes 4-7: 0xff instead of 0x1f).
                if (op_type == vpiArithRShiftOp && is_signed) {
                    std::string cell_name = generate_cell_name(uhdm_op, "sshr");
                    auto c = module->addSshr(RTLIL::escape_id(cell_name), operands[0], operands[1], result, true);
                    add_src_attribute(c->attributes, uhdm_op);
                } else {
                    std::string cell_name = generate_cell_name(uhdm_op, "shr");
                    auto c = module->addShr(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                    add_src_attribute(c->attributes, uhdm_op);
                }
                return result;
            }
            break;
        case vpiEqOp:
            if (operands.size() == 2)
            {
                // Size-match operands: in SV, a signed constant compared with a
                // wider unsigned operand is sign-extended to the wider width.
                // Example: `logic [127:0] a == -1` → -1 sign-extends to 128'hFFFF...
                RTLIL::SigSpec lhs = operands[0];
                RTLIL::SigSpec rhs = operands[1];
                // Guard against zero-size operands (e.g. an unresolved
                // var_select on an unpacked array element returns an empty
                // SigSpec). Calling `.as_const().back()` on a zero-bit Const
                // dereferences past the bit-vector end and crashes.
                if (lhs.size() != rhs.size() && lhs.size() > 0 && rhs.size() > 0) {
                    if (rhs.is_fully_const() && rhs.size() < lhs.size()) {
                        // Narrow constant on RHS compared with wider LHS wire.
                        // Sign-extend if the constant's MSB is 1 (negative/signed value).
                        bool rhs_msb = rhs.as_const().back() == RTLIL::State::S1;
                        rhs.extend_u0(lhs.size(), rhs_msb);
                    } else if (lhs.is_fully_const() && lhs.size() < rhs.size()) {
                        bool lhs_msb = lhs.as_const().back() == RTLIL::State::S1;
                        lhs.extend_u0(rhs.size(), lhs_msb);
                    }
                }

                // Create output wire for the comparison with proper naming
                std::string wire_name = generate_cell_name(uhdm_op, "eq") + "_Y";
                RTLIL::Wire* result_wire = module->addWire(RTLIL::escape_id(wire_name), 1);
                add_src_attribute(result_wire->attributes, uhdm_op);

                // Create cell with source location-based name
                std::string cell_name = generate_cell_name(uhdm_op, "eq");

                RTLIL::Cell* eq_cell = module->addEq(RTLIL::escape_id(cell_name),
                    lhs, rhs, result_wire);
                add_src_attribute(eq_cell->attributes, uhdm_op);
                return result_wire;
            }
            break;
        case vpiCaseEqOp:
            // Case equality (===) - use $eqx which properly handles X and Z values
            if (operands.size() == 2)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "eqx");
                    return module->Eqx(RTLIL::escape_id(cell_name), operands[0], operands[1]);
                }
            break;
        case vpiNeqOp:
            if (operands.size() == 2)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "ne");
                    return module->Ne(RTLIL::escape_id(cell_name), operands[0], operands[1]);
                }
            break;
        case vpiLtOp:
        case vpiLeOp:
        case vpiGtOp:
        case vpiGeOp:
            if (operands.size() == 2)
                {
                    // SV: a relational comparison is SIGNED iff BOTH operands
                    // are signed (e.g. `$signed(a) < $signed(b)`).  The `$signed`
                    // wrapper marks its result wire is_signed; without this the
                    // cell defaulted to unsigned, so signed `<`/`>=` collapsed to
                    // the unsigned version (picorv32 alu_lts === alu_ltu → SLTI/
                    // SLT/BLT/BGE decoded wrong).
                    bool a_signed = operands[0].is_wire() && operands[0].as_wire()->is_signed;
                    bool b_signed = operands[1].is_wire() && operands[1].as_wire()->is_signed;
                    // A constant operand (e.g. a folded `2**(SIZEOUT-1)`) is not
                    // a wire, so its signedness can't come from is_signed; fall
                    // back to the UHDM expression type so `signed_reg >= 2**N`
                    // stays signed (Verilog: signed iff BOTH operands signed).
                    if (uhdm_op->Operands() && uhdm_op->Operands()->size() == 2) {
                        auto& uops = *uhdm_op->Operands();
                        if (!a_signed)
                            if (auto ae = any_cast<const expr*>(uops[0]))
                                a_signed = is_expr_signed(ae);
                        if (!b_signed)
                            if (auto be = any_cast<const expr*>(uops[1]))
                                b_signed = is_expr_signed(be);
                    }
                    bool cmp_signed = a_signed && b_signed;
                    const char* nm = op_type == vpiLtOp ? "lt" :
                                     op_type == vpiLeOp ? "le" :
                                     op_type == vpiGtOp ? "gt" : "ge";
                    std::string cell_name = generate_cell_name(uhdm_op, nm);
                    RTLIL::IdString cid = RTLIL::escape_id(cell_name);
                    switch (op_type) {
                        case vpiLtOp: return module->Lt(cid, operands[0], operands[1], cmp_signed);
                        case vpiLeOp: return module->Le(cid, operands[0], operands[1], cmp_signed);
                        case vpiGtOp: return module->Gt(cid, operands[0], operands[1], cmp_signed);
                        default:      return module->Ge(cid, operands[0], operands[1], cmp_signed);
                    }
                }
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

                // SV §11.8.1: a conditional `?:` is signed only when BOTH
                // result branches are signed; a mixed `c ? s1 : u2` is UNSIGNED,
                // so its branches zero-extend (operators mode 82: 0x09 not the
                // sign-extended 0xf9).  Operand signedness comes from the UHDM
                // expressions (is_expr_signed) — `check_operands_signed`
                // returned true if EITHER branch was signed (wrong here).
                bool is_signed = false;
                if (uhdm_op->Operands() && uhdm_op->Operands()->size() == 3) {
                    auto& uops = *uhdm_op->Operands();
                    auto te = any_cast<const expr*>(uops[1]);
                    auto fe = any_cast<const expr*>(uops[2]);
                    is_signed = te && fe && is_expr_signed(te) && is_expr_signed(fe);
                }

                // Ensure the condition is 1-bit
                RTLIL::SigSpec cond = operands[0];
                if (cond.size() > 1) {
                    log("UHDM: Reducing %d-bit condition to 1-bit\n", cond.size());
                    // Reduce multi-bit condition to single bit using ReduceBool
                    std::string cell_name = generate_cell_name(uhdm_op, "reduce_bool");
                    cond = module->ReduceBool(RTLIL::escape_id(cell_name), cond);
                }

                // Match operand widths for the mux output
                int max_width = std::max(operands[1].size(), operands[2].size());
                RTLIL::SigSpec true_val = operands[1];
                RTLIL::SigSpec false_val = operands[2];

                // Extend operands to match widths if needed
                // Use sign-extension when operands are signed
                if (true_val.size() < max_width) {
                    true_val = RTLIL::SigSpec(true_val);
                    true_val.extend_u0(max_width, is_signed);
                }
                if (false_val.size() < max_width) {
                    false_val = RTLIL::SigSpec(false_val);
                    false_val.extend_u0(max_width, is_signed);
                }

                log("UHDM: Creating Mux with selector size=%d, true_val size=%d, false_val size=%d, signed=%d\n",
                    cond.size(), true_val.size(), false_val.size(), is_signed);

                // Mux signature: Mux(name, sig_a, sig_b, sig_s)
                // sig_a = value when selector is 0 (false value)
                // sig_b = value when selector is 1 (true value)
                // sig_s = selector
                std::string cell_name = generate_cell_name(uhdm_op, "mux");
                RTLIL::SigSpec result = module->Mux(RTLIL::escape_id(cell_name), false_val, true_val, cond);
                if (is_signed) mark_result_signed(result);
                return result;
            }
            break;
        case vpiConcatOp:
            // Concatenation operation {a, b, c}
            {
                log_debug("UHDM: Processing vpiConcatOp with %d operands\n", (int)operands.size());
                RTLIL::SigSpec result;
                // In SystemVerilog concatenation, the leftmost item appears in the MSBs
                // So we need to reverse the order when building the result
                for (int i = operands.size() - 1; i >= 0; i--) {
                    if (operands[i].size() == 0) {
                        log_warning("Empty operand in concatenation at position %d\n", i);
                    }
                    result.append(operands[i]);
                }
                log_debug("UHDM: Concatenation result size: %d\n", result.size());
                return result;
            }
            break;
        case vpiMultiConcatOp:
            // Repeated concatenation {count{expr}}
            {
                if (operands.size() == 2) {
                    // First operand is the replication count (must be constant)
                    if (!operands[0].is_fully_const()) {
                        log_warning("Non-constant replication count in multi-concat\n");
                        return RTLIL::SigSpec();
                    }
                    int rep_count = operands[0].as_const().as_int();
                    log_debug("UHDM: Processing vpiMultiConcatOp: replicating %d-bit signal %d times\n",
                              operands[1].size(), rep_count);
                    if (rep_count <= 0) {
                        log_warning("Invalid replication count %d in multi-concat\n", rep_count);
                        return RTLIL::SigSpec();
                    }
                    RTLIL::SigSpec result;
                    for (int i = 0; i < rep_count; i++) {
                        result.append(operands[1]);
                    }
                    log_debug("UHDM: Multi-concat result size: %d\n", result.size());
                    return result;
                }
                log_warning("vpiMultiConcatOp: expected 2 operands, got %d\n", (int)operands.size());
                return RTLIL::SigSpec();
            }
            break;
        case vpiStreamRLOp:
        case vpiStreamLROp:
            // Stream operators `{<<{...}}` (right-to-left) and
            // `{>>{...}}` (left-to-right).  Surelog represents the
            // streamed value as a single `vpiConcatOp` operand
            // (`{<<{val}}` → streamRL(concat(val))); on the LHS of an
            // assignment these can also unpack into multiple targets,
            // but that's not what jeras/UHDM-tests' `test_reverse.sv`
            // uses, so we only handle the RHS / value form here.
            //
            // Slice size (e.g. `{<<8{val}}`) lives in `uhdm_op->Typespec()`
            // when set; an absent slice size means "1 bit".
            {
                if (operands.empty()) {
                    log_warning("Stream op with no operand\n");
                    return RTLIL::SigSpec();
                }
                // The single operand is already the flattened source
                // value (the inner concat collapses to one SigSpec).
                RTLIL::SigSpec src = operands[0];
                int n = src.size();
                int slice_w = 1;
                if (uhdm_op->Typespec()) {
                    if (auto ats = uhdm_op->Typespec()->Actual_typespec())
                        slice_w = std::max(1, get_width_from_typespec(ats, inst));
                }
                // `{>>{val}}` with no slice size is a no-op identity;
                // with a slice size it groups into `slice_w` chunks
                // (still in source order — see LRM §11.4.14.2).
                if (op_type == vpiStreamLROp && slice_w == 1)
                    return src;
                // Build the result from `slice_w`-wide chunks of `src`,
                // emitted in reverse chunk order for `<<` (and in
                // source order for `>>` with slice_w > 1).  Any leftover
                // bits at the high end of `src` keep their position
                // (LRM: "Source bits that are not part of any slice are
                // ignored" — actually they are *appended unchanged* at
                // the top of the result; replicate that).
                int num_full = n / slice_w;
                int leftover = n - num_full * slice_w;
                RTLIL::SigSpec result;
                if (op_type == vpiStreamRLOp) {
                    // Reverse-order chunks: chunk[0] becomes the HIGHEST chunk.
                    // SigSpec.append appends at the MSB-end by convention here
                    // (see vpiConcatOp above which iterates in reverse to put
                    // the first operand at the top).  We want chunk[0]
                    // (low-order in source) to end up at the top.
                    // Iterate i from 0..num_full-1 and prepend.
                    for (int i = 0; i < num_full; i++) {
                        RTLIL::SigSpec chunk = src.extract(i * slice_w, slice_w);
                        // Build incrementally — earlier chunks land at
                        // higher positions, so append to the LSB side.
                        RTLIL::SigSpec next;
                        next.append(chunk);
                        next.append(result);
                        result = next;
                    }
                    // Leftover bits stay at their source MSB position.
                    if (leftover > 0)
                        result.append(src.extract(num_full * slice_w, leftover));
                } else {
                    // Source-order chunks (only matters when slice_w > 1).
                    for (int i = 0; i < num_full; i++)
                        result.append(src.extract(i * slice_w, slice_w));
                    if (leftover > 0)
                        result.append(src.extract(num_full * slice_w, leftover));
                }
                if (mode_debug)
                    log("    Stream op type=%d slice_w=%d n=%d "
                        "result_size=%d\n", op_type, slice_w, n, result.size());
                return result;
            }
            break;
        case vpiCastOp:
            // SV size/type cast: N'(expr), byte'(expr), int'(expr),
            // typename'(expr), etc.  Width comes from the cast's typespec;
            // signedness for extension comes from the *operand* (per LRM,
            // the cast type signedness sets the result type signedness, but
            // the bit-pattern conversion sign-extends only if the source is
            // signed; otherwise zero-extends).
            log("    Processing cast operation\n");
            if (operands.size() == 1) {
                int target_width = 0;
                bool target_signed = false;
                if (uhdm_op->Typespec()) {
                    const ref_typespec* ref_ts = uhdm_op->Typespec();
                    const typespec* ts = ref_ts ? ref_ts->Actual_typespec() : nullptr;
                    if (ts) {
                        // For literal-width casts (e.g. 3'(...)), Surelog
                        // stores the width as the VpiValue of an
                        // integer_typespec.  For parameterized casts (e.g.
                        // `WIDTH'(...)` with `parameter int WIDTH = 16`),
                        // Surelog elaborates the typespec to an int_typespec
                        // whose VpiName is the parameter name and VpiValue
                        // is the resolved constant ("UINT:16") — handle both.
                        // Track whether this is a size cast (`N'(...)`,
                        // `WIDTH'(...)`) vs a type cast (`byte'(...)`,
                        // `int'(...)`, etc.). Per SV LRM §6.24.1, size
                        // casts preserve the OPERAND's signedness; type
                        // casts take the cast TYPE's signedness.
                        bool is_size_cast = false;
                        if (ts->VpiType() == vpiIntegerTypespec) {
                            const integer_typespec* its = any_cast<const integer_typespec*>(ts);
                            std::string val_str = std::string(its->VpiValue());
                            if (!val_str.empty()) {
                                RTLIL::Const width_const = extract_const_from_value(val_str);
                                if (width_const.size() > 0) {
                                    target_width = width_const.as_int();
                                    is_size_cast = true;
                                }
                            }
                        } else if (ts->VpiType() == vpiIntTypespec) {
                            // For a parameterized size cast `WIDTH'(...)`,
                            // Surelog elaborates the typespec to an
                            // `int_typespec` whose VpiName is the parameter
                            // identifier and VpiValue is the resolved
                            // constant ("UINT:16").  Only consume VpiValue
                            // when VpiName is non-empty so we don't
                            // accidentally reinterpret a literal LRM
                            // `int'(...)` cast (which has empty VpiName and
                            // means a 32-bit cast — handled by the
                            // `get_width_from_typespec` fallthrough below).
                            const int_typespec* its = any_cast<const int_typespec*>(ts);
                            if (!its->VpiName().empty()) {
                                std::string val_str = std::string(its->VpiValue());
                                if (!val_str.empty()) {
                                    RTLIL::Const width_const =
                                        extract_const_from_value(val_str);
                                    if (width_const.size() > 0) {
                                        target_width = width_const.as_int();
                                        is_size_cast = true;
                                    }
                                }
                            }
                        }
                        // Otherwise compute the width from the type itself
                        // (byte/int/short/long/typedef/struct/logic).
                        if (target_width <= 0) {
                            int w = get_width_from_typespec(ts, current_instance);
                            if (w > 0) target_width = w;
                        }
                        target_signed = is_typespec_signed(ts);
                        // Size casts: preserve OPERAND signedness (LRM
                        // §6.24.1). The cast typespec for `N'(...)` is an
                        // unsigned integer_typespec describing only the
                        // width, so reading is_typespec_signed on it would
                        // give the wrong answer for `4'(signed_expr)`.
                        if (is_size_cast && uhdm_op->Operands() && !uhdm_op->Operands()->empty()) {
                            if (auto src_e = any_cast<const expr*>(uhdm_op->Operands()->at(0)))
                                target_signed = is_expr_signed(src_e);
                        }
                    }
                }

                if (target_width > 0) {
                    RTLIL::SigSpec operand = operands[0];

                    // Determine source signedness from the UHDM expression
                    // (handles ref/const/$signed/$unsigned/nested-cast cases).
                    // We deliberately don't fall back to the operand wire's
                    // is_signed flag here, because that would override an
                    // explicit `unsigned'(signed_wire)` cast — the wire is
                    // still signed but the value should be treated as
                    // unsigned for extension (static_cast_simple).
                    bool src_signed = false;
                    bool src_signed_known = false;
                    if (uhdm_op->Operands() && !uhdm_op->Operands()->empty()) {
                        if (auto src_e = any_cast<const expr*>(uhdm_op->Operands()->at(0))) {
                            src_signed = is_expr_signed(src_e);
                            // We always trust is_expr_signed when the operand
                            // is a $signed/$unsigned/cast (those carry an
                            // explicit signedness override).
                            if (src_e->VpiType() == vpiSysFuncCall) {
                                auto sfc = any_cast<const sys_func_call*>(src_e);
                                if (sfc && (sfc->VpiName() == "$signed" ||
                                            sfc->VpiName() == "$unsigned"))
                                    src_signed_known = true;
                            } else if (src_e->VpiType() == vpiOperation) {
                                auto op = any_cast<const operation*>(src_e);
                                if (op && op->VpiOpType() == vpiCastOp)
                                    src_signed_known = true;
                            }
                        }
                    }
                    if (!src_signed_known && !src_signed && operand.is_wire())
                        src_signed = operand.as_wire()->is_signed;

                    if (operand.is_fully_const()) {
                        RTLIL::Const const_val = operand.as_const();
                        if (const_val.size() < target_width) {
                            // Special-case constants whose bits are all one
                            // state — those represent fill literals (`'1`,
                            // `'0`, `'x`, `'z`) that should self-replicate.
                            bool all_x = true, all_z = true, all_0 = true, all_1 = true;
                            for (auto bit : const_val) {
                                if (bit != RTLIL::State::Sx) all_x = false;
                                if (bit != RTLIL::State::Sz) all_z = false;
                                if (bit != RTLIL::State::S0) all_0 = false;
                                if (bit != RTLIL::State::S1) all_1 = false;
                            }
                            RTLIL::State fill = RTLIL::State::S0;
                            if (all_x)      fill = RTLIL::State::Sx;
                            else if (all_z) fill = RTLIL::State::Sz;
                            else if (all_1) fill = RTLIL::State::S1;
                            else if (all_0) fill = RTLIL::State::S0;
                            else if (src_signed) fill = const_val.back();
                            const_val.resize(target_width, fill);
                        } else if (const_val.size() > target_width) {
                            const_val.resize(target_width, RTLIL::State::S0);
                        }
                        // Tag the result const with the cast's signedness
                        // so downstream consumers can pick the right
                        // sign-extension if needed.
                        if (target_signed) const_val.flags |= RTLIL::CONST_FLAG_SIGNED;
                        return RTLIL::SigSpec(const_val);
                    }

                    // Non-constant operand: emit `$pos` so synthesis correctly
                    // sign- or zero-extends.  Pass src_signed so the resulting
                    // cell sets A_SIGNED appropriately.
                    if (operand.size() == target_width)
                        return operand;
                    RTLIL::Wire* result_wire = module->addWire(NEW_ID, target_width);
                    result_wire->is_signed = target_signed;
                    add_src_attribute(result_wire->attributes, uhdm_op);
                    module->addPos(NEW_ID, operand, result_wire, src_signed);
                    return RTLIL::SigSpec(result_wire);
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

// Helper function to find wire in hierarchical generate scopes
RTLIL::Wire* UhdmImporter::find_wire_in_scope(const std::string& signal_name, const std::string& context_for_log) {
    // First try hierarchical lookup if we're in a generate scope
    std::string gen_scope = get_current_gen_scope();
    if (!gen_scope.empty()) {
        // Try the full hierarchical name
        std::string hierarchical_name = gen_scope + "." + signal_name;
        if (name_map.count(hierarchical_name)) {
            RTLIL::Wire* wire = name_map[hierarchical_name];
            if (!context_for_log.empty()) {
                log("UHDM: Found hierarchical wire %s for %s\n", hierarchical_name.c_str(), context_for_log.c_str());
            }
            return wire;
        }
        
        // If not found, try parent scopes
        for (int i = gen_scope_stack.size() - 1; i >= 0; i--) {
            std::string parent_path;
            for (int j = 0; j <= i; j++) {
                if (j > 0) parent_path += ".";
                parent_path += gen_scope_stack[j];
            }
            std::string parent_hierarchical = parent_path + "." + signal_name;
            if (name_map.count(parent_hierarchical)) {
                RTLIL::Wire* wire = name_map[parent_hierarchical];
                if (!context_for_log.empty()) {
                    log("UHDM: Found wire %s in parent scope %s for %s\n", 
                        signal_name.c_str(), parent_path.c_str(), context_for_log.c_str());
                }
                return wire;
            }
        }
    }
    
    // Try regular lookup in name_map
    if (name_map.count(signal_name)) {
        RTLIL::Wire* wire = name_map[signal_name];
        if (!context_for_log.empty()) {
            log("UHDM: Found wire %s in name_map for %s\n", signal_name.c_str(), context_for_log.c_str());
        }
        return wire;
    }
    
    // Finally, try with escaped name in module
    RTLIL::IdString wire_id = RTLIL::escape_id(signal_name);
    RTLIL::Wire* wire = module->wire(wire_id);
    if (wire && !context_for_log.empty()) {
        log("UHDM: Found wire %s via module->wire for %s\n", signal_name.c_str(), context_for_log.c_str());
    }
    
    return wire;
}

// Import reference to object
RTLIL::SigSpec UhdmImporter::import_ref_obj(const ref_obj* uhdm_ref, const UHDM::scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    // Get the referenced object name
    std::string ref_name = std::string(uhdm_ref->VpiName());
    
    if (mode_debug)
        log("    Importing ref_obj: %s (current_gen_scope: %s)\n", ref_name.c_str(), get_current_gen_scope().c_str());
    
    // Check if this is a function input parameter
    if (input_mapping) {
        auto it = input_mapping->find(ref_name);
        if (it != input_mapping->end()) {
            if (mode_debug)
                log("    Found %s in function input_mapping\n", ref_name.c_str());
            
            // Check if we have a constant value for this parameter
            FunctionCallContext* ctx = getCurrentFunctionContext();
            if (ctx && ctx->const_wire_values.count(ref_name)) {
                RTLIL::Const const_val = ctx->const_wire_values[ref_name];
                // Size the constant to the parameter's declared width.
                // Surelog stores integer literals at the platform default
                // (e.g. 64 bits) — using them raw inside a `{a, b}` concat
                // pollutes the result with phantom upper bits (operation4 in
                // various/const_arg_loop.sv passed `0` as a 1-bit `b` and
                // got 64 zero bits in front of `a`).
                int param_width = it->second.size();
                if (param_width > 0 &&
                    (int)const_val.size() != param_width) {
                    RTLIL::Const sized = const_val;
                    sized.resize(param_width, RTLIL::State::S0);
                    const_val = sized;
                }
                log("UHDM: Function parameter %s has constant value %s\n",
                    ref_name.c_str(), const_val.as_string().c_str());
                return RTLIL::SigSpec(const_val);
            }
            
            log("UHDM: Function parameter %s mapped to signal %s\n", 
                ref_name.c_str(), it->second.is_wire() ? 
                it->second.as_wire()->name.c_str() : "const/temp");
            return it->second;
        }
    }

    // In always_ff body mode, a blocking (`=`) temp that was already assigned
    // earlier in this evaluation must read its in-flight `$0\<sig>` value, not
    // the stale registered wire (e.g. `a = ctrl+1; ... case(a*b) ...` or
    // `current_pc = reg_next_pc; reg_pc <= current_pc;`).  ff_blocking_temps is
    // populated in program order during body processing and only holds
    // blocking targets, so registers (non-blocking `<=`) are unaffected and a
    // blocking accumulator's own RHS (`t = t+1`) still reads the old `\t`
    // because the map entry is added only after the assignment.
    if (in_always_ff_body_mode) {
        auto bt = ff_blocking_temps.find(ref_name);
        if (bt != ff_blocking_temps.end())
            return bt->second;
    }

    // Unrolled loop variable: substitute its current value.  This must run
    // BEFORE the Actual_group()/net resolution below, because a module-level
    // `integer k` resolves to its `\k` net there and would mask the loop
    // value (there is a second, now-redundant, loop_values check further down
    // that only caught locally-declared loop vars).  loop_values is non-empty
    // only while the owning block's loop body / post-loop tail is being
    // imported, so a bare `k` correctly reads the wire in unrelated blocks.
    // e.g. forloops01: `x <= k + {a,b}` in the always_ff must see k=2 (its
    // loop's final value), not the shared `\k` net the always_comb drives to 4.
    if (loop_values.count(ref_name))
        return RTLIL::SigSpec(RTLIL::Const(loop_values[ref_name], 32));

    // Check if the ref_obj has an Actual_group() that points to the real signal
    // This is used in generate blocks where ref_obj names include generate scope prefixes
    // but the Actual_group() points to the real module-level signal
    // Note: Actual_group() is also used for parameters, so check the type
    const any* actual_for_signal = uhdm_ref->Actual_group();
    if (actual_for_signal && actual_for_signal->UhdmType() == uhdmlogic_net) {
        const logic_net* net = any_cast<const logic_net*>(actual_for_signal);
        std::string actual_name = std::string(net->VpiName());
        if (mode_debug)
            log("    ref_obj has Actual_group() pointing to logic_net: %s\n", actual_name.c_str());
        
        // Check if this is a module output that was incorrectly prefixed with generate scope
        if (name_map.count(actual_name)) {
            if (mode_debug)
                log("    Using actual signal: %s\n", actual_name.c_str());
            return RTLIL::SigSpec(name_map[actual_name]);
        }
        
        // Try with escaped name
        RTLIL::IdString wire_id = RTLIL::escape_id(actual_name);
        if (module->wire(wire_id)) {
            if (mode_debug)
                log("    Found actual signal as module wire: %s\n", wire_id.c_str());
            return RTLIL::SigSpec(module->wire(wire_id));
        }
    }
    
    // Check if this is a loop variable that needs substitution
    if (loop_values.count(ref_name)) {
        int value = loop_values[ref_name];
        if (mode_debug)
            log("    Substituting loop variable %s with value %d\n", ref_name.c_str(), value);
        return RTLIL::SigSpec(RTLIL::Const(value, 32));
    }
    
    // Check if the ref_obj has an Actual_group() that points to a parameter or enum constant
    if (uhdm_ref->Actual_group()) {
        const any* actual = uhdm_ref->Actual_group();
        
        // Check for enum constant
        if (actual->UhdmType() == uhdmenum_const) {
            const UHDM::enum_const* enum_val = any_cast<const UHDM::enum_const*>(actual);
            // Get the enum value - enum constants store their value in VpiValue
            std::string val_str = std::string(enum_val->VpiValue());
            
            if (mode_debug)
                log("UHDM: Found enum constant %s with value %s\n", ref_name.c_str(), val_str.c_str());
            
            // Parse value from format like "INT:0", "UINT:1", "HEX:BB", etc.
            RTLIL::Const enum_value;
            if (!val_str.empty()) {
                int width = enum_val->VpiSize() > 0 ? enum_val->VpiSize() : 32;
                int int_val = parse_vpi_value_to_int(val_str);
                enum_value = RTLIL::Const(int_val, width);
            } else {
                // Default to 0 if no value specified
                enum_value = RTLIL::Const(0, 32);
            }
            
            return RTLIL::SigSpec(enum_value);
        }
        
        if (actual->VpiType() == vpiParameter) {
            const parameter* param = any_cast<const parameter*>(actual);
            std::string param_name = std::string(param->VpiName());

            // For parameterized modules, prefer the module's actual parameter value
            // over the base module's VpiValue (which may be the unelaborated default)
            RTLIL::Const param_value;
            RTLIL::IdString p_id = RTLIL::escape_id(param_name);
            if (module->parameter_default_values.count(p_id)) {
                param_value = module->parameter_default_values.at(p_id);
                if (mode_debug)
                    log("UHDM: Using module parameter %s value %s (overrides base VpiValue)\n",
                        param_name.c_str(), param_value.as_string().c_str());
            } else {
                // Fall back to VpiValue from the UHDM parameter object
                std::string val_str = std::string(param->VpiValue());

                // Determine the parameter's actual width and signedness from its typespec.
                // This is critical for types like shortint (16-bit), byte (8-bit), etc.
                // Without this, INT:-1 would always produce a 32-bit constant.
                int param_width = 32; // default
                bool param_signed = false;
                if (param->Typespec()) {
                    const UHDM::typespec* actual_ts = param->Typespec()->Actual_typespec();
                    if (actual_ts) {
                        int tw = get_width_from_typespec(actual_ts, current_instance);
                        if (tw > 0) param_width = tw;
                        // Check signedness from typespec
                        switch (actual_ts->UhdmType()) {
                            case uhdminteger_typespec: {
                                auto its = any_cast<const integer_typespec*>(actual_ts);
                                if (its) { param_signed = its->VpiSigned(); } break;
                            }
                            case uhdmint_typespec: {
                                auto its = any_cast<const int_typespec*>(actual_ts);
                                if (its) { param_signed = its->VpiSigned(); } break;
                            }
                            case uhdmshort_int_typespec: {
                                auto its = any_cast<const short_int_typespec*>(actual_ts);
                                if (its) { param_signed = its->VpiSigned(); } break;
                            }
                            case uhdmlong_int_typespec: {
                                auto its = any_cast<const long_int_typespec*>(actual_ts);
                                if (its) { param_signed = its->VpiSigned(); } break;
                            }
                            case uhdmbyte_typespec: {
                                auto its = any_cast<const byte_typespec*>(actual_ts);
                                if (its) { param_signed = its->VpiSigned(); } break;
                            }
                            case uhdmlogic_typespec: {
                                auto lts = any_cast<const logic_typespec*>(actual_ts);
                                if (lts) { param_signed = lts->VpiSigned(); } break;
                            }
                            case uhdmbit_typespec: {
                                auto bts = any_cast<const bit_typespec*>(actual_ts);
                                if (bts) { param_signed = bts->VpiSigned(); } break;
                            }
                            default: break;
                        }
                    }
                }
                // Also fall back to param->VpiSigned() directly
                if (!param_signed && param->VpiSigned())
                    param_signed = true;

                // Parse value from format like "UINT:0", "UINT:1", "HEX:AA", "INT:-1", etc.
                if (!val_str.empty()) {
                    size_t colon_pos = val_str.find(':');
                    if (colon_pos != std::string::npos) {
                        std::string type_part = val_str.substr(0, colon_pos);
                        std::string value_part = val_str.substr(colon_pos + 1);

                        if (type_part == "HEX") {
                            try {
                                unsigned long long hex_val = std::stoull(value_part, nullptr, 16);
                                param_value = RTLIL::Const(hex_val, param_width);
                            } catch (...) {
                                param_value = RTLIL::Const::from_string(value_part);
                            }
                        } else if (type_part == "BIN") {
                            RTLIL::Const bin_const = RTLIL::Const::from_string(value_part);
                            if (bin_const.size() != param_width) {
                                RTLIL::SigSpec sig(bin_const);
                                sig.extend_u0(param_width, param_signed);
                                param_value = sig.as_const();
                            } else {
                                param_value = bin_const;
                            }
                        } else if (type_part == "UINT") {
                            try {
                                unsigned long long uint_val = std::stoull(value_part);
                                param_value = RTLIL::Const(uint_val, param_width);
                            } catch (...) {
                                param_value = RTLIL::Const(0, param_width);
                            }
                        } else {
                            // INT: or other numeric prefix — treat as signed long long
                            try {
                                long long int_val = std::stoll(value_part);
                                param_value = RTLIL::Const(int_val, param_width);
                            } catch (...) {
                                param_value = RTLIL::Const(0, param_width);
                            }
                        }
                    } else {
                        try {
                            long long int_val = std::stoll(val_str);
                            param_value = RTLIL::Const(int_val, param_width);
                        } catch (...) {
                            param_value = RTLIL::Const(0, param_width);
                        }
                    }
                } else {
                    // If no VpiValue, check if there's an expression
                    if (param->Expr()) {
                        RTLIL::SigSpec expr_val = import_expression(any_cast<const expr*>(param->Expr()));
                        if (expr_val.is_fully_const()) {
                            param_value = expr_val.as_const();
                        }
                    } else {
                        // For function-local localparams (e.g. localparam A = 32 - 1),
                        // Surelog stores the value expression in the parent param_assign's Rhs(),
                        // not in the parameter's VpiValue() or Expr().
                        const BaseClass* parent = param->VpiParent();
                        if (parent && parent->UhdmType() == uhdmparam_assign) {
                            const param_assign* pa = any_cast<const param_assign*>(parent);
                            if (pa && pa->Rhs()) {
                                RTLIL::SigSpec expr_val = import_expression(
                                    any_cast<const expr*>(pa->Rhs()));
                                if (expr_val.is_fully_const()) {
                                    param_value = expr_val.as_const();
                                }
                            }
                        }
                    }
                }
            }
            
            if (mode_debug)
                log("UHDM: ref_obj %s refers to parameter with value %s\n", 
                    ref_name.c_str(), param_value.as_string().c_str());
            return RTLIL::SigSpec(param_value);
        }
    }
    
    // Check if this is a parameter reference
    RTLIL::IdString param_id = RTLIL::escape_id(ref_name);
    if (module->parameter_default_values.count(param_id)) {
        RTLIL::Const param_value = module->parameter_default_values.at(param_id);
        if (mode_debug)
            log("UHDM: Found parameter %s with value %s (bits=%d)\n", 
                ref_name.c_str(), param_value.as_string().c_str(), param_value.size());
        return RTLIL::SigSpec(param_value);
    }
    
    // If we're in a generate scope, try hierarchical lookups
    std::string gen_scope = get_current_gen_scope();
    if (!gen_scope.empty()) {
        // First try the full hierarchical name
        std::string hierarchical_name = gen_scope + "." + ref_name;
        if (mode_debug)
            log("    Looking for hierarchical wire: %s (gen_scope=%s, ref=%s)\n", 
                hierarchical_name.c_str(), gen_scope.c_str(), ref_name.c_str());
        if (name_map.count(hierarchical_name)) {
            RTLIL::Wire* wire = name_map[hierarchical_name];
            log("UHDM: Found hierarchical wire %s in name_map\n", hierarchical_name.c_str());
            return RTLIL::SigSpec(wire);
        }
        
        // If not found, try parent scopes
        // For example, if we're in gen3[0].gen4[0] looking for tmp2,
        // we should also check gen3[0].tmp2
        for (int i = gen_scope_stack.size() - 1; i >= 0; i--) {
            std::string parent_path;
            for (int j = 0; j <= i; j++) {
                if (j > 0) parent_path += ".";
                parent_path += gen_scope_stack[j];
            }
            std::string parent_hierarchical = parent_path + "." + ref_name;
            if (name_map.count(parent_hierarchical)) {
                RTLIL::Wire* wire = name_map[parent_hierarchical];
                log("UHDM: Found wire %s in parent scope %s\n", ref_name.c_str(), parent_path.c_str());
                return RTLIL::SigSpec(wire);
            }
        }
        
        log("UHDM: In generate scope %s, wire %s not found in hierarchical lookup\n",
            gen_scope.c_str(), ref_name.c_str());
    }
    
    // Look up in name map with simple name
    if (name_map.count(ref_name)) {
        RTLIL::Wire* wire = name_map[ref_name];
        return RTLIL::SigSpec(wire);
    }
    
    // Check if wire exists in current module
    // Skip this check if we're in a generate scope to avoid finding global wires
    // when we should be using generate-local wires
    if (module && gen_scope.empty()) {
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
    
    // Check if this ref_obj points to a variable with an integer typespec via Actual_group()
    // The Actual_group() can point directly to an integer_var or other variable types
    if (uhdm_ref->Actual_group()) {
        const any* actual = uhdm_ref->Actual_group();
        
        // Check if the actual is an integer_var - these are always 32-bit
        if (actual->UhdmType() == uhdminteger_var) {
            log("Reference to integer variable '%s' via Actual_group() - creating 32-bit wire\n", ref_name.c_str());
            return create_wire(ref_name, 32);
        }
        
        // For other variable types, check their typespec
        const typespec* ts = nullptr;
        
        if (actual->UhdmType() == uhdmlogic_var) {
            const logic_var* log_var = any_cast<const logic_var*>(actual);
            if (log_var && log_var->Typespec() && log_var->Typespec()->Actual_typespec()) {
                ts = log_var->Typespec()->Actual_typespec();
            }
        } else if (actual->UhdmType() == uhdmvariables) {
            const variables* var = any_cast<const variables*>(actual);
            if (var && var->Typespec() && var->Typespec()->Actual_typespec()) {
                ts = var->Typespec()->Actual_typespec();
            }
        }
        
        // Check if the typespec is integer
        if (ts && ts->UhdmType() == uhdminteger_typespec) {
            log("Reference to variable with integer typespec '%s' - creating 32-bit wire\n", ref_name.c_str());
            return create_wire(ref_name, 32);
        }
    }
    
    // If not found, create a new wire
    // In generate scopes, use hierarchical naming
    std::string wire_name = ref_name;
    if (!gen_scope.empty()) {
        wire_name = gen_scope + "." + ref_name;
        log("Creating wire with hierarchical name: %s (in generate scope %s)\n", 
            wire_name.c_str(), gen_scope.c_str());
    }
    
    log_warning("Reference to unknown signal: %s\n", ref_name.c_str());
    RTLIL::SigSpec wire_sig = create_wire(wire_name, 1);
    
    // Add to name_map with both hierarchical and simple names for future lookups
    if (!gen_scope.empty() && module) {
        RTLIL::IdString wire_id = RTLIL::escape_id(wire_name);
        if (RTLIL::Wire* created_wire = module->wire(wire_id)) {
            name_map[wire_name] = created_wire;  // Hierarchical name
            // Don't map simple name to avoid conflicts with other generate instances
        }
    }
    
    return wire_sig;
}

// Import part select (e.g., sig[7:0])
RTLIL::SigSpec UhdmImporter::import_part_select(const part_select* uhdm_part, const UHDM::scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
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
        // If this is a for-loop variable, substitute its current constant value
        if (loop_values.count(base_signal_name)) {
            int lv = loop_values.at(base_signal_name);
            RTLIL::Wire* w = find_wire_in_scope(base_signal_name, "part select width");
            int bw = w ? w->width : 32;
            base = RTLIL::SigSpec(RTLIL::Const(lv, bw));
            log("      PartSelect: substituting loop var '%s' = %d\n", base_signal_name.c_str(), lv);
        } else {
        RTLIL::Wire* wire = find_wire_in_scope(base_signal_name, "part select");
        if (wire) {
            base = RTLIL::SigSpec(wire);
        } else {
            // Try as a parameter (e.g., OUTPUT[15:8] where OUTPUT is a parameter)
            RTLIL::IdString param_id = RTLIL::escape_id(base_signal_name);
            if (module->parameter_default_values.count(param_id)) {
                base = RTLIL::SigSpec(module->parameter_default_values.at(param_id));
                log("      Resolved '%s' as parameter for part select (width=%d)\n",
                    base_signal_name.c_str(), base.size());
            } else {
                std::string gen_scope = get_current_gen_scope();
                log_warning("Base signal '%s' not found in module or generate scope %s\n",
                    base_signal_name.c_str(), gen_scope.c_str());
                return RTLIL::SigSpec();
            }
        }
        } // end loop_values else
    } else {
        // If we can't get the name directly, try importing the parent as an expression
        base = import_expression(any_cast<const expr*>(parent), input_mapping);
    }

    // In always_ff body mode, a part-select of a BLOCKING temp assigned
    // earlier in this evaluation (e.g. `tmp = A-B; result <= tmp[7:0];`)
    // must read the in-flight `$0\tmp`, not the stale registered `\tmp` — the
    // same redirect import_ref_obj applies to whole-signal reads.  Without it
    // the read picks up the FF Q and the consumer gets an extra cycle of delay.
    if (in_always_ff_body_mode && !base_signal_name.empty()) {
        auto bt = ff_blocking_temps.find(base_signal_name);
        if (bt != ff_blocking_temps.end() && bt->second.size() == base.size())
            base = bt->second;
    }
    // The SSA always_ff path (ff_simple_eval) and always_comb thread same-cycle
    // blocking values through input_mapping rather than ff_blocking_temps; a
    // part-select of such a value must read the in-flight value too, mirroring
    // import_ref_obj's whole-signal substitution.  PR #291 redirected
    // whole-signal blocking-temp reads but missed part/bit-selects, so the
    // consumer read the registered wire and got an extra cycle of delay.
    if (input_mapping && !base_signal_name.empty()) {
        auto im = input_mapping->find(base_signal_name);
        if (im != input_mapping->end() && im->second.size() == base.size())
            base = im->second;
    }

    log("      Base signal width: %d\n", base.size());

    // Get range
    int left = -1, right = -1;
    if (auto left_expr = uhdm_part->Left_range()) {
        RTLIL::SigSpec left_sig = import_expression(left_expr, input_mapping);
        if (left_sig.is_fully_const())
            left = left_sig.as_const().as_int();
    }
    if (auto right_expr = uhdm_part->Right_range()) {
        RTLIL::SigSpec right_sig = import_expression(right_expr, input_mapping);
        if (right_sig.is_fully_const())
            right = right_sig.as_const().as_int();
    }
    
    if (left >= 0 && right >= 0) {
        int width = abs(left - right) + 1;
        int offset = std::min(left, right);
        
        // Bounds check to prevent out-of-bounds access
        int base_width = base.size();
        if (offset >= base_width) {
            // Completely out of bounds - return undefined
            log_warning("Part select [%d:%d] is out of bounds for signal of width %d, returning undefined\n", 
                       left, right, base_width);
            return RTLIL::SigSpec(RTLIL::State::Sx, width);
        }
        
        if (offset + width > base_width) {
            // Partially out of bounds - pad with undefined
            int valid_width = base_width - offset;
            RTLIL::SigSpec result = base.extract(offset, valid_width);
            result.append(RTLIL::SigSpec(RTLIL::State::Sx, width - valid_width));
            log_warning("Part select [%d:%d] partially out of bounds for signal of width %d\n", 
                       left, right, base_width);
            return result;
        }
        
        return base.extract(offset, width);
    }
    
    return base;
}

// Import bit select (e.g., sig[3])
RTLIL::SigSpec UhdmImporter::import_bit_select(const bit_select* uhdm_bit, const UHDM::scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    if (mode_debug)
        log("    Importing bit select\n");

    // Get the signal name directly from the bit_select
    std::string signal_name = std::string(uhdm_bit->VpiName());

    if (mode_debug)
        log("    Bit select signal name: '%s'\n", signal_name.c_str());

    // Function-parameter bit access: if the parameter has a constant
    // value tracked in the current FunctionCallContext, return the
    // constant bit so subsequent expressions can constant-fold.  This
    // makes `inp[0] = inp[0] ^ 1; result = num * inp;` evaluate the
    // XOR as a constant, so the bit-select LHS update can in turn
    // propagate the new value back into const_wire_values
    // (various/const_arg_loop.sv operation2).
    if (input_mapping && input_mapping->count(signal_name) && uhdm_bit->VpiIndex()) {
        FunctionCallContext* ctx = getCurrentFunctionContext();
        if (ctx && ctx->const_wire_values.count(signal_name)) {
            RTLIL::SigSpec idx_sig = import_expression(
                any_cast<const expr*>(uhdm_bit->VpiIndex()), input_mapping);
            if (idx_sig.is_fully_const()) {
                int idx = idx_sig.as_int();
                const RTLIL::Const& cur = ctx->const_wire_values[signal_name];
                if (idx >= 0 && idx < (int)cur.size()) {
                    return RTLIL::SigSpec(RTLIL::Const(
                        std::vector<RTLIL::State>{cur[idx]}));
                }
            }
        }
    }
    
    // Check if this is a memory access
    RTLIL::IdString mem_id = RTLIL::escape_id(signal_name);
    if (module->memories.count(mem_id) > 0) {
        if (mode_debug)
            log("    This is a memory access - creating $memrd cell\n");
        
        // Get memory info
        RTLIL::Memory* memory = module->memories.at(mem_id);
        
        // Get the address expression
        RTLIL::SigSpec addr = import_expression(uhdm_bit->VpiIndex(), input_mapping);
        
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
    
    // Check for expanded array: individual element wires exist (not a $memory object).
    // Handles both constant and dynamic indices.
    if (!module->memories.count(mem_id)) {
        RTLIL::Wire* first_elem = module->wire(RTLIL::escape_id(signal_name + "[0]"));
        if (first_elem) {
            int elem_w = first_elem->width;
            // Count elements
            int num_elems = 0;
            while (module->wire(RTLIL::escape_id(signal_name + "[" + std::to_string(num_elems) + "]")))
                num_elems++;

            RTLIL::SigSpec idx = import_expression(uhdm_bit->VpiIndex(), input_mapping);

            if (idx.is_fully_const()) {
                // Constant index — return current tracked value or raw wire.
                // In always_ff body mode the tracked (in-flight `$0\`) value is
                // suppressed so a non-blocking RHS reads the REGISTERED element
                // (NB semantics) — e.g. aes_kexp128's `w[2] <= w[0]^w[1]^w[2]`
                // must read the old w[0..2], not the values just queued for the
                // next clock.  (Mirrors emit_comb_assign's scalar suppression.)
                int i = idx.as_const().as_int();
                std::string elem_name = signal_name + "[" + std::to_string(i) + "]";
                if (!in_always_ff_body_mode && current_comb_values.count(elem_name))
                    return current_comb_values.at(elem_name);
                RTLIL::Wire* w = module->wire(RTLIL::escape_id(elem_name));
                if (w) return RTLIL::SigSpec(w);
            } else {
                // Dynamic index — build mux chain.
                int last = num_elems - 1;
                int idx_w = GetSize(idx);
                // Can the index address a non-existent element?  If the
                // index width can represent a value >= num_elems, an
                // out-of-range read is possible and needs an explicit
                // fall-through value.  Otherwise every representable index
                // is valid and the last element serves as the default.
                bool oob_possible = (idx_w >= 31) ||
                                    ((1LL << idx_w) > (long long)num_elems);
                RTLIL::SigSpec result;
                int start;
                if (oob_possible) {
                    // An out-of-range index reads 0.  SystemVerilog calls
                    // this X (don't-care), but emitting a literal X lets
                    // `opt` fold the fall-through mux back to an arbitrary
                    // element; a defined 0 both matches simulator behaviour
                    // (Verilator reads OOB as 0) and stays a valid refinement
                    // of the Verilog frontend's X, so formal equivalence is
                    // preserved.
                    result = RTLIL::SigSpec(RTLIL::State::S0, elem_w);
                    start = last;  // give EVERY element an explicit idx==i mux
                } else {
                    std::string last_name = signal_name + "[" + std::to_string(last) + "]";
                    if (current_comb_values.count(last_name))
                        result = current_comb_values.at(last_name);
                    else {
                        RTLIL::Wire* w = module->wire(RTLIL::escape_id(last_name));
                        result = w ? RTLIL::SigSpec(w) : RTLIL::SigSpec(RTLIL::State::Sx, elem_w);
                    }
                    start = last - 1;
                }

                for (int i = start; i >= 0; i--) {
                    std::string ename = signal_name + "[" + std::to_string(i) + "]";
                    RTLIL::SigSpec elem_val;
                    if (current_comb_values.count(ename))
                        elem_val = current_comb_values.at(ename);
                    else {
                        RTLIL::Wire* w = module->wire(RTLIL::escape_id(ename));
                        elem_val = w ? RTLIL::SigSpec(w) : RTLIL::SigSpec(RTLIL::State::Sx, elem_w);
                    }
                    // sel = (idx == i)
                    RTLIL::Wire* sel = module->addWire(NEW_ID, 1);
                    module->addEq(NEW_ID, idx, RTLIL::SigSpec(RTLIL::Const(i, GetSize(idx))), sel);
                    // result = sel ? elem_val : result  (Yosys mux: Y = S ? B : A)
                    RTLIL::Wire* mux_out = module->addWire(NEW_ID, elem_w);
                    module->addMux(NEW_ID, result, elem_val, RTLIL::SigSpec(sel), mux_out);
                    result = RTLIL::SigSpec(mux_out);
                }
                return result;
            }
        }
    }

    // Bit-select on a *parameter* whose typespec is a packed array
    // (`parameter logic [0:0][3:0] P = '{'{1'b1, 1'b0, 1'b0, 1'b0}}`)
    // — evaluate the parameter at compile time and extract the right
    // slice, since there is no module-level wire for a parameter.
    // Surelog's elaborated TopModules sets the bit_select's
    // `Actual_group()` to the parameter; AllModules leaves it null,
    // so we also fall back to looking the parameter up by name in the
    // current module.
    {
        const UHDM::parameter* param = nullptr;
        if (auto a = uhdm_bit->Actual_group()) {
            if (a->UhdmType() == uhdmparameter)
                param = any_cast<const UHDM::parameter*>(a);
        }
        if (!param && current_instance) {
            if (auto m = dynamic_cast<const UHDM::module_inst*>(current_instance)) {
                if (m->Parameters()) {
                    for (auto p : *m->Parameters()) {
                        if (std::string(p->VpiName()) == signal_name) {
                            param = dynamic_cast<const UHDM::parameter*>(p);
                            break;
                        }
                    }
                }
            }
        }
        if (param) {
            // Pull the elaborated value from `Param_assigns()->Rhs()`
            // (post-substitution), with a fallback to the parameter's
            // own `VpiValue()`.
            RTLIL::Const param_value;
            bool got = false;
            const UHDM::module_inst* pmod =
                dynamic_cast<const UHDM::module_inst*>(current_instance);
            if (pmod && pmod->Param_assigns()) {
                for (auto pa : *pmod->Param_assigns()) {
                    if (!pa->Lhs() || std::string(pa->Lhs()->VpiName()) != signal_name)
                        continue;
                    if (auto re = dynamic_cast<const UHDM::expr*>(pa->Rhs())) {
                        RTLIL::SigSpec rs = import_expression(re);
                        if (rs.is_fully_const()) {
                            param_value = rs.as_const();
                            got = true;
                        }
                    }
                    break;
                }
            }
            if (!got && !std::string(param->VpiValue()).empty()) {
                std::string v = std::string(param->VpiValue());
                RTLIL::Const c = extract_const_from_value(v);
                if (c.size() > 0) { param_value = c; got = true; }
            }
            if (got) {
                int total = param_value.size();
                RTLIL::SigSpec index = import_expression(uhdm_bit->VpiIndex(), input_mapping);
                if (index.is_fully_const()) {
                    int idx = index.as_const().as_int();
                    // Compute the element width from the parameter's
                    // typespec ranges.  For a packed multi-range
                    // logic_typespec the OUTER range count divides the
                    // total width to give the slot width that `P[i]`
                    // extracts.  For a plain 1-D parameter (single
                    // range or int_typespec) `P[i]` is just bit `i`.
                    int elem_w = 1;
                    int outer_low = 0;
                    bool packed_multidim = false;
                    if (auto rts = param->Typespec()) {
                        if (auto ats = rts->Actual_typespec()) {
                            if (ats->UhdmType() == uhdmlogic_typespec) {
                                auto lt = dynamic_cast<const UHDM::logic_typespec*>(ats);
                                if (lt && lt->Ranges() && !lt->Ranges()->empty() &&
                                    (lt->Ranges()->size() > 1 ||
                                     lt->Elem_typespec() != nullptr)) {
                                    packed_multidim = true;
                                    auto r0 = (*lt->Ranges())[0];
                                    RTLIL::SigSpec ls = import_expression(r0->Left_expr());
                                    RTLIL::SigSpec rs2 = import_expression(r0->Right_expr());
                                    if (ls.is_fully_const() && rs2.is_fully_const()) {
                                        int l = ls.as_int(), r = rs2.as_int();
                                        int outer_size = std::abs(l - r) + 1;
                                        outer_low = std::min(l, r);
                                        if (outer_size > 0 && total % outer_size == 0)
                                            elem_w = total / outer_size;
                                    }
                                }
                            }
                        }
                    }
                    (void)packed_multidim;
                    int slot = idx - outer_low;
                    int off = slot * elem_w;
                    if (off >= 0 && off + elem_w <= total) {
                        RTLIL::SigSpec full(param_value);
                        RTLIL::SigSpec slice = full.extract(off, elem_w);
                        if (mode_debug)
                            log("    Bit-select on parameter %s[%d]: extracted %d bits @off %d\n",
                                signal_name.c_str(), idx, elem_w, off);
                        return slice;
                    }
                }
            }
        }
    }

    // Regular bit select on a wire
    RTLIL::Wire* wire = find_wire_in_scope(signal_name, "bit select");

    // If wire not found, check if this is a shift register array element
    if (!wire) {
        // Get the index
        RTLIL::SigSpec index = import_expression(uhdm_bit->VpiIndex(), input_mapping);
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
        // Check if this is a function input parameter
        if (input_mapping) {
            auto it = input_mapping->find(signal_name);
            if (it != input_mapping->end()) {
                // This is a function parameter, use the mapped signal
                RTLIL::SigSpec index = import_expression(uhdm_bit->VpiIndex(), input_mapping);
                if (index.is_fully_const()) {
                    int idx = index.as_const().as_int();
                    if (idx >= 0 && idx < it->second.size()) {
                        return it->second.extract(idx, 1);
                    }
                }
                // For non-constant index, we'd need to create a mux tree
                // For now, just return the mapped signal
                return it->second;
            }
        }
        log_error("Could not find wire '%s' for bit select\n", signal_name.c_str());
    }
    
    RTLIL::SigSpec base(wire);
    // always_ff blocking-temp redirect (see import_ref_obj/import_part_select):
    // a bit-select of a blocking temp assigned earlier this cycle (e.g.
    // `CF <= tmp[8]`) reads the in-flight `$0\tmp`, not the registered `\tmp`.
    if (in_always_ff_body_mode) {
        auto bt = ff_blocking_temps.find(signal_name);
        if (bt != ff_blocking_temps.end() && bt->second.size() == base.size())
            base = bt->second;
    }
    // SSA always_ff (ff_simple_eval) / always_comb thread same-cycle blocking
    // values through input_mapping; a bit-select of such a value must read the
    // in-flight value too (mirrors import_ref_obj; PR #291 missed bit-selects).
    if (input_mapping && !signal_name.empty()) {
        auto im = input_mapping->find(signal_name);
        if (im != input_mapping->end() && im->second.size() == base.size())
            base = im->second;
    }
    RTLIL::SigSpec index = import_expression(uhdm_bit->VpiIndex(), input_mapping);

    if (index.size() == 0) {
        log_warning("Bit select index expression returned empty SigSpec for signal %s\n", signal_name.c_str());
        return RTLIL::SigSpec();
    }
    
    // Detect packed-multidim-array element access — the wire was tagged
    // with `packed_elem_width` / `packed_outer_left` / `packed_outer_right`
    // during `import_port` / `import_net`.  This metadata is needed for
    // BOTH constant- and dynamic-index paths: `parts[i]` on
    // `logic [NUM-1:0][W-1:0] parts` must extract a W-bit slot, not a
    // single bit (synlig#581's orv64 PTW reproducer reads `parts[i]`
    // with constant `i` inside a static-unrolled loop).
    int packed_elem_w = 1;
    int packed_outer_l = -1, packed_outer_r = -1;
    if (wire && wire->attributes.count(RTLIL::escape_id("packed_elem_width"))) {
        packed_elem_w = wire->attributes.at(RTLIL::escape_id("packed_elem_width")).as_int();
        packed_outer_l = wire->attributes.at(RTLIL::escape_id("packed_outer_left")).as_int();
        packed_outer_r = wire->attributes.at(RTLIL::escape_id("packed_outer_right")).as_int();
    }

    if (index.is_fully_const()) {
        int idx = index.as_const().as_int();
        if (mode_debug)
            log("    Bit select index: %d\n", idx);

        if (packed_elem_w > 1) {
            int outer_lo = std::min(packed_outer_l, packed_outer_r);
            int slot = idx - outer_lo;
            int off = slot * packed_elem_w;
            if (off < 0 || off + packed_elem_w > base.size()) {
                log_warning("Packed array element index %d is out of range "
                            "for wire '%s' (elem_w=%d, total=%d)\n",
                            idx, signal_name.c_str(), packed_elem_w, base.size());
                return RTLIL::SigSpec(RTLIL::State::Sx, packed_elem_w);
            }
            return base.extract(off, packed_elem_w);
        }

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

            // Check bounds before extracting
            if (rtlil_idx < 0 || rtlil_idx >= base.size()) {
                log_warning("Bit select index %d (RTLIL index %d) is out of range for wire '%s' (width=%d), returning undefined\n",
                    idx, rtlil_idx, signal_name.c_str(), base.size());
                return RTLIL::SigSpec(RTLIL::State::Sx, 1);
            }
            return base.extract(rtlil_idx, 1);
        } else {
            // Standard bit ordering
            // Check bounds before extracting
            if (idx < 0 || idx >= base.size()) {
                log_warning("Bit select index %d is out of range for wire '%s' (width=%d), returning undefined\n",
                    idx, signal_name.c_str(), base.size());
                return RTLIL::SigSpec(RTLIL::State::Sx, 1);
            }
            return base.extract(idx, 1);
        }
    }

    // Dynamic bit select - check for packed multidimensional array element access
    int element_width = packed_elem_w;
    int outer_left = packed_outer_l, outer_right = packed_outer_r;

    // Fall back to UHDM typespec detection if no wire attributes
    if (element_width <= 1) {
        if (auto actual_group = uhdm_bit->Actual_group()) {
            const UHDM::ref_typespec* net_ref_ts = nullptr;
            if (auto logic_net = dynamic_cast<const UHDM::logic_net*>(actual_group)) {
                net_ref_ts = logic_net->Typespec();
            } else if (auto logic_var = dynamic_cast<const UHDM::logic_var*>(actual_group)) {
                net_ref_ts = logic_var->Typespec();
            }
            if (net_ref_ts && net_ref_ts->Actual_typespec()) {
                auto ts = net_ref_ts->Actual_typespec();
                if (ts->UhdmType() == uhdmlogic_typespec) {
                    auto logic_ts = dynamic_cast<const UHDM::logic_typespec*>(ts);
                    if (logic_ts && logic_ts->Ranges() && !logic_ts->Ranges()->empty()) {
                        auto first_range = (*logic_ts->Ranges())[0];
                        if (first_range->Left_expr() && first_range->Right_expr()) {
                            RTLIL::SigSpec l = import_expression(first_range->Left_expr());
                            RTLIL::SigSpec r = import_expression(first_range->Right_expr());
                            if (l.is_fully_const() && r.is_fully_const()) {
                                outer_left = l.as_int();
                                outer_right = r.as_int();
                            }
                        }

                        if (logic_ts->Ranges()->size() > 1) {
                            // Variant A: multiple ranges (e.g., [0:3][7:0])
                            element_width = 1;
                            for (size_t i = 1; i < logic_ts->Ranges()->size(); i++) {
                                auto rng = (*logic_ts->Ranges())[i];
                                if (rng->Left_expr() && rng->Right_expr()) {
                                    RTLIL::SigSpec rl = import_expression(rng->Left_expr());
                                    RTLIL::SigSpec rr = import_expression(rng->Right_expr());
                                    if (rl.is_fully_const() && rr.is_fully_const()) {
                                        element_width *= abs(rl.as_int() - rr.as_int()) + 1;
                                    }
                                }
                            }
                        } else if (logic_ts->Elem_typespec() != nullptr) {
                            // Variant B: Elem_typespec (e.g., reg8_t [0:3])
                            auto elem_ref = logic_ts->Elem_typespec();
                            if (elem_ref->Actual_typespec()) {
                                auto elem_actual = elem_ref->Actual_typespec();
                                if (elem_actual->UhdmType() == uhdmlogic_typespec) {
                                    auto elem_logic = dynamic_cast<const UHDM::logic_typespec*>(elem_actual);
                                    if (elem_logic && elem_logic->Elem_typespec() != nullptr &&
                                        elem_logic->Elem_typespec()->Actual_typespec()) {
                                        element_width = get_width_from_typespec(
                                            elem_logic->Elem_typespec()->Actual_typespec(), inst);
                                    } else {
                                        element_width = get_width_from_typespec(elem_actual, inst);
                                    }
                                } else {
                                    element_width = get_width_from_typespec(elem_actual, inst);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (mode_debug)
        log("    Creating $shiftx for dynamic bit select (element_width=%d)\n", element_width);

    RTLIL::SigSpec shift_amount;
    if (element_width > 1) {
        // Packed array element access - compute byte offset
        // Zero-extend index to 32 bits for arithmetic cells
        RTLIL::SigSpec index32 = index;
        index32.extend_u0(32);

        if (outer_left >= 0 && outer_right >= 0 && outer_left < outer_right) {
            // Reversed range [0:N] - need $sub(right, ix) then $mul by element_width
            RTLIL::Wire* sub_wire = module->addWire(NEW_ID, 32);
            std::string sub_name = generate_cell_name(uhdm_bit, "sub");
            RTLIL::Cell* sub_cell = module->addCell(RTLIL::escape_id(sub_name), ID($sub));
            sub_cell->setParam(ID::A_SIGNED, 0);
            sub_cell->setParam(ID::B_SIGNED, 0);
            sub_cell->setParam(ID::A_WIDTH, 32);
            sub_cell->setParam(ID::B_WIDTH, 32);
            sub_cell->setParam(ID::Y_WIDTH, 32);
            sub_cell->setPort(ID::A, RTLIL::SigSpec(RTLIL::Const(outer_right, 32)));
            sub_cell->setPort(ID::B, index32);
            sub_cell->setPort(ID::Y, sub_wire);
            add_src_attribute(sub_cell->attributes, uhdm_bit);

            RTLIL::Wire* mul_wire = module->addWire(NEW_ID, 32);
            std::string mul_name = generate_cell_name(uhdm_bit, "mul");
            RTLIL::Cell* mul_cell = module->addCell(RTLIL::escape_id(mul_name), ID($mul));
            mul_cell->setParam(ID::A_SIGNED, 0);
            mul_cell->setParam(ID::B_SIGNED, 0);
            mul_cell->setParam(ID::A_WIDTH, 32);
            mul_cell->setParam(ID::B_WIDTH, 32);
            mul_cell->setParam(ID::Y_WIDTH, 32);
            mul_cell->setPort(ID::A, RTLIL::SigSpec(sub_wire));
            mul_cell->setPort(ID::B, RTLIL::SigSpec(RTLIL::Const(element_width, 32)));
            mul_cell->setPort(ID::Y, mul_wire);
            add_src_attribute(mul_cell->attributes, uhdm_bit);

            shift_amount = RTLIL::SigSpec(mul_wire);
        } else {
            // Normal range [N:0] - $mul(ix, element_width)
            RTLIL::Wire* mul_wire = module->addWire(NEW_ID, 32);
            std::string mul_name = generate_cell_name(uhdm_bit, "mul");
            RTLIL::Cell* mul_cell = module->addCell(RTLIL::escape_id(mul_name), ID($mul));
            mul_cell->setParam(ID::A_SIGNED, 0);
            mul_cell->setParam(ID::B_SIGNED, 0);
            mul_cell->setParam(ID::A_WIDTH, 32);
            mul_cell->setParam(ID::B_WIDTH, 32);
            mul_cell->setParam(ID::Y_WIDTH, 32);
            mul_cell->setPort(ID::A, index32);
            mul_cell->setPort(ID::B, RTLIL::SigSpec(RTLIL::Const(element_width, 32)));
            mul_cell->setPort(ID::Y, mul_wire);
            add_src_attribute(mul_cell->attributes, uhdm_bit);

            shift_amount = RTLIL::SigSpec(mul_wire);
        }
    } else {
        shift_amount = index;
    }

    // Create output wire for the result
    RTLIL::Wire* result_wire = module->addWire(NEW_ID, element_width);

    // Create $shiftx cell
    std::string cell_name = generate_cell_name(uhdm_bit, "shiftx");
    RTLIL::Cell* shiftx_cell = module->addCell(RTLIL::escape_id(cell_name), ID($shiftx));
    shiftx_cell->setParam(ID::A_SIGNED, 0);
    shiftx_cell->setParam(ID::B_SIGNED, element_width > 1 ? 1 : 0);
    shiftx_cell->setParam(ID::A_WIDTH, base.size());
    shiftx_cell->setParam(ID::B_WIDTH, shift_amount.size());
    shiftx_cell->setParam(ID::Y_WIDTH, element_width);

    shiftx_cell->setPort(ID::A, base);
    shiftx_cell->setPort(ID::B, shift_amount);
    shiftx_cell->setPort(ID::Y, result_wire);

    // Add source attribute
    add_src_attribute(shiftx_cell->attributes, uhdm_bit);

    return RTLIL::SigSpec(result_wire);
}

// Import indexed part select (e.g., data[i*8 +: 8])
RTLIL::SigSpec UhdmImporter::import_indexed_part_select(const indexed_part_select* uhdm_indexed, const UHDM::scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    if (mode_debug)
        log("    Importing indexed part select\n");

    // Get the parent object - this should contain the base signal
    const any* parent = uhdm_indexed->VpiParent();
    if (!parent) {
        log_warning("Indexed part select has no parent\n");
        return RTLIL::SigSpec();
    }
    
    if (mode_debug)
        log("      Parent type: %s\n", UhdmName(parent->UhdmType()).c_str());

    // Check if the indexed part select itself has the signal name
    std::string base_signal_name;
    if (!uhdm_indexed->VpiDefName().empty()) {
        base_signal_name = std::string(uhdm_indexed->VpiDefName());
    } else if (!uhdm_indexed->VpiName().empty()) {
        base_signal_name = std::string(uhdm_indexed->VpiName());
    }

    // If not found in the indexed part select, try the parent
    if (base_signal_name.empty()) {
        if (!parent->VpiDefName().empty()) {
            base_signal_name = std::string(parent->VpiDefName());
        } else if (!parent->VpiName().empty()) {
            base_signal_name = std::string(parent->VpiName());
        }
    }

    // Look up the wire in the current module
    RTLIL::SigSpec base;
    if (!base_signal_name.empty()) {
        // If this is a for-loop variable, substitute its current constant value
        if (loop_values.count(base_signal_name)) {
            int lv = loop_values.at(base_signal_name);
            RTLIL::Wire* w = find_wire_in_scope(base_signal_name, "indexed part select width");
            int bw = w ? w->width : 32;
            base = RTLIL::SigSpec(RTLIL::Const(lv, bw));
        } else {
            RTLIL::Wire* wire = find_wire_in_scope(base_signal_name, "part select");
            if (wire) {
                base = RTLIL::SigSpec(wire);
            } else {
                // Try as a parameter (e.g., OUTPUT[15:8] where OUTPUT is a parameter)
                RTLIL::IdString param_id = RTLIL::escape_id(base_signal_name);
                if (module->parameter_default_values.count(param_id)) {
                    base = RTLIL::SigSpec(module->parameter_default_values.at(param_id));
                } else {
                    std::string gen_scope = get_current_gen_scope();
                    log_warning("Base signal '%s' not found in module or generate scope %s\n",
                        base_signal_name.c_str(), gen_scope.c_str());
                    return RTLIL::SigSpec();
                }
            }
        }
    } else {
        // If we can't get the name directly, try importing the parent as an expression
        base = import_expression(any_cast<const expr*>(parent), input_mapping);
    }

    // Get the base index and width expressions.  These are *address*
    // operands, independent of the slice's datapath width — so the
    // surrounding assignment's context width (e.g. the 4-bit LHS of
    // `slice = data[offset+3 -: 4]`) must NOT cap them, or an arithmetic
    // base like `offset+3` gets truncated (offset[3:0]) and the high
    // address bits are lost.  Clear the context for these sub-imports.
    int saved_ctx_width = expression_context_width;
    expression_context_width = 0;
    RTLIL::SigSpec base_index = import_expression(uhdm_indexed->Base_expr(), input_mapping);
    RTLIL::SigSpec width_expr = import_expression(uhdm_indexed->Width_expr(), input_mapping);
    expression_context_width = saved_ctx_width;
    
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
    
    // Dynamic base index — emit $shiftx cell
    // $shiftx: Y = A[B +: Y_WIDTH], i.e. B is the LSB start index
    if (!width_expr.is_fully_const()) {
        log_warning("Indexed part select with non-constant width not supported\n");
        return RTLIL::SigSpec();
    }
    int width = width_expr.as_const().as_int();
    if (width <= 0) {
        log_warning("Indexed part select with invalid width %d\n", width);
        return RTLIL::SigSpec();
    }

    // Compute LSB shift amount
    RTLIL::SigSpec shift_amount;
    if (uhdm_indexed->VpiIndexedPartSelectType() == vpiPosIndexed) {
        // [base +: width] — LSB = base
        shift_amount = base_index;
    } else {
        // [base -: width] — LSB = base - (width - 1)
        int sub_val = width - 1;
        RTLIL::Wire* lsb_wire = module->addWire(NEW_ID, base_index.size());
        std::string sub_name = generate_cell_name(uhdm_indexed, "sub");
        RTLIL::Cell* sub_cell = module->addCell(RTLIL::escape_id(sub_name), ID($sub));
        sub_cell->setParam(ID::A_SIGNED, 0);
        sub_cell->setParam(ID::B_SIGNED, 0);
        sub_cell->setParam(ID::A_WIDTH, base_index.size());
        sub_cell->setParam(ID::B_WIDTH, base_index.size());
        sub_cell->setParam(ID::Y_WIDTH, base_index.size());
        sub_cell->setPort(ID::A, base_index);
        sub_cell->setPort(ID::B, RTLIL::SigSpec(RTLIL::Const(sub_val, base_index.size())));
        sub_cell->setPort(ID::Y, lsb_wire);
        add_src_attribute(sub_cell->attributes, uhdm_indexed);
        shift_amount = RTLIL::SigSpec(lsb_wire);
    }

    // Create output wire and $shiftx cell
    RTLIL::Wire* result_wire = module->addWire(NEW_ID, width);
    std::string cell_name = generate_cell_name(uhdm_indexed, "shiftx");
    RTLIL::Cell* shiftx_cell = module->addCell(RTLIL::escape_id(cell_name), ID($shiftx));
    shiftx_cell->setParam(ID::A_SIGNED, 0);
    shiftx_cell->setParam(ID::B_SIGNED, 0);
    shiftx_cell->setParam(ID::A_WIDTH, base.size());
    shiftx_cell->setParam(ID::B_WIDTH, shift_amount.size());
    shiftx_cell->setParam(ID::Y_WIDTH, width);
    shiftx_cell->setPort(ID::A, base);
    shiftx_cell->setPort(ID::B, shift_amount);
    shiftx_cell->setPort(ID::Y, result_wire);
    add_src_attribute(shiftx_cell->attributes, uhdm_indexed);

    return RTLIL::SigSpec(result_wire);
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
RTLIL::SigSpec UhdmImporter::import_hier_path(const hier_path* uhdm_hier, const scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    if (mode_debug)
        log("    Importing hier_path\n");
    
    // Get the full path name first
    std::string path_name;
    std::string_view name_view = uhdm_hier->VpiName();
    if (!name_view.empty()) {
        path_name = std::string(name_view);
    }
    std::string_view full_name_view = uhdm_hier->VpiFullName();
    if (!full_name_view.empty() && path_name.empty()) {
        path_name = std::string(full_name_view);
    }
    
    log("    hier_path: VpiName='%s', VpiFullName='%s', using='%s'\n",
        std::string(name_view).c_str(), std::string(full_name_view).c_str(), path_name.c_str());

    // Hierarchical function call: `module_scope_func_top.incr(10)`.
    // Surelog represents this as a hier_path whose last Path_elem is a
    // `method_func_call`.  Resolve the function (use the bound
    // Function() pointer or look it up by name in the current module's
    // Task_funcs) and either compile-time-evaluate it (when all
    // arguments are constants — covers `localparam = top.func(...)`)
    // or inline it into the surrounding combinational/initial context.
    if (uhdm_hier->Path_elems() && !uhdm_hier->Path_elems()->empty()) {
        auto last_elem = uhdm_hier->Path_elems()->back();
        if (last_elem->UhdmType() == uhdmmethod_func_call) {
            auto mfc = any_cast<const UHDM::method_func_call*>(last_elem);
            std::string func_name = std::string(mfc->VpiName());
            const UHDM::function* fdef = mfc->Function();
            // Fall back: walk the current module's Task_funcs by name.
            if (!fdef && current_instance) {
                if (auto mod = dynamic_cast<const UHDM::module_inst*>(current_instance)) {
                    if (mod->Task_funcs()) {
                        for (auto tf : *mod->Task_funcs()) {
                            if (tf->UhdmType() == uhdmfunction &&
                                std::string(tf->VpiName()) == func_name) {
                                fdef = any_cast<const UHDM::function*>(tf);
                                break;
                            }
                        }
                    }
                }
            }
            if (fdef) {
                // Collect arguments.
                std::vector<RTLIL::SigSpec> args;
                if (mfc->Tf_call_args()) {
                    for (auto a : *mfc->Tf_call_args()) {
                        args.push_back(import_expression(
                            any_cast<const UHDM::expr*>(a), input_mapping));
                    }
                }
                bool all_const = true;
                std::vector<RTLIL::Const> const_args;
                for (const auto& arg : args) {
                    if (arg.is_fully_const()) {
                        const_args.push_back(arg.as_const());
                    } else {
                        all_const = false;
                        break;
                    }
                }
                if (all_const) {
                    const_eval_module_writes.clear();
                    std::map<std::string, RTLIL::Const> output_params;
                    RTLIL::Const result =
                        evaluate_function_call(fdef, const_args, output_params);
                    const_eval_module_writes.clear();
                    if (mode_debug)
                        log("    hier_path func call %s → compile-time const\n",
                            func_name.c_str());
                    return RTLIL::SigSpec(result);
                }
                UHDM::Serializer* s = uhdm_design->GetSerializer();
                UHDM::func_call* tmp = s->MakeFunc_call();
                tmp->VpiName(func_name);
                tmp->Function(const_cast<UHDM::function*>(fdef));
                if (mfc->Tf_call_args()) {
                    UHDM::VectorOfany* args_vec = s->MakeAnyVec();
                    for (auto a : *mfc->Tf_call_args()) args_vec->push_back(a);
                    tmp->Tf_call_args(args_vec);
                }
                if (current_comb_process) {
                    // Inline into the current combinational process via
                    // the synthesised func_call.
                    return import_func_call_comb(tmp, current_comb_process);
                }
                // Continuous-assign context: route through the existing
                // function-call pipeline.
                return process_function_with_context(fdef, args, tmp, nullptr);
            }
            log_warning("UHDM: hier_path function '%s' — no Function() and "
                        "no match in current module's Task_funcs\n",
                        func_name.c_str());
        }
    }

    // Packed-union-of-structs field access: `dec.r.rd` where `dec` is
    // a `union packed` whose `r` member is a `struct packed`.  All
    // union members occupy the same bits, so level 2 (the union
    // member) just picks the layout; level 3 (the struct field)
    // extracts the actual slice.  Imported from jeras/UHDM-tests/
    // test_union.sv (RISC-V op32_t union).
    //
    // Without this, Surelog's `Actual_group()` on the third path
    // element wrongly resolves a field name like `rd` to a same-named
    // module net (`work@test_union.rd`), producing the self-loop
    // `connect \rd \rd`.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 3) {
        auto& pe3 = *uhdm_hier->Path_elems();
        if (pe3[0]->UhdmType() == uhdmref_obj &&
            pe3[1]->UhdmType() == uhdmref_obj &&
            pe3[2]->UhdmType() == uhdmref_obj) {
            std::string base_name = std::string(
                any_cast<const ref_obj*>(pe3[0])->VpiName());
            std::string union_member = std::string(
                any_cast<const ref_obj*>(pe3[1])->VpiName());
            std::string field_name = std::string(
                any_cast<const ref_obj*>(pe3[2])->VpiName());

            RTLIL::Wire* base_wire = name_map.count(base_name)
                ? name_map[base_name] : nullptr;

            // Chase the base ref's typespec to the union_typespec; pick
            // the matching member; chase that to its struct_typespec.
            const UHDM::union_typespec* ut = nullptr;
            if (base_wire) {
                auto base_ref = any_cast<const ref_obj*>(pe3[0]);
                const UHDM::ref_typespec* rts = nullptr;
                if (auto a = base_ref->Actual_group()) {
                    if (a->UhdmType() == uhdmlogic_net)
                        rts = any_cast<const UHDM::logic_net*>(a)->Typespec();
                    else if (a->UhdmType() == uhdmlogic_var)
                        rts = any_cast<const UHDM::logic_var*>(a)->Typespec();
                    else if (a->UhdmType() == uhdmstruct_var)
                        rts = any_cast<const UHDM::struct_var*>(a)->Typespec();
                    else if (a->UhdmType() == uhdmunion_var)
                        rts = any_cast<const UHDM::union_var*>(a)->Typespec();
                }
                if (rts && rts->Actual_typespec() &&
                    rts->Actual_typespec()->UhdmType() == uhdmunion_typespec)
                    ut = any_cast<const UHDM::union_typespec*>(rts->Actual_typespec());
            }

            const UHDM::struct_typespec* st = nullptr;
            if (ut && ut->Members()) {
                for (auto m : *ut->Members()) {
                    if (std::string(m->VpiName()) != union_member) continue;
                    if (auto mts = m->Typespec()) {
                        if (auto ats = mts->Actual_typespec()) {
                            if (ats->UhdmType() == uhdmstruct_typespec)
                                st = any_cast<const UHDM::struct_typespec*>(ats);
                        }
                    }
                    break;
                }
            }

            if (base_wire && st && st->Members()) {
                // Find the field; LSB-first iteration accumulates the
                // offset (struct's last member is the LSB).
                int field_off = 0, field_w = 0;
                bool found = false;
                for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                    auto m = (*st->Members())[i];
                    int mw = 0;
                    if (auto mts = m->Typespec())
                        if (auto ats = mts->Actual_typespec())
                            mw = get_width_from_typespec(ats, inst);
                    if (std::string(m->VpiName()) == field_name) {
                        field_w = mw;
                        found = true;
                        break;
                    }
                    field_off += mw;
                }
                if (found && field_w > 0 &&
                    field_off + field_w <= base_wire->width) {
                    log("    hier_path: union+struct %s.%s.%s -> %s[%d+:%d]\n",
                        base_name.c_str(), union_member.c_str(),
                        field_name.c_str(), base_wire->name.c_str(),
                        field_off, field_w);
                    return RTLIL::SigSpec(base_wire).extract(field_off, field_w);
                }
            }
        }
    }

    // Interface-port signal bit/part-select access (e.g. `bus.adr[3:0]`
    // where `bus` is a `tcb_if.sub` modport port and `adr` is one of the
    // interface's signals).  Path_elems = [ref_obj(bus),
    // bit_select|part_select(adr[...])].  `import_port` already created
    // `\bus.adr` as a module-local wire of the right width; just apply
    // the bit/part-select on top of that.  Imported from
    // jeras/UHDM-tests/tcb_gpio.sv (`case (bus.adr[2+2-1:0])`).
    //
    // Without this, the path falls through to the generic walker which
    // can't find the slice and returns a constant (effectively
    // `4'xxxx`), and `bus.rdt` never gets driven.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pe_bp = *uhdm_hier->Path_elems();
        bool is_part_or_bit =
            pe_bp[0]->UhdmType() == uhdmref_obj &&
            (pe_bp[1]->UhdmType() == uhdmbit_select ||
             pe_bp[1]->UhdmType() == uhdmpart_select);
        if (is_part_or_bit) {
            std::string base_name = std::string(
                any_cast<const ref_obj*>(pe_bp[0])->VpiName());
            std::string field_name;
            if (pe_bp[1]->UhdmType() == uhdmbit_select)
                field_name = std::string(
                    any_cast<const bit_select*>(pe_bp[1])->VpiName());
            else
                field_name = std::string(
                    any_cast<const part_select*>(pe_bp[1])->VpiName());

            std::string full = base_name + "." + field_name;
            auto it = name_map.find(full);
            if (it != name_map.end() && it->second) {
                RTLIL::Wire* sig_wire = it->second;
                if (pe_bp[1]->UhdmType() == uhdmbit_select) {
                    const bit_select* bs = any_cast<const bit_select*>(pe_bp[1]);
                    RTLIL::SigSpec idx_sig = import_expression(
                        bs->VpiIndex(), input_mapping);
                    if (idx_sig.is_fully_const()) {
                        int idx = idx_sig.as_const().as_int();
                        if (idx >= 0 && idx < sig_wire->width) {
                            log("    hier_path: %s[%d] → \\%s[%d]\n",
                                full.c_str(), idx, full.c_str(), idx);
                            return RTLIL::SigSpec(sig_wire).extract(idx, 1);
                        }
                    }
                } else {
                    const part_select* ps = any_cast<const part_select*>(pe_bp[1]);
                    RTLIL::SigSpec ls = import_expression(
                        ps->Left_range(), input_mapping);
                    RTLIL::SigSpec rs = import_expression(
                        ps->Right_range(), input_mapping);
                    if (ls.is_fully_const() && rs.is_fully_const()) {
                        int l = ls.as_int();
                        int r = rs.as_int();
                        int lo = std::min(l, r);
                        int w  = std::abs(l - r) + 1;
                        if (lo >= 0 && lo + w <= sig_wire->width) {
                            log("    hier_path: %s[%d:%d] → \\%s[%d+:%d]\n",
                                full.c_str(), l, r, full.c_str(), lo, w);
                            return RTLIL::SigSpec(sig_wire).extract(lo, w);
                        }
                    }
                }
            }
        }
    }

    // Interface-port signal access (e.g. `ha_intf.sum` where `ha_intf`
    // is the module's interface port).  `import_port` already created
    // `\ha_intf.sum` as a module-local wire, so the full path name
    // resolves directly.  This must run before the generic Actual_group
    // walk below, because Surelog's `Actual_group()` on the field
    // ref_obj sometimes points to a module-local same-named net (e.g.
    // `\sum`) and the walker would then return that net — turning
    // `assign sum = ha_intf.sum;` into a `connect \sum \sum` no-op.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pe2 = *uhdm_hier->Path_elems();
        if (pe2[0]->UhdmType() == uhdmref_obj &&
            pe2[1]->UhdmType() == uhdmref_obj) {
            std::string base = std::string(
                any_cast<const ref_obj*>(pe2[0])->VpiName());
            std::string field = std::string(
                any_cast<const ref_obj*>(pe2[1])->VpiName());
            if (!base.empty() && !field.empty()) {
                std::string full = base + "." + field;
                auto it = name_map.find(full);
                if (it != name_map.end()) {
                    log("    hier_path: resolved %s → %s via name_map\n",
                        full.c_str(), it->second->name.c_str());
                    return RTLIL::SigSpec(it->second);
                }

                // Interface-parameter access (e.g. `bus.DATA_WIDTH` where
                // `bus` is a `bus_if.master` modport port and DATA_WIDTH
                // is a parameter on the interface).  Used for port widths
                // (`input [bus.DATA_WIDTH-1:0] din`).  AllModules-pass
                // resolution returns the interface's *default* value; the
                // hierarchy pass then specializes the module per call
                // site via the `(* dynports *)` attribute on the module.
                auto base_ref = any_cast<const ref_obj*>(pe2[0]);
                const UHDM::interface_inst* iface = nullptr;
                if (auto a = base_ref->Actual_group()) {
                    if (a->UhdmType() == uhdminterface_inst)
                        iface = any_cast<const UHDM::interface_inst*>(a);
                    else if (a->UhdmType() == uhdmmodport) {
                        auto mp = any_cast<const UHDM::modport*>(a);
                        if (mp && mp->VpiParent() &&
                            mp->VpiParent()->UhdmType() == uhdminterface_inst)
                            iface = any_cast<const UHDM::interface_inst*>(mp->VpiParent());
                    }
                }
                if (!iface && uhdm_design && uhdm_design->AllInterfaces()) {
                    // No Actual_group (AllModules pass) — find the port
                    // `<base>` in the current module and use its
                    // `\interface_type` attribute to pick the interface.
                    std::string iface_name;
                    if (auto port_wire = module->wire(RTLIL::escape_id(base))) {
                        if (port_wire->attributes.count(RTLIL::escape_id("interface_type"))) {
                            iface_name = port_wire->attributes.at(
                                RTLIL::escape_id("interface_type")).decode_string();
                            if (!iface_name.empty() && iface_name[0] == '\\')
                                iface_name = iface_name.substr(1);
                        }
                    }
                    if (!iface_name.empty()) {
                        for (auto ii : *uhdm_design->AllInterfaces()) {
                            std::string n = std::string(ii->VpiDefName());
                            if (n.substr(0, 5) == "work@") n = n.substr(5);
                            if (n == iface_name) { iface = ii; break; }
                        }
                    }
                }
                if (iface) {
                    // Search Parameters() by name.
                    if (iface->Parameters()) {
                        for (auto p : *iface->Parameters()) {
                            if (std::string(p->VpiName()) != field) continue;
                            auto par = dynamic_cast<const UHDM::parameter*>(p);
                            if (!par) break;
                            // Prefer explicit override from Param_assigns
                            // (the elaborated value).
                            if (iface->Param_assigns()) {
                                for (auto pa : *iface->Param_assigns()) {
                                    auto lhs = pa->Lhs();
                                    if (!lhs ||
                                        lhs->VpiType() != par->VpiType() ||
                                        std::string(lhs->VpiName()) != field)
                                        continue;
                                    if (auto re = dynamic_cast<const UHDM::expr*>(pa->Rhs())) {
                                        RTLIL::SigSpec s = import_expression(re);
                                        if (s.is_fully_const()) {
                                            log("    hier_path: resolved %s → param value %d via interface\n",
                                                full.c_str(), s.as_const().as_int());
                                            // Mark module dynports so
                                            // the hierarchy pass re-
                                            // specializes per call site
                                            // (the value here is the
                                            // *default*; each instance
                                            // may override).
                                            module->set_bool_attribute(ID::dynports);
                                            return s;
                                        }
                                    }
                                }
                            }
                            // Fall back to parameter's VpiValue (default).
                            std::string v = std::string(par->VpiValue());
                            if (!v.empty()) {
                                RTLIL::Const c = extract_const_from_value(v);
                                if (c.size() > 0) {
                                    log("    hier_path: resolved %s → param default %d via interface\n",
                                        full.c_str(), c.as_int());
                                    module->set_bool_attribute(ID::dynports);
                                    return RTLIL::SigSpec(c);
                                }
                            }
                            break;
                        }
                    }
                }
            }
        }
    }

    // Check if the hier_path has path elements that resolve to a full path
    // This handles generate block references like foo.x that resolve to outer.foo.foo.x
    // In UHDM, the hier_path contains multiple ref_obj elements in Path_elems
    // The last ref_obj typically has the fully resolved name
    if (uhdm_hier->Path_elems()) {
        log("    hier_path has %d path elements\n", (int)uhdm_hier->Path_elems()->size());
        
        // Look through all path elements to find one with a resolved full name
        // Sometimes the resolution is in the Actual() of the ref_obj
        for (auto elem : *uhdm_hier->Path_elems()) {
            log("      Path elem type: %s\n", UHDM::UhdmName(elem->UhdmType()).c_str());
            
            if (elem->UhdmType() == uhdmref_obj) {
                const ref_obj* ref = any_cast<const ref_obj*>(elem);
                log("        ref_obj: name=%s, full_name=%s\n", 
                    std::string(ref->VpiName()).c_str(), std::string(ref->VpiFullName()).c_str());
                
                // Check if this ref_obj has an Actual_group() pointing to the real signal
                if (ref->Actual_group()) {
                    const any* actual = ref->Actual_group();
                    log("        ref_obj has Actual_group of type %s\n", UHDM::UhdmName(actual->UhdmType()).c_str());

                    // Extract full name from the actual object (works for logic_net, integer_var, logic_var)
                    std::string_view actual_full_name;
                    if (actual->UhdmType() == uhdmlogic_net) {
                        actual_full_name = any_cast<const logic_net*>(actual)->VpiFullName();
                    } else if (actual->UhdmType() == uhdminteger_var) {
                        actual_full_name = any_cast<const integer_var*>(actual)->VpiFullName();
                    } else if (actual->UhdmType() == uhdmlogic_var) {
                        actual_full_name = any_cast<const logic_var*>(actual)->VpiFullName();
                    }

                    if (!actual_full_name.empty()) {
                        std::string full_str = std::string(actual_full_name);
                        log("          Actual full name: %s\n", full_str.c_str());
                        // Extract module-relative path (remove work@module_name. prefix)
                        size_t module_end = full_str.find('.');
                        if (module_end != std::string::npos) {
                            std::string signal_path = full_str.substr(module_end + 1);
                            log("          Extracted signal path: %s\n", signal_path.c_str());
                            if (name_map.count(signal_path)) {
                                log("          Found in name_map, resolving to: %s\n", name_map[signal_path]->name.c_str());
                                return RTLIL::SigSpec(name_map[signal_path]);
                            } else if (!name_map.count(path_name)) {
                                // Wire not yet created and hier_path name also absent —
                                // forward reference across generate scopes: create it now.
                                int width = get_width(actual, current_instance);
                                RTLIL::Wire* w = create_wire(signal_path, width);
                                wire_map[actual] = w;
                                name_map[signal_path] = w;
                                log("          Created forward-ref wire '%s' (width=%d)\n", signal_path.c_str(), width);
                                return RTLIL::SigSpec(w);
                            }
                            // path_name is already in name_map (e.g., interface port "bus.a"):
                            // fall through so the standard name_map lookup below resolves it.
                        }
                    }
                }
                
                // Also check VpiFullName of the ref_obj itself (fallback)
                std::string_view ref_full_name = ref->VpiFullName();
                if (!ref_full_name.empty()) {
                    std::string full_str = std::string(ref_full_name);
                    // Extract module-relative path
                    size_t module_end = full_str.find('.');
                    if (module_end != std::string::npos) {
                        std::string signal_path = full_str.substr(module_end + 1);
                        if (mode_debug)
                            log("      ref_obj has VpiFullName: %s -> %s\n", full_str.c_str(), signal_path.c_str());
                        if (name_map.count(signal_path)) {
                            if (mode_debug)
                                log("      Found in name_map: %s\n", name_map[signal_path]->name.c_str());
                            return RTLIL::SigSpec(name_map[signal_path]);
                        }
                    }
                }
            }
        }
    } else {
        if (mode_debug)
            log("    hier_path has no Path_elems\n");
    }

    // Handle unpacked-array-of-struct element + array-member element access:
    // arr[i].f[j]  where `arr` is an array_var with array_typespec wrapping a
    // struct_typespec, and the struct member `f` is itself an unpacked array.
    // UHDM models this as Path_elems = [bit_select(arr[i]), bit_select(.f[j])]
    // (the second bit_select's VpiName is the struct field name, not the
    // base).  Resolves to the flat bit slice
    //
    //   base_wire[ (i - low0)*elem_w + field_off + (j - lowF)*elem_f_w +: elem_f_w ]
    //
    // Drives `fb[0].f[0]` in unpacked_struct_array_typedef.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pelems_aa = *uhdm_hier->Path_elems();
        if (pelems_aa[0]->UhdmType() == uhdmbit_select &&
            pelems_aa[1]->UhdmType() == uhdmbit_select) {
            const bit_select* base_bs  = any_cast<const bit_select*>(pelems_aa[0]);
            const bit_select* field_bs = any_cast<const bit_select*>(pelems_aa[1]);
            std::string base_name = std::string(base_bs->VpiName());
            std::string field_name = std::string(field_bs->VpiName());
            if (base_name != field_name && base_bs->VpiIndex() && field_bs->VpiIndex()) {
                RTLIL::Wire* base_wire = name_map.count(base_name)
                                              ? name_map[base_name]
                                              : nullptr;
                // The first bit_select's Actual_group is the array_var; chase
                // the typespec chain array_typespec -> struct_typespec to find
                // the named member and its inner array_typespec.
                const UHDM::array_var* av = nullptr;
                if (base_bs->Actual_group() &&
                    base_bs->Actual_group()->UhdmType() == uhdmarray_var)
                    av = any_cast<const UHDM::array_var*>(base_bs->Actual_group());
                const UHDM::array_typespec* outer_ats = nullptr;
                const UHDM::struct_typespec* st = nullptr;
                if (av && av->Typespec()) {
                    if (auto ats = av->Typespec()->Actual_typespec()) {
                        if (ats->UhdmType() == uhdmarray_typespec) {
                            outer_ats = any_cast<const UHDM::array_typespec*>(ats);
                            if (outer_ats->Elem_typespec()) {
                                if (auto et = outer_ats->Elem_typespec()->Actual_typespec()) {
                                    if (et->UhdmType() == uhdmstruct_typespec)
                                        st = any_cast<const UHDM::struct_typespec*>(et);
                                }
                            }
                        }
                    }
                }
                RTLIL::SigSpec base_idx = import_expression(base_bs->VpiIndex(), input_mapping);
                RTLIL::SigSpec field_idx = import_expression(field_bs->VpiIndex(), input_mapping);
                if (base_wire && outer_ats && st && st->Members() &&
                    base_idx.is_fully_const() && field_idx.is_fully_const()) {
                    int i_idx = base_idx.as_const().as_int();
                    int j_idx = field_idx.as_const().as_int();
                    // Outer (foobar_t) bounds.
                    int outer_low = 0;
                    int elem_w = 0;
                    if (outer_ats->Ranges() && !outer_ats->Ranges()->empty()) {
                        auto r = (*outer_ats->Ranges())[0];
                        RTLIL::SigSpec ls = import_expression(r->Left_expr(), input_mapping);
                        RTLIL::SigSpec rs = import_expression(r->Right_expr(), input_mapping);
                        if (ls.is_fully_const() && rs.is_fully_const())
                            outer_low = std::min(ls.as_int(), rs.as_int());
                    }
                    // Element (bar_t) width = sum of struct member widths.
                    for (auto m : *st->Members()) {
                        if (auto mts = m->Typespec())
                            if (auto ats = mts->Actual_typespec())
                                elem_w += get_width_from_typespec(ats, inst);
                    }
                    // Walk struct members for the matching field; capture its
                    // bit offset (from LSB of the struct, accumulating
                    // widths in reverse — last member = LSB) and its
                    // typespec (expected to be an inner array_typespec).
                    int field_off = 0;
                    const UHDM::array_typespec* inner_ats = nullptr;
                    bool found_field = false;
                    for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                        auto m = (*st->Members())[i];
                        int mw = 0;
                        const UHDM::typespec* mts_actual = nullptr;
                        if (auto mts = m->Typespec())
                            if (auto ats = mts->Actual_typespec()) {
                                mts_actual = ats;
                                mw = get_width_from_typespec(ats, inst);
                            }
                        if (std::string(m->VpiName()) == field_name) {
                            if (mts_actual && mts_actual->UhdmType() == uhdmarray_typespec)
                                inner_ats = any_cast<const UHDM::array_typespec*>(mts_actual);
                            found_field = true;
                            break;
                        }
                        field_off += mw;
                    }
                    if (found_field && inner_ats && inner_ats->Elem_typespec()) {
                        int inner_low = 0;
                        if (inner_ats->Ranges() && !inner_ats->Ranges()->empty()) {
                            auto r = (*inner_ats->Ranges())[0];
                            RTLIL::SigSpec ls = import_expression(r->Left_expr(), input_mapping);
                            RTLIL::SigSpec rs = import_expression(r->Right_expr(), input_mapping);
                            if (ls.is_fully_const() && rs.is_fully_const())
                                inner_low = std::min(ls.as_int(), rs.as_int());
                        }
                        int elem_f_w = 0;
                        if (auto eat = inner_ats->Elem_typespec()->Actual_typespec())
                            elem_f_w = get_width_from_typespec(eat, inst);
                        if (elem_w > 0 && elem_f_w > 0) {
                            int abs_start =
                                (i_idx - outer_low) * elem_w + field_off +
                                (j_idx - inner_low) * elem_f_w;
                            if (abs_start >= 0 &&
                                abs_start + elem_f_w <= base_wire->width) {
                                if (mode_debug)
                                    log("    Array-of-struct + array-member: "
                                        "%s[%d].%s[%d] -> %s[%d+:%d]\n",
                                        base_name.c_str(), i_idx,
                                        field_name.c_str(), j_idx,
                                        base_wire->name.c_str(),
                                        abs_start, elem_f_w);
                                return RTLIL::SigSpec(base_wire)
                                    .extract(abs_start, elem_f_w);
                            }
                        }
                    }
                }
            }
        }
    }

    // Handle multi-dim packed-array element + scalar field access:
    // sig[i0][i1]...[iN-1].field — Path_elems pattern
    // [bit_select × N, ref_obj].  Walks all bit_selects to compute a flat
    // element offset against the packed_array_var's Ranges, then offsets
    // by the struct field within the element.  Returns the slice on the
    // flat base wire.  Drives e.g. `a[0][0].min_v` in int_port_signed.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 2) {
        auto& pelems_md = *uhdm_hier->Path_elems();
        size_t nelems = pelems_md.size();
        // All but the last element must be bit_select; last must be ref_obj.
        bool shape_ok = pelems_md[nelems - 1]->UhdmType() == uhdmref_obj;
        for (size_t i = 0; shape_ok && i + 1 < nelems; i++)
            shape_ok = (pelems_md[i]->UhdmType() == uhdmbit_select);
        if (shape_ok && nelems >= 3) {
            const bit_select* first_bs = any_cast<const bit_select*>(pelems_md[0]);
            const ref_obj*    field_r  = any_cast<const ref_obj*>(pelems_md[nelems - 1]);
            std::string base_name = std::string(first_bs->VpiName());
            std::string field_name = std::string(field_r->VpiName());
            RTLIL::Wire* base_wire = name_map.count(base_name)
                                          ? name_map[base_name]
                                          : nullptr;
            // Resolve the packed_array_var via the first bit_select's Actual_group().
            const UHDM::packed_array_var* pav = nullptr;
            if (first_bs->Actual_group() &&
                first_bs->Actual_group()->UhdmType() == uhdmpacked_array_var) {
                pav = any_cast<const UHDM::packed_array_var*>(first_bs->Actual_group());
            }
            const UHDM::struct_typespec* st = nullptr;
            int elem_width = 0;
            std::vector<std::pair<int,int>> range_lr;  // (left, right) per dim
            if (pav) {
                if (pav->Ranges()) {
                    for (auto r : *pav->Ranges()) {
                        if (r->Left_expr() && r->Right_expr()) {
                            RTLIL::SigSpec ls = import_expression(r->Left_expr(), input_mapping);
                            RTLIL::SigSpec rs = import_expression(r->Right_expr(), input_mapping);
                            if (ls.is_fully_const() && rs.is_fully_const())
                                range_lr.push_back({ls.as_int(), rs.as_int()});
                        }
                    }
                }
                if (pav->Elements() && !pav->Elements()->empty()) {
                    const any* elem0 = (*pav->Elements())[0];
                    if (auto sv = dynamic_cast<const UHDM::struct_var*>(elem0)) {
                        if (auto rts = sv->Typespec()) {
                            if (auto ats = rts->Actual_typespec()) {
                                if (ats->UhdmType() == uhdmstruct_typespec)
                                    st = any_cast<const UHDM::struct_typespec*>(ats);
                            }
                        }
                    }
                }
                if (st && st->Members()) {
                    elem_width = 0;
                    for (auto m : *st->Members())
                        if (auto mts = m->Typespec())
                            if (auto ats = mts->Actual_typespec())
                                elem_width += get_width_from_typespec(ats, inst);
                }
            }
            if (base_wire && st && elem_width > 0 &&
                range_lr.size() == nelems - 1) {
                // Compute the flat element offset using row-major layout:
                // offset = ((((i0 - lo0) * size1) + (i1 - lo1)) * size2 + ...)
                // For our layout the leftmost dim is the outer/slowest.
                int64_t lin_idx = 0;
                bool all_const = true;
                for (size_t d = 0; d < nelems - 1; d++) {
                    const bit_select* bs = any_cast<const bit_select*>(pelems_md[d]);
                    RTLIL::SigSpec idx_sig = import_expression(bs->VpiIndex(), input_mapping);
                    if (!idx_sig.is_fully_const()) { all_const = false; break; }
                    int idx = idx_sig.as_const().as_int();
                    int lo = std::min(range_lr[d].first, range_lr[d].second);
                    int hi = std::max(range_lr[d].first, range_lr[d].second);
                    int size = hi - lo + 1;
                    lin_idx = lin_idx * size + (idx - lo);
                }
                if (all_const) {
                    int field_offset = 0, field_width = 0;
                    bool found_field = false;
                    for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                        auto m = (*st->Members())[i];
                        int mw = 0;
                        if (auto mts = m->Typespec())
                            if (auto ats = mts->Actual_typespec())
                                mw = get_width_from_typespec(ats, inst);
                        if (std::string(m->VpiName()) == field_name) {
                            field_width = mw;
                            found_field = true;
                            break;
                        }
                        field_offset += mw;
                    }
                    if (found_field && field_width > 0) {
                        int abs_start = (int)lin_idx * elem_width + field_offset;
                        if (abs_start >= 0 &&
                            abs_start + field_width <= base_wire->width) {
                            if (mode_debug)
                                log("    Multi-dim array struct field: %s[lin=%lld]"
                                    ".%s -> %s[%d+:%d]\n",
                                    base_name.c_str(), (long long)lin_idx,
                                    field_name.c_str(),
                                    base_wire->name.c_str(),
                                    abs_start, field_width);
                            return RTLIL::SigSpec(base_wire)
                                .extract(abs_start, field_width);
                        }
                    }
                }
            }
        }
    }

    // Handle unpacked-/packed-array element + scalar struct field access:
    // sig[i].field  — Path_elems pattern [bit_select(sig[i]), ref_obj(field)].
    // Returns the bit slice of the per-element wire `\sig[i]` corresponding
    // to `field` within the packed struct element.  Used by the
    // ucsbece154b_victim_cache test's `dll_d[i].valid && dll_d[i].tag`
    // priority-search loop.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pelems_rf = *uhdm_hier->Path_elems();
        if (pelems_rf[0]->UhdmType() == uhdmbit_select &&
            pelems_rf[1]->UhdmType() == uhdmref_obj) {
            const bit_select* bs = any_cast<const bit_select*>(pelems_rf[0]);
            const ref_obj*   fr = any_cast<const ref_obj*>(pelems_rf[1]);
            if (bs && fr && bs->VpiIndex()) {
                std::string base_name = std::string(bs->VpiName());
                std::string field_name = std::string(fr->VpiName());
                RTLIL::SigSpec idx_sig =
                    import_expression(bs->VpiIndex(), input_mapping);
                if (idx_sig.is_fully_const()) {
                    int elem_idx = idx_sig.as_const().as_int();
                    std::string elem_name = base_name + "[" +
                                            std::to_string(elem_idx) + "]";
                    RTLIL::Wire* elem_wire = nullptr;
                    if (name_map.count(elem_name))
                        elem_wire = name_map[elem_name];
                    // Find the struct typespec via the inner struct_net of
                    // the array_net (recorded in wire_map by the array_net
                    // handler), or via any other registered UHDM object that
                    // shares the flat base wire.
                    const UHDM::struct_typespec* st = nullptr;
                    RTLIL::Wire* base_flat_wire = name_map.count(base_name)
                                                    ? name_map[base_name]
                                                    : nullptr;
                    if (base_flat_wire) {
                        for (auto& kv : wire_map) {
                            if (kv.second != base_flat_wire) continue;
                            if (auto sn = dynamic_cast<const UHDM::struct_net*>(kv.first)) {
                                if (auto rts = sn->Typespec()) {
                                    if (auto ats = rts->Actual_typespec()) {
                                        if (ats->UhdmType() == uhdmstruct_typespec)
                                            st = any_cast<const UHDM::struct_typespec*>(ats);
                                    }
                                }
                            }
                            if (st) break;
                        }
                    }
                    if (elem_wire && st && st->Members()) {
                        // Find field offset (from LSB) and width by walking
                        // members in reverse (last listed = LSB).
                        int field_offset = 0;
                        int field_width  = 0;
                        bool found_field = false;
                        for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                            auto m = (*st->Members())[i];
                            int mw = 0;
                            if (auto mts = m->Typespec())
                                if (auto ats = mts->Actual_typespec())
                                    mw = get_width_from_typespec(ats, inst);
                            if (std::string(m->VpiName()) == field_name) {
                                field_width = mw;
                                found_field = true;
                                break;
                            }
                            field_offset += mw;
                        }
                        if (found_field && field_width > 0 &&
                            field_offset + field_width <= elem_wire->width) {
                            if (mode_debug)
                                log("    Array struct scalar field: %s[%d].%s -> "
                                    "%s[%d+:%d]\n",
                                    base_name.c_str(), elem_idx,
                                    field_name.c_str(),
                                    elem_wire->name.c_str(),
                                    field_offset, field_width);
                            return RTLIL::SigSpec(elem_wire)
                                .extract(field_offset, field_width);
                        }
                    }
                }
            }
        }
    }

    // Handle packed array element + struct field access: sig[i].field[hi:lo]
    // Path_elems pattern: [bit_select(sig[i]), part_select(field[hi:lo])]
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pelems = *uhdm_hier->Path_elems();
        if (pelems[0]->UhdmType() == uhdmbit_select &&
            pelems[1]->UhdmType() == uhdmpart_select) {
            const bit_select* bs = any_cast<const bit_select*>(pelems[0]);
            const part_select* ps = any_cast<const part_select*>(pelems[1]);
            if (bs && ps && bs->VpiIndex() && ps->Left_range() && ps->Right_range()) {
                std::string base_name = std::string(bs->VpiName());
                RTLIL::Wire* base_wire = name_map.count(base_name) ? name_map[base_name] : nullptr;
                if (!base_wire) {
                    // Try with current gen scope prefix
                    std::string gen_prefix = get_current_gen_scope();
                    if (!gen_prefix.empty()) {
                        std::string scoped = gen_prefix + "." + base_name;
                        if (name_map.count(scoped)) base_wire = name_map[scoped];
                    }
                }
                RTLIL::SigSpec idx_sig = import_expression(bs->VpiIndex(), input_mapping);
                RTLIL::SigSpec left_sig = import_expression(ps->Left_range(), input_mapping);
                RTLIL::SigSpec right_sig = import_expression(ps->Right_range(), input_mapping);
                std::string field_name = std::string(ps->VpiName());

                if (base_wire && idx_sig.is_fully_const() &&
                    left_sig.is_fully_const() && right_sig.is_fully_const()) {
                    int elem_idx = idx_sig.as_const().as_int();
                    int ps_left  = left_sig.as_const().as_int();
                    int ps_right = right_sig.as_const().as_int();

                    // Find UHDM object for base wire to get packed_array_typespec
                    const any* base_uhdm = nullptr;
                    for (auto& kv : wire_map) {
                        if (kv.second == base_wire) { base_uhdm = kv.first; break; }
                    }

                    // Get array ranges and element struct typespec from the UHDM object.
                    // packed_array_var has Ranges() directly and Elements() for child vars.
                    // For logic_net with packed_array_typespec, use the typespec chain.
                    const VectorOfrange* arr_ranges = nullptr;
                    const UHDM::struct_typespec* st = nullptr;
                    if (base_uhdm) {
                        if (auto pav = dynamic_cast<const UHDM::packed_array_var*>(base_uhdm)) {
                            arr_ranges = pav->Ranges();
                            // Get element struct type from first element (a struct_var)
                            if (pav->Elements() && !pav->Elements()->empty()) {
                                const any* elem0 = (*pav->Elements())[0];
                                const ref_typespec* elem_rts = nullptr;
                                if (auto sv = dynamic_cast<const UHDM::struct_var*>(elem0))
                                    elem_rts = sv->Typespec();
                                if (elem_rts) {
                                    const typespec* ets = elem_rts->Actual_typespec();
                                    if (ets && ets->UhdmType() == uhdmstruct_typespec)
                                        st = any_cast<const UHDM::struct_typespec*>(ets);
                                }
                            }
                        } else if (auto ln = dynamic_cast<const UHDM::logic_net*>(base_uhdm)) {
                            const ref_typespec* rts = ln->Typespec();
                            if (rts) {
                                const typespec* ts = rts->Actual_typespec();
                                if (ts && ts->UhdmType() == uhdmpacked_array_typespec) {
                                    auto pa = any_cast<const packed_array_typespec*>(ts);
                                    arr_ranges = pa->Ranges();
                                    if (pa->Elem_typespec()) {
                                        const typespec* ets = pa->Elem_typespec()->Actual_typespec();
                                        if (ets && ets->UhdmType() == uhdmstruct_typespec)
                                            st = any_cast<const UHDM::struct_typespec*>(ets);
                                    }
                                }
                            }
                        }
                    }

                    if (st && arr_ranges && !arr_ranges->empty()) {

                        // Compute element width from struct members
                        int elem_width = 0;
                        if (st->Members()) {
                            for (auto m : *st->Members()) {
                                if (auto mts = m->Typespec())
                                    if (auto ats = mts->Actual_typespec())
                                        elem_width += get_width_from_typespec(ats, inst);
                            }
                        }

                        // Array bounds from first range
                        const UHDM::range* arr_range = (*arr_ranges)[0];
                        RTLIL::SigSpec rl = import_expression(arr_range->Left_expr(), input_mapping);
                        RTLIL::SigSpec rr = import_expression(arr_range->Right_expr(), input_mapping);
                        if (rl.is_fully_const() && rr.is_fully_const() && elem_width > 0) {
                            int arr_l = rl.as_const().as_int();
                            int arr_r = rr.as_const().as_int();
                            int arr_low = std::min(arr_l, arr_r);

                            // Element offset from LSB of base wire
                            int elem_offset = (elem_idx - arr_low) * elem_width;

                            // Find field offset (from LSB of element) and width
                            int field_offset = 0;
                            bool found_field = false;
                            if (st->Members()) {
                                // Iterate in reverse (last member = LSB)
                                for (int i = (int)st->Members()->size()-1; i >= 0; i--) {
                                    auto m = (*st->Members())[i];
                                    int mw = 0;
                                    if (auto mts = m->Typespec())
                                        if (auto ats = mts->Actual_typespec())
                                            mw = get_width_from_typespec(ats, inst);
                                    if (std::string(m->VpiName()) == field_name) {
                                        (void)mw;
                                        found_field = true;
                                        break;
                                    }
                                    field_offset += mw;
                                }
                            }

                            if (found_field) {
                                int abs_start = elem_offset + field_offset + ps_right;
                                int abs_len   = ps_left - ps_right + 1;
                                if (mode_debug)
                                    log("    Packed array struct: %s[%d].%s[%d:%d] → wire[%d+:%d]\n",
                                        base_name.c_str(), elem_idx, field_name.c_str(),
                                        ps_left, ps_right, abs_start, abs_len);
                                if (abs_start >= 0 && abs_start + abs_len <= base_wire->width)
                                    return RTLIL::SigSpec(base_wire).extract(abs_start, abs_len);
                            }
                        }
                    }
                }
            }
        }
    }

    // Handle unpacked-array element + struct field indexed part-select:
    //   `a[i].field[base -: width]` (or `+:`).
    // Path_elems pattern: [bit_select(a[i]), indexed_part_select(field …)].
    // The unpacked array was flattened into per-element wires `\a[i]` by
    // `import_module`'s array_var handler, so the bit_select resolves to
    // a wire and the indexed_part_select extracts a slice of it.  Field
    // offset within the per-element wire is computed by walking the
    // struct typespec (members in reverse: last listed = LSB).
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pe_ips = *uhdm_hier->Path_elems();
        if (pe_ips[0]->UhdmType() == uhdmbit_select &&
            pe_ips[1]->UhdmType() == uhdmindexed_part_select) {
            const bit_select* bs = any_cast<const bit_select*>(pe_ips[0]);
            const indexed_part_select* ips =
                any_cast<const indexed_part_select*>(pe_ips[1]);
            if (bs && ips && bs->VpiIndex() && ips->Base_expr() && ips->Width_expr()) {
                std::string base_name = std::string(bs->VpiName());
                std::string field_name = std::string(ips->VpiName());

                RTLIL::SigSpec idx_sig = import_expression(bs->VpiIndex(), input_mapping);
                if (idx_sig.is_fully_const()) {
                    int elem_idx = idx_sig.as_const().as_int();
                    std::string elem_name =
                        base_name + "[" + std::to_string(elem_idx) + "]";
                    RTLIL::Wire* elem_wire =
                        name_map.count(elem_name) ? name_map[elem_name] : nullptr;
                    if (!elem_wire)
                        elem_wire = module->wire(RTLIL::escape_id(elem_name));

                    // Find the struct typespec via the bit_select's
                    // Actual_group (which resolves to the array_var,
                    // whose Variables()[0] is a struct_var with the
                    // typespec) — needed for field offset.  When the
                    // struct has only one field (or Actual_group is
                    // unavailable in the AllModules pass), default to
                    // the whole wire (offset 0, full width).
                    int field_offset = 0;
                    int field_width = elem_wire ? elem_wire->width : 0;
                    bool found_field = true;  // default to whole-wire fallback
                    if (elem_wire && bs->Actual_group()) {
                        const UHDM::struct_typespec* st = nullptr;
                        if (auto av = dynamic_cast<const UHDM::array_var*>(bs->Actual_group())) {
                            if (av->Variables() && !av->Variables()->empty()) {
                                if (auto sv = dynamic_cast<const UHDM::struct_var*>(av->Variables()->at(0))) {
                                    if (auto rts = sv->Typespec())
                                        if (auto ats = rts->Actual_typespec())
                                            if (ats->UhdmType() == uhdmstruct_typespec)
                                                st = any_cast<const UHDM::struct_typespec*>(ats);
                                }
                            }
                        }
                        if (st && st->Members() && !field_name.empty()) {
                            int off = 0;
                            bool match = false;
                            for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                                auto m = (*st->Members())[i];
                                int mw = 0;
                                if (auto mts = m->Typespec())
                                    if (auto ats = mts->Actual_typespec())
                                        mw = get_width_from_typespec(ats, inst);
                                if (std::string(m->VpiName()) == field_name) {
                                    field_offset = off;
                                    field_width = mw;
                                    match = true;
                                    break;
                                }
                                off += mw;
                            }
                            if (!match) {
                                // Field name didn't match — refuse the
                                // whole-wire fallback so we don't return
                                // garbage.
                                found_field = false;
                            }
                        }
                    }

                    if (elem_wire && found_field && field_width > 0) {
                        RTLIL::SigSpec field_slice =
                            RTLIL::SigSpec(elem_wire).extract(field_offset, field_width);
                        RTLIL::SigSpec base_expr = import_expression(ips->Base_expr(), input_mapping);
                        RTLIL::SigSpec width_expr = import_expression(ips->Width_expr(), input_mapping);
                        if (width_expr.is_fully_const()) {
                            int width = width_expr.as_const().as_int();
                            int type = ips->VpiIndexedPartSelectType();
                            if (base_expr.is_fully_const()) {
                                int base_val = base_expr.as_const().as_int();
                                int lsb = (type == vpiPosIndexed)
                                    ? base_val : base_val - width + 1;
                                if (lsb >= 0 && lsb + width <= field_slice.size()) {
                                    if (mode_debug)
                                        log("    Unpacked-array indexed-part-select: %s[%d].%s[%d%s%d] → wire[%d+:%d]\n",
                                            base_name.c_str(), elem_idx,
                                            field_name.c_str(), base_val,
                                            type == vpiPosIndexed ? "+:" : "-:",
                                            width, lsb, width);
                                    return field_slice.extract(lsb, width);
                                }
                            } else {
                                // Dynamic base — emit `$shiftx`.
                                int A_width = field_slice.size();
                                RTLIL::SigSpec shift_amount = base_expr;
                                if (type == vpiNegIndexed) {
                                    // lsb = base - (width - 1)
                                    RTLIL::SigSpec sub = base_expr;
                                    sub.extend_u0(32);
                                    RTLIL::Wire* sub_w = module->addWire(NEW_ID, 32);
                                    module->addSub(NEW_ID, sub,
                                        RTLIL::SigSpec(RTLIL::Const(width - 1, 32)),
                                        sub_w, true);
                                    shift_amount = RTLIL::SigSpec(sub_w);
                                }
                                RTLIL::Wire* out = module->addWire(NEW_ID, width);
                                RTLIL::Cell* sx = module->addCell(NEW_ID, ID($shiftx));
                                sx->setParam(ID::A_SIGNED, 0);
                                sx->setParam(ID::B_SIGNED, 1);
                                sx->setParam(ID::A_WIDTH, A_width);
                                sx->setParam(ID::B_WIDTH, shift_amount.size());
                                sx->setParam(ID::Y_WIDTH, width);
                                sx->setPort(ID::A, field_slice);
                                sx->setPort(ID::B, shift_amount);
                                sx->setPort(ID::Y, RTLIL::SigSpec(out));
                                return RTLIL::SigSpec(out);
                            }
                        }
                    }
                }
            }
        }
    }

    // Handle struct field access with bit_select / part_select on a field
    // that is a packed array.  Path_elems pattern:
    //   `s.field[i]`     → [ref_obj(s), bit_select(field, idx=i)]
    //   `s.field[hi:lo]` → [ref_obj(s), part_select(field, [hi:lo])]
    // where `s` is a packed struct whose `field` is `logic [N-1:0][M-1:0]`
    // or `logic4 [N-1:0]`.  Walk the struct typespec to find `field`'s bit
    // offset, compute the element width from the field's typespec
    // (Elem_typespec or first range), then return the slice on the flat
    // base wire.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pe = *uhdm_hier->Path_elems();
        bool shape_ok =
            pe[0]->UhdmType() == uhdmref_obj &&
            (pe[1]->UhdmType() == uhdmbit_select ||
             pe[1]->UhdmType() == uhdmpart_select ||
             pe[1]->UhdmType() == uhdmvar_select);
        if (shape_ok) {
            const ref_obj* base_ref = any_cast<const ref_obj*>(pe[0]);
            std::string base_name = std::string(base_ref->VpiName());
            std::string field_name;
            if (pe[1]->UhdmType() == uhdmbit_select)
                field_name = std::string(
                    any_cast<const bit_select*>(pe[1])->VpiName());
            else if (pe[1]->UhdmType() == uhdmvar_select)
                field_name = std::string(
                    any_cast<const var_select*>(pe[1])->VpiName());
            else
                field_name = std::string(
                    any_cast<const part_select*>(pe[1])->VpiName());

            RTLIL::Wire* base_wire = name_map.count(base_name)
                                         ? name_map[base_name]
                                         : nullptr;

            // Find the base's UHDM object (must be a net/var with a
            // struct_typespec) so we can walk its members.
            const UHDM::struct_typespec* st = nullptr;
            if (base_wire) {
                for (auto& kv : wire_map) {
                    if (kv.second != base_wire) continue;
                    const ref_typespec* rts = nullptr;
                    if (auto ln = dynamic_cast<const UHDM::logic_net*>(kv.first))
                        rts = ln->Typespec();
                    else if (auto lv = dynamic_cast<const UHDM::logic_var*>(kv.first))
                        rts = lv->Typespec();
                    else if (auto sv = dynamic_cast<const UHDM::struct_var*>(kv.first))
                        rts = sv->Typespec();
                    else if (auto sn = dynamic_cast<const UHDM::struct_net*>(kv.first))
                        rts = sn->Typespec();
                    if (rts) {
                        if (auto ats = rts->Actual_typespec()) {
                            if (ats->UhdmType() == uhdmstruct_typespec)
                                st = any_cast<const UHDM::struct_typespec*>(ats);
                        }
                    }
                    if (st) break;
                }
            }

            if (base_wire && st && st->Members()) {
                // Find field's offset (from LSB; last listed member = LSB)
                // and its typespec.
                int field_offset = 0;
                int field_width = 0;
                const UHDM::typespec* field_ts_actual = nullptr;
                bool found_field = false;
                for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                    auto m = (*st->Members())[i];
                    int mw = 0;
                    const UHDM::typespec* mts_actual = nullptr;
                    if (auto mts = m->Typespec())
                        if (auto ats = mts->Actual_typespec()) {
                            mts_actual = ats;
                            mw = get_width_from_typespec(ats, inst);
                        }
                    if (std::string(m->VpiName()) == field_name) {
                        field_ts_actual = mts_actual;
                        field_width = mw;
                        found_field = true;
                        break;
                    }
                    field_offset += mw;
                }
                // The field's typespec may be `logic_typespec` (logic / reg
                // declarations) or `bit_typespec` (bit / byte declarations
                // — Surelog routes `bit [N:0]` through a separate node that
                // exposes `Ranges()` but no `Elem_typespec()`).  Both share
                // the same outer-range layout, so collect Ranges + (optional)
                // Elem_typespec once and reuse the slice arithmetic.
                const UHDM::VectorOfrange* field_ranges = nullptr;
                const UHDM::ref_typespec* field_elem_rts = nullptr;
                if (found_field && field_ts_actual) {
                    if (auto lt = dynamic_cast<const UHDM::logic_typespec*>(field_ts_actual)) {
                        field_ranges = lt->Ranges();
                        field_elem_rts = lt->Elem_typespec();
                    } else if (auto bt = dynamic_cast<const UHDM::bit_typespec*>(field_ts_actual)) {
                        field_ranges = bt->Ranges();
                    } else if (auto at = dynamic_cast<const UHDM::array_typespec*>(field_ts_actual)) {
                        // Unpacked array nested in a packed struct (Yosys
                        // extension): array_typespec carries the unpacked
                        // dimension(s) in Ranges() and the per-element
                        // typespec (e.g., bit [7:0]) in Elem_typespec.
                        field_ranges = at->Ranges();
                        field_elem_rts = at->Elem_typespec();
                    } else if (auto pat = dynamic_cast<const UHDM::packed_array_typespec*>(field_ts_actual)) {
                        // Typedef'd packed array field (e.g., `bit8_t [5:0] a`
                        // where `typedef bit [7:0] bit8_t`).  PR 5's Surelog
                        // fix wraps the typedef in a packed_array_typespec
                        // exposing Ranges() for the outer dim and
                        // Elem_typespec() for the typedef'd element.
                        field_ranges = pat->Ranges();
                        field_elem_rts = pat->Elem_typespec();
                    }
                }
                if (field_ranges) {
                    int elem_width = 1;
                    int range_left = 0, range_right = 0;
                    bool have_outer_range = false;
                    if (!field_ranges->empty()) {
                        auto r0 = (*field_ranges)[0];
                        if (r0->Left_expr() && r0->Right_expr()) {
                            RTLIL::SigSpec ls = import_expression(r0->Left_expr(), input_mapping);
                            RTLIL::SigSpec rs = import_expression(r0->Right_expr(), input_mapping);
                            if (ls.is_fully_const() && rs.is_fully_const()) {
                                range_left = ls.as_int();
                                range_right = rs.as_int();
                                have_outer_range = true;
                            }
                        }
                    }
                    int outer_low = std::min(range_left, range_right);
                    int outer_high = std::max(range_left, range_right);
                    bool ascending = range_left < range_right;  // [0:7]-style
                    // For a multi-range typespec (e.g.,
                    // `packed_array_typespec` with Ranges = [[0:7], [1:0]]),
                    // Elem_typespec is the LEAF after consuming every
                    // dimension, not the element after one dimension —
                    // using it would give the leaf width and ignore the
                    // inner array dims.  Prefer `field_width / outer_size`
                    // unless this is genuinely a single-dim field, where
                    // Elem_typespec is more reliable than the divide.
                    if (have_outer_range && field_ranges->size() > 1) {
                        elem_width = field_width / (outer_high - outer_low + 1);
                    } else if (field_elem_rts && field_elem_rts->Actual_typespec()) {
                        elem_width = get_width_from_typespec(
                            field_elem_rts->Actual_typespec(), inst);
                    } else if (have_outer_range) {
                        elem_width = field_width / (outer_high - outer_low + 1);
                    }
                    if (elem_width <= 0) elem_width = 1;

                    // Position-from-LSB of element index `i` in the field.
                    // The leftmost-declared element occupies the high bits
                    // and the rightmost-declared occupies the low bits, so
                    // - descending [L:R] (L>=R): pos(i) = i - R
                    // - ascending  [L:R] (L<R):  pos(i) = R - i
                    auto pos_of = [&](int i) {
                        return ascending ? (range_right - i)
                                         : (i - range_right);
                    };

                    if (pe[1]->UhdmType() == uhdmbit_select) {
                        const bit_select* bs = any_cast<const bit_select*>(pe[1]);
                        RTLIL::SigSpec idx_sig = import_expression(bs->VpiIndex(), input_mapping);
                        if (idx_sig.is_fully_const() && have_outer_range) {
                            int idx = idx_sig.as_const().as_int();
                            int abs_start = field_offset + pos_of(idx) * elem_width;
                            if (abs_start >= 0 &&
                                abs_start + elem_width <= base_wire->width) {
                                if (mode_debug)
                                    log("    Struct field bit-select: %s.%s[%d] → "
                                        "%s[%d+:%d]\n",
                                        base_name.c_str(), field_name.c_str(), idx,
                                        base_wire->name.c_str(), abs_start, elem_width);
                                return RTLIL::SigSpec(base_wire).extract(abs_start, elem_width);
                            }
                        }
                        // Dynamic index: emit $shiftx reading the field slice.
                        // shift = pos_of(idx) * elem_width (signed); out-of-range
                        // indices produce X via $shiftx with signed B.
                        if (!idx_sig.is_fully_const() && have_outer_range &&
                            field_offset + field_width <= base_wire->width) {
                            // Use the currently-tracked combinational value of
                            // the base if available, so reads see prior writes
                            // within the same always_comb block.
                            RTLIL::SigSpec base_sig(base_wire);
                            if (input_mapping) {
                                auto it = input_mapping->find(base_name);
                                if (it != input_mapping->end() &&
                                    it->second.size() == base_wire->width)
                                    base_sig = it->second;
                            }
                            RTLIL::SigSpec field_slice =
                                base_sig.extract(field_offset, field_width);
                            int shamt_w = std::max(idx_sig.size() + 4, 32);
                            RTLIL::SigSpec idx_ext = idx_sig;
                            idx_ext.extend_u0(shamt_w, false);
                            RTLIL::Wire* pos_w = module->addWire(NEW_ID, shamt_w);
                            if (ascending) {
                                RTLIL::SigSpec rr_sig(RTLIL::Const(range_right, shamt_w));
                                module->addSub(NEW_ID, rr_sig, idx_ext,
                                               pos_w, true);
                            } else {
                                RTLIL::SigSpec rr_sig(RTLIL::Const(range_right, shamt_w));
                                module->addSub(NEW_ID, idx_ext, rr_sig,
                                               pos_w, true);
                            }
                            RTLIL::Wire* shift_w = module->addWire(NEW_ID, shamt_w);
                            module->addMul(NEW_ID, RTLIL::SigSpec(pos_w),
                                           RTLIL::SigSpec(RTLIL::Const(elem_width, shamt_w)),
                                           shift_w, true);
                            RTLIL::Wire* result_w = module->addWire(NEW_ID, elem_width);
                            module->addShiftx(NEW_ID, field_slice,
                                              RTLIL::SigSpec(shift_w),
                                              RTLIL::SigSpec(result_w), true);
                            if (mode_debug)
                                log("    Struct field dynamic bit-select: %s.%s[<dyn>] → "
                                    "$shiftx(%s[%d+:%d])\n",
                                    base_name.c_str(), field_name.c_str(),
                                    base_wire->name.c_str(),
                                    field_offset, field_width);
                            return RTLIL::SigSpec(result_w);
                        }
                    } else if (pe[1]->UhdmType() == uhdmvar_select) {
                        // `s.field[i0][i1]...[iK-1]` — chained bit-selects
                        // on a multi-dim packed array field.  Walk Ranges()
                        // dimension by dimension, applying pos_of for each
                        // index and shrinking the slice width.
                        const var_select* vs = any_cast<const var_select*>(pe[1]);
                        if (vs->Exprs() && field_ranges &&
                            vs->Exprs()->size() <= field_ranges->size()) {
                            int abs_start = field_offset;
                            int slice_width = field_width;
                            bool ok = true;
                            for (size_t d = 0; d < vs->Exprs()->size() && ok; d++) {
                                auto rd = (*field_ranges)[d];
                                if (!rd->Left_expr() || !rd->Right_expr()) { ok = false; break; }
                                RTLIL::SigSpec lls = import_expression(rd->Left_expr(), input_mapping);
                                RTLIL::SigSpec rrs = import_expression(rd->Right_expr(), input_mapping);
                                if (!lls.is_fully_const() || !rrs.is_fully_const()) { ok = false; break; }
                                int rl = lls.as_int();
                                int rr = rrs.as_int();
                                int rlow = std::min(rl, rr);
                                int rhigh = std::max(rl, rr);
                                int rsize = rhigh - rlow + 1;
                                bool rasc = rl < rr;
                                RTLIL::SigSpec idx_sig =
                                    import_expression((*vs->Exprs())[d], input_mapping);
                                if (!idx_sig.is_fully_const()) { ok = false; break; }
                                int idx = idx_sig.as_const().as_int();
                                int pos = rasc ? (rr - idx) : (idx - rr);
                                int sub_width = slice_width / rsize;
                                abs_start += pos * sub_width;
                                slice_width = sub_width;
                            }
                            if (ok && abs_start >= 0 &&
                                abs_start + slice_width <= base_wire->width) {
                                if (mode_debug)
                                    log("    Struct field var-select: %s.%s[...] → "
                                        "%s[%d+:%d]\n",
                                        base_name.c_str(), field_name.c_str(),
                                        base_wire->name.c_str(), abs_start, slice_width);
                                return RTLIL::SigSpec(base_wire).extract(abs_start, slice_width);
                            }
                        }
                    } else {
                        const part_select* ps = any_cast<const part_select*>(pe[1]);
                        RTLIL::SigSpec ls = import_expression(ps->Left_range(), input_mapping);
                        RTLIL::SigSpec rs = import_expression(ps->Right_range(), input_mapping);
                        if (ls.is_fully_const() && rs.is_fully_const() && have_outer_range) {
                            int ps_left = ls.as_int();
                            int ps_right = rs.as_int();
                            int pos_l = pos_of(ps_left);
                            int pos_r = pos_of(ps_right);
                            int lsb_pos = std::min(pos_l, pos_r);
                            int abs_start = field_offset + lsb_pos * elem_width;
                            int abs_len =
                                (std::abs(ps_left - ps_right) + 1) * elem_width;
                            if (abs_start >= 0 &&
                                abs_start + abs_len <= base_wire->width) {
                                if (mode_debug)
                                    log("    Struct field part-select: %s.%s[%d:%d] → "
                                        "%s[%d+:%d]\n",
                                        base_name.c_str(), field_name.c_str(),
                                        ps_left, ps_right,
                                        base_wire->name.c_str(), abs_start, abs_len);
                                return RTLIL::SigSpec(base_wire).extract(abs_start, abs_len);
                            }
                        }
                    }
                }
            }
        }
    }

    // Handle chained `s.field[idx0]...[idxK-1][hi:lo]` (bit/var-select
    // on a packed-array struct field, then part-select on the resulting
    // element).  This is the umbrella-test pattern (e.g. `s2.a[7][1:0]`
    // and `s3_lbl.a[0][0][2:3]`).  The bit/var_select narrows the field
    // through one or more outer dimensions; the part_select then carves
    // a slice out of the remaining element using its own range.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 3) {
        auto& pe3p = *uhdm_hier->Path_elems();
        if (pe3p[0]->UhdmType() == uhdmref_obj &&
            (pe3p[1]->UhdmType() == uhdmbit_select ||
             pe3p[1]->UhdmType() == uhdmvar_select) &&
            pe3p[2]->UhdmType() == uhdmpart_select) {
            const ref_obj* base_ref = any_cast<const ref_obj*>(pe3p[0]);
            const part_select* ps   = any_cast<const part_select*>(pe3p[2]);
            std::string base_name  = std::string(base_ref->VpiName());
            // Collect index expressions from bit_select or var_select.
            std::vector<const UHDM::expr*> idx_exprs;
            std::string field_name;
            if (pe3p[1]->UhdmType() == uhdmbit_select) {
                auto bs = any_cast<const bit_select*>(pe3p[1]);
                field_name = std::string(bs->VpiName());
                if (bs->VpiIndex()) idx_exprs.push_back(bs->VpiIndex());
            } else {
                auto vs = any_cast<const var_select*>(pe3p[1]);
                field_name = std::string(vs->VpiName());
                if (vs->Exprs()) {
                    for (auto e : *vs->Exprs()) idx_exprs.push_back(e);
                }
            }

            RTLIL::Wire* base_wire = name_map.count(base_name)
                                         ? name_map[base_name] : nullptr;

            const UHDM::struct_typespec* st = nullptr;
            if (base_wire) {
                for (auto& kv : wire_map) {
                    if (kv.second != base_wire) continue;
                    const ref_typespec* rts = nullptr;
                    if (auto ln = dynamic_cast<const UHDM::logic_net*>(kv.first))    rts = ln->Typespec();
                    else if (auto lv = dynamic_cast<const UHDM::logic_var*>(kv.first))   rts = lv->Typespec();
                    else if (auto sv = dynamic_cast<const UHDM::struct_var*>(kv.first))  rts = sv->Typespec();
                    else if (auto sn = dynamic_cast<const UHDM::struct_net*>(kv.first))  rts = sn->Typespec();
                    if (rts) {
                        if (auto ats = rts->Actual_typespec()) {
                            if (ats->UhdmType() == uhdmstruct_typespec)
                                st = any_cast<const UHDM::struct_typespec*>(ats);
                        }
                    }
                    if (st) break;
                }
            }

            if (base_wire && st && st->Members() && !idx_exprs.empty() &&
                ps->Left_range() && ps->Right_range()) {
                // Walk struct members to find field offset and typespec.
                int field_offset = 0;
                int field_width = 0;
                const UHDM::typespec* field_ts = nullptr;
                bool found = false;
                for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                    auto m = (*st->Members())[i];
                    int mw = 0;
                    const UHDM::typespec* mts = nullptr;
                    if (auto mref = m->Typespec())
                        if (auto ats = mref->Actual_typespec()) {
                            mts = ats;
                            mw = get_width_from_typespec(ats, inst);
                        }
                    if (std::string(m->VpiName()) == field_name) {
                        field_ts = mts;
                        field_width = mw;
                        found = true;
                        break;
                    }
                    field_offset += mw;
                }

                // Flatten the field's dimension list across nested
                // packed_array_typespec / typedef chains so that
                // `bit3l_t [0:7][1:0]` (where `typedef bit [0:3] bit3l_t`)
                // exposes all three dimensions at once.
                std::vector<const UHDM::range*> flat_ranges;
                const UHDM::ref_typespec* field_elem_rts = nullptr;
                {
                    const UHDM::typespec* cur = field_ts;
                    while (cur) {
                        const UHDM::VectorOfrange* r = nullptr;
                        const UHDM::ref_typespec* next_rts = nullptr;
                        if (auto lt = dynamic_cast<const UHDM::logic_typespec*>(cur)) {
                            r = lt->Ranges();
                            next_rts = lt->Elem_typespec();
                        } else if (auto bt = dynamic_cast<const UHDM::bit_typespec*>(cur)) {
                            r = bt->Ranges();
                        } else if (auto at = dynamic_cast<const UHDM::array_typespec*>(cur)) {
                            r = at->Ranges();
                            next_rts = at->Elem_typespec();
                        } else if (auto pat = dynamic_cast<const UHDM::packed_array_typespec*>(cur)) {
                            r = pat->Ranges();
                            next_rts = pat->Elem_typespec();
                        }
                        if (r) for (auto rg : *r) flat_ranges.push_back(rg);
                        // Stop the descent if we used Ranges() but have no
                        // child typespec (logic_typespec multi-range form):
                        // each range is its own dimension and the leaf is
                        // 1-bit, so there's nothing further to flatten.
                        if (!next_rts) {
                            // Keep field_elem_rts for the part-select element
                            // range fallback even when there is no chain.
                            if (cur == field_ts) {
                                if (auto lt = dynamic_cast<const UHDM::logic_typespec*>(cur))
                                    field_elem_rts = lt->Elem_typespec();
                            }
                            break;
                        }
                        field_elem_rts = next_rts;
                        cur = next_rts->Actual_typespec();
                    }
                }
                const std::vector<const UHDM::range*>* field_ranges = &flat_ranges;

                if (found && !flat_ranges.empty() &&
                    flat_ranges.size() >= idx_exprs.size() && field_width > 0) {
                    // Walk dimensions one at a time using the index list.
                    int sub_offset = field_offset;
                    int sub_width = field_width;
                    bool ok = true;
                    for (size_t d = 0; d < idx_exprs.size() && ok; d++) {
                        auto rd = (*field_ranges)[d];
                        if (!rd->Left_expr() || !rd->Right_expr()) { ok = false; break; }
                        RTLIL::SigSpec ls = import_expression(rd->Left_expr(), input_mapping);
                        RTLIL::SigSpec rs = import_expression(rd->Right_expr(), input_mapping);
                        RTLIL::SigSpec idx = import_expression(idx_exprs[d], input_mapping);
                        if (!ls.is_fully_const() || !rs.is_fully_const() ||
                            !idx.is_fully_const()) { ok = false; break; }
                        int rl = ls.as_int();
                        int rr = rs.as_int();
                        int idx_v = idx.as_const().as_int();
                        int range_size = std::abs(rl - rr) + 1;
                        bool asc = rl < rr;
                        int pos = asc ? (rr - idx_v) : (idx_v - rr);
                        int slice_w = sub_width / range_size;
                        sub_offset += pos * slice_w;
                        sub_width = slice_w;
                    }
                    RTLIL::SigSpec pls = import_expression(ps->Left_range(), input_mapping);
                    RTLIL::SigSpec prs = import_expression(ps->Right_range(), input_mapping);
                    if (ok && pls.is_fully_const() && prs.is_fully_const()) {
                        // Element's range governs the part-select arithmetic.
                        // Source order of preference: Elem_typespec's first
                        // range; otherwise field_ranges[idx_exprs.size()]
                        // (the dimension just past the consumed ones).
                        int elem_rl = sub_width - 1, elem_rr = 0;
                        const UHDM::range* elem_range = nullptr;
                        if (idx_exprs.size() == 1 && field_elem_rts &&
                            field_elem_rts->Actual_typespec()) {
                            auto et = field_elem_rts->Actual_typespec();
                            const UHDM::VectorOfrange* erngs = nullptr;
                            if (auto elt = dynamic_cast<const UHDM::logic_typespec*>(et)) erngs = elt->Ranges();
                            else if (auto ebt = dynamic_cast<const UHDM::bit_typespec*>(et)) erngs = ebt->Ranges();
                            if (erngs && !erngs->empty()) elem_range = (*erngs)[0];
                        }
                        if (!elem_range && field_ranges->size() > idx_exprs.size()) {
                            elem_range = (*field_ranges)[idx_exprs.size()];
                        }
                        if (elem_range && elem_range->Left_expr() && elem_range->Right_expr()) {
                            RTLIL::SigSpec els = import_expression(elem_range->Left_expr(), input_mapping);
                            RTLIL::SigSpec ers = import_expression(elem_range->Right_expr(), input_mapping);
                            if (els.is_fully_const() && ers.is_fully_const()) {
                                elem_rl = els.as_int();
                                elem_rr = ers.as_int();
                            }
                        }
                        bool elem_asc = elem_rl < elem_rr;
                        int ps_left  = pls.as_int();
                        int ps_right = prs.as_int();
                        int p_l = elem_asc ? (elem_rr - ps_left)  : (ps_left  - elem_rr);
                        int p_r = elem_asc ? (elem_rr - ps_right) : (ps_right - elem_rr);
                        int lsb_pos = std::min(p_l, p_r);
                        int abs_start = sub_offset + lsb_pos;
                        int abs_len   = std::abs(ps_left - ps_right) + 1;
                        if (abs_start >= 0 &&
                            abs_start + abs_len <= base_wire->width) {
                            if (mode_debug)
                                log("    Struct field chained select: %s.%s[...][%d:%d] → "
                                    "%s[%d+:%d]\n",
                                    base_name.c_str(), field_name.c_str(),
                                    ps_left, ps_right,
                                    base_wire->name.c_str(), abs_start, abs_len);
                            return RTLIL::SigSpec(base_wire).extract(abs_start, abs_len);
                        }
                    }
                }
            }
        }
    }

    // First check if this is a generate hierarchy wire (e.g., blk[0].sub.x)
    // These are already created during generate scope import
    if (name_map.count(path_name)) {
        if (mode_debug)
            log("    Found wire in name_map: %s\n", name_map[path_name]->name.c_str());
        return RTLIL::SigSpec(name_map[path_name]);
    }
    
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
                    } else if (auto net_obj = dynamic_cast<const UHDM::net*>(struct_uhdm_obj)) {
                        struct_ref_typespec = net_obj->Typespec();
                    } else if (auto port_obj = dynamic_cast<const UHDM::port*>(struct_uhdm_obj)) {
                        struct_ref_typespec = port_obj->Typespec();
                    } else if (auto struct_var_obj = dynamic_cast<const UHDM::struct_var*>(struct_uhdm_obj)) {
                        struct_ref_typespec = struct_var_obj->Typespec();
                    } else if (auto union_var_obj = dynamic_cast<const UHDM::union_var*>(struct_uhdm_obj)) {
                        struct_ref_typespec = union_var_obj->Typespec();
                    }

                    if (struct_ref_typespec) {
                        const typespec* struct_typespec = struct_ref_typespec->Actual_typespec();
                        if (struct_typespec && (struct_typespec->UhdmType() == uhdmstruct_typespec ||
                                               struct_typespec->UhdmType() == uhdmunion_typespec)) {
                            bool is_union = (struct_typespec->UhdmType() == uhdmunion_typespec);
                            const VectorOftypespec_member* members = nullptr;
                            if (is_union) {
                                auto u_spec = any_cast<const UHDM::union_typespec*>(struct_typespec);
                                members = u_spec->Members();
                            } else {
                                auto s_spec = any_cast<const UHDM::struct_typespec*>(struct_typespec);
                                members = s_spec->Members();
                            }

                            if (mode_debug)
                                log("    Found %s typespec\n", is_union ? "union" : "struct");

                            // Find the first-level member
                            if (members) {
                                int first_member_offset = 0;
                                const typespec* first_member_typespec = nullptr;
                                bool found_first_member = false;

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

                                    // Only accumulate offset for structs, not unions
                                    if (!is_union)
                                        first_member_offset += member_width;
                                }

                                if (found_first_member && first_member_typespec &&
                                    (first_member_typespec->UhdmType() == uhdmstruct_typespec ||
                                     first_member_typespec->UhdmType() == uhdmunion_typespec)) {
                                    // Now find the second-level member
                                    bool nested_is_union = (first_member_typespec->UhdmType() == uhdmunion_typespec);
                                    const VectorOftypespec_member* nested_members = nullptr;
                                    if (nested_is_union) {
                                        auto nu_spec = any_cast<const UHDM::union_typespec*>(first_member_typespec);
                                        nested_members = nu_spec->Members();
                                    } else {
                                        auto ns_spec = any_cast<const UHDM::struct_typespec*>(first_member_typespec);
                                        nested_members = ns_spec->Members();
                                    }
                                    if (nested_members) {
                                        int second_member_offset = 0;
                                        int second_member_width = 0;
                                        bool found_second_member = false;

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

                                            // Only accumulate offset for structs, not unions
                                            if (!nested_is_union)
                                                second_member_offset += member_width;
                                        }

                                        if (found_second_member) {
                                            if (mode_debug)
                                                log("    Found nested member: total_offset=%d, width=%d\n",
                                                    first_member_offset + second_member_offset, second_member_width);

                                            // Return bit slice from the wire
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
                } else if (auto struct_var_obj = dynamic_cast<const UHDM::struct_var*>(base_uhdm_obj)) {
                    base_ref_typespec = struct_var_obj->Typespec();
                } else if (auto union_var_obj = dynamic_cast<const UHDM::union_var*>(base_uhdm_obj)) {
                    base_ref_typespec = union_var_obj->Typespec();
                }

                if (base_ref_typespec) {
                    base_typespec = base_ref_typespec->Actual_typespec();

                    // Check if this is a packed struct or union typespec
                    if (base_typespec && (base_typespec->UhdmType() == uhdmstruct_typespec ||
                                         base_typespec->UhdmType() == uhdmunion_typespec)) {
                        bool base_is_union = (base_typespec->UhdmType() == uhdmunion_typespec);
                        const VectorOftypespec_member* members = nullptr;
                        if (base_is_union) {
                            auto u_ts = any_cast<const UHDM::union_typespec*>(base_typespec);
                            members = u_ts->Members();
                        } else {
                            auto s_ts = any_cast<const UHDM::struct_typespec*>(base_typespec);
                            members = s_ts->Members();
                        }

                        if (mode_debug)
                            log("    Found %s typespec for base wire '%s'\n",
                                base_is_union ? "union" : "struct", base_name.c_str());

                        // Find the member
                        if (members) {
                            int bit_offset = 0;
                            int member_width = 0;
                            bool found_member = false;

                            // Iterate through members in reverse order (MSB to LSB for packed structs)
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

                                // Only accumulate offset for structs, not unions
                                if (!base_is_union)
                                    bit_offset += current_member_width;
                            }
                            
                            if (found_member) {
                                if (mode_debug)
                                    log("    Found packed member: offset=%d, width=%d\n", bit_offset, member_width);

                                // Return a bit slice of the base wire
                                return RTLIL::SigSpec(base_wire, bit_offset, member_width);
                            }
                        }
                    } else if (mode_debug) {
                        log("    Base wire typespec is not a struct/union (UhdmType=%s)\n",
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
                } else if (auto port_obj = dynamic_cast<const UHDM::port*>(struct_uhdm_obj)) {
                    ref_ts = port_obj->Typespec();
                } else if (auto struct_var_obj = dynamic_cast<const UHDM::struct_var*>(struct_uhdm_obj)) {
                    ref_ts = struct_var_obj->Typespec();
                } else if (auto union_var_obj = dynamic_cast<const UHDM::union_var*>(struct_uhdm_obj)) {
                    ref_ts = union_var_obj->Typespec();
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
        bool is_struct = current_ts && current_ts->UhdmType() == uhdmstruct_typespec;
        bool is_union = current_ts && current_ts->UhdmType() == uhdmunion_typespec;
        if (!is_struct && !is_union) {
            return false;
        }

        const VectorOftypespec_member* members = nullptr;
        if (is_struct) {
            auto struct_ts = any_cast<const struct_typespec*>(current_ts);
            members = struct_ts->Members();
        } else {
            auto union_ts = any_cast<const union_typespec*>(current_ts);
            members = union_ts->Members();
        }
        if (!members) {
            return false;
        }

        // Calculate offset within this level
        // For unions: offset is always 0. For structs: accumulate offset.
        int offset_in_level = 0;
        bool found = false;
        const typespec* found_member_ts = nullptr;

        // Iterate through members in reverse order (MSB to LSB for packed structs)
        for (int i = members->size() - 1; i >= 0; i--) {
            auto member = (*members)[i];
            std::string current_member_name = std::string(member->VpiName());

            if (current_member_name == member_name) {
                // Found the member
                if (auto ref_ts = member->Typespec()) {
                    if (auto actual_ts = ref_ts->Actual_typespec()) {
                        found_member_ts = actual_ts;
                        member_width = get_width_from_typespec(actual_ts, inst);
                    }
                }
                found = true;
                break;
            }

            // Only accumulate offset for structs, not unions
            if (is_struct) {
                if (auto ref_ts = member->Typespec()) {
                    if (auto actual_ts = ref_ts->Actual_typespec()) {
                        int width = get_width_from_typespec(actual_ts, inst);
                        offset_in_level += width;
                    }
                }
            }
        }

        if (!found) {
            return false;
        }

        // Add the offset within this level to the total offset
        bit_offset += offset_in_level;

        // For the next iteration, use the member's typespec
        current_ts = found_member_ts;
    }
    
    return member_width > 0;
}

YOSYS_NAMESPACE_END