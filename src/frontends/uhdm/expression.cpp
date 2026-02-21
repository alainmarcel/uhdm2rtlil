/*
 * Expression handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog expressions
 * including operations, constants, and references.
 */

#include "uhdm2rtlil.h"
#include <uhdm/logic_var.h>
#include <uhdm/integer_var.h>
#include <uhdm/ref_var.h>
#include <uhdm/logic_net.h>
#include <uhdm/logic_typespec.h>
#include <uhdm/net.h>
#include <uhdm/port.h>
#include <uhdm/struct_typespec.h>
#include <uhdm/typespec_member.h>
#include <uhdm/vpi_visitor.h>
#include <uhdm/assignment.h>
#include <uhdm/uhdm_vpi_user.h>
#include <uhdm/parameter.h>
#include <uhdm/uhdm_types.h>
#include <uhdm/integer_typespec.h>
#include <uhdm/range.h>
#include <uhdm/sys_func_call.h>
#include <uhdm/func_call.h>
#include <uhdm/function.h>
#include <uhdm/case_stmt.h>
#include <uhdm/case_item.h>
#include <uhdm/io_decl.h>
#include <uhdm/begin.h>
#include <uhdm/named_begin.h>
#include <uhdm/if_else.h>
#include <uhdm/var_select.h>
#include <uhdm/array_net.h>

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
            } else if (assign->Lhs()->UhdmType() == uhdmbit_select) {
                // Handle bit select assignment
                const bit_select* bs = any_cast<const bit_select*>(assign->Lhs());
                std::string base_name = std::string(bs->VpiName());
                
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
                        
                        if (idx >= 0 && idx < target_wire->width) {
                            lhs_sig = RTLIL::SigSpec(target_wire, idx, 1);
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
                            if (idx >= 0 && idx < base_sig.size()) {
                                lhs_sig = base_sig.extract(idx, 1);
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
                                // Check if this variable is in input_mapping (could be result or function name)
                                auto it = input_mapping.find(accumulator_var);
                                if (it != input_mapping.end() && assign->Rhs() && 
                                    assign->Rhs()->UhdmType() == uhdmoperation) {
                                    const operation* op = any_cast<const operation*>(assign->Rhs());
                                    if (op && op->VpiOpType() == vpiAddOp) {
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
                        // Initialize with the current value of the accumulator variable
                        auto it = input_mapping.find(accumulator_var);
                        if (it != input_mapping.end()) {
                            // Start with zero for the accumulator
                            current_accumulator = RTLIL::SigSpec(RTLIL::State::S0, it->second.size());
                            // Store in loop_accumulators so import_expression can use it
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
                if (func_name == "$signed" && args.size() == 1) {
                    // $signed just returns the argument with signed interpretation
                    // The signedness will be handled by the operation that uses it
                    log_debug("UHDM: $signed returning argument of size %d\n", args[0].size());
                    return args[0];
                } else if (func_name == "$unsigned" && args.size() == 1) {
                    // $unsigned just returns the argument with unsigned interpretation
                    return args[0];
                } else if (func_name == "$floor" && args.size() == 1) {
                    // $floor for integer arguments is identity (integer division already truncates)
                    return args[0];
                } else if (func_name == "$ceil" && args.size() == 1) {
                    // $ceil for integer arguments is identity
                    return args[0];
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

                // Get the function definition
                const function* func_def = fc->Function();
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
                int ret_width = 1;
                if (func_def->Return()) {
                    ret_width = get_width(func_def->Return(), current_instance);
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
                    // Evaluate function at compile time for optimization
                    log("UHDM: Evaluating function %s at compile time (all arguments are constant)\n", func_name.c_str());
                    std::map<std::string, RTLIL::Const> output_params;
                    RTLIL::Const result = evaluate_function_call(func_def, const_args, output_params);

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
                    const_val.resize(size, RTLIL::State::S0);
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

// Mark the output wire of a SigSpec as signed
static void mark_result_signed(RTLIL::SigSpec& result) {
    if (result.is_wire()) {
        result.as_wire()->is_signed = true;
    }
}

// Import operation
RTLIL::SigSpec UhdmImporter::import_operation(const operation* uhdm_op, const UHDM::scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    int op_type = uhdm_op->VpiOpType();

    // Handle side-effect operations before reduceExpr (which doesn't understand them)
    if (op_type == vpiPostIncOp || op_type == vpiPreIncOp ||
        op_type == vpiPostDecOp || op_type == vpiPreDecOp) {
        // Inc/dec as expression: emit side-effect and return updated value
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

            // Emit side-effect: target_wire = result
            if (current_comb_process) {
                emit_comb_assign(target_wire, result, current_comb_process);
            }

            return result;
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

    // Try to reduce it first (for non-side-effect operations)
    ExprEval eval;
    bool invalidValue = false;
    expr* res = eval.reduceExpr(uhdm_op, invalidValue, inst, uhdm_op->VpiParent(), true);
    if (res && res->UhdmType() == uhdmconstant) {
        return import_constant(dynamic_cast<const UHDM::constant*>(res));
    }
    
    if (mode_debug)
        log("    Importing operation: %d\n", op_type);
    
    // Get operands
    std::vector<RTLIL::SigSpec> operands;
    if (uhdm_op->Operands()) {
        if (op_type == vpiConditionOp) { 
            log("UHDM: ConditionOp (type=%d) has %d operands\n", op_type, (int)uhdm_op->Operands()->size());
        }
        for (auto operand : *uhdm_op->Operands()) {
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
    
    // Check if all operands are constant - if so, we can evaluate the operation
    // But only do this when we're in a function context with loop variables
    bool all_const = true;
    for (const auto& op : operands) {
        if (!op.is_fully_const()) {
            all_const = false;
            break;
        }
    }
    
    // If all operands are constant AND we have loop variables (indicating we're in a loop unrolling context),
    // evaluate the operation and return a constant
    if (all_const && operands.size() > 0 && !loop_values.empty()) {
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
        case vpiMinusOp:
            // Unary minus operation
            if (operands.size() == 1) {
                log_debug("UHDM: Found vpiMinusOp (unary minus) with operand size %d\n", operands[0].size());
                if (operands[0].size() == 0) {
                    log_warning("vpiMinusOp has empty operand!\n");
                    return RTLIL::SigSpec();
                }
                // Create a negation operation
                int result_width = operands[0].size();
                RTLIL::SigSpec result = module->addWire(NEW_ID, result_width);
                
                // Check if operand is signed - for unary minus with $signed, assume signed
                bool is_signed = true;  // Default to signed for unary minus
                
                std::string cell_name = generate_cell_name(uhdm_op, "neg");
                module->addNeg(RTLIL::escape_id(cell_name), operands[0], result, is_signed);
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
                    bool is_signed = check_operands_signed(operands);
                    std::string cell_name = generate_cell_name(uhdm_op, "and");
                    RTLIL::SigSpec result = module->And(RTLIL::escape_id(cell_name), operands[0], operands[1], is_signed);
                    if (is_signed) mark_result_signed(result);
                    return result;
                }
            break;
        case vpiBitOrOp:
            if (operands.size() == 2)
                {
                    bool is_signed = check_operands_signed(operands);
                    std::string cell_name = generate_cell_name(uhdm_op, "or");
                    RTLIL::SigSpec result = module->Or(RTLIL::escape_id(cell_name), operands[0], operands[1], is_signed);
                    if (is_signed) mark_result_signed(result);
                    return result;
                }
            break;
        case vpiBitXorOp:
            if (operands.size() == 2)
                {
                    bool is_signed = check_operands_signed(operands);
                    std::string cell_name = generate_cell_name(uhdm_op, "xor");
                    RTLIL::SigSpec result = module->Xor(RTLIL::escape_id(cell_name), operands[0], operands[1], is_signed);
                    if (is_signed) mark_result_signed(result);
                    return result;
                }
            break;
        case vpiBitNegOp:
            if (operands.size() == 1)
                {
                    bool is_signed = check_operands_signed(operands);
                    std::string cell_name = generate_cell_name(uhdm_op, "not");
                    RTLIL::SigSpec result = module->Not(RTLIL::escape_id(cell_name), operands[0], is_signed);
                    if (is_signed) mark_result_signed(result);
                    return result;
                }
            break;
        case vpiBitXNorOp:  // Both vpiBitXNorOp and vpiBitXnorOp are the same
            if (operands.size() == 2)
                {
                    bool is_signed = check_operands_signed(operands);
                    std::string cell_name = generate_cell_name(uhdm_op, "xnor");
                    RTLIL::SigSpec result = module->Xnor(RTLIL::escape_id(cell_name), operands[0], operands[1], is_signed);
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
                // For addition, create an add cell
                // Use context width from LHS if available (Verilog context-determined sizing)
                int result_width = std::max(operands[0].size(), operands[1].size());
                if (expression_context_width > result_width)
                    result_width = expression_context_width;
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
                
                std::string cell_name = generate_cell_name(uhdm_op, "add");
                module->addAdd(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
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
                
                std::string cell_name = generate_cell_name(uhdm_op, "sub");
                module->addSub(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                return result;
            }
            break;
        case vpiDivOp:
            if (operands.size() == 2) {
                // For division, create a div cell
                int result_width = operands[0].size();
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
                
                std::string cell_name = generate_cell_name(uhdm_op, "div");
                module->addDiv(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
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
                
                std::string cell_name = generate_cell_name(uhdm_op, "mul");
                module->addMul(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
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
                std::string cell_name = generate_cell_name(uhdm_op, "pow");
                module->addPow(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                return result;
            }
            break;
        case vpiLShiftOp:
            if (operands.size() == 2) {
                // Left shift operation: a << b
                // Result width is typically the same as the first operand
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
                
                // Use Shl cell for left shift operation
                std::string cell_name = generate_cell_name(uhdm_op, "shl");
                module->addShl(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                return result;
            }
            break;
        case vpiRShiftOp:
            if (operands.size() == 2) {
                // Right shift operation: a >> b
                // Result width is typically the same as the first operand
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
                
                // Use Shr cell for right shift operation (or Sshr for signed)
                if (is_signed) {
                    std::string cell_name = generate_cell_name(uhdm_op, "sshr");
                    module->addSshr(RTLIL::escape_id(cell_name), operands[0], operands[1], result, is_signed);
                } else {
                    std::string cell_name = generate_cell_name(uhdm_op, "shr");
                    module->addShr(RTLIL::escape_id(cell_name), operands[0], operands[1], result, false);
                }
                return result;
            }
            break;
        case vpiEqOp:
            if (operands.size() == 2)
                //return module->Eq(NEW_ID, operands[0], operands[1]);
            {
                // Create output wire for the comparison with proper naming
                std::string wire_name = generate_cell_name(uhdm_op, "eq") + "_Y";
                RTLIL::Wire* result_wire = module->addWire(RTLIL::escape_id(wire_name), 1);
                add_src_attribute(result_wire->attributes, uhdm_op);
                
                // Create cell with source location-based name
                std::string cell_name = generate_cell_name(uhdm_op, "eq");
                
                RTLIL::Cell* eq_cell = module->addEq(RTLIL::escape_id(cell_name), 
                    operands[0], operands[1], result_wire);
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
            if (operands.size() == 2)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "lt");
                    return module->Lt(RTLIL::escape_id(cell_name), operands[0], operands[1]);
                }
            break;
        case vpiLeOp:
            if (operands.size() == 2)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "le");
                    return module->Le(RTLIL::escape_id(cell_name), operands[0], operands[1]);
                }
            break;
        case vpiGtOp:
            if (operands.size() == 2)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "gt");
                    return module->Gt(RTLIL::escape_id(cell_name), operands[0], operands[1]);
                }
            break;
        case vpiGeOp:
            if (operands.size() == 2)
                {
                    std::string cell_name = generate_cell_name(uhdm_op, "ge");
                    return module->Ge(RTLIL::escape_id(cell_name), operands[0], operands[1]);
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

                // Check if the true/false operands are signed
                std::vector<RTLIL::SigSpec> value_operands = {operands[1], operands[2]};
                bool is_signed = check_operands_signed(value_operands);

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
                            for (auto bit : const_val) {
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
                            const_val.resize(target_width, RTLIL::State::S0);
                        } else if (const_val.size() > target_width) {
                            // Truncate
                            const_val.resize(target_width, RTLIL::State::S0);
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
            
            // Parse value from format like "INT:0", "UINT:1", etc.
            RTLIL::Const enum_value;
            if (!val_str.empty()) {
                size_t colon_pos = val_str.find(':');
                if (colon_pos != std::string::npos) {
                    std::string value_part = val_str.substr(colon_pos + 1);
                    // Parse as integer
                    enum_value = RTLIL::Const(std::stoi(value_part), 32);
                } else {
                    // Try to parse as integer directly
                    enum_value = RTLIL::Const(std::stoi(val_str), 32);
                }
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

                // Parse value from format like "UINT:0", "UINT:1", "HEX:AA", etc.
                if (!val_str.empty()) {
                    size_t colon_pos = val_str.find(':');
                    if (colon_pos != std::string::npos) {
                        std::string type_part = val_str.substr(0, colon_pos);
                        std::string value_part = val_str.substr(colon_pos + 1);

                        if (type_part == "HEX") {
                            param_value = RTLIL::Const::from_string(value_part);
                        } else if (type_part == "BIN") {
                            param_value = RTLIL::Const::from_string(value_part);
                        } else {
                            param_value = RTLIL::Const(std::stoi(value_part), 32);
                        }
                    } else {
                        param_value = RTLIL::Const(std::stoi(val_str), 32);
                    }
                } else {
                    // If no VpiValue, check if there's an expression
                    if (param->Expr()) {
                        RTLIL::SigSpec expr_val = import_expression(any_cast<const expr*>(param->Expr()));
                        if (expr_val.is_fully_const()) {
                            param_value = expr_val.as_const();
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
    } else {
        // If we can't get the name directly, try importing the parent as an expression
        base = import_expression(any_cast<const expr*>(parent), input_mapping);
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
    RTLIL::SigSpec index = import_expression(uhdm_bit->VpiIndex(), input_mapping);
    
    if (index.size() == 0) {
        log_warning("Bit select index expression returned empty SigSpec for signal %s\n", signal_name.c_str());
        return RTLIL::SigSpec();
    }
    
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
    int element_width = 1;
    int outer_left = -1, outer_right = -1;

    // First check wire attributes set during port/net import
    if (wire && wire->attributes.count(RTLIL::escape_id("packed_elem_width"))) {
        element_width = wire->attributes.at(RTLIL::escape_id("packed_elem_width")).as_int();
        outer_left = wire->attributes.at(RTLIL::escape_id("packed_outer_left")).as_int();
        outer_right = wire->attributes.at(RTLIL::escape_id("packed_outer_right")).as_int();
    }

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
    } else {
        // If we can't get the name directly, try importing the parent as an expression
        base = import_expression(any_cast<const expr*>(parent), input_mapping);
    }
    
    log("      Base signal width: %d\n", base.size());
    
    // Get the base index expression
    RTLIL::SigSpec base_index = import_expression(uhdm_indexed->Base_expr(), input_mapping);
    log("      Base index: %s\n", base_index.is_fully_const() ? 
        std::to_string(base_index.as_const().as_int()).c_str() : "non-const");
    
    // Get the width expression
    RTLIL::SigSpec width_expr = import_expression(uhdm_indexed->Width_expr(), input_mapping);
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
                    if (actual->UhdmType() == uhdmlogic_net) {
                        const logic_net* net = any_cast<const logic_net*>(actual);
                        std::string actual_name = std::string(net->VpiName());
                        
                        // Try to find it with generate scope prefix
                        std::string_view full_name = net->VpiFullName();
                        if (!full_name.empty()) {
                            std::string full_str = std::string(full_name);
                            log("          logic_net full name: %s\n", full_str.c_str());
                            // Extract module-relative path (remove work@module_name. prefix)
                            size_t module_end = full_str.find('.');
                            if (module_end != std::string::npos) {
                                std::string signal_path = full_str.substr(module_end + 1);
                                log("          Extracted signal path: %s\n", signal_path.c_str());
                                if (name_map.count(signal_path)) {
                                    log("          Found in name_map, resolving to: %s\n", name_map[signal_path]->name.c_str());
                                    return RTLIL::SigSpec(name_map[signal_path]);
                                } else {
                                    log("          Not found in name_map\n");
                                }
                            }
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