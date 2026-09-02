/*
 * Expression handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog expressions
 * including operations, constants, and references.
 */

#include "uhdm2rtlil.h"
#include <algorithm>
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
#include <uhdm/scope.h>
#include <uhdm/tagged_pattern.h>
#include <uhdm/return_stmt.h>
#include <uhdm/struct_net.h>
#include <uhdm/modport.h>
#include <uhdm/array_typespec.h>
#include <uhdm/module_inst.h>
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

        // Each arm runs on a copy of the variable mapping; SSA renames made
        // inside an arm are phi-merged after the switch (see uhdmif_else).
        std::map<std::string, RTLIL::SigSpec> pre_map = input_mapping;
        std::vector<std::pair<RTLIL::CaseRule*, std::map<std::string, RTLIL::SigSpec>>> arm_maps;

        if (cs->Case_items()) {
            for (auto item : *cs->Case_items()) {
                const case_item* ci = any_cast<const case_item*>(item);
                if (!ci) continue;
                input_mapping = pre_map;

                RTLIL::CaseRule* item_case = new RTLIL::CaseRule;
                
                // Add source location attribute for the case item
                add_src_attribute(item_case->attributes, ci);
                
                // Get the case value(s).  A multi-label arm
                // (`EQ, NE, LTS: …`) has SEVERAL VpiExprs — taking only
                // at(0) matched just the first label (ariane_pkg
                // op_is_branch mis-classified NE/LTS/… as non-branches).
                // `case … inside` additionally wraps a label list in ONE
                // vpiListOp operation — expand its operands to individual
                // labels (multiple compares in one CaseRule are OR'd, the
                // exact case-label semantics).
                if (ci->VpiExprs() && !ci->VpiExprs()->empty()) {
                    // `case … inside` items arrive as ONE vpiInsideOp whose
                    // operands are vpiListOps: SINGLE-element = one label
                    // value (ariane_pkg op_is_branch); TWO-element = a
                    // `[lo:hi]` RANGE that must be ENUMERATED, not treated
                    // as two point values (decoder FP rounding-mode checks
                    // `case (frm_i) inside [3'b000:3'b010]` missed 3'b001).
                    std::vector<RTLIL::SigSpec> label_vals;
                    std::function<void(const any*)> add_label =
                        [&](const any* le) {
                            if (le->VpiType() == vpiOperation) {
                                auto lop = any_cast<const operation*>(le);
                                if (lop->VpiOpType() == vpiInsideOp && lop->Operands()) {
                                    for (auto o : *lop->Operands())
                                        add_label(o);
                                    return;
                                }
                                if (lop->VpiOpType() == vpiListOp && lop->Operands()) {
                                    auto& mo = *lop->Operands();
                                    if (mo.size() == 2) {
                                        RTLIL::SigSpec ls = import_expression(
                                            any_cast<const expr*>(mo[0]), &input_mapping);
                                        RTLIL::SigSpec hs = import_expression(
                                            any_cast<const expr*>(mo[1]), &input_mapping);
                                        if (ls.is_fully_const() && hs.is_fully_const()) {
                                            int lo = ls.as_const().as_int();
                                            int hi = hs.as_const().as_int();
                                            if (lo > hi) std::swap(lo, hi);
                                            int w = std::max(ls.size(), hs.size());
                                            for (int v = lo; v <= hi && (v - lo) < 4096; v++)
                                                label_vals.push_back(
                                                    RTLIL::SigSpec(RTLIL::Const(v, w)));
                                            return;
                                        }
                                    }
                                    for (auto o : *lop->Operands())
                                        add_label(o);
                                    return;
                                }
                            }
                            label_vals.push_back(import_expression(
                                any_cast<const expr*>(le), &input_mapping));
                        };
                    for (auto le : *ci->VpiExprs())
                        add_label(le);
                    for (auto case_value : label_vals) {
                        // Ensure case value has same width as case expression
                        if (case_value.size() < case_expr.size()) {
                            case_value.extend_u0(case_expr.size());
                        } else if (case_value.size() > case_expr.size()) {
                            case_value = case_value.extract(0, case_expr.size());
                        }
                        item_case->compare.push_back(case_value);
                    }
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
                arm_maps.push_back({item_case, input_mapping});
            }
            input_mapping = pre_map;
            // A `default:` may appear anywhere in the source (LRM 12.5) but
            // only applies when no other label matches; RTLIL cases are
            // priority-ordered and empty-compare matches everything, so move
            // defaults last (CVA6 decoder R4-type case lists default FIRST).
            std::stable_partition(sw->cases.begin(), sw->cases.end(),
                                  [](const RTLIL::CaseRule* c) { return !c->compare.empty(); });
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
            arm_maps.push_back({default_case, pre_map});
        }

        // Phi-merge variables renamed inside any arm.
        for (auto& pm : pre_map) {
            const std::string& nm = pm.first;
            bool changed = false;
            for (auto& am : arm_maps) {
                auto ai = am.second.find(nm);
                if (ai != am.second.end() && ai->second != pm.second) {
                    changed = true;
                    break;
                }
            }
            if (!changed) continue;
            if (pm.second.is_wire() && pm.second.as_wire() == result_wire)
                continue;
            RTLIL::Wire* join = module->addWire(
                RTLIL::escape_id(stringf("$%s$phi_%s_%d",
                    func_call_context.c_str(), nm.c_str(), incr_autoidx())),
                pm.second.size());
            add_src_attribute(join->attributes, cs);
            for (auto& am : arm_maps) {
                auto ai = am.second.find(nm);
                RTLIL::SigSpec av =
                    (ai != am.second.end()) ? ai->second : pm.second;
                am.first->actions.push_back(RTLIL::SigSig(join, av));
            }
            input_mapping[nm] = RTLIL::SigSpec(join);
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

            // Run each arm on a COPY of the variable mapping and phi-merge
            // afterwards: an arm-local SSA rename (see the assignment
            // handler) must not leak into the other arm, and reads after the
            // if must see mux(cond, then_value, else_value).
            std::map<std::string, RTLIL::SigSpec> pre_map = input_mapping;
            std::map<std::string, RTLIL::SigSpec> then_map = pre_map;
            std::map<std::string, RTLIL::SigSpec> else_map = pre_map;
            RTLIL::CaseRule* phi_if_case = nullptr;
            RTLIL::CaseRule* phi_else_case = nullptr;

            // If branch (when condition is true)
            if (ie->VpiStmt()) {
                RTLIL::CaseRule* if_case = new RTLIL::CaseRule;
                phi_if_case = if_case;
                
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
                then_map = input_mapping;
                input_mapping = pre_map;
            }

            // Else branch (default case)
            if (ie->VpiElseStmt()) {
                RTLIL::CaseRule* else_case = new RTLIL::CaseRule;
                phi_else_case = else_case;
                
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
                else_map = input_mapping;
                input_mapping = pre_map;
            }

            // Phi-merge: for every variable an arm renamed, drive one join
            // wire from both arms and point the outer mapping at it.
            for (auto& pm : pre_map) {
                const std::string& nm = pm.first;
                auto ti = then_map.find(nm);
                auto ei = else_map.find(nm);
                RTLIL::SigSpec tv = (ti != then_map.end()) ? ti->second : pm.second;
                RTLIL::SigSpec ev = (ei != else_map.end()) ? ei->second : pm.second;
                if (tv == pm.second && ev == pm.second) continue;
                if (pm.second.is_wire() && pm.second.as_wire() == result_wire) continue;
                RTLIL::Wire* join = module->addWire(
                    RTLIL::escape_id(stringf("$%s$phi_%s_%d",
                        func_call_context.c_str(), nm.c_str(), incr_autoidx())),
                    pm.second.size());
                add_src_attribute(join->attributes, ie);
                if (!phi_if_case) {
                    phi_if_case = new RTLIL::CaseRule;
                    phi_if_case->compare.push_back(RTLIL::SigSpec(1, cond.size()));
                    sw->cases.insert(sw->cases.begin(), phi_if_case);
                }
                if (!phi_else_case) {
                    phi_else_case = new RTLIL::CaseRule;
                    sw->cases.push_back(phi_else_case);
                }
                phi_if_case->actions.push_back(RTLIL::SigSig(join, tv));
                phi_else_case->actions.push_back(RTLIL::SigSig(join, ev));
                input_mapping[nm] = RTLIL::SigSpec(join);
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

            // Same phi discipline as uhdmif_else: the arm runs on the shared
            // mapping, and every variable it SSA-renamed is merged into a
            // join wire driven by the arm (new value) and the default case
            // (held pre-if value).
            std::map<std::string, RTLIL::SigSpec> pre_map = input_mapping;
            RTLIL::CaseRule* phi_if_case = nullptr;

            if (is->VpiStmt()) {
                RTLIL::CaseRule* if_case = new RTLIL::CaseRule;
                phi_if_case = if_case;
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

            // Phi-merge arm-renamed variables (default case holds the
            // pre-if value).
            for (auto& pm : pre_map) {
                auto ci2 = input_mapping.find(pm.first);
                if (ci2 == input_mapping.end() || ci2->second == pm.second)
                    continue;
                if (pm.second.is_wire() && pm.second.as_wire() == result_wire)
                    continue;
                RTLIL::Wire* join = module->addWire(
                    RTLIL::escape_id(stringf("$%s$phi_%s_%d",
                        func_call_context.c_str(), pm.first.c_str(),
                        incr_autoidx())),
                    pm.second.size());
                add_src_attribute(join->attributes, is);
                if (phi_if_case)
                    phi_if_case->actions.push_back(
                        RTLIL::SigSig(join, ci2->second));
                default_case->actions.push_back(RTLIL::SigSig(join, pm.second));
                input_mapping[pm.first] = RTLIL::SigSpec(join);
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
            RTLIL::SigSpec rhs_sig;
            // Value the LHS variable held BEFORE this assignment when the
            // named-LHS branch SSA-renames it — the compound-assignment
            // combine below must read this, not the freshly-allocated wire.
            RTLIL::SigSpec ssa_prev_value;
            // Size the RHS to the LHS *field* width for a struct-field write
            // (`decode.gpr = '{...}`).  Otherwise the surrounding function-call
            // context (the WHOLE return struct — e.g. rp32's 306-bit dec_t)
            // leaks in as the target width, and an assignment-pattern RHS
            // (`'{'1,'0,'0}`) sizes each unsized fill literal to
            // context/field_count bits instead of one field, so every field
            // collapses to the same value (dec.gpr became 000/111 not 100/011,
            // breaking the GPR write-enable so no register was ever written).
            {
                int fw = 0;
                if (assign->Lhs()->UhdmType() == uhdmhier_path) {
                    auto hp = any_cast<const hier_path*>(assign->Lhs());
                    auto pe = hp ? hp->Path_elems() : nullptr;
                    if (pe && pe->size() == 2) {
                        std::string bn = std::string((*pe)[0]->VpiName());
                        std::string fn = std::string((*pe)[1]->VpiName());
                        const UHDM::struct_typespec* st = nullptr;
                        if (bn == func_name)
                            st = current_func_return_struct_ts;
                        if (!st)
                            if (auto bref = dynamic_cast<const UHDM::ref_obj*>((*pe)[0]))
                                if (auto bts = bref->Typespec())
                                    if (auto a = bts->Actual_typespec())
                                        if (a->UhdmType() == uhdmstruct_typespec)
                                            st = any_cast<const UHDM::struct_typespec*>(a);
                        if (st && st->Members())
                            for (auto m : *st->Members())
                                if (std::string(m->VpiName()) == fn)
                                    if (auto mts = m->Typespec())
                                        if (auto a = mts->Actual_typespec())
                                            fw = get_width_from_typespec(a, current_instance);
                    }
                }
                int saved_ctx = expression_context_width;
                if (fw > 0) expression_context_width = fw;
                rhs_sig = import_expression(any_cast<const expr*>(assign->Rhs()), &input_mapping);
                expression_context_width = saved_ctx;
            }

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
            
            // Check if LHS is the function name (return value), a parameter, or
            // a block-local variable.  A simple named LHS is either a `ref_obj`
            // OR — for a declaration initializer like `logic [2:0] data = in;`
            // — the variable object itself (uhdmlogic_var etc.), which is NOT a
            // ref_obj.  Without handling the latter, lhs_sig stays empty, no
            // action is emitted, and the local (and any output that returns it)
            // is left undriven — FunctionWireAssignmentOnDeclaration.
            int lhs_utype_named = assign->Lhs()->UhdmType();
            bool lhs_is_named = (lhs_utype_named == uhdmref_obj ||
                                 lhs_utype_named == uhdmlogic_var ||
                                 lhs_utype_named == uhdmint_var ||
                                 lhs_utype_named == uhdminteger_var ||
                                 lhs_utype_named == uhdmbit_var ||
                                 lhs_utype_named == uhdmbyte_var ||
                                 lhs_utype_named == uhdmenum_var ||
                                 lhs_utype_named == uhdmstruct_var);
            if (lhs_is_named) {
                {
                    std::string lhs_name = std::string(assign->Lhs()->VpiName());
                    // Check input_mapping first - this handles function params, return variable,
                    // and block-local variables that may shadow the function name
                    auto it = input_mapping.find(lhs_name);
                    if (it != input_mapping.end()) {
                        // SSA-rename on every whole-variable write: reads and
                        // writes both resolving to ONE block wire turn a
                        // reassignment (`result ^= x`, or `temp = f(temp)`)
                        // into `wire = wire ^ x` — a combinational self-loop
                        // that simulates as 0 (CVA6 aes_pkg::gfmul zeroed
                        // aes_mixcolumn_inv and with it aes64dsm/aes64im).
                        // Give each write a fresh wire and point the mapping
                        // at it so later reads see the value-so-far; the
                        // if/case handlers phi-merge arm-local renames.  The
                        // function's return variable stays bound to
                        // result_wire (its value is taken from there).
                        // Two exclusions from SSA renaming:
                        // - output/inout parameters: their mapped wire IS
                        //   the caller's destination — renaming orphans the
                        //   caller's read (function_output/fib_simple);
                        // - inside an unrolled for-loop body: the loop
                        //   accumulator machinery threads values by
                        //   temporarily remapping the variable and restoring
                        //   it afterwards, which would clobber SSA renames
                        //   (const_arg_loop).
                        bool ssa_excluded = !loop_values.empty();
                        // The return binding must stay on the result-wire
                        // chain: the function name and any return variable
                        // map to a `...$result$N` wire, and nested case/if
                        // levels pass INTERMEDIATE result wires as
                        // result_wire, so identity against the local
                        // result_wire parameter is not enough
                        // (fsm_using_function collapsed to 0 cells).
                        if (!ssa_excluded && lhs_name == func_name)
                            ssa_excluded = true;
                        if (!ssa_excluded && it->second.is_wire() &&
                            it->second.as_wire()->name.str().find(".$result") !=
                                std::string::npos)
                            ssa_excluded = true;
                        if (!ssa_excluded) {
                            FunctionCallContext* fctx2 = getCurrentFunctionContext();
                            if (fctx2 && fctx2->func_def &&
                                fctx2->func_def->Io_decls()) {
                                for (auto iod : *fctx2->func_def->Io_decls()) {
                                    if (std::string(iod->VpiName()) == lhs_name &&
                                        iod->VpiDirection() != vpiInput) {
                                        ssa_excluded = true;
                                        break;
                                    }
                                }
                            }
                        }
                        if (!ssa_excluded && it->second.is_wire() &&
                            it->second.as_wire() != result_wire) {
                            int w = it->second.size();
                            ssa_prev_value = it->second;
                            std::string ssa_name = stringf("$%s$ssa_%s_%d",
                                func_call_context.c_str(), lhs_name.c_str(),
                                incr_autoidx());
                            RTLIL::Wire* ssa_wire = module->addWire(
                                RTLIL::escape_id(ssa_name), w);
                            add_src_attribute(ssa_wire->attributes, assign);
                            lhs_sig = RTLIL::SigSpec(ssa_wire);
                            input_mapping[lhs_name] = lhs_sig;
                        } else {
                            lhs_sig = it->second;
                        }
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
            } else if (assign->Lhs()->UhdmType() == uhdmindexed_part_select) {
                // Indexed part-select LHS `out[k*W +: W] = …`.  Only the plain
                // `[hi:lo]` form was handled, so the byte/hword/word replication
                // loops in CVA6 wt_dcache_wbuffer's repData64/repData32
                //     2'b00: for (int k = 0; k < 8; k++) out[k*8+:8] = data[offset*8+:8];
                // wrote nothing: miss_wdata_o's three replication case arms all
                // collapsed to the same undriven value, so the write buffer fed
                // the miss unit zeros instead of the replicated store data.
                const indexed_part_select* ips =
                    any_cast<const indexed_part_select*>(assign->Lhs());
                std::string base_name = std::string(ips->VpiName());
                int base_val = -1, width_val = -1;
                if (ips->Base_expr()) {
                    RTLIL::SigSpec s2 = import_expression(
                        any_cast<const expr*>(ips->Base_expr()), &input_mapping);
                    if (s2.is_fully_const()) base_val = s2.as_int();
                }
                if (ips->Width_expr()) {
                    RTLIL::SigSpec s2 = import_expression(
                        any_cast<const expr*>(ips->Width_expr()), &input_mapping);
                    if (s2.is_fully_const()) width_val = s2.as_int();
                }
                if (base_val >= 0 && width_val > 0) {
                    // `-:` counts DOWN from the base.
                    int offset = (ips->VpiIndexedPartSelectType() == vpiPosIndexed)
                                     ? base_val : (base_val - width_val + 1);
                    RTLIL::SigSpec base_spec;
                    if (base_name == func_name) {
                        base_spec = RTLIL::SigSpec(result_wire);
                    } else {
                        auto it = input_mapping.find(base_name);
                        if (it != input_mapping.end())
                            base_spec = it->second;
                    }
                    if (offset >= 0 && base_spec.size() > 0 &&
                        offset + width_val <= base_spec.size()) {
                        lhs_sig = base_spec.extract(offset, width_val);
                        if (mode_debug)
                            log("  process_stmt_to_case: indexed part-select LHS "
                                "%s[%d +: %d]\n", base_name.c_str(), offset, width_val);
                    } else {
                        log_warning("Indexed part-select LHS %s[%d +: %d] out of "
                                    "bounds (base_size=%d)\n", base_name.c_str(),
                                    offset, width_val, base_spec.size());
                    }
                } else {
                    log_warning("Indexed part-select LHS %s has non-constant "
                                "base/width\n", base_name.c_str());
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
                        } else if (!index_sig.empty() && loop_values.empty()) {
                            // DYNAMIC bit/element write on a function local
                            // (`out[in] = 1'b1` in wt_dcache_missunit's
                            // way_bin2oh): read-modify-write the value-so-far
                            // and SSA-rename the local so later reads (and
                            // the return) see the merged value.  Without
                            // this, lhs_sig stayed empty and the write was
                            // silently DROPPED — the function returned its
                            // initializer.  Excluded inside unrolled loops
                            // (the accumulator machinery owns the mapping
                            // there, and indices are constant anyway).
                            RTLIL::SigSpec old_sig = it->second;
                            int bw = old_sig.size();
                            RTLIL::SigSpec idx32 = index_sig;
                            idx32.extend_u0(32, false);
                            RTLIL::SigSpec shamt = idx32;
                            if (element_width > 1)
                                shamt = module->Mul(NEW_ID, idx32,
                                    RTLIL::Const(element_width, 32), false);
                            RTLIL::SigSpec mask_base(
                                RTLIL::Const(RTLIL::State::S1, element_width));
                            mask_base.extend_u0(bw, false);
                            RTLIL::SigSpec mask =
                                module->Shl(NEW_ID, mask_base, shamt, false);
                            RTLIL::SigSpec data = rhs_sig;
                            if (data.size() > element_width)
                                data = data.extract(0, element_width);
                            else if (data.size() < element_width)
                                data.extend_u0(element_width);
                            data.extend_u0(bw, false);
                            RTLIL::SigSpec data_sh =
                                module->Shl(NEW_ID, data, shamt, false);
                            RTLIL::SigSpec keep = module->And(NEW_ID, old_sig,
                                module->Not(NEW_ID, mask, false), false);
                            RTLIL::SigSpec merged =
                                module->Or(NEW_ID, keep, data_sh, false);
                            RTLIL::Wire* ssa_w = module->addWire(NEW_ID, bw);
                            lhs_sig = RTLIL::SigSpec(ssa_w);
                            rhs_sig = merged;
                            input_mapping[base_name] = RTLIL::SigSpec(ssa_w);
                            if (mode_debug)
                                log("UHDM: dynamic bit-select write %s[dyn] "
                                    "-> RMW + SSA rename (ew=%d)\n",
                                    base_name.c_str(), element_width);
                        }
                    }
                }
            } else if (assign->Lhs()->UhdmType() == uhdmhier_path) {
                // Struct-field write to the return value or a local struct var:
                // `funcname.field = ...` / `localvar.field = ...`.  The LHS is a
                // hier_path [ref_obj(base), ref_obj(field)].  Map it to the base
                // SigSpec's field slice so the field write is captured — a
                // struct-returning function (rp32 dec32) otherwise stays 0.
                const hier_path* hp = any_cast<const hier_path*>(assign->Lhs());
                auto pe = hp ? hp->Path_elems() : nullptr;
                if (pe && pe->size() == 2) {
                    std::string base_name = std::string((*pe)[0]->VpiName());
                    std::string field_name = std::string((*pe)[1]->VpiName());
                    // Base signal: a mapped local/param, or the return wire.
                    RTLIL::SigSpec base_sig;
                    auto bit = input_mapping.find(base_name);
                    if (bit != input_mapping.end())
                        base_sig = bit->second;
                    else if (base_name == func_name)
                        base_sig = result_wire;
                    // Struct typespec: the return struct for the function name,
                    // otherwise the base variable's own typespec.
                    const UHDM::struct_typespec* st = nullptr;
                    if (base_name == func_name)
                        st = current_func_return_struct_ts;
                    if (!st)
                        if (auto bref = dynamic_cast<const UHDM::ref_obj*>((*pe)[0]))
                            if (auto bts = bref->Typespec())
                                if (auto a = bts->Actual_typespec())
                                    if (a->UhdmType() == uhdmstruct_typespec)
                                        st = any_cast<const UHDM::struct_typespec*>(a);
                    if (!base_sig.empty() && st && st->Members()) {
                        // LSB-first iteration: the struct's last member is the LSB.
                        int field_off = 0, field_w = 0;
                        bool found = false;
                        for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                            auto m = (*st->Members())[i];
                            int mw = 0;
                            if (auto mts = m->Typespec())
                                if (auto a = mts->Actual_typespec())
                                    mw = get_width_from_typespec(a, current_instance);
                            if (std::string(m->VpiName()) == field_name) {
                                field_w = mw;
                                found = true;
                                break;
                            }
                            field_off += mw;
                        }
                        if (found && field_w > 0 &&
                            field_off + field_w <= base_sig.size()) {
                            lhs_sig = base_sig.extract(field_off, field_w);
                            if (mode_debug)
                                log("UHDM: struct-field return %s.%s -> [%d+:%d]\n",
                                    base_name.c_str(), field_name.c_str(),
                                    field_off, field_w);
                        }
                    }
                }
            }

            // Compound assignment (`x |= y`, `x += y`, ...): UHDM encodes the
            // operator on the assignment's VpiOpType (a binary op, not the plain
            // vpiAssignmentOp) and stores only `y` as the RHS.  Combine with the
            // LHS's current value so that unrolled-loop accumulation
            // (`encode |= v[i] ? ... : '0`) chains across iterations instead of
            // each iteration overwriting the previous one.
            if (lhs_sig.size() > 0 && !skip_assignment) {
                // The accumulator's current value: with SSA renaming it is
                // the mapping value from BEFORE this assignment (the fresh
                // LHS wire has no value yet — reading it would recreate the
                // self-loop).  Otherwise it is the most recent action
                // targeting this exact LHS (the pre-loop initializer or the
                // previous iteration's result); fall back to the wire itself.
                RTLIL::SigSpec acc = lhs_sig;
                if (!ssa_prev_value.empty()) {
                    acc = ssa_prev_value;
                } else {
                    for (const auto& act : case_rule->actions)
                        if (act.first == lhs_sig) acc = act.second;
                }
                if (acc.size() < rhs_sig.size()) acc.extend_u0(rhs_sig.size());
                else if (acc.size() > rhs_sig.size()) rhs_sig.extend_u0(acc.size());
                RTLIL::SigSpec c;
                bool did = true;
                switch (assign->VpiOpType()) {
                case vpiBitOrOp:  c = module->Or (NEW_ID, acc, rhs_sig); break;
                case vpiBitAndOp: c = module->And(NEW_ID, acc, rhs_sig); break;
                case vpiBitXorOp: c = module->Xor(NEW_ID, acc, rhs_sig); break;
                case vpiAddOp:    c = module->Add(NEW_ID, acc, rhs_sig); break;
                case vpiSubOp:    c = module->Sub(NEW_ID, acc, rhs_sig); break;
                case vpiMultOp:   c = module->Mul(NEW_ID, acc, rhs_sig); break;
                case vpiDivOp:    c = module->Div(NEW_ID, acc, rhs_sig); break;
                case vpiModOp:    c = module->Mod(NEW_ID, acc, rhs_sig); break;
                case vpiLShiftOp: c = module->Shl(NEW_ID, acc, rhs_sig); break;
                case vpiRShiftOp: c = module->Shr(NEW_ID, acc, rhs_sig); break;
                default: did = false;
                }
                if (did) rhs_sig = c;
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
                        // A locally-declared loop var (`for (int i=0; ...)`) has
                        // the variable DECLARATION itself as the init Lhs (an
                        // int_var/integer_var/logic_var), not a ref_obj/ref_var.
                        // Any of these carries the name via VpiName().
                        loop_var_name = init_assign->Lhs()->VpiName();
                        
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
                            } else if (right_op->UhdmType() == uhdmhier_path) {
                                // Struct-param field bound
                                // (`k < Cfg.NrExecuteRegionRules` in CVA6's
                                // is_inside_execute_regions).  In function
                                // context the member imports as a SLICE of
                                // the arg WIRE (correct as hardware, useless
                                // as a bound), so when the import is
                                // non-const, slice the numeric value out of
                                // the call context's constant argument.
                                RTLIL::SigSpec hv = import_expression(
                                    any_cast<const expr*>(right_op),
                                    &input_mapping);
                                bool bound_ok =
                                    hv.is_fully_const() && hv.is_fully_def();
                                if (bound_ok) {
                                    end_value = hv.as_const().as_int();
                                } else if (FunctionCallContext* fctx =
                                               getCurrentFunctionContext()) {
                                    auto hp = any_cast<const hier_path*>(right_op);
                                    if (hp->Path_elems() &&
                                        hp->Path_elems()->size() >= 2 &&
                                        fctx->func_def &&
                                        fctx->func_def->Io_decls()) {
                                        std::string bn(
                                            (*hp->Path_elems())[0]->VpiName());
                                        auto cit =
                                            fctx->const_wire_values.find(bn);
                                        const UHDM::typespec* ats = nullptr;
                                        for (auto iod :
                                             *fctx->func_def->Io_decls())
                                            if (std::string(iod->VpiName()) ==
                                                    bn &&
                                                iod->Typespec()) {
                                                ats = iod->Typespec()
                                                          ->Actual_typespec();
                                                break;
                                            }
                                        if (cit != fctx->const_wire_values.end() &&
                                            ats) {
                                            std::string mpath;
                                            for (size_t pi = 1;
                                                 pi < hp->Path_elems()->size();
                                                 pi++) {
                                                if (!mpath.empty())
                                                    mpath += ".";
                                                mpath += std::string(
                                                    (*hp->Path_elems())[pi]
                                                        ->VpiName());
                                            }
                                            int off = 0, w = 0;
                                            if (calculate_struct_member_offset(
                                                    ats, mpath,
                                                    current_instance, off,
                                                    w) &&
                                                w > 0 &&
                                                off + w <=
                                                    cit->second.size()) {
                                                end_value =
                                                    cit->second
                                                        .extract(off, w)
                                                        .as_int();
                                                bound_ok = true;
                                            }
                                        }
                                    }
                                }
                                if (!bound_ok) can_unroll = false;
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

// Helper function to import an attribute value as RTLIL::Const
RTLIL::Const UhdmImporter::import_attribute_value(const UHDM::attribute* attr) {
    if (!attr) {
        return RTLIL::Const(1);
    }
    std::string val_str = std::string(attr->VpiValue());
    if (val_str.empty()) {
        return RTLIL::Const(1);
    }
    if (val_str.substr(0, 7) == "STRING:") {
        return RTLIL::Const(val_str.substr(7));
    }
    if (val_str.substr(0, 4) == "INT:") {
        return RTLIL::Const(std::stoi(val_str.substr(4)));
    }
    if (val_str.substr(0, 5) == "UINT:") {
        return RTLIL::Const(std::stoull(val_str.substr(5)));
    }
    if (val_str.substr(0, 5) == "REAL:") {
        return RTLIL::Const(val_str.substr(5));
    }
    if (val_str.substr(0, 4) == "BIN:") {
        return RTLIL::Const::from_string(val_str.substr(4));
    }
    if (val_str.substr(0, 4) == "HEX:") {
        return extract_const_from_value(val_str);
    }
    try {
        return RTLIL::Const(std::stoi(val_str));
    } catch (...) {
        return RTLIL::Const(val_str);
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
        // Build the constant nibble-by-nibble so arbitrarily wide values work
        // (std::stoull caps at 64 bits and throws std::out_of_range on, e.g.,
        // a 160-bit `logic [159:0]` package parameter — ParameterSizeOfInstance).
        std::string hex_str = value_str.substr(4);
        int width = hex_str.length() * 4;
        std::vector<RTLIL::State> bits(width, RTLIL::State::S0);
        for (size_t i = 0; i < hex_str.length(); i++) {
            char c = hex_str[hex_str.length() - 1 - i];  // LSB nibble first
            size_t base = i * 4;
            if (c == 'x' || c == 'X') {
                for (int b = 0; b < 4; b++) bits[base + b] = RTLIL::State::Sx;
                continue;
            }
            if (c == 'z' || c == 'Z') {
                for (int b = 0; b < 4; b++) bits[base + b] = RTLIL::State::Sz;
                continue;
            }
            int v = 0;
            if (c >= '0' && c <= '9') v = c - '0';
            else if (c >= 'a' && c <= 'f') v = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') v = c - 'A' + 10;
            for (int b = 0; b < 4; b++)
                bits[base + b] = (v & (1 << b)) ? RTLIL::State::S1 : RTLIL::State::S0;
        }
        return RTLIL::Const(bits);
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

                // A function parameter (`arg[0][0]` inside a function body) is
                // not a module wire — it is staged in `input_mapping`.  Resolve
                // the base wire from there first so the element extraction below
                // slices the staged argument value instead of finding nothing
                // and returning X (2DFunctionArg / SelectFromUnpackedInFunction).
                RTLIL::Wire* mapped_base_wire = nullptr;
                if (input_mapping) {
                    auto mit = input_mapping->find(base_name);
                    if (mit != input_mapping->end() && mit->second.is_wire())
                        mapped_base_wire = mit->second.as_wire();
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
                        bool have_psel = parse_mem_partial_select(vs, addr_expr, psel_lo, psel_hi,
                                                                  memory->width);
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

                // PACKED multi-dim var_select (`x[i][j]` on
                // `logic [0:N][2:0][31:0] x`): resolve every index against
                // the net's typespec dimensions with correct MSB-first
                // flattening (leftmost dim occupies the MSBs; ascending
                // ranges put index `low` at the MSBs).  fpnew's pipeline
                // arrays (`inp_pipe_operands_q[NUM_INP_REGS][k]`) come
                // through here with no Actual_group — fall back to the
                // elaborated instance's net list for the typespec.
                {
                    RTLIL::Wire* bw = mapped_base_wire ? mapped_base_wire
                                    : module->wire(RTLIL::escape_id(base_name));
                    const UHDM::ref_typespec* rt = nullptr;
                    if (auto actual = vs->Actual_group()) {
                        if (auto e = dynamic_cast<const UHDM::expr*>(actual))
                            rt = e->Typespec();
                        else if (auto io = dynamic_cast<const UHDM::io_decl*>(actual))
                            rt = io->Typespec();
                    }
                    if (!rt && current_instance) {
                        if (auto mi = dynamic_cast<const UHDM::module_inst*>(current_instance)) {
                            if (mi->Nets())
                                for (auto n : *mi->Nets())
                                    if (std::string(n->VpiName()) == base_name) { rt = n->Typespec(); break; }
                            if (!rt && mi->Variables())
                                for (auto v : *mi->Variables())
                                    if (std::string(v->VpiName()) == base_name) { rt = v->Typespec(); break; }
                        }
                    }
                    const UHDM::any* a = rt ? rt->Actual_typespec() : nullptr;
                    const UHDM::logic_typespec* lt =
                        a ? dynamic_cast<const UHDM::logic_typespec*>(a) : nullptr;
                    // Typedef'd packed array (`mshr_sram_data_t [ways-1:0]`):
                    // the outer dims live on the packed_array_var/net's own
                    // Ranges() and the element width on its typespec — build
                    // the dim list from those (mirrors
                    // emit_dynamic_packed_select_write's geometry).
                    std::vector<std::pair<int,int>> own_dims;
                    {
                        auto own_geo = [&](const UHDM::any* obj) {
                            const UHDM::VectorOfrange* org = nullptr;
                            const UHDM::ref_typespec* ots = nullptr;
                            if (auto pv = dynamic_cast<const UHDM::packed_array_var*>(obj)) {
                                org = pv->Ranges(); ots = pv->Typespec();
                            } else if (auto pn = dynamic_cast<const UHDM::packed_array_net*>(obj)) {
                                org = pn->Ranges(); ots = pn->Typespec();
                            } else return;
                            if (!org || org->empty() || !own_dims.empty()) return;
                            for (auto r : *org) {
                                RTLIL::SigSpec l = import_expression(r->Left_expr(), input_mapping);
                                RTLIL::SigSpec rr = import_expression(r->Right_expr(), input_mapping);
                                if (!l.is_fully_const() || !rr.is_fully_const()) { own_dims.clear(); return; }
                                own_dims.push_back({l.as_const().as_int(), rr.as_const().as_int()});
                            }
                            int ew = 0;
                            if (ots && ots->Actual_typespec())
                                ew = get_width_from_typespec(ots->Actual_typespec(), current_instance);
                            if (ew > 0)
                                own_dims.push_back({ew - 1, 0});
                            else
                                own_dims.clear();
                        };
                        own_geo(vs->Actual_group());
                        if (own_dims.empty() && current_instance) {
                            if (current_instance->Nets())
                                for (auto n : *current_instance->Nets())
                                    if (std::string(n->VpiName()) == base_name) { own_geo(n); break; }
                            if (own_dims.empty() && current_instance->Variables())
                                for (auto v : *current_instance->Variables())
                                    if (std::string(v->VpiName()) == base_name) { own_geo(v); break; }
                        }
                    }
                    if (bw && ((lt && lt->Ranges() && lt->Ranges()->size() >= 2 &&
                                !lt->Elem_typespec()) || !own_dims.empty())) {
                        // Evaluate all dims.
                        std::vector<std::pair<int,int>> dims;  // (left,right)
                        bool dims_ok = true;
                        if (!own_dims.empty()) {
                            dims = own_dims;
                        } else for (auto r : *lt->Ranges()) {
                            RTLIL::SigSpec l = import_expression(r->Left_expr(), input_mapping);
                            RTLIL::SigSpec rr = import_expression(r->Right_expr(), input_mapping);
                            if (!l.is_fully_const() || !rr.is_fully_const()) { dims_ok = false; break; }
                            dims.push_back({l.as_const().as_int(), rr.as_const().as_int()});
                        }
                        long total = 1;
                        if (dims_ok)
                            for (auto& d : dims) total *= (std::abs(d.first - d.second) + 1);
                        // Only plain index expressions (no part-selects) and
                        // no more indices than dims.
                        bool idx_ok = dims_ok && total == bw->width &&
                                      exprs->size() <= dims.size();
                        // A TRAILING constant indexed-part-select
                        // (`mshr_rdata[i][0 +: K]`) selects a sub-slice of
                        // the resolved element; other part-selects bail.
                        const UHDM::indexed_part_select* trail_ips = nullptr;
                        size_t n_idx = exprs->size();
                        if (idx_ok)
                            for (size_t ei = 0; ei < exprs->size(); ei++) {
                                int t = (*exprs)[ei]->VpiType();
                                if (t == vpiIndexedPartSelect &&
                                    ei == exprs->size() - 1) {
                                    trail_ips = any_cast<const UHDM::indexed_part_select*>((*exprs)[ei]);
                                    n_idx = ei;
                                } else if (t == vpiPartSelect ||
                                           t == vpiIndexedPartSelect) {
                                    idx_ok = false; break;
                                }
                            }
                        if (idx_ok && n_idx == 0) idx_ok = false;
                        if (idx_ok && n_idx > dims.size()) idx_ok = false;
                        if (idx_ok) {
                            // stride[i] = product of sizes of dims after i
                            std::vector<long> stride(dims.size(), 1);
                            for (int i = (int)dims.size() - 2; i >= 0; i--)
                                stride[i] = stride[i + 1] *
                                    (std::abs(dims[i + 1].first - dims[i + 1].second) + 1);
                            long const_off = 0;
                            RTLIL::SigSpec dyn_off;   // accumulated dynamic bit offset
                            bool fail = false;
                            for (size_t i = 0; i < n_idx; i++) {
                                const expr* ie = (*exprs)[i];
                                if (ie->VpiType() == vpiBitSelect)
                                    ie = any_cast<const expr*>(
                                        any_cast<const UHDM::bit_select*>(ie)->VpiIndex());
                                RTLIL::SigSpec is = import_expression(ie, input_mapping);
                                int l = dims[i].first, r = dims[i].second;
                                bool asc = l < r;
                                if (is.is_fully_const()) {
                                    int idx = is.as_const().as_int();
                                    long slot = asc ? (long)(r - idx) : (long)(idx - r);
                                    if (slot < 0 || slot > std::abs(l - r)) { fail = true; break; }
                                    const_off += slot * stride[i];
                                } else if (!is.empty()) {
                                    RTLIL::SigSpec iv = is;
                                    iv.extend_u0(32, false);
                                    RTLIL::SigSpec slot;
                                    if (asc)
                                        slot = module->Sub(NEW_ID, RTLIL::Const(r, 32), iv, false);
                                    else if (r != 0)
                                        slot = module->Sub(NEW_ID, iv, RTLIL::Const(r, 32), false);
                                    else
                                        slot = iv;
                                    RTLIL::SigSpec contrib = (stride[i] == 1) ? slot
                                        : (RTLIL::SigSpec)module->Mul(NEW_ID, slot,
                                              RTLIL::Const((int)stride[i], 32), false);
                                    dyn_off = dyn_off.empty() ? contrib
                                        : (RTLIL::SigSpec)module->Add(NEW_ID, dyn_off, contrib, false);
                                } else { fail = true; break; }
                            }
                            if (!fail) {
                                long res_w = stride[n_idx - 1];
                                // Apply the trailing constant [base +: w]
                                // within the element.
                                long ips_off = 0, ips_w = -1;
                                if (trail_ips) {
                                    RTLIL::SigSpec b = import_expression(
                                        trail_ips->Base_expr(), input_mapping);
                                    RTLIL::SigSpec w = import_expression(
                                        trail_ips->Width_expr(), input_mapping);
                                    bool pos = trail_ips->VpiIndexedPartSelectType() == vpiPosIndexed;
                                    if (b.is_fully_const() && w.is_fully_const() &&
                                        w.as_const().as_int() > 0) {
                                        ips_w = w.as_const().as_int();
                                        int bb = b.as_const().as_int();
                                        ips_off = pos ? bb : (bb - ips_w + 1);
                                    } else fail = true;
                                }
                                if (!fail && ips_w > 0 &&
                                    (ips_off < 0 || ips_off + ips_w > res_w))
                                    fail = true;
                                if (fail) { /* fall through to legacy */ }
                                else {
                                if (dyn_off.empty()) {
                                    long bit_off = const_off + (ips_w > 0 ? ips_off : 0);
                                    long sel_w = (ips_w > 0) ? ips_w : res_w;
                                    if (bit_off >= 0 && bit_off + sel_w <= bw->width) {
                                        log("  vpiVarSelect: packed %zuD %s → [%ld+:%ld]\n",
                                            exprs->size(), base_name.c_str(), bit_off, sel_w);
                                        return RTLIL::SigSpec(bw).extract((int)bit_off, (int)sel_w);
                                    }
                                } else {
                                    // stride[i] is in BITS (innermost dim is
                                    // the bit dim), so the accumulated offset
                                    // is already a bit offset.
                                    RTLIL::SigSpec bit_off = dyn_off;
                                    if (const_off != 0)
                                        bit_off = module->Add(NEW_ID, bit_off,
                                                          RTLIL::Const((int)const_off, 32), false);
                                    if (ips_w > 0 && ips_off != 0)
                                        bit_off = module->Add(NEW_ID, bit_off,
                                            RTLIL::Const((int)ips_off, 32), false);
                                    long sel_w = (ips_w > 0) ? ips_w : res_w;
                                    RTLIL::Wire* y = module->addWire(NEW_ID, (int)sel_w);
                                    module->addShiftx(NEW_ID, RTLIL::SigSpec(bw), bit_off, y);
                                    return RTLIL::SigSpec(y);
                                }
                                }
                            }
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
                        if (RTLIL::Wire* base_wire = mapped_base_wire ? mapped_base_wire : module->wire(wire_id)) {
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

                // Multi-index element read with a DYNAMIC index on a struct
                // array flattened to one wide wire (bht/btb
                // `q[rd_idx][j]`): shiftx at Σ (idx_k − low_k)·stride_k.
                {
                    RTLIL::Wire* bw2 = mapped_base_wire ? mapped_base_wire
                                     : (name_map.count(base_name) ? name_map[base_name]
                                        : module->wire(RTLIL::escape_id(base_name)));
                    std::vector<std::pair<int,int>> gdims;
                    const UHDM::struct_typespec* gst = nullptr;
                    int gelem_w = 0;
                    if (bw2 && exprs->size() >= 1 &&
                        flat_struct_array_geom(base_name, vs->Actual_group(),
                                               current_instance, gdims, &gst, &gelem_w) &&
                        exprs->size() <= gdims.size() && gelem_w > 0) {
                        size_t K = exprs->size();
                        std::vector<RTLIL::SigSpec> gidx;
                        bool gok = true, gdyn = false;
                        for (size_t k = 0; k < K; k++) {
                            RTLIL::SigSpec ix = import_expression((*exprs)[k], input_mapping);
                            if (ix.size() == 0) { gok = false; break; }
                            if (!ix.is_fully_const()) gdyn = true;
                            gidx.push_back(ix);
                        }
                        int level_w = gelem_w;
                        for (size_t k = K; k < gdims.size(); k++) level_w *= gdims[k].first;
                        if (gok && gdyn &&
                            (int)(level_w) <= bw2->width) {
                            std::vector<int> strides(K, gelem_w);
                            for (size_t k = 0; k < K; k++)
                                for (size_t k2 = k + 1; k2 < gdims.size(); k2++)
                                    strides[k] *= gdims[k2].first;
                            int shamt_w = 32;
                            for (auto& ix : gidx) shamt_w = std::max(shamt_w, ix.size() + 6);
                            RTLIL::SigSpec acc = RTLIL::SigSpec(RTLIL::Const(0, shamt_w));
                            for (size_t k = 0; k < K; k++) {
                                RTLIL::SigSpec ix = gidx[k];
                                ix.extend_u0(shamt_w, false);
                                if (gdims[k].second != 0) {
                                    RTLIL::Wire* pw = module->addWire(NEW_ID, shamt_w);
                                    module->addSub(NEW_ID, ix,
                                        RTLIL::SigSpec(RTLIL::Const(gdims[k].second, shamt_w)),
                                        pw, true);
                                    ix = RTLIL::SigSpec(pw);
                                }
                                RTLIL::Wire* mw2 = module->addWire(NEW_ID, shamt_w);
                                module->addMul(NEW_ID, ix,
                                    RTLIL::SigSpec(RTLIL::Const(strides[k], shamt_w)), mw2, true);
                                RTLIL::Wire* aw = module->addWire(NEW_ID, shamt_w);
                                module->addAdd(NEW_ID, acc, RTLIL::SigSpec(mw2), aw, true);
                                acc = RTLIL::SigSpec(aw);
                            }
                            RTLIL::Wire* out = module->addWire(NEW_ID, level_w);
                            RTLIL::Cell* sx = module->addCell(NEW_ID, ID($shiftx));
                            sx->setParam(ID::A_SIGNED, 0);
                            sx->setParam(ID::B_SIGNED, 0);
                            sx->setParam(ID::A_WIDTH, bw2->width);
                            sx->setParam(ID::B_WIDTH, shamt_w);
                            sx->setParam(ID::Y_WIDTH, level_w);
                            sx->setPort(ID::A, RTLIL::SigSpec(bw2));
                            sx->setPort(ID::B, acc);
                            sx->setPort(ID::Y, out);
                            add_src_attribute(sx->attributes, vs);
                            log("  vpiVarSelect: dynamic %zu-index %s → shiftx (w=%d)\n",
                                K, base_name.c_str(), level_w);
                            return RTLIL::SigSpec(out);
                        }
                    }
                }

                // PACKED multi-dim array element: `x[i0]...[iK-1]` on a fully
                // packed `logic [d0]...[dN-1] x` (LogicPackedArray:
                // `logic [1:0][2:0][3:0] x; x[0][0]`).  Walk the logic_typespec
                // Ranges to dims; after K indices the element is
                // product(dims[K..N-1]) bits at the row-major offset
                //   sum_k (ik-low_k) * product(dims[k+1..N-1]).
                // Without this the K-index select collapsed to a single bit.
                if (exprs->size() >= 2) {
                    RTLIL::Wire* bw = mapped_base_wire ? mapped_base_wire
                                    : module->wire(RTLIL::escape_id(base_name));
                    // Inside a generate scope the wire is registered under the
                    // scope-qualified name (`gen_arbiter.index_nodes`), not
                    // the bare one, and the reference can sit in a NESTED
                    // scope (`gen_arbiter.gen_levels[0]...`) while the var is
                    // declared levels above — walk the scope path upwards
                    // (rr_arb_tree's index_nodes[i][range] in a paramod).
                    if (!bw && !gen_scope_stack.empty()) {
                        std::string sc = get_current_gen_scope();
                        while (!bw && !sc.empty()) {
                            bw = module->wire(RTLIL::escape_id(sc + "." + base_name));
                            size_t dot = sc.rfind('.');
                            sc = (dot == std::string::npos) ? "" : sc.substr(0, dot);
                        }
                    }
                    // Typespec from the Actual_group — works for a wire-backed
                    // expr AND for a packed-array PARAMETER with no wire (both
                    // extend `expr`; the param branch handles ParameterPackedArray).
                    const UHDM::any* ts = nullptr;
                    const UHDM::parameter* pr = nullptr;
                    if (vs->Actual_group()) {
                        if (auto e = dynamic_cast<const UHDM::expr*>(vs->Actual_group()))
                            if (e->Typespec()) ts = e->Typespec()->Actual_typespec();
                        pr = dynamic_cast<const UHDM::parameter*>(vs->Actual_group());
                        if (!ts && pr && pr->Typespec()) ts = pr->Typespec()->Actual_typespec();
                    }
                    std::vector<std::pair<int,int>> pdims; // (size, low) outer->inner
                    bool pdim_ok = true;
                    auto push_ranges = [&](const UHDM::VectorOfrange* rgs) {
                        if (!rgs) return;
                        for (auto r : *rgs) {
                            RTLIL::SigSpec l = import_expression(r->Left_expr(), input_mapping);
                            RTLIL::SigSpec rr = import_expression(r->Right_expr(), input_mapping);
                            if (l.is_fully_const() && rr.is_fully_const())
                                pdims.push_back({std::abs(l.as_const().as_int() - rr.as_const().as_int()) + 1,
                                                 std::min(l.as_const().as_int(), rr.as_const().as_int())});
                            else pdim_ok = false;
                        }
                    };
                    // A packed array whose ELEMENT type is a typedef or TYPE
                    // PARAMETER (`idx_t [2**NumLevels-2:0] index_nodes`,
                    // rr_arb_tree) elaborates as a packed_array_var/net whose
                    // OUTER dims sit in its own Ranges() while its typespec is
                    // just the element type — the walk below then saw one dim
                    // and the second index was dropped (arb_idx_cast: idx_o's
                    // child bit lost, the arbiter reported the wrong port).
                    // Prepending the object's own Ranges completes the chain;
                    // the `total == base_sig.size()` check below still bails
                    // on any double-count.
                    if (vs->Actual_group()) {
                        if (auto pav = dynamic_cast<const UHDM::packed_array_var*>(vs->Actual_group()))
                            push_ranges(pav->Ranges());
                        else if (auto pan = dynamic_cast<const UHDM::packed_array_net*>(vs->Actual_group()))
                            push_ranges(pan->Ranges());
                    }
                    const UHDM::any* cur = ts;
                    int ts_hops = 0;
                    while (cur && ts_hops++ < 8) {
                        if (cur->UhdmType() == uhdmlogic_typespec) {
                            auto lt = any_cast<const UHDM::logic_typespec*>(cur);
                            push_ranges(lt->Ranges());
                            cur = (lt->Elem_typespec() && lt->Elem_typespec()->Actual_typespec())
                                  ? lt->Elem_typespec()->Actual_typespec() : nullptr;
                        } else if (cur->UhdmType() == uhdmpacked_array_typespec) {
                            auto pt = any_cast<const UHDM::packed_array_typespec*>(cur);
                            push_ranges(pt->Ranges());
                            cur = (pt->Elem_typespec() && pt->Elem_typespec()->Actual_typespec())
                                  ? pt->Elem_typespec()->Actual_typespec() : nullptr;
                        } else {
                            // Erased type parameter or other alias: resolve to
                            // the bound type and keep walking.
                            const UHDM::typespec* tsp =
                                dynamic_cast<const UHDM::typespec*>(cur);
                            const UHDM::typespec* bound =
                                tsp ? resolve_type_param_typespec(
                                          tsp, current_scope ? current_scope
                                                             : current_instance)
                                    : nullptr;
                            if (bound && bound != cur) { cur = bound; continue; }
                            break;
                        }
                    }
                    // No typespec at all (a gen-scope type-param packed array
                    // — rr_arb_tree's index_nodes in a paramod): fall back to
                    // the packed_* geometry attrs stamped at wire creation.
                    if (pdims.empty() && bw) {
                        auto& wa = bw->attributes;
                        auto ew_id = RTLIL::escape_id("packed_elem_width");
                        auto ol_id = RTLIL::escape_id("packed_outer_left");
                        auto or_id = RTLIL::escape_id("packed_outer_right");
                        if (wa.count(ew_id) && wa.count(ol_id) && wa.count(or_id)) {
                            int ew = wa.at(ew_id).as_int();
                            int ol = wa.at(ol_id).as_int();
                            int orr = wa.at(or_id).as_int();
                            if (ew > 1) {
                                pdims.push_back({std::abs(ol - orr) + 1,
                                                 std::min(ol, orr)});
                                pdims.push_back({ew, 0});
                            }
                        }
                    }
                    size_t K = exprs->size();
                    if (pdim_ok && pdims.size() >= 2 && pdims.size() >= K) {
                        int total = 1;
                        for (auto& d : pdims) total *= d.first;
                        // Base value: the wire, or — for a parameter with no wire
                        // — the param's constant value, sized to `total` by
                        // importing its pattern with expression_context_width set
                        // (ParameterPackedArray).
                        RTLIL::SigSpec base_sig;
                        if (bw) base_sig = RTLIL::SigSpec(bw);
                        else if (pr) {
                            RTLIL::SigSpec pv;
                            RTLIL::IdString pid = RTLIL::escape_id(base_name);
                            if (module->parameter_default_values.count(pid))
                                pv = module->parameter_default_values.at(pid);
                            int saved_ctx = expression_context_width;
                            expression_context_width = total;
                            if (!pv.is_fully_const() && pr->Expr())
                                pv = import_expression(any_cast<const expr*>(pr->Expr()), input_mapping);
                            if (!pv.is_fully_const())
                                if (auto scp = dynamic_cast<const UHDM::scope*>(pr->VpiParent()))
                                    if (scp->Param_assigns())
                                        for (auto pa : *scp->Param_assigns())
                                            if (pa->Lhs() && std::string(pa->Lhs()->VpiName()) == base_name && pa->Rhs()) {
                                                pv = import_expression(any_cast<const expr*>(pa->Rhs()), input_mapping);
                                                break;
                                            }
                            expression_context_width = saved_ctx;
                            if (pv.is_fully_const()) base_sig = pv;
                        }
                        if (!base_sig.empty() && total == base_sig.size()) {
                            int leaf_w = 1;
                            for (size_t d = K; d < pdims.size(); d++) leaf_w *= pdims[d].first;
                            long off = 0; bool ok = true;
                            bool any_dyn_idx = false;
                            int sel_w = leaf_w;
                            for (size_t k = 0; k < K; k++) {
                                int inner = 1;
                                for (size_t d = k + 1; d < pdims.size(); d++) inner *= pdims[d].first;
                                // Trailing RANGE select of a dim
                                // (`vaddr_vpn_match[i][z][PtLevels-1:x]`, CVA6
                                // cva6_tlb): the last Exprs entry is a
                                // part_select node windowing dim K-1 — the
                                // const-index import below returned non-const
                                // and the read collapsed to a single wrong bit.
                                if (k == K - 1 &&
                                    (*exprs)[k]->UhdmType() == uhdmpart_select) {
                                    auto psx = any_cast<const UHDM::part_select*>((*exprs)[k]);
                                    RTLIL::SigSpec l = import_expression(psx->Left_range(), input_mapping);
                                    RTLIL::SigSpec rr = import_expression(psx->Right_range(), input_mapping);
                                    if (!l.is_fully_const() || !rr.is_fully_const()) { ok = false; break; }
                                    int lo = std::min(l.as_const().as_int(), rr.as_const().as_int());
                                    int w = std::abs(l.as_const().as_int() -
                                                     rr.as_const().as_int()) + 1;
                                    int rel = lo - pdims[k].second;
                                    if (rel < 0 || rel + w > pdims[k].first) { ok = false; break; }
                                    off += (long)rel * inner;
                                    sel_w = w * inner;
                                    continue;
                                }
                                RTLIL::SigSpec is = import_expression((*exprs)[k], input_mapping);
                                if (!is.is_fully_const()) {
                                    ok = false;
                                    any_dyn_idx = true;
                                    break;
                                }
                                off += (long)(is.as_const().as_int() - pdims[k].second) * inner;
                            }
                            if (ok && off >= 0 && off + sel_w <= base_sig.size()) {
                                log("  vpiVarSelect: packed %dD %s[...] → [%d+:%d]\n",
                                    (int)pdims.size(), base_name.c_str(), (int)off, sel_w);
                                return base_sig.extract((int)off, sel_w);
                            }
                            // DYNAMIC index into a multi-dim PACKED array
                            // (`vaddr_lvl[0][ptw_lvl_q[0]]` on
                            // `logic [A:0][B:0][8:0]`, CVA6 cva6_ptw): the
                            // const path above bails, and without this the read
                            // fell through to a plain 1-BIT bit_select —
                            // ptw_pptr_n lost 8 of the element's 9 bits.  Shift
                            // the element out of the flat value at
                            // Σ (idx_k − low_k)·stride_k.
                            if (any_dyn_idx && pdims.size() >= K) {
                                int leaf_w = 1;
                                for (size_t d = K; d < pdims.size(); d++)
                                    leaf_w *= pdims[d].first;
                                int shamt_w = 32;
                                RTLIL::SigSpec acc(RTLIL::Const(0, shamt_w));
                                bool dyn_ok = leaf_w > 1;
                                for (size_t k = 0; k < K && dyn_ok; k++) {
                                    int inner = 1;
                                    for (size_t d = k + 1; d < pdims.size(); d++)
                                        inner *= pdims[d].first;
                                    RTLIL::SigSpec ix =
                                        import_expression((*exprs)[k], input_mapping);
                                    if (ix.empty()) { dyn_ok = false; break; }
                                    ix.extend_u0(shamt_w, false);
                                    if (pdims[k].second != 0) {
                                        RTLIL::Wire* sw = module->addWire(NEW_ID, shamt_w);
                                        module->addSub(NEW_ID, ix,
                                            RTLIL::SigSpec(RTLIL::Const(pdims[k].second, shamt_w)),
                                            sw, true);
                                        ix = RTLIL::SigSpec(sw);
                                    }
                                    RTLIL::Wire* mw = module->addWire(NEW_ID, shamt_w);
                                    module->addMul(NEW_ID, ix,
                                        RTLIL::SigSpec(RTLIL::Const(inner, shamt_w)), mw, true);
                                    RTLIL::Wire* aw = module->addWire(NEW_ID, shamt_w);
                                    module->addAdd(NEW_ID, acc, RTLIL::SigSpec(mw), aw, true);
                                    acc = RTLIL::SigSpec(aw);
                                }
                                if (dyn_ok) {
                                    RTLIL::Wire* out = module->addWire(NEW_ID, leaf_w);
                                    RTLIL::Cell* sx = module->addCell(NEW_ID, ID($shiftx));
                                    sx->setParam(ID::A_SIGNED, 0);
                                    sx->setParam(ID::B_SIGNED, 0);
                                    sx->setParam(ID::A_WIDTH, base_sig.size());
                                    sx->setParam(ID::B_WIDTH, shamt_w);
                                    sx->setParam(ID::Y_WIDTH, leaf_w);
                                    sx->setPort(ID::A, base_sig);
                                    sx->setPort(ID::B, acc);
                                    sx->setPort(ID::Y, out);
                                    log("  vpiVarSelect: DYNAMIC packed %dD %s[...] → "
                                        "shiftx (w=%d)\n",
                                        (int)pdims.size(), base_name.c_str(), leaf_w);
                                    return RTLIL::SigSpec(out);
                                }
                            }
                        }
                    }
                }

                // Packed array of (packed) STRUCTS: `status_t [1:0][1:0] g;
                // g[i][j]` reads the (i,j) struct element.  The dims live on the
                // packed_array_var's Ranges and the element is the struct width —
                // neither is a logic_typespec, so the logic path above misses it
                // (DotMultirange).
                if (exprs->size() >= 2) {
                    RTLIL::Wire* bw = mapped_base_wire ? mapped_base_wire
                                    : module->wire(RTLIL::escape_id(base_name));
                    const UHDM::packed_array_var* pav =
                        dynamic_cast<const UHDM::packed_array_var*>(vs->Actual_group());
                    if (!pav && bw)
                        for (auto& kv : wire_map)
                            if (kv.second == bw && kv.first->UhdmType() == uhdmpacked_array_var) {
                                pav = any_cast<const UHDM::packed_array_var*>(kv.first);
                                break;
                            }
                    if (bw && pav && pav->Ranges() && !pav->Ranges()->empty()) {
                        int elem_w = 0;
                        if (pav->Typespec() && pav->Typespec()->Actual_typespec())
                            elem_w = get_width_from_typespec(pav->Typespec()->Actual_typespec(),
                                                             current_instance);
                        if (elem_w <= 0 && pav->Elements() && !pav->Elements()->empty())
                            elem_w = get_width((*pav->Elements())[0], current_instance);
                        std::vector<std::pair<int,int>> adims; // (size, low) outer->inner
                        bool ok = true;
                        for (auto r : *pav->Ranges()) {
                            RTLIL::SigSpec l = import_expression(r->Left_expr(), input_mapping);
                            RTLIL::SigSpec rr = import_expression(r->Right_expr(), input_mapping);
                            if (l.is_fully_const() && rr.is_fully_const())
                                adims.push_back({std::abs(l.as_const().as_int() - rr.as_const().as_int()) + 1,
                                                 std::min(l.as_const().as_int(), rr.as_const().as_int())});
                            else ok = false;
                        }
                        size_t K = exprs->size();
                        if (ok && elem_w > 0 && adims.size() >= K && adims.size() >= 1) {
                            int total = elem_w;
                            for (auto& d : adims) total *= d.first;
                            if (total == bw->width) {
                                int leaf_w = elem_w;
                                for (size_t d = K; d < adims.size(); d++) leaf_w *= adims[d].first;
                                long off = 0; bool cok = true;
                                for (size_t k = 0; k < K; k++) {
                                    RTLIL::SigSpec is = import_expression((*exprs)[k], input_mapping);
                                    if (!is.is_fully_const()) { cok = false; break; }
                                    int inner = elem_w;
                                    for (size_t d = k + 1; d < adims.size(); d++) inner *= adims[d].first;
                                    off += (long)(is.as_const().as_int() - adims[k].second) * inner;
                                }
                                if (cok && off >= 0 && off + leaf_w <= bw->width) {
                                    log("  vpiVarSelect: packed struct-array %s[...] → [%d+:%d]\n",
                                        base_name.c_str(), (int)off, leaf_w);
                                    return RTLIL::SigSpec(bw).extract((int)off, leaf_w);
                                }
                            }
                        }
                    }
                }

                // Fully-indexed N-dim var_select `x[i0][i1]...[ik]` on a
                // packed+unpacked array that carries no wire metadata.  Walk the
                // array_var typespec dimensions outer->inner (unpacked
                // array_typespec Ranges, then packed Elem_typespec/logic_typespec
                // Ranges) and compute the flat leaf-bit offset ourselves
                // (struct_pattern_loop: `bit [0:0][0:0] b [0:0]; b[0][0][0]`).
                if (exprs->size() >= 3) {
                    RTLIL::Wire* bw = mapped_base_wire ? mapped_base_wire
                                    : module->wire(RTLIL::escape_id(base_name));
                    const UHDM::any* ats = nullptr;
                    if (vs->Actual_group())
                        if (auto e = dynamic_cast<const UHDM::expr*>(vs->Actual_group()))
                            if (e->Typespec()) ats = e->Typespec()->Actual_typespec();
                    if (bw && ats) {
                        // The packed (inner) dims are not reachable from the
                        // array_var typespec here (an empty array_typespec), but
                        // the UNPACKED (outer) dims live on the array_var's
                        // Ranges() and the wire is already flattened, so derive
                        // the packed-element bit-width from the wire width.
                        std::vector<std::pair<int,int>> udims; // (size, low) outer->inner
                        bool dim_ok = true;
                        auto add_ranges = [&](UHDM::VectorOfrange* rs){
                            if (!rs) return;
                            for (auto r : *rs) {
                                RTLIL::SigSpec l = import_expression(r->Left_expr(), input_mapping);
                                RTLIL::SigSpec rr = import_expression(r->Right_expr(), input_mapping);
                                if (l.is_fully_const() && rr.is_fully_const()) {
                                    int lv = l.as_const().as_int(), rv = rr.as_const().as_int();
                                    udims.push_back({std::abs(lv - rv) + 1, std::min(lv, rv)});
                                } else dim_ok = false;
                            }
                        };
                        if (auto av = dynamic_cast<const UHDM::array_var*>(vs->Actual_group()))
                            add_ranges(av->Ranges());
                        size_t n_unp = udims.size();
                        if (dim_ok && n_unp >= 1 && exprs->size() >= n_unp) {
                            int unp_product = 1;
                            for (auto& d : udims) unp_product *= d.first;
                            if (unp_product > 0 && bw->width % unp_product == 0) {
                                int packed_bits = bw->width / unp_product;
                                bool ok = true;
                                long unp_flat = 0;
                                for (size_t d = 0; d < n_unp; d++) {
                                    RTLIL::SigSpec is = import_expression((*exprs)[d], input_mapping);
                                    if (!is.is_fully_const()) { ok = false; break; }
                                    unp_flat = unp_flat * udims[d].first +
                                               (is.as_const().as_int() - udims[d].second);
                                }
                                // Remaining indices select within the packed
                                // element.  We don't have the packed dim sizes,
                                // so only resolve the unambiguous single-bit case
                                // (all remaining indices must be 0) — enough for
                                // `bit [0:0][0:0] b [0:0]` (struct_pattern_loop).
                                bool rem_zero = true;
                                for (size_t d = n_unp; d < exprs->size(); d++) {
                                    RTLIL::SigSpec is = import_expression((*exprs)[d], input_mapping);
                                    if (!is.is_fully_const() || is.as_const().as_int() != 0)
                                        rem_zero = false;
                                }
                                if (ok && rem_zero && packed_bits == 1) {
                                    int bit_off = (int)unp_flat;
                                    if (bit_off >= 0 && bit_off < bw->width) {
                                        log("  vpiVarSelect: %dD %s[...] → %s[%d]\n",
                                            (int)exprs->size(), base_name.c_str(),
                                            bw->name.c_str(), bit_off);
                                        return RTLIL::SigSpec(bw).extract(bit_off, 1);
                                    }
                                }
                            }
                        }
                    }
                }

                // First expression is the array index.
                const expr* first_idx = (*exprs)[0];
                RTLIL::SigSpec idx_sig = import_expression(first_idx, input_mapping);

                // Packed multi-dim array element width (0 if not packed): for
                // `logic [N-1:0][M-1:0] x`, `x[idx]` is an element_width-bit slice
                // of the single packed wire `x` (element_width = base/outer or the
                // Elem_typespec width).
                RTLIL::Wire* base_wire = mapped_base_wire ? mapped_base_wire
                                       : module->wire(RTLIL::escape_id(base_name));
                int elem_w = 0, array_low = 0;
                if (base_wire) {
                    if (auto actual = vs->Actual_group()) {
                        const UHDM::ref_typespec* rt = nullptr;
                        if (auto e = dynamic_cast<const UHDM::expr*>(actual))
                            rt = e->Typespec();
                        // A function parameter resolves to an io_decl (not an
                        // expr); it carries the packed typespec too (2DFunctionArg).
                        else if (auto io = dynamic_cast<const UHDM::io_decl*>(actual))
                            rt = io->Typespec();
                        const UHDM::any* a = rt ? rt->Actual_typespec() : nullptr;
                        if (a && a->UhdmType() == uhdmlogic_typespec) {
                            auto lt = dynamic_cast<const UHDM::logic_typespec*>(a);
                            if (lt && lt->Elem_typespec() &&
                                    lt->Elem_typespec()->Actual_typespec()) {
                                elem_w = get_width_from_typespec(
                                    lt->Elem_typespec()->Actual_typespec(), current_instance);
                            } else if (lt && lt->Ranges() && lt->Ranges()->size() > 1) {
                                auto r0 = lt->Ranges()->at(0);
                                if (r0->Left_expr() && r0->Right_expr()) {
                                    RTLIL::SigSpec lo = import_expression(r0->Left_expr(), input_mapping);
                                    RTLIL::SigSpec hi = import_expression(r0->Right_expr(), input_mapping);
                                    if (lo.is_fully_const() && hi.is_fully_const()) {
                                        int sz = std::abs(lo.as_const().as_int() -
                                                          hi.as_const().as_int()) + 1;
                                        if (sz > 0 && base_wire->width % sz == 0)
                                            elem_w = base_wire->width / sz;
                                    }
                                }
                            }
                        }
                    }
                }

                // Unpacked array (array_var): the packed logic_typespec path
                // above leaves elem_w=0.  Derive the FIRST unpacked dimension's
                // stride (element width) and low bound from the array_var Ranges
                // so a DYNAMIC index resolves to a $shiftx into the flattened
                // wire.  For `logic m [3:2][2:0]` (bw=6): outer dim size 2 →
                // elem_w=3, array_low=2; `m[sel][i]` = bit (sel-2)*3 + i (the
                // trailing const index selects within the elem_w-bit element
                // below).  Without this a dynamic index returned empty → 0
                // (check_mem/init,non_zero,power_of_two).
                if (elem_w == 0 && base_wire) {
                    if (auto av = dynamic_cast<const UHDM::array_var*>(vs->Actual_group())) {
                        if (av->Ranges() && !av->Ranges()->empty()) {
                            auto r0 = (*av->Ranges())[0];
                            RTLIL::SigSpec l = import_expression(r0->Left_expr(), input_mapping);
                            RTLIL::SigSpec rr = import_expression(r0->Right_expr(), input_mapping);
                            if (l.is_fully_const() && rr.is_fully_const()) {
                                int lv = l.as_const().as_int(), rv = rr.as_const().as_int();
                                int outer = std::abs(lv - rv) + 1;
                                if (outer > 0 && base_wire->width % outer == 0) {
                                    elem_w = base_wire->width / outer;
                                    array_low = std::min(lv, rv);
                                }
                            }
                        }
                    }
                }
                // `element_sig` = value of `base[idx]`.
                RTLIL::SigSpec element_sig;
                if (idx_sig.is_fully_const()) {
                    int array_idx = idx_sig.as_const().as_int();
                    std::string element_name = base_name + "[" + std::to_string(array_idx) + "]";
                    // Dedicated element wire (UNPACKED array)?
                    RTLIL::Wire* element_wire = nullptr;
                    std::string gen_scope = get_current_gen_scope();
                    if (!gen_scope.empty() && name_map.count(gen_scope + "." + element_name))
                        element_wire = name_map[gen_scope + "." + element_name];
                    if (!element_wire && name_map.count(element_name))
                        element_wire = name_map[element_name];
                    if (!element_wire)
                        element_wire = module->wire(RTLIL::escape_id(element_name));
                    // Prefer the in-flight blocking value of this element if one
                    // was assigned earlier in the same comb block — a later RHS
                    // read must see it, not the final wire value.  Without this a
                    // self-referential blocking update like
                    //   dout_array[0] = din_array[0];
                    //   {dout_array[0][1],dout_array[0][0]} = dout_array[0][0] + ...
                    // reads the wire being written and folds to `dout[0] ^ ...`
                    // (mem2reg_test6).
                    if (!in_always_ff_body_mode && current_comb_values.count(element_name)) {
                        element_sig = current_comb_values.at(element_name);
                    } else if (element_wire) {
                        element_sig = RTLIL::SigSpec(element_wire);
                    } else if (elem_w > 0 && base_wire) {
                        int off = (array_idx - array_low) * elem_w;
                        if (off >= 0 && off + elem_w <= base_wire->width)
                            element_sig = RTLIL::SigSpec(base_wire).extract(off, elem_w);
                    }
                    if (element_sig.empty()) {
                        log_warning("vpiVarSelect: element '%s' not found\n", element_name.c_str());
                        return RTLIL::SigSpec();
                    }
                } else if (elem_w > 0 && base_wire) {
                    // Dynamic index — element = (base >> (idx-low)*elem_w)[elem_w]
                    // via $shiftx.  `opt` const-folds it when the index is
                    // effectively constant (PartSelectOfPartSelectedBitSelect:
                    // `iccm[iccm_addr[0:0]][5:0]`, the index is a const-driven
                    // wire slice).  `low` accounts for a non-zero-based unpacked
                    // dimension (`m [3:2][2:0]`).
                    RTLIL::SigSpec shift_amt = idx_sig;
                    shift_amt.extend_u0(32, false);
                    if (array_low != 0)
                        shift_amt = module->Sub(NEW_ID, shift_amt,
                                                RTLIL::Const(array_low, 32), false);
                    if (elem_w > 1)
                        shift_amt = module->Mul(NEW_ID, shift_amt,
                                                RTLIL::Const(elem_w, 32), false);
                    RTLIL::Wire* ew = module->addWire(NEW_ID, elem_w);
                    module->addShiftx(NEW_ID, RTLIL::SigSpec(base_wire), shift_amt, ew);
                    element_sig = RTLIL::SigSpec(ew);
                } else {
                    log_warning("vpiVarSelect '%s': non-constant array index\n", base_name.c_str());
                    return RTLIL::SigSpec();
                }

                RTLIL::SigSpec result = element_sig;

                // If there's a second expression (part_select / bit_select), apply it
                if (exprs->size() > 1) {
                    const expr* second_idx = (*exprs)[1];
                    if (second_idx->VpiType() == vpiConstant) {
                        // Bit index given as a plain constant (`dout_array[0][1]`
                        // — mem2reg_test6).  Extract that bit of the element.
                        RTLIL::SigSpec b = import_expression(second_idx, input_mapping);
                        if (b.is_fully_const()) {
                            int bit_idx = b.as_const().as_int();
                            if (bit_idx >= 0 && bit_idx < element_sig.size())
                                result = element_sig.extract(bit_idx, 1);
                        }
                    } else if (second_idx->VpiType() == vpiPartSelect) {
                        const part_select* ps = any_cast<const part_select*>(second_idx);
                        RTLIL::SigSpec left_sig = import_expression(ps->Left_range(), input_mapping);
                        RTLIL::SigSpec right_sig = import_expression(ps->Right_range(), input_mapping);
                        if (left_sig.is_fully_const() && right_sig.is_fully_const()) {
                            int left_val = left_sig.as_const().as_int();
                            int right_val = right_sig.as_const().as_int();
                            int width = std::abs(left_val - right_val) + 1;
                            int offset = std::min(left_val, right_val);
                            if (offset + width <= element_sig.size()) {
                                result = element_sig.extract(offset, width);
                            } else {
                                log_warning("vpiVarSelect: part select [%d:%d] out of range for %d-bit element of '%s'\n",
                                    left_val, right_val, element_sig.size(), base_name.c_str());
                            }
                        } else {
                            log_warning("vpiVarSelect: non-constant part select on '%s'\n", base_name.c_str());
                        }
                    } else if (second_idx->VpiType() == vpiIndexedPartSelect) {
                        // Indexed part select WITHIN the element:
                        // `wdata[j][i*8 +: 8]`.  This case was missing, so the
                        // access fell through to the generic branch below,
                        // which re-imports the select against the FULL base
                        // wire instead of the element — for a base narrower
                        // than base+width that aborts yosys outright with
                        // "Assert `offset + length <= size()' failed"
                        // (CVA6's behavioural byte-enable SRAM, whose write
                        // loop is exactly this shape).
                        const indexed_part_select* ips =
                            any_cast<const indexed_part_select*>(second_idx);
                        RTLIL::SigSpec base_sig =
                            import_expression(ips->Base_expr(), input_mapping);
                        RTLIL::SigSpec w_sig =
                            import_expression(ips->Width_expr(), input_mapping);
                        bool pos = ips->VpiIndexedPartSelectType() == vpiPosIndexed;
                        if (w_sig.is_fully_const()) {
                            int w = w_sig.as_const().as_int();
                            if (base_sig.is_fully_const() && w > 0) {
                                int b = base_sig.as_const().as_int();
                                int off = pos ? b : (b - w + 1);
                                if (off >= 0 && off + w <= element_sig.size()) {
                                    result = element_sig.extract(off, w);
                                } else {
                                    log_warning("vpiVarSelect: indexed part select "
                                                "[%d +/- %d] out of range for %d-bit "
                                                "element of '%s'\n",
                                                b, w, element_sig.size(),
                                                base_name.c_str());
                                }
                            } else if (!base_sig.empty() && w > 0) {
                                // Dynamic base — shift the ELEMENT, not the
                                // whole array, and take w bits.
                                RTLIL::Wire* y = module->addWire(NEW_ID, w);
                                module->addShiftx(NEW_ID, element_sig, base_sig, y);
                                result = RTLIL::SigSpec(y);
                            }
                        } else {
                            log_warning("vpiVarSelect: non-constant width in indexed "
                                        "part select on '%s'\n", base_name.c_str());
                        }
                    } else if (second_idx->VpiType() == vpiBitSelect) {
                        // Bit select within the element.  Index may be dynamic
                        // (SelfSelects… `a[0][a[0][3:0]]`) → $shiftx.
                        const bit_select* bs = any_cast<const bit_select*>(second_idx);
                        RTLIL::SigSpec bit_sig = bs->VpiIndex()
                            ? import_expression(any_cast<const expr*>(bs->VpiIndex()), input_mapping)
                            : RTLIL::SigSpec();
                        if (bit_sig.is_fully_const()) {
                            int bit_idx = bit_sig.as_const().as_int();
                            if (bit_idx >= 0 && bit_idx < element_sig.size())
                                result = element_sig.extract(bit_idx, 1);
                        } else if (!bit_sig.empty()) {
                            RTLIL::Wire* y = module->addWire(NEW_ID, 1);
                            module->addShiftx(NEW_ID, element_sig, bit_sig, y);
                            result = RTLIL::SigSpec(y);
                        }
                    } else {
                        // Generic second index EXPRESSION (not wrapped in a
                        // bit_select/part_select node) — e.g. an unrolled loop
                        // variable `m[sel][i]` (check_mem/init).  Import it: a
                        // constant selects that bit of the element, a dynamic
                        // value → $shiftx.  Without this the whole element leaked
                        // through and got truncated to bit 0.
                        RTLIL::SigSpec bit_sig = import_expression(second_idx, input_mapping);
                        if (bit_sig.is_fully_const()) {
                            int bit_idx = bit_sig.as_const().as_int();
                            if (bit_idx >= 0 && bit_idx < element_sig.size())
                                result = element_sig.extract(bit_idx, 1);
                        } else if (!bit_sig.empty()) {
                            RTLIL::Wire* y = module->addWire(NEW_ID, 1);
                            module->addShiftx(NEW_ID, element_sig, bit_sig, y);
                            result = RTLIL::SigSpec(y);
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
                        // Pass input_mapping so args resolve function params/locals
                        // in the inline path (rp32 imm_i_f: `$signed(op.imm_11_0)`).
                        RTLIL::SigSpec arg_sig = import_expression(any_cast<const expr*>(arg), input_mapping);
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
                } else if (func_name == "$clog2" && args.size() == 1 &&
                           args[0].is_fully_const()) {
                    // $clog2(n) = ceil(log2(n)) = smallest k with 2^k >= n (0 for
                    // n <= 1).  Needed inline in a part-select bound like
                    // `sub.req_dly[DLY].adr[$clog2(sub.CFG_BUS_BYT)-1:0]`
                    // (tcb_lite_lib_logsize2byteena) where the argument is an
                    // interface localparam that resolves to a constant.
                    uint64_t n = (uint64_t)args[0].as_const().as_int();
                    int r = 0;
                    if (n > 1) { uint64_t v = n - 1; while (v) { v >>= 1; r++; } }
                    return RTLIL::SigSpec(RTLIL::Const(r, 32));
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

                    // `$bits(T)` where T is a TYPE PARAMETER.  Surelog folds
                    // `$bits(pkg::struct_t)` to a constant during elaboration,
                    // but leaves the type-parameter form as an unevaluated
                    // sys_func_call whose argument is a bare `ref_obj` naming
                    // the parameter — importing that ref as an expression
                    // yields 1 bit, so the query collapsed to 1.  CVA6's
                    // hpdcache modules are built on exactly this shape
                    // (`parameter type hpdcache_req_t = …;
                    //   parameter int DATA_WIDTH = $bits(hpdcache_req_t)`),
                    // which sized every data port to 1 instead of 147.
                    // Resolve the parameter's BOUND typespec from the
                    // elaborated instance and measure that instead.
                    if (auto ro = dynamic_cast<const UHDM::ref_obj*>(first_arg)) {
                        const UHDM::typespec* bound_ts = nullptr;
                        if (auto ag = ro->Actual_group()) {
                            if (ag->UhdmType() == uhdmtype_parameter)
                                if (auto tp = any_cast<const UHDM::type_parameter*>(ag))
                                    if (tp->Typespec())
                                        bound_ts = tp->Typespec()->Actual_typespec();
                        }
                        // The ref is often unbound (no Actual_group) — look the
                        // name up among the enclosing instance's type
                        // parameters.  `current_instance` is NOT yet set while
                        // the module's own parameters are being imported (and
                        // `$bits` in a parameter default is exactly that
                        // case), so fall back to walking the call's parent
                        // chain to whatever scope encloses it.
                        if (!bound_ts) {
                            const UHDM::module_inst* mi =
                                dynamic_cast<const UHDM::module_inst*>(
                                    (const UHDM::any*)current_instance);
                            if (!mi) {
                                for (const UHDM::any* up = func_call->VpiParent();
                                     up; up = up->VpiParent()) {
                                    if ((mi = dynamic_cast<const UHDM::module_inst*>(up)))
                                        break;
                                }
                            }
                            if (mi && mi->Parameters()) {
                                for (auto p : *mi->Parameters()) {
                                    if (p->UhdmType() != uhdmtype_parameter) continue;
                                    if (p->VpiName() != ro->VpiName()) continue;
                                    if (auto tp = any_cast<const UHDM::type_parameter*>(p))
                                        if (tp->Typespec())
                                            bound_ts = tp->Typespec()->Actual_typespec();
                                    break;
                                }
                            }
                        }
                        if (bound_ts) {
                            int w = get_width_from_typespec(bound_ts, current_instance);
                            if (w > 0) {
                                total_bits = w;
                                if (func_name == "$bits") {
                                    log_debug("UHDM: $bits(type param %s) = %d\n",
                                              std::string(ro->VpiName()).c_str(), w);
                                    return RTLIL::SigSpec(RTLIL::Const(w, 32));
                                }
                            }
                        }
                    }

                    // `$bits(v)` where v's declared type is a TYPE PARAMETER.
                    // Surelog defers this query to elaboration (it cannot fold
                    // it at definition time, where the parameter has no
                    // binding), so it arrives here as a live sys_func_call whose
                    // argument is a bare ref_obj.  Importing that ref as an
                    // expression can still yield 1 bit, so take the width from
                    // the DECLARATION: resolve the variable's typespec through
                    // the type parameter, falling back to the already-imported
                    // RTLIL wire.  CVA6 cva6_rvfi_probes gates its whole output
                    // on `$bits(rvfi_probes_o.instr) == $bits(instr)`.
                    if (total_bits <= 1) {
                        if (auto ro2 = dynamic_cast<const UHDM::ref_obj*>(first_arg)) {
                            std::string vn2 = std::string(ro2->VpiName());
                            const UHDM::ref_typespec* vrt = nullptr;
                            if (auto ag2 = ro2->Actual_group()) {
                                if (auto v2 = dynamic_cast<const UHDM::variables*>(ag2))
                                    vrt = v2->Typespec();
                                else if (auto n2 = dynamic_cast<const UHDM::net*>(ag2))
                                    vrt = n2->Typespec();
                            }
                            if (!vrt)
                                if (auto mi2 = dynamic_cast<const UHDM::module_inst*>(current_instance)) {
                                    if (mi2->Variables())
                                        for (auto v : *mi2->Variables())
                                            if (std::string(v->VpiName()) == vn2) { vrt = v->Typespec(); break; }
                                    if (!vrt && mi2->Nets())
                                        for (auto n : *mi2->Nets())
                                            if (std::string(n->VpiName()) == vn2) { vrt = n->Typespec(); break; }
                                }
                            int w2 = 0;
                            if (vrt && vrt->Actual_typespec()) {
                                const UHDM::typespec* vts =
                                    resolve_type_param_typespec(vrt->Actual_typespec(), current_instance);
                                if (vts) w2 = get_width_from_typespec(vts, current_instance);
                            }
                            if (w2 <= 1 && !vn2.empty()) {
                                RTLIL::Wire* vw = name_map.count(vn2)
                                                      ? name_map[vn2]
                                                      : module->wire(RTLIL::escape_id(vn2));
                                if (vw) w2 = vw->width;
                            }
                            if (w2 > total_bits) total_bits = w2;
                        }
                    }

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

                // Collect arguments first.  Resolve them against the in-flight
                // blocking values (current_comb_values) when we're inlining into
                // a combinational process and there's no nested-call input_mapping
                // — an argument may be a blocking temp assigned earlier in the same
                // always_comb (Ibex ibex_compressed_decoder: `cm_rlist_d =
                // cm_rlist_init(...)` then `cm_push_store_reg(.rlist(cm_rlist_d))`).
                // Reading the module wire instead would both violate the
                // read-after-write blocking semantics and form a combinational
                // loop (the wire is still being driven by this very process).
                const std::map<std::string, RTLIL::SigSpec>* arg_mapping =
                    input_mapping ? input_mapping
                                  : (current_comb_process ? &current_comb_values : nullptr);
                std::vector<RTLIL::SigSpec> args;
                std::vector<std::string> arg_names;
                if (fc->Tf_call_args()) {
                    for (auto arg : *fc->Tf_call_args()) {
                        RTLIL::SigSpec arg_sig = import_expression(any_cast<const expr*>(arg), arg_mapping);
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
                // instead of creating a separate process (avoids feedback loops).
                // EXCEPT functions whose body has a for loop: the SSA inliner
                // (inline_func_body_comb) doesn't unroll loops or handle a
                // bit-select LHS on the function name, so a body like
                // `for (i) bitrev[i] = val[XLEN-1-i]` (rp32 r5p_mouse) is dropped.
                // Route those to process_function_with_context, whose
                // process_stmt_to_case unrolls the loop and writes the result
                // bit-selects.
                // A NESTED call (input_mapping set — we're already inside a
                // function body being inlined) must NOT use import_func_call_comb:
                // it imports its arguments against current_comb_values, not the
                // caller's input_mapping, so an argument that is the caller's own
                // local/parameter (Ibex cm_stack_adj_word's `cm_stack_adj(
                // .rlist(rlist), …)`, rlist being a 4-bit formal) resolves to a
                // stray 1-bit module wire.  process_function_with_context threads
                // input_mapping into the argument import.
                // Conditional control flow (if / case) IS handled by the SSA
                // inliner (inline_func_body_comb builds branch-muxes over
                // func_mapping and captures per-branch returns), so it stays here.
                // A top-level always_comb call passes &current_comb_values as
                // input_mapping (so `!input_mapping` is NOT how you detect
                // top-level).  A genuinely NESTED call — imported from within
                // another function body being inlined — passes that function's
                // local func_mapping instead.  import_func_call_comb imports its
                // arguments against current_comb_values, so it's only correct for
                // the top-level case; a nested call whose argument is the
                // caller's own local/parameter (Ibex cm_stack_adj_word's
                // `cm_stack_adj(.rlist(rlist), …)`) would resolve rlist to a
                // stray 1-bit wire.  Route nested calls to
                // process_function_with_context, which receives the already-
                // imported args (resolved against the caller's mapping above).
                bool top_level_call =
                    (input_mapping == nullptr || input_mapping == &current_comb_values);
                if (current_comb_process && func_def->Stmt() && top_level_call &&
                    !has_for_loop(func_def->Stmt())) {
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
        case vpiPackedArrayVar: {
            // Value-carrying packed_array_var: Surelog's elaborated hand-off
            // for a packed-array parameter override (fpnew_top's FmtUnitTypes
            // = '{...} of unit-type enums).  Elements() holds one value-tagged
            // var per element, declaration order = left index first = MSBs.
            // Without this the parameter imported EMPTY and every
            // fpnew_opgroup_block generate decision (PARALLEL/MERGED slices)
            // collapsed.
            auto pav = any_cast<const UHDM::packed_array_var*>(uhdm_expr);
            if (pav && pav->Elements() && !pav->Elements()->empty()) {
                int total = pav->VpiSize();
                int n = (int)pav->Elements()->size();
                if (total > 0 && n > 0 && total % n == 0) {
                    int ew = total / n;
                    RTLIL::SigSpec res;
                    bool ok = true;
                    for (int i = n - 1; i >= 0; i--) {
                        auto ev = dynamic_cast<const UHDM::variables*>(
                            (*pav->Elements())[i]);
                        std::string vs2 =
                            ev ? std::string(ev->VpiValue()) : std::string();
                        if (vs2.empty()) { ok = false; break; }
                        RTLIL::Const c = extract_const_from_value(vs2);
                        if (c.size() == 0) { ok = false; break; }
                        if (c.size() > ew) c = RTLIL::Const(c.extract(0, ew));
                        else if (c.size() < ew) c.resize(ew, RTLIL::State::S0);
                        res.append(RTLIL::SigSpec(c));
                    }
                    if (ok && res.size() == total) {
                        if (mode_debug)
                            log("UHDM: packed_array_var assembled to %d-bit constant\n",
                                total);
                        return res;
                    }
                }
            }
            log_warning("Unsupported expression type: %s\n",
                        UhdmName(uhdm_expr->UhdmType()).c_str());
            return RTLIL::SigSpec();
        }
        case vpiStructVar: {
            // READER-SIDE assembly first: walk the struct_var's typespec
            // members and evaluate each member's annotated value with OUR
            // import machinery — package params, casts, patterns and logical
            // ops all resolve here, while ExprEval lacks the context functors
            // and failed on `CVA6ConfigA && CVA6ConfigB`-style member values.
            // Packing: first declared member = MSBs (RTLIL Const bits are
            // LSB-first, so the LAST member's bits go in first).
            {
                auto sv0 = any_cast<const struct_var*>(uhdm_expr);
                // Re-entrancy guard: a member's value expression can
                // reference the SAME config struct
                // (`NonIdemPotenceEn = CVA6Cfg.NrNonIdempotentRules != 0 &&
                // ...`) — without the guard the inner reference re-enters
                // this assembly and recurses to a stack overflow.  Inside
                // the guard the inner hier_path resolves through the
                // typespec-member annotation walk instead.
                static thread_local std::set<const UHDM::any*> rasm_in_progress;
                if (rasm_in_progress.count(uhdm_expr)) {
                    log_warning("Unsupported expression type: %s\n",
                                UhdmName(uhdm_expr->UhdmType()).c_str());
                    return RTLIL::SigSpec();
                }
                rasm_in_progress.insert(uhdm_expr);
                auto rasm_cleanup = [&]() { rasm_in_progress.erase(uhdm_expr); };
                std::function<bool(const UHDM::struct_typespec*, RTLIL::Const&)>
                    asm_members = [&](const UHDM::struct_typespec* stps,
                                      RTLIL::Const& out) -> bool {
                    if (!stps || !stps->Members()) return false;
                    std::vector<RTLIL::Const> vals;  // declaration order
                    for (auto member : *stps->Members()) {
                        const UHDM::typespec* mts =
                            member->Typespec()
                                ? member->Typespec()->Actual_typespec()
                                : nullptr;
                        int mw = get_width_from_typespec(mts, current_instance);
                        if (mw <= 0 && mts &&
                            mts->UhdmType() == uhdmenum_typespec) {
                            auto ets =
                                any_cast<const UHDM::enum_typespec*>(mts);
                            if (ets->Base_typespec() &&
                                ets->Base_typespec()->Actual_typespec())
                                mw = get_width_from_typespec(
                                    ets->Base_typespec()->Actual_typespec(),
                                    current_instance);
                            if (mw <= 0) mw = 32;
                        }
                        if (mw <= 0) {
                            return false;
                        }
                        const UHDM::any* mv = member->Actual_value();
                        if (!mv) mv = member->Default_value();
                        RTLIL::Const mc;
                        bool got = false;
                        if (mv) {
                            if (mv->UhdmType() == uhdmstruct_var) {
                                const UHDM::struct_typespec* nst = nullptr;
                                auto nsv = any_cast<const struct_var*>(mv);
                                if (nsv->Typespec())
                                    nst = dynamic_cast<
                                        const UHDM::struct_typespec*>(
                                        nsv->Typespec()->Actual_typespec());
                                if (!nst && mts &&
                                    mts->UhdmType() == uhdmstruct_typespec)
                                    nst = any_cast<
                                        const UHDM::struct_typespec*>(mts);
                                got = asm_members(nst, mc);
                            } else if (auto me =
                                           dynamic_cast<const expr*>(mv)) {
                                bool saved_fcf = force_const_fold;
                                int saved_ctx = expression_context_width;
                                force_const_fold = true;
                                expression_context_width = mw;
                                RTLIL::SigSpec msig = import_expression(me);
                                expression_context_width = saved_ctx;
                                force_const_fold = saved_fcf;
                                if (msig.is_fully_const() &&
                                    msig.is_fully_def()) {
                                    mc = msig.as_const();
                                    got = true;
                                }
                            }
                        }
                        if (!got) {
                            return false;
                        }
                        if (mc.size() > mw) {
                            mc = mc.extract(0, mw);
                        } else if (mc.size() < mw) {
                            RTLIL::SigSpec t(mc);
                            t.extend_u0(mw, false);
                            mc = t.as_const();
                        }
                        vals.push_back(mc);
                    }
                    std::vector<RTLIL::State> packed;
                    for (auto it = vals.rbegin(); it != vals.rend(); ++it)
                        for (int i = 0; i < it->size(); i++)
                            packed.push_back((*it)[i]);
                    out = RTLIL::Const(packed);
                    return true;
                };
                RTLIL::Const full;
                const UHDM::struct_typespec* stps = nullptr;
                if (sv0->Typespec())
                    stps = dynamic_cast<const UHDM::struct_typespec*>(
                        sv0->Typespec()->Actual_typespec());
                bool rasm_ok = asm_members(stps, full) && full.size() > 0;
                rasm_cleanup();
                if (rasm_ok) {
                    if (mode_debug)
                        log("UHDM: struct_var reader-assembled to %d-bit constant\n",
                            full.size());
                    return RTLIL::SigSpec(full);
                }
            }
            // A function-computed struct VALUE (`parameter cva6_cfg_t CVA6Cfg =
            // build_config(...)` — the param_assign RHS is an opaque struct_var
            // whose typespec members carry the evaluated field constants).
            // ExprEval assembles the packed constant from those annotations;
            // without this the value imported as EMPTY and a function argument
            // fed from it (`is_inside_execute_regions(CVA6Cfg, paddr)`)
            // materialized as an all-zero 17217-bit Cfg — every config member
            // read 0 and pmp_data_if never raised the PMA access fault.
            ExprEval eval;
            bool invalidValue = false;
            expr* res = eval.reduceExpr(uhdm_expr, invalidValue,
                                        current_instance
                                            ? (const any*)current_instance
                                            : nullptr,
                                        uhdm_expr->VpiParent(), true);
            if (res) {
                if (!invalidValue && res->UhdmType() == uhdmconstant) {
                    RTLIL::SigSpec cv =
                        import_constant(any_cast<const constant*>(res));
                    if (cv.is_fully_const() && cv.is_fully_def()) {
                        if (mode_debug)
                            log("UHDM: struct_var assembled to %d-bit constant\n",
                                cv.size());
                        return cv;
                    }
                }
            }
            log_warning("Unsupported expression type: %s\n",
                        UhdmName(uhdm_expr->UhdmType()).c_str());
            return RTLIL::SigSpec();
        }
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
                    // IEEE 1800 §5.7.1 value extension: a sized literal whose
                    // most-significant specified digit is x or z is x/z-EXTENDED,
                    // not zero-extended.  Surelog gives `32'bx` as BIN:x with
                    // vpiSize 32 (a single `x` digit), which must become 32 bits
                    // of x — not `0…0x` (undef_eqx_nex's `=== 32'bx`).
                    RTLIL::State msb = sig.size() > 0
                        ? sig[sig.size() - 1].data : RTLIL::State::S0;
                    if (!is_signed && (msb == RTLIL::State::Sx || msb == RTLIL::State::Sz)) {
                        while (sig.size() < size) sig.append(RTLIL::SigBit(msb));
                    } else {
                        sig.extend_u0(size, is_signed);
                    }
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
            
            // Create hex constant with proper bit width.  Build via the
            // nibble-by-nibble helper so arbitrarily wide values work (std::stoull
            // caps at 64 bits — a 160-bit `logic [159:0]` constant overflowed it).
            {
                RTLIL::Const const_val = extract_const_from_value("HEX:" + hex_str);
                int target = size > 0 ? size : const_val.size();
                if (const_val.size() != target)
                    const_val = const_val.extract(0, target, RTLIL::State::S0);
                return RTLIL::SigSpec(const_val);
            }
        }
        case vpiDecConst: {
            std::string dec_str = value.substr(4);
            int width = (size > 0) ? size : 32;
            // A decimal constant can be all-x / all-z — an unsized `'x` / `'z`
            // literal that Surelog stored as DEC:x / DEC:z (rp32 r5p_mouse has
            // one).  stoll would throw on the letter, so map it to an X/Z const.
            if (dec_str.find_first_of("xX") != std::string::npos)
                return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::Sx, width));
            if (dec_str.find_first_of("zZ") != std::string::npos)
                return RTLIL::SigSpec(RTLIL::Const(RTLIL::State::Sz, width));
            try {
                // Use stoll to handle larger integers
                long long int_val = std::stoll(dec_str);
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
                // An UNSIZED value (vpiSize == -1, e.g. the folded `~'hF` in
                // cva6_tlb's napot mask) must not pass -1 as the Const width —
                // yosys v0.68's WIDTH_LIMIT assert rejects it (v0.67 silently
                // built a bogus Const).  Use the propagated context width, else
                // the natural 64 bits of the folded value.
                int w = size > 0 ? size
                        : (expression_context_width > 0 ? expression_context_width
                                                        : 64);
                // Handle UHDM format: "UINT:value"
                if (value.substr(0, 5) == "UINT:") {
                    std::string num_str = value.substr(5);
                    // Use stoull to handle large values like 18446744073709551615 (0xFFFFFFFFFFFFFFFF)
                    unsigned long long uint_val = std::stoull(num_str);
                    return RTLIL::SigSpec(RTLIL::Const(uint_val, w));
                } else {
                    // Handle plain number format
                    unsigned long long uint_val = std::stoull(value);
                    return RTLIL::SigSpec(RTLIL::Const(uint_val, w));
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
int UhdmImporter::self_determined_width(const UHDM::any* node,
        const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    if (!node)
        return 0;
    if (node->VpiType() == vpiOperation) {
        const operation* op = any_cast<const operation*>(node);
        std::vector<const UHDM::any*> ops;
        if (op->Operands())
            for (auto o : *op->Operands())
                ops.push_back(o);
        auto W = [&](size_t i) -> int {
            return i < ops.size() ? self_determined_width(ops[i], input_mapping) : 0;
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
            case vpiWildEqOp: case vpiWildNeqOp:
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
        return import_expression(e, input_mapping).size();
    return 0;
}

// Width-equalise the two operands of a case-equality (=== / !==) to their max
// width using IEEE 1800 §5.7.1 value extension: a constant whose MSB is x or z
// is x/z-EXTENDED into the wider comparison context, not zero-extended.  Needed
// because $eqx/$nex zero-extend the narrower operand, which would make
// `0/0 === 32'bx` compare a 64-bit all-x (Surelog sizes the unsized `0` at 64
// bits) against `{32'b0, 32'bx}` and wrongly return 0 (undef_eqx_nex).
static void xz_value_extend_pair(RTLIL::SigSpec &a, RTLIL::SigSpec &b) {
    int w = std::max(a.size(), b.size());
    auto ext = [&](RTLIL::SigSpec &s) {
        if (s.size() >= w) return;
        RTLIL::State fill = RTLIL::State::S0;
        if (s.is_fully_const() && s.size() > 0) {
            RTLIL::State msb = s[s.size() - 1].data;
            if (msb == RTLIL::State::Sx || msb == RTLIL::State::Sz) fill = msb;
        }
        while (s.size() < w) s.append(RTLIL::SigBit(fill));
    };
    ext(a);
    ext(b);
}

// Import operation
// An assignment-pattern operation carries no typespec of its own, and in a
// PROCEDURAL context its parent is an `assignment` (or a `cont_assign`) rather
// than the `param_assign` the pattern handlers originally expected.  Recover the
// target type from the assignment's LHS so `'{...}` can be laid out against the
// real struct.  Returns null when the LHS carries no typespec.
static const UHDM::typespec* assignment_lhs_typespec(const UHDM::operation* uhdm_op) {
    if (!uhdm_op || !uhdm_op->VpiParent()) return nullptr;
    const UHDM::any* lhs = nullptr;
    if (uhdm_op->VpiParent()->UhdmType() == uhdmassignment)
        lhs = any_cast<const UHDM::assignment*>(uhdm_op->VpiParent())->Lhs();
    else if (uhdm_op->VpiParent()->UhdmType() == uhdmcont_assign)
        lhs = any_cast<const UHDM::cont_assign*>(uhdm_op->VpiParent())->Lhs();
    // A PARAMETER initialiser (`localparam cfg_t LIT = '{n: 3, base: ...}`) is a
    // param_assign.  The `'{default:}` handler has its own param_assign case,
    // but the named-field handler had none.
    else if (uhdm_op->VpiParent()->UhdmType() == uhdmparam_assign)
        lhs = any_cast<const UHDM::param_assign*>(uhdm_op->VpiParent())->Lhs();
    if (!lhs) return nullptr;
    // A ref_obj LHS points at the declaration that carries the typespec.
    if (auto r = dynamic_cast<const UHDM::ref_obj*>(lhs))
        if (auto ag = r->Actual_group()) lhs = ag;
    // An ELEMENT write into an unpacked array (`resp_o[1] <= '{err:..,..}`
    // on a type-param'd struct array — the pattern-write sibling of
    // typaram_struct_array_elem_read): the element struct lives on the
    // array_var's INNER var (vpiReg), not on the bit_select or the array.
    // Without it the pattern fell back to the ctx/count width guess, an
    // operation member inflated to the LHS width, and the final truncation
    // kept {data[41:0], last} — err/id silently dropped.
    if (auto bsl = dynamic_cast<const UHDM::bit_select*>(lhs))
        if (auto ag = bsl->Actual_group()) lhs = ag;
    if (auto av = dynamic_cast<const UHDM::array_var*>(lhs)) {
        if (av->Variables() && !av->Variables()->empty())
            if (auto v0 = dynamic_cast<const UHDM::variables*>(
                    (*av->Variables())[0]))
                if (v0->Typespec())
                    return v0->Typespec()->Actual_typespec();
    }
    const UHDM::ref_typespec* rt = nullptr;
    if (auto pm = dynamic_cast<const UHDM::parameter*>(lhs)) rt = pm->Typespec();
    else if (auto sv = dynamic_cast<const UHDM::struct_var*>(lhs)) rt = sv->Typespec();
    else if (auto uv = dynamic_cast<const UHDM::union_var*>(lhs)) rt = uv->Typespec();
    else if (auto sn = dynamic_cast<const UHDM::struct_net*>(lhs)) rt = sn->Typespec();
    else if (auto lv = dynamic_cast<const UHDM::logic_var*>(lhs)) rt = lv->Typespec();
    else if (auto ln = dynamic_cast<const UHDM::logic_net*>(lhs)) rt = ln->Typespec();
    else if (auto pav = dynamic_cast<const UHDM::packed_array_var*>(lhs)) {
        if (pav->Elements() && !pav->Elements()->empty())
            if (auto e0 = dynamic_cast<const UHDM::expr*>((*pav->Elements())[0]))
                rt = e0->Typespec();
    }
    return rt ? rt->Actual_typespec() : nullptr;
}

// Rewrite chunks of `res` that reference a wire carrying an in-flight (blocking)
// value in the current always_comb onto that value.  A read of a signal the SAME
// block writes must observe the value written earlier in the block; reading the
// process's own output wire instead closes a combinational loop (CVA6 id_stage:
// `if (!issue_n[0].valid)` follows `issue_n[0].valid = 1'b0`).  Applied only to
// operation OPERANDS and comb conditions, which are values, never assignment
// targets, so a write target is never rewritten to a non-wire.
static RTLIL::SigSpec remap_sig_inflight(const RTLIL::SigSpec& res,
                                         const std::map<std::string, RTLIL::SigSpec>& ccv) {
    if (res.empty() || ccv.empty()) return res;
    RTLIL::SigSpec out;
    bool changed = false;
    for (const auto& ch : res.chunks()) {
        if (ch.wire) {
            std::string wn = ch.wire->name.str();
            if (!wn.empty() && wn[0] == '\\') wn = wn.substr(1);
            auto it = ccv.find(wn);
            if (it != ccv.end() && it->second.size() == ch.wire->width &&
                ch.offset + ch.width <= it->second.size()) {
                out.append(it->second.extract(ch.offset, ch.width));
                changed = true;
                continue;
            }
        }
        out.append(RTLIL::SigSpec(ch));
    }
    return changed ? out : res;
}

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
        // `'{default: V}` — a tagged_pattern whose tag typespec is named
        // "default" fills EVERY member of the target struct/union with V
        // (UnionParameter: `flimish_giant LovingHome = '{default: 1}`).  The
        // generic operand loop below casts each operand to `expr` and would skip
        // the tagged_pattern, yielding 0.
        if (uhdm_op->Operands()) {
            const UHDM::tagged_pattern* deftp = nullptr;
            for (auto operand : *uhdm_op->Operands()) {
                if (operand->UhdmType() != uhdmtagged_pattern) continue;
                auto tp = any_cast<const UHDM::tagged_pattern*>(operand);
                // The `default` tag is the tagged_pattern's typespec — a
                // string_typespec named "default" (reached via Actual_typespec).
                if (tp->Typespec()) {
                    std::string tn = std::string(tp->Typespec()->VpiName());
                    if (auto a = tp->Typespec()->Actual_typespec())
                        if (tn.empty()) tn = std::string(a->VpiName());
                    if (tn == "default") { deftp = tp; break; }
                }
            }
            // Target struct/union typespec — on the op, else on the op's parent
            // param_assign's Lhs parameter (the op itself carries no typespec).
            const UHDM::typespec* ats = nullptr;
            if (uhdm_op->Typespec()) ats = uhdm_op->Typespec()->Actual_typespec();
            if (!ats && uhdm_op->VpiParent() &&
                uhdm_op->VpiParent()->UhdmType() == uhdmparam_assign) {
                auto pa = any_cast<const UHDM::param_assign*>(uhdm_op->VpiParent());
                if (pa->Lhs())
                    if (auto p = dynamic_cast<const UHDM::parameter*>(pa->Lhs()))
                        if (p->Typespec()) ats = p->Typespec()->Actual_typespec();
            }
            // Recover the target type from a procedural assignment's LHS, but
            // ONLY for a struct/union target.  The packed-VECTOR branch further
            // down sizes the fill to `ats`'s full width, and handing it the
            // whole LHS object there produced a 104256-bit constant in
            // rp32_r5p_csr (Verilator then refused to build the netlist).  The
            // vector case keeps using the context width, as before.
            if (!ats)
                if (auto lt = assignment_lhs_typespec(uhdm_op))
                    if (lt->UhdmType() == uhdmstruct_typespec ||
                        lt->UhdmType() == uhdmunion_typespec)
                        ats = lt;
            const VectorOftypespec_member* members = nullptr;
            if (ats && ats->UhdmType() == uhdmstruct_typespec)
                members = any_cast<const UHDM::struct_typespec*>(ats)->Members();
            else if (ats && ats->UhdmType() == uhdmunion_typespec)
                members = any_cast<const UHDM::union_typespec*>(ats)->Members();
            if (deftp && members && deftp->Pattern()) {
                RTLIL::SigSpec defval =
                    import_expression(any_cast<const expr*>(deftp->Pattern()), input_mapping);
                // NAMED tags override the default for their member —
                // `'{is_normal: 1'b1, is_boxed: 1'b1, default: 1'b0}`
                // (fpnew_fma's ADD-arm info_a) filled every field with the
                // default and dropped the named ones, so is_normal read 0 and
                // the injected 1.0 multiplicand lost its implicit bit.
                std::map<std::string, const UHDM::expr*> named_tags;
                for (auto operand : *uhdm_op->Operands()) {
                    if (operand->UhdmType() != uhdmtagged_pattern) continue;
                    auto tp = any_cast<const UHDM::tagged_pattern*>(operand);
                    if (!tp->Typespec() || !tp->Pattern()) continue;
                    std::string tn = std::string(tp->Typespec()->VpiName());
                    if (auto a = tp->Typespec()->Actual_typespec())
                        if (tn.empty()) tn = std::string(a->VpiName());
                    if (!tn.empty() && tn != "default")
                        named_tags[tn] = any_cast<const expr*>(tp->Pattern());
                }
                RTLIL::SigSpec result;
                // First member at MSB (concat order), matching packed layout.
                for (int i = (int)members->size() - 1; i >= 0; i--) {
                    auto m = (*members)[i];
                    int mw = 0;
                    if (auto mts = m->Typespec())
                        if (auto a = mts->Actual_typespec())
                            mw = get_width_from_typespec(a, inst);
                    RTLIL::SigSpec v;
                    auto nt = named_tags.find(std::string(m->VpiName()));
                    if (nt != named_tags.end())
                        v = import_expression(nt->second, input_mapping);
                    else
                        v = defval;
                    if (mw > 0) {
                        if (v.size() < mw) v.extend_u0(mw);
                        else if (v.size() > mw) v = v.extract(0, mw);
                    }
                    result.append(v);
                }
                if (result.size() > 0)
                    return result;
            }

            // `'{default: V}` on a PACKED VECTOR / packed array target
            // (`logic [TLB_ENTRIES-1:0] m = RVH ? '{default: 0} : '{default: 1}`,
            // CVA6 cva6_tlb match_vmid): every ELEMENT gets V — for a plain
            // vector the elements are single bits, so `'{default: 1}` is
            // all-ones, NOT the literal 1 the generic loop below produced.
            if (deftp && !members && deftp->Pattern()) {
                int ew = 1, tw = 0;
                if (ats) {
                    tw = get_width_from_typespec(ats, inst);
                    if (auto pt = dynamic_cast<const UHDM::packed_array_typespec*>(ats)) {
                        if (pt->Elem_typespec() && pt->Elem_typespec()->Actual_typespec()) {
                            int w = get_width_from_typespec(
                                pt->Elem_typespec()->Actual_typespec(), inst);
                            if (w > 0) ew = w;
                        }
                    } else if (auto lt = dynamic_cast<const UHDM::logic_typespec*>(ats)) {
                        // Multi-range vector `logic [A][B]`: element = product of
                        // the inner ranges; single range → 1-bit elements.
                        if (lt->Ranges() && lt->Ranges()->size() >= 2) {
                            int iw = 1;
                            for (size_t ri = 1; ri < lt->Ranges()->size(); ri++) {
                                auto rn = (*lt->Ranges())[ri];
                                RTLIL::SigSpec il = import_expression(rn->Left_expr(), input_mapping);
                                RTLIL::SigSpec ir = import_expression(rn->Right_expr(), input_mapping);
                                if (il.is_fully_const() && ir.is_fully_const())
                                    iw *= std::abs(il.as_const().as_int() -
                                                   ir.as_const().as_int()) + 1;
                            }
                            if (iw > 0) ew = iw;
                        }
                    }
                }
                if (tw <= 0) tw = expression_context_width;
                RTLIL::SigSpec defval = import_expression(
                    any_cast<const expr*>(deftp->Pattern()), input_mapping);
                // In a PROCEDURAL assignment the pattern carries no typespec,
                // so the element width above stays 1 and the value is
                // replicated BIT-wise -- `'{default: rd_idx_i[sel]}` on a
                // `logic [3:0][7:0]` filled all 32 bits with bit 0 of the
                // 8-bit value (wt_dcache_mem's bank_idx).  When the fill value
                // is a NON-CONSTANT expression narrower than the target and
                // dividing it evenly, it is already element-typed, so take its
                // width as the element width.  Constant fills (`'{default: 0}`,
                // `'{default: 1}`) keep the bitwise semantics they need.
                if (ew == 1 && !defval.is_fully_const() && defval.size() > 1 &&
                    tw > defval.size() && tw % defval.size() == 0)
                    ew = defval.size();
                if (tw > 0 && ew > 0 && tw % ew == 0) {
                    if (defval.size() < ew) defval.extend_u0(ew);
                    else if (defval.size() > ew) defval = defval.extract(0, ew);
                    RTLIL::SigSpec result;
                    for (int i = 0; i < tw / ew; i++) result.append(defval);
                    if (result.size() > 0)
                        return result;
                }
            }
        }

        // Struct/array aggregate: '{field: val, field: val, ...}
        // Surelog stores the value expressions directly as operands (hier_path, ref_obj, etc.),
        // in struct field definition order (first field = MSB for packed structs).
        // Same concatenation order as vpiConcatOp: first operand at MSB —
        // UNLESS the operation has `vpiReordered:1` set, which means
        // Surelog already reordered the operands into LSB-first order
        // (post-substitution path in the elaborated TopModules).
        if (uhdm_op->Operands()) {
            std::vector<RTLIL::SigSpec> field_sigs;
            // When the target width is known (expression_context_width), every
            // element is context/count bits — size each leaf to that and
            // PROPAGATE the per-element width down so nested patterns size their
            // own leaves.  A packed `logic [1:0][2:0][3:0]` pattern then folds to
            // 24 bits, not 24*64 (ParameterPackedArray).  No context (=0) keeps
            // the prior behaviour, so struct/other patterns are unaffected.
            int pat_count = (int)uhdm_op->Operands()->size();
            // Target width: the surrounding context, else the pattern's own
            // typespec (on the op, or on the op's param_assign parent's
            // parameter) — the latter bootstraps a packed-array PARAMETER init at
            // module-import time, where no context is set (ParameterPackedArray).
            int ctx_w = expression_context_width;
            if (ctx_w == 0) {
                const UHDM::typespec* myts = nullptr;
                if (uhdm_op->Typespec()) myts = uhdm_op->Typespec()->Actual_typespec();
                if (!myts && uhdm_op->VpiParent() &&
                    uhdm_op->VpiParent()->UhdmType() == uhdmparam_assign) {
                    auto pa = any_cast<const UHDM::param_assign*>(uhdm_op->VpiParent());
                    if (pa->Lhs())
                        if (auto p = dynamic_cast<const UHDM::parameter*>(pa->Lhs()))
                            if (p->Typespec()) myts = p->Typespec()->Actual_typespec();
                }
                if (myts) {
                    int w = get_width_from_typespec(myts, inst);
                    if (w > 0) ctx_w = w;
                }
            }
            int pelem_w = (ctx_w > 0 && pat_count > 0 && ctx_w % pat_count == 0)
                          ? ctx_w / pat_count : 0;
            // For a STRUCT target the fields have (possibly) UNEQUAL widths, so
            // the ctx/count assumption is wrong — resolve each field's real width
            // from the struct typespec instead.  Prefer the op's own typespec,
            // then the threaded LHS context typespec.
            const UHDM::struct_typespec* struct_ts = nullptr;
            {
                const UHDM::typespec* cand = nullptr;
                if (uhdm_op->Typespec()) cand = uhdm_op->Typespec()->Actual_typespec();
                if ((!cand || cand->UhdmType() != uhdmstruct_typespec) &&
                    expression_context_typespec &&
                    expression_context_typespec->UhdmType() == uhdmstruct_typespec)
                    cand = expression_context_typespec;
                // Neither is set for a PROCEDURAL `r = '{sign: .., exponent: '1,
                // ..}` (CVA6 fpnew_noncomp's NaN-box canonicalization), so every
                // field fell back to the ctx/count guess — 32/3 is not a whole
                // number, giving field_w 0, no per-field resizing, and a concat
                // wider than the target whose TOP fields (sign, exponent) were
                // then truncated away: 0x00400000 instead of 0x7fc00000.
                if (!cand || cand->UhdmType() != uhdmstruct_typespec)
                    if (auto lt = assignment_lhs_typespec(uhdm_op))
                        if (lt->UhdmType() == uhdmstruct_typespec) cand = lt;
                if (cand && cand->UhdmType() == uhdmstruct_typespec)
                    struct_ts = any_cast<const UHDM::struct_typespec*>(cand);
            }
            int field_idx = 0;
            for (auto operand : *uhdm_op->Operands()) {
                const expr* field_expr = nullptr;
                // Named-field patterns (`'{a: 0, b: 1, ...}`) wrap each value in a
                // `tagged_pattern` (not an expr), so unwrap its Pattern(); these
                // are emitted in struct field order (PatternAssignmentOfStructParam).
                // The tagged_pattern's typespec (a string_typespec) names the
                // target field — use it to look up that field's exact width.
                int field_w = pelem_w;
                if (operand->UhdmType() == uhdmtagged_pattern) {
                    auto tp = any_cast<const UHDM::tagged_pattern*>(operand);
                    if (tp && tp->Pattern())
                        field_expr = any_cast<const expr*>(tp->Pattern());
                    if (struct_ts && struct_ts->Members() && tp && tp->Typespec()) {
                        if (auto tag = tp->Typespec()->Actual_typespec()) {
                            std::string fname = std::string(tag->VpiName());
                            for (auto m : *struct_ts->Members())
                                if (std::string(m->VpiName()) == fname) {
                                    if (auto mt = m->Typespec())
                                        if (auto at = mt->Actual_typespec())
                                            field_w = get_width_from_typespec(at, inst);
                                    break;
                                }
                        }
                    }
                } else {
                    field_expr = any_cast<const expr*>(operand);
                    // An ELABORATED struct parameter's pattern carries BARE
                    // exprs in declaration order -- Surelog strips the tags --
                    // so the tagged_pattern branch above never runs and every
                    // field fell back to the ctx/count guess.  For a 96-bit
                    // {int unsigned; logic[63:0]} that is 96/2 = 48 bits apiece,
                    // packing {48'd3, 48'h1000} instead of {32'd3, 64'h1000}, so
                    // every field then reads at the wrong offset (CVA6
                    // pmp_data_if: Cfg.NrExecuteRegionRules came out 0).
                    // Size positionally from the struct's members instead.
                    if (struct_ts && struct_ts->Members() &&
                        (int)struct_ts->Members()->size() == pat_count) {
                        auto m = (*struct_ts->Members())[field_idx];
                        if (auto mt = m->Typespec())
                            if (auto at = mt->Actual_typespec()) {
                                int w = get_width_from_typespec(at, inst);
                                if (w > 0) field_w = w;
                            }
                    }
                }
                field_idx++;
                if (!field_expr) continue;
                int saved_ctx = expression_context_width;
                if (field_w > 0) expression_context_width = field_w;
                RTLIL::SigSpec val = import_expression(field_expr, input_mapping);
                expression_context_width = saved_ctx;
                if (field_w > 0) {
                    if (val.size() > field_w) val = val.extract(0, field_w);
                    else if (val.size() < field_w) val.extend_u0(field_w);
                }
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

    if (op_type == vpiMultiAssignmentPatternOp) {
        // Replicated array aggregate: '{N{pattern}}.  Operands: [0] = count
        // constant N, [1] = the pattern element (often wrapped in a concat).
        // Build the element value once and replicate it N times.  First element
        // ends up at the MSB (same order as concatenation).
        if (uhdm_op->Operands() && uhdm_op->Operands()->size() >= 2) {
            auto& ops = *uhdm_op->Operands();
            RTLIL::SigSpec count_sig = import_expression(any_cast<const expr*>(ops[0]), input_mapping);
            int count = count_sig.is_fully_const() ? count_sig.as_const().as_int() : 0;
            RTLIL::SigSpec elem = import_expression(any_cast<const expr*>(ops[1]), input_mapping);
            // Each replicated element occupies target_width/count bits.  Surelog
            // sizes a bare literal `1` to its natural width (e.g. 64), so without
            // this `'{8{1}}` into `logic [7:0]` would build a 512-bit value and
            // truncate to 0x01 instead of 0xFF.  Resize the element to the
            // per-element width when the target (context) width is known.
            if (expression_context_width > 0 && count > 0 &&
                expression_context_width % count == 0) {
                int ew = expression_context_width / count;
                if ((int)elem.size() > ew) elem = elem.extract(0, ew);
                else if ((int)elem.size() < ew) elem.extend_u0(ew);
            }
            RTLIL::SigSpec result;
            for (int i = 0; i < count; i++)
                result.append(elem);
            if (mode_debug)
                log("UHDM: MultiAssignmentPatternOp %d x %d-bit = %d-bit\n",
                    count, elem.size(), result.size());
            return result;
        }
        return RTLIL::SigSpec();
    }

    // `x inside {v1, v2, [lo:hi], ...}` set-membership EXPRESSION: a vpiInsideOp
    // whose operand[0] is the test value and whose remaining operands are the
    // set members — a plain value (`x == v`) or a vpiListOp of two values for a
    // `[lo:hi]` range (`x >= lo && x <= hi`).  Result is the 1-bit OR of all
    // member matches (OneInside).  (The `case (x) inside` form is handled
    // separately in import_case_stmt_comb.)
    if (op_type == vpiInsideOp && uhdm_op->Operands() &&
        uhdm_op->Operands()->size() >= 2) {
        auto& ops = *uhdm_op->Operands();
        RTLIL::SigSpec lhs = import_expression(any_cast<const UHDM::expr*>(ops[0]), input_mapping);
        bool sg = is_expr_signed(any_cast<const UHDM::expr*>(ops[0]));
        auto match_eq = [&](RTLIL::SigSpec a, RTLIL::SigSpec b) {
            int w = std::max(a.size(), b.size());
            if (a.size() < w) a.extend_u0(w, sg);
            if (b.size() < w) b.extend_u0(w, sg);
            return module->Eq(NEW_ID, a, b, false);
        };
        RTLIL::SigSpec result;
        for (size_t i = 1; i < ops.size(); i++) {
            RTLIL::SigSpec cond;
            auto lop = dynamic_cast<const UHDM::operation*>(ops[i]);
            if (lop && lop->VpiOpType() == vpiListOp && lop->Operands() &&
                lop->Operands()->size() == 2) {
                RTLIL::SigSpec lo = import_expression(any_cast<const UHDM::expr*>((*lop->Operands())[0]), input_mapping);
                RTLIL::SigSpec hi = import_expression(any_cast<const UHDM::expr*>((*lop->Operands())[1]), input_mapping);
                int w = std::max({lhs.size(), lo.size(), hi.size()});
                RTLIL::SigSpec lx = lhs, lox = lo, hix = hi;
                if (lx.size() < w) lx.extend_u0(w, sg);
                if (lox.size() < w) lox.extend_u0(w, sg);
                if (hix.size() < w) hix.extend_u0(w, sg);
                cond = module->And(NEW_ID,
                    module->Ge(NEW_ID, lx, lox, sg),
                    module->Le(NEW_ID, lx, hix, sg));
            } else {
                cond = match_eq(lhs, import_expression(any_cast<const UHDM::expr*>(ops[i]), input_mapping));
            }
            result = result.empty() ? cond : module->Or(NEW_ID, result, cond);
        }
        if (result.empty()) result = RTLIL::SigSpec(RTLIL::State::S0);
        return result;
    }

    // A TYPED named assignment pattern `T'{field: val, ...}` is emitted by
    // Surelog as a cast (vpiCastOp) wrapping a CONCAT whose operands alternate
    // (member-name ref_obj, value): the field-name keys leak in as unresolved
    // refs — producing undriven phantom wires + "unknown signal" warnings — and
    // the values are otherwise dropped (rp32 hamster/degu NOP = `op32_i_t'{...}`
    // collapses to 0).  Detect this shape (each odd operand is a ref_obj naming
    // a member of the cast's struct type) and build the struct value from the
    // VALUE operands in member order, matching the non-cast `'{...}` path.
    if (op_type == vpiCastOp && uhdm_op->Operands() &&
        uhdm_op->Operands()->size() == 1) {
        const struct_typespec* sts = nullptr;
        if (auto rt = uhdm_op->Typespec())
            if (auto at = rt->Actual_typespec())
                if (at->UhdmType() == uhdmstruct_typespec)
                    sts = any_cast<const struct_typespec*>(at);
        auto inner = dynamic_cast<const UHDM::operation*>((*uhdm_op->Operands())[0]);
        if (sts && sts->Members() && inner &&
            inner->VpiOpType() == vpiConcatOp && inner->Operands() &&
            inner->Operands()->size() == sts->Members()->size() * 2) {
            auto& iops = *inner->Operands();
            auto& mems = *sts->Members();
            std::map<std::string, const UHDM::expr*> field_val;
            bool tagged = true;
            for (size_t i = 0; i < iops.size() && tagged; i += 2) {
                auto key = dynamic_cast<const ref_obj*>(iops[i]);
                auto val = dynamic_cast<const UHDM::expr*>(iops[i + 1]);
                if (!key || !val) { tagged = false; break; }
                std::string kn = std::string(key->VpiName());
                bool is_member = false;
                for (auto m : mems)
                    if (std::string(m->VpiName()) == kn) { is_member = true; break; }
                if (!is_member) { tagged = false; break; }
                field_val[kn] = val;
            }
            if (tagged && field_val.size() == mems.size()) {
                // Concat the per-field values in member order (first member =
                // MSB), each sized to its member width.
                RTLIL::SigSpec result;
                for (int i = (int)mems.size() - 1; i >= 0; i--) {
                    std::string mn = std::string(mems[i]->VpiName());
                    int mw = 0;
                    if (auto mt = mems[i]->Typespec())
                        if (auto ma = mt->Actual_typespec())
                            mw = get_width_from_typespec(
                                const_cast<UHDM::typespec*>(ma), inst);
                    RTLIL::SigSpec v = import_expression(field_val[mn], input_mapping);
                    if (mw > 0) {
                        if (v.size() < mw) v.extend_u0(mw);
                        else if (v.size() > mw) v = v.extract(0, mw);
                    }
                    result.append(v);
                }
                return result;
            }
        }
    }

    // Try to reduce it first (for non-side-effect operations). We skip
    // `vpiCastOp` here: Surelog's reduceExpr folds `8'(4'(signed'(...)))`
    // into a single constant but applies plain zero-extension at the
    // final widen — losing the explicit `signed'`/`unsigned'` cast and
    // producing the wrong bits (static_cast_simple).  Our own cast
    // handler below tracks signedness through the chain correctly.
    // An UNBASED UNSIZED fill literal (`'1`/`'0`/`'x`/`'z`, VpiSize()==-1) in a
    // context-determined position must REPLICATE to the context width, but
    // reduceExpr collapses it to a single bit and we then zero-extend — CVA6
    // cva6_ptw's `assign req_port_o.data_be = CVA6Cfg.IS_XLEN32 ? be_gen_32(…)
    // : '1;` folded to 8'h01 instead of 8'hff.  Let the operand-wise path below
    // handle those (it sizes fill branches to the context).
    bool has_unsized_fill_operand = false;
    if (op_type == vpiConditionOp && uhdm_op->Operands())
        for (auto o : *uhdm_op->Operands())
            if (auto c = dynamic_cast<const UHDM::constant*>(o))
                if (c->VpiSize() == -1) { has_unsized_fill_operand = true; break; }

    // A hier_path operand rooted at a STRUCT-typed parameter must go through
    // our own operand-wise import: ExprEval resolves the base parameter to its
    // stamped VALUE constant, which for a function-computed config that failed
    // whole-struct elaboration is a garbage 0 (hpdcache's HPDcacheCfg is
    // stamped BIN:0 through the opaque struct_var override hand-off), and the
    // member select of that garbage folds the whole operation confidently
    // wrong — `!HPDcacheCfg.u.lowLatency` became constant 1 and st1 logic
    // that must be dead stayed live.  import_hier_path resolves these through
    // the typespec-member value annotations instead.
    bool has_struct_param_hier_operand = false;
    if (uhdm_op->Operands()) {
        for (auto o : *uhdm_op->Operands()) {
            auto ohp = dynamic_cast<const UHDM::hier_path*>(o);
            if (!ohp || !ohp->Path_elems() || ohp->Path_elems()->size() < 2)
                continue;
            auto r0 = dynamic_cast<const ref_obj*>((*ohp->Path_elems())[0]);
            if (!r0) continue;
            const UHDM::parameter* bp =
                dynamic_cast<const UHDM::parameter*>(r0->Actual_group());
            if (!bp && !r0->Actual_group() && current_instance) {
                std::string bn(r0->VpiName());
                if (!bn.empty() && current_instance->Parameters())
                    for (auto p0 : *current_instance->Parameters())
                        if (std::string(p0->VpiName()) == bn) {
                            bp = dynamic_cast<const UHDM::parameter*>(p0);
                            break;
                        }
            }
            if (bp && bp->Typespec() && bp->Typespec()->Actual_typespec() &&
                bp->Typespec()->Actual_typespec()->UhdmType() ==
                    uhdmstruct_typespec) {
                has_struct_param_hier_operand = true;
                break;
            }
        }
    }

    if (op_type != vpiCastOp && !has_unsized_fill_operand &&
        !has_struct_param_hier_operand) {
        ExprEval eval;
        bool invalidValue = false;
        expr* res = eval.reduceExpr(uhdm_op, invalidValue, inst, uhdm_op->VpiParent(), true);
        // invalidValue MUST gate the result: a partially-failed reduction
        // (e.g. `(XLEN'(1) << (XLEN-1)) | XLEN'(5)` with a void-typespec
        // cast) returns a GARBAGE constant with invalidValue=true — CVA6
        // decoder folded every INTERRUPTS.* field to 1'b1 through this.
        if (res && !invalidValue && res->UhdmType() == uhdmconstant) {
            return import_constant(dynamic_cast<const UHDM::constant*>(res));
        }
    }

    // No RTLIL module to emit into: width probing (type_param_signature) runs
    // BEFORE import_module creates `module`, and everything below this point
    // creates wires/cells.  A non-foldable operation here (cvxif driver's
    // `parameter type` port ranges with unresolved params) previously
    // SEGFAULTed in module->addWire.  Returning empty yields a stable
    // approximate width, which is all the signature needs (same contract as
    // import_hier_path's null-module guard).
    if (!module) {
        if (mode_debug)
            log("    import_operation: no RTLIL module yet — cannot emit cells, returning empty\n");
        return RTLIL::SigSpec();
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
               op_type == vpiWildEqOp || op_type == vpiWildNeqOp ||
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
        //
        // But zero context is not right either: per LRM 11.8.2 the operands
        // are evaluated at max(self-size(A), self-size(B)), and that width
        // must flow INTO nested arithmetic.  `p - z + 1 >= 0` sized the
        // inner sub at 10 bits while the 32/64-bit literal `1` widened the
        // add — p-z wrapped for p-z < -512 and the (signed) compare took
        // the wrong branch (fpnew_fma subnormals; signed_interm_cmp).
        expression_context_width = 0;
        if (uhdm_op->Operands() && uhdm_op->Operands()->size() == 2) {
            int sa = self_determined_width((*uhdm_op->Operands())[0], input_mapping);
            int sb = self_determined_width((*uhdm_op->Operands())[1], input_mapping);
            if (sa > 0 && sb > 0)
                expression_context_width = std::max(sa, sb);
        }
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
            // The ternary CONDITION (operand 0) is SELF-DETERMINED per LRM
            // 11.4.11 — importing it under the assignment's wide LHS context
            // widened `~less` to 64 bits BEFORE the inversion, making the
            // condition nonzero for BOTH values of `less` (CVA6 alu MIN/MINU
            // always returned operand_b).
            // A replication COUNT (operand 0 of `{count{expr}}`) is a
            // compile-time constant expression — force const folding so a
            // struct-param arithmetic count (`{{53+CVA6Cfg.VLEN-64{sign}}}`,
            // CVA6 instr_scan rvc_imm_o) folds instead of emitting cells and
            // zero-filling the replication.
            int cond_saved_ctx = expression_context_width;
            bool cond_saved_fcf = force_const_fold;
            if ((op_type == vpiConditionOp || op_type == vpiMultiConcatOp) &&
                operands.empty()) {
                expression_context_width = 0;
                if (op_type == vpiMultiConcatOp)
                    force_const_fold = true;
            }
            RTLIL::SigSpec op_sig = import_expression(any_cast<const expr*>(operand), input_mapping);
            if (op_type == vpiConditionOp || op_type == vpiMultiConcatOp) {
                expression_context_width = cond_saved_ctx;
                force_const_fold = cond_saved_fcf;
            }
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
            if (input_mapping == &current_comb_values && current_comb_process &&
                !in_always_ff_body_mode && !in_always_ff_context)
                op_sig = remap_sig_inflight(op_sig, current_comb_values);
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
    // Short-circuit logical ops with a dominant constant operand, regardless
    // of context: `HPDcacheCfg.u.eccScrubberEn && st1_dat_err_i` with the
    // config field folded to 0 must be constant 0 so the guarded branch is
    // PRUNED at import (a $logic_and cell keeps the branch as a runtime
    // switch, changing comb threading even though opt later removes it).
    if ((op_type == vpiLogAndOp || op_type == vpiLogOrOp) &&
        operands.size() == 2) {
        for (int oi = 0; oi < 2; oi++) {
            if (!operands[oi].is_fully_const()) continue;
            bool as_true = operands[oi].as_const().as_bool();
            if (op_type == vpiLogAndOp && !as_true &&
                operands[oi].is_fully_def())
                return RTLIL::SigSpec(RTLIL::State::S0);
            if (op_type == vpiLogOrOp && as_true)
                return RTLIL::SigSpec(RTLIL::State::S1);
        }
    }

    if (all_const && operands.size() > 0 &&
        (!loop_values.empty() || getCurrentFunctionContext() != nullptr ||
         !gen_scope_stack.empty() || force_const_fold ||
         has_struct_param_hier_operand ||
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
            case vpiPowerOp:
                if (operands.size() == 2) {
                    // `base ** exp` with constant operands (e.g. the genvar
                    // `2 ** level` index arithmetic in lzc.sv's generate loops)
                    // MUST fold to a constant here — otherwise it falls through
                    // to the vpiPowerOp handler below and emits a runtime $pow
                    // cell.  In CVA6 this produced ~4700 spurious $pow cells (the
                    // reference slang netlist has zero).  Self-determined width;
                    // the caller applies any wider assignment context.
                    result = RTLIL::const_pow(operands[0].as_const(), operands[1].as_const(), false, false, -1);
                }
                break;
            case vpiLShiftOp:
                if (operands.size() == 2) {
                    // NB: RTLIL::const_shl passes result_len straight to
                    // extend_u0() (unlike const_shr, which guards it with
                    // max(result_len, size)), so a result_len of -1 becomes
                    // resize((size_t)-1) and throws std::vector::_M_fill_insert.
                    // Pass max(context, left-operand size) — same LRM sizing
                    // rule as the cell path: the context may widen the shift
                    // but truncation belongs to the assignment.  Using the
                    // bare operand size folded `1'b1 << 4` (a 1-bit left
                    // operand) to ZERO inside
                    //   cnt_d = cnt_q + (1'b1 << CVA6Cfg.DCACHE_OFFSET_WIDTH);
                    // (CVA6 miss_handler's flush counter), so the FLUSHING
                    // loop never advanced and the whole flush sequence — and
                    // everything ordered after it — diverged from the first
                    // post-reset cycle.  (The "caller applies any wider
                    // context" note was wrong for a fold nested inside a
                    // wider arithmetic expression.)
                    result = RTLIL::const_shl(operands[0].as_const(), operands[1].as_const(),
                                              false, false,
                                              std::max(expression_context_width,
                                                       operands[0].size()));
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
                // VALUE comparison, not bit-vector identity: RTLIL::Const's
                // operator== also compares the WIDTH, so a 32-bit 0 (what an
                // unrolled loop variable folds to) compared against a 64-bit
                // literal 0 came out FALSE.  `y == 0` inside an unrolled
                // `for (int unsigned y …)` therefore always folded to 0 —
                // CVA6 cva6_ptw's `shared_tlb_update_o.is_page[x][y] =
                // y == 0 ? … : 1'b0` lost every y==0 term.  const_eq extends
                // both operands to a common width first, like the const_lt /
                // const_gt cases below already did.
                if (operands.size() == 2) {
                    result = RTLIL::const_eq(operands[0].as_const(), operands[1].as_const(),
                                             false, false, 1);
                }
                break;
            case vpiNeqOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_ne(operands[0].as_const(), operands[1].as_const(),
                                             false, false, 1);
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
            case vpiLogAndOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_logic_and(operands[0].as_const(), operands[1].as_const(), false, false, 1);
                }
                break;
            case vpiLogOrOp:
                if (operands.size() == 2) {
                    result = RTLIL::const_logic_or(operands[0].as_const(), operands[1].as_const(), false, false, 1);
                }
                break;
            case vpiNotOp:
                if (operands.size() == 1) {
                    result = RTLIL::const_logic_not(operands[0].as_const(), RTLIL::Const(), false, false, 1);
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

    // An unsized fill literal ('0 / '1 / 'x / 'z) in a COMPARISON is
    // context-determined: it replicates to the width of the other operand.
    // It arrives here as a SINGLE BIT, so `exponent != '1` compared against
    // 5'b00001 instead of 5'b11111 — CVA6 fpnew_classifier's is_normal,
    // is_inf and is_nan all hinge on `exponent == '1`, and every operand was
    // misclassified.  Replicate it before the per-operator sizing below.
    if ((op_type == vpiEqOp || op_type == vpiNeqOp ||
         op_type == vpiCaseEqOp || op_type == vpiCaseNeqOp ||
         op_type == vpiWildEqOp || op_type == vpiWildNeqOp ||
         op_type == vpiLtOp || op_type == vpiLeOp ||
         op_type == vpiGtOp || op_type == vpiGeOp) &&
        operands.size() == 2 && uhdm_op->Operands() &&
        uhdm_op->Operands()->size() == 2) {
        auto& uops = *uhdm_op->Operands();
        for (int k = 0; k < 2; k++) {
            auto fc = dynamic_cast<const UHDM::constant*>(uops[k]);
            if (!fc || fc->VpiSize() != -1) continue;      // not a fill literal
            const int other = 1 - k;
            if (operands[k].size() != 1) continue;         // already sized
            if (operands[other].size() <= 1) continue;
            if (!operands[k].is_fully_const()) continue;
            RTLIL::State bit = operands[k].as_const()[0];
            operands[k] = RTLIL::SigSpec(bit, operands[other].size());
            if (mode_debug)
                log("    fill literal operand %d replicated to %d bits\n",
                    k, operands[other].size());
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
                for (size_t oi = 0; oi < operands.size(); oi++) {
                    const auto& operand = operands[oi];
                    bool op_signed = false;
                    if (operand.is_wire()) {
                        op_signed = operand.as_wire()->is_signed;
                    } else if (operand.is_fully_const()) {
                        op_signed = (operand.as_const().flags &
                                     RTLIL::CONST_FLAG_SIGNED) != 0;
                    }
                    // The RTLIL view loses signedness for an intermediate
                    // operation result (anonymous wire, never marked) and for
                    // unsuffixed decimal literals (signed per LRM §5.7.1, but
                    // the flag isn't set on import) — fall back to the UHDM
                    // expression.  fpnew_fma's `p - z + 1 >= 0` zero-extended
                    // the signed 10-bit sub into a 64-bit add, so -1 compared
                    // as 1023 and the subnormal branch was never taken.
                    if (!op_signed && uhdm_op->Operands() &&
                        oi < uhdm_op->Operands()->size()) {
                        if (auto oe = any_cast<const expr*>(
                                (*uhdm_op->Operands())[oi]))
                            op_signed = is_expr_signed(oe);
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
                    // NB: is_signed is true only when EVERY operand is signed
                    // (LRM §11.8.1), so extension follows it directly.  A
                    // wire-level `is_signed` veto here zero-extended
                    // intermediate operation results (anonymous wires are
                    // never marked signed) — fpnew_fma's `p - z + 1`.
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
                if (is_signed) mark_result_signed(result);
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
                    // NB: is_signed is true only when EVERY operand is signed
                    // (LRM §11.8.1), so extension follows it directly.  A
                    // wire-level `is_signed` veto here zero-extended
                    // intermediate operation results (anonymous wires are
                    // never marked signed) — fpnew_fma's `p - z + 1`.
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
                if (is_signed) mark_result_signed(result);
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
                // Result width: MAX of the context width and the left
                // operand's width (SV context-determined sizing).  The context
                // may only WIDEN, never clip: a narrow context leaking through
                // enclosing reductions truncated `~(1 << sel_q)` to 1 BIT in
                //   assign any_unselected_port_valid = |(req_flat & ~(1 << sel_q));
                // (CVA6 miss_handler's axi_adapter_arbiter), so the fairness
                // mask kept only port 0 and the arbiter re-granted the selected
                // port while others were waiting — std_cache_subsystem served
                // AXI requests in the wrong order.
                int result_width = std::max(
                    expression_context_width > 0 ? expression_context_width : 0,
                    operands[0].size());
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
                int result_width = std::max(
                    expression_context_width > 0 ? expression_context_width : 0,
                    operands[0].size());
                // (max(), not context alone: a narrow leaked context must not
                // clip the shift — see the vpiLShiftOp comment above.)
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
                    RTLIL::SigSpec a = operands[0], b = operands[1];
                    xz_value_extend_pair(a, b);
                    std::string cell_name = generate_cell_name(uhdm_op, "eqx");
                    return module->Eqx(RTLIL::escape_id(cell_name), a, b);
                }
            break;
        case vpiCaseNeqOp:
            // Case inequality (!==) - use $nex, the X/Z-aware counterpart of $eqx
            // (undef_eqx_nex's `0/1 !== 32'bx`).  Without this the op was
            // unhandled → empty RHS → the assigned bit defaulted to 0.
            if (operands.size() == 2)
                {
                    RTLIL::SigSpec a = operands[0], b = operands[1];
                    xz_value_extend_pair(a, b);
                    std::string cell_name = generate_cell_name(uhdm_op, "nex");
                    return module->Nex(RTLIL::escape_id(cell_name), a, b);
                }
            break;
        case vpiWildEqOp:
        case vpiWildNeqOp:
            // Wildcard equality `==?` / `!=?`: bits where the RHS pattern is x/z
            // are DON'T-CARE (unlike `===`/$eqx, which require an exact x match).
            // The pattern is normally a constant literal (rp32
            // tcb_lite_lib_decoder `adr ==? DAM[i]`, DAM carries x wildcards).
            // Build a care-mask from the constant RHS (1 where it is 0/1) and
            // compare only those bits: (a & mask) == (b_with_x_as_0).  Without
            // this the op was unsupported → 0, so no address ever matched and
            // every peripheral store was misrouted to data memory.
            if (operands.size() == 2)
                {
                    RTLIL::SigSpec a = operands[0], b = operands[1];
                    xz_value_extend_pair(a, b);
                    RTLIL::SigSpec res;
                    if (b.is_fully_const()) {
                        std::vector<RTLIL::State> mask, bdef;
                        for (auto bit : b.as_const().to_bits()) {
                            bool care = (bit == RTLIL::State::S0 ||
                                         bit == RTLIL::State::S1);
                            mask.push_back(care ? RTLIL::State::S1 : RTLIL::State::S0);
                            bdef.push_back(care ? bit : RTLIL::State::S0);
                        }
                        RTLIL::SigSpec am = module->And(NEW_ID, a, RTLIL::Const(mask));
                        res = module->Eq(NEW_ID, am, RTLIL::Const(bdef));
                    } else {
                        // Non-constant pattern: no compile-time wildcards.
                        res = module->Eq(NEW_ID, a, b);
                    }
                    if (op_type == vpiWildNeqOp)
                        res = module->Not(NEW_ID, res);
                    return res;
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
                // An UNBASED UNSIZED fill literal branch (`'1`, `'0`, `'x`,
                // `'z` — VpiSize()==-1) is 1 bit as imported but must
                // REPLICATE to the result width, not zero-extend.  CVA6
                // cva6_ptw's `assign req_port_o.data_be = CVA6Cfg.IS_XLEN32 ?
                // be_gen_32(…) : '1;` produced data_be = 8'h01 instead of
                // 8'hff.  The assignment sites already handle a bare fill RHS;
                // inside a ternary the branch never reached them.  Take the
                // width from the other branch, else the surrounding context.
                auto fill_state_of = [&](size_t i) -> std::pair<bool, RTLIL::State> {
                    if (!uhdm_op->Operands() || uhdm_op->Operands()->size() < 3)
                        return {false, RTLIL::State::S0};
                    auto c = dynamic_cast<const UHDM::constant*>(
                        (*uhdm_op->Operands())[i]);
                    if (!c || c->VpiSize() != -1) return {false, RTLIL::State::S0};
                    std::string v(c->VpiValue());
                    if (v == "BIN:1") return {true, RTLIL::State::S1};
                    if (v == "BIN:0") return {true, RTLIL::State::S0};
                    if (v == "BIN:x" || v == "BIN:X") return {true, RTLIL::State::Sx};
                    if (v == "BIN:z" || v == "BIN:Z") return {true, RTLIL::State::Sz};
                    return {false, RTLIL::State::S0};
                };
                auto tf = fill_state_of(1), ff = fill_state_of(2);
                // A `?:` is context-determined (LRM 11.4.11): the surrounding
                // assignment width wins over the sibling branch's own width —
                // `data_be = cond ? be_gen_32(…4 bits…) : '1` must fill all 8
                // LHS bits, not 4.  Fall back to the sibling branch when there
                // is no context.
                int fill_w = expression_context_width > 0
                                 ? expression_context_width
                                 : max_width;
                if ((tf.first || ff.first) && fill_w > max_width) max_width = fill_w;
                RTLIL::SigSpec true_val = operands[1];
                RTLIL::SigSpec false_val = operands[2];
                if (tf.first && fill_w > 0) true_val = RTLIL::SigSpec(tf.second, fill_w);
                if (ff.first && fill_w > 0) false_val = RTLIL::SigSpec(ff.second, fill_w);

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
        case vpiListOp:
            // `case … inside` wraps each label in a ListOp (Surelog emits a
            // SINGLE-element list per label) — transparently its value.
            // Multi-element lists are expanded at the case-label sites.
            if (operands.size() == 1)
                return operands[0];
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
                // An EXPLICIT slice size `{<<8{val}}` is operand[0] (a constant)
                // with the value in operand[1]; an IMPLICIT one `{<<{val}}` has
                // just the value (slice = 1 bit).  The value is the inner concat,
                // already collapsed to one SigSpec (StreamOp).
                RTLIL::SigSpec src;
                int slice_w = 1;
                if (operands.size() >= 2) {
                    if (operands[0].is_fully_const())
                        slice_w = std::max(1, operands[0].as_const().as_int());
                    src = operands[1];
                } else {
                    src = operands[0];
                    if (uhdm_op->Typespec())
                        if (auto ats = uhdm_op->Typespec()->Actual_typespec())
                            slice_w = std::max(1, get_width_from_typespec(ats, inst));
                }
                int n = src.size();
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
                            // EXPRESSION-width size cast — `((CVA6Cfg.PtLevels +
                            // HYP_EXT) * (CVA6Cfg.VpnLen / CVA6Cfg.PtLevels))'
                            // (vpn_to_store)` (CVA6 cva6_tlb tag update):
                            // VpiValue is EMPTY and the width lives in the
                            // integer_typespec's Expr().  Without this the
                            // fallthrough defaulted to 32 and the oversized
                            // cast STOLE bits from the enclosing concat (the
                            // stored TLB asid lost its top 5 bits).
                            if (target_width <= 0 && its->Expr()) {
                                bool saved = force_const_fold;
                                force_const_fold = true;
                                RTLIL::SigSpec ws = import_expression(its->Expr());
                                force_const_fold = saved;
                                if (ws.is_fully_const() && ws.as_const().as_int() > 0) {
                                    target_width = ws.as_const().as_int();
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
                        // (byte/int/short/long/typedef/struct/logic).  A
                        // VOID typespec means the cast width did NOT
                        // elaborate (`CVA6Cfg.XLEN'(expr)`) — get_width would
                        // default it to 1 and silently TRUNCATE the operand
                        // (CVA6 INTERRUPTS.* collapsed through
                        // `(XLEN'(1)<<(XLEN-1))`); leave it unresolved so the
                        // pass-through fallback below keeps the operand.
                        if (target_width <= 0 &&
                            ts->UhdmType() != uhdmvoid_typespec) {
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
                            // An UNSIZED fill literal (`'1`, `'0`, `'x`, `'z`,
                            // VpiSize==-1) self-replicates its single state to
                            // the cast width.  A regular sized constant must NOT
                            // — `int'(2'b11)` is the value 3, not a fill, so it
                            // zero-extends (logic is unsigned), not all-ones
                            // (BitSelectPartSelectInFunction).
                            bool is_fill_literal = false;
                            if (uhdm_op->Operands() && !uhdm_op->Operands()->empty()) {
                                if (auto c = dynamic_cast<const UHDM::constant*>(
                                        uhdm_op->Operands()->at(0)))
                                    is_fill_literal = (c->VpiSize() == -1);
                            }
                            RTLIL::State fill = src_signed ? const_val.back()
                                                           : RTLIL::State::S0;
                            if (is_fill_literal) {
                                bool all_x = true, all_z = true, all_0 = true, all_1 = true;
                                for (auto bit : const_val) {
                                    if (bit != RTLIL::State::Sx) all_x = false;
                                    if (bit != RTLIL::State::Sz) all_z = false;
                                    if (bit != RTLIL::State::S0) all_0 = false;
                                    if (bit != RTLIL::State::S1) all_1 = false;
                                }
                                if (all_x)      fill = RTLIL::State::Sx;
                                else if (all_z) fill = RTLIL::State::Sz;
                                else if (all_1) fill = RTLIL::State::S1;
                                else if (all_0) fill = RTLIL::State::S0;
                            }
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
            // Cast with an unresolvable width (`CVA6Cfg.XLEN'(expr)` leaves a
            // void_typespec when the width expression didn't elaborate):
            // return the operand UNCHANGED rather than an empty SigSpec —
            // Surelog pre-sizes the operand constants where it can (the
            // `XLEN'(1)` literal arrives as a 64-bit constant), and an empty
            // result poisons every enclosing fold (CVA6 INTERRUPTS.* pattern
            // exprs collapsed through `(XLEN'(1)<<(XLEN-1)) | XLEN'(5)`).
            if (operands.size() == 1 && !operands[0].empty()) {
                if (mode_debug)
                    log("    Cast with unresolved width: passing operand through (%d bits)\n",
                        operands[0].size());
                return operands[0];
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
    // Break reference CYCLES.  A parameter whose value resolves back to itself
    // (directly, or around a chain of parameters) recursed through
    // import_expression until the stack was exhausted: CVA6's fpnew_top died
    // with SIGSEGV about 53,000 frames deep, reported only as an opaque
    // "crash".  Guard on the OBJECT, not a depth counter, so genuinely deep
    // (but finite) parameter chains still resolve.
    struct CycleGuard {
        std::set<const UHDM::any*>& set_;
        const UHDM::any* key_;
        bool inserted_;
        CycleGuard(std::set<const UHDM::any*>& s, const UHDM::any* k)
            : set_(s), key_(k), inserted_(s.insert(k).second) {}
        ~CycleGuard() { if (inserted_) set_.erase(key_); }
    } _cycle_guard(ref_obj_in_progress, uhdm_ref);
    if (!_cycle_guard.inserted_) {
        log_warning("UHDM: cyclic reference through '%s' — returning empty "
                    "instead of recursing\n",
                    std::string(uhdm_ref->VpiName()).c_str());
        return RTLIL::SigSpec();
    }
    // Get the referenced object name
    std::string ref_name = std::string(uhdm_ref->VpiName());
    
    if (mode_debug)
        log("    Importing ref_obj: %s (current_gen_scope: %s)\n", ref_name.c_str(), get_current_gen_scope().c_str());
    
    // A loop variable being unrolled must resolve to the CURRENT iteration's
    // constant.  A comb_read_map()-threaded input_mapping can carry a STALE
    // value for the same name — e.g. the post-loop `i = N` recorded by an
    // EARLIER unrolled loop in the same block, truncated to the loop var's
    // wire width (CVA6 frontend: the second loop's `cf_type[i]` wrote element
    // 0 on EVERY iteration).  Genuine function-argument mappings keep
    // priority: a function body's own parameter shadows any outer loop var.
    if (input_mapping && !getCurrentFunctionContext() && loop_values.count(ref_name))
        return RTLIL::SigSpec(RTLIL::Const(loop_values[ref_name], 32));

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

    // A bare reference to a whole UNPACKED ARRAY (`logic [2:0] a [3:0]`,
    // `int x [1:0][0:0]`) — e.g. passing it as a function argument
    // `get_3rd(a)` / `my_func(x)` — resolves to the concatenation of its
    // per-element wires (\a[0]..\a[N-1]), element 0 at the LSB so the callee's
    // flattened formal lines up (mat[i] == a[i]).  Without this the bare name
    // resolved to a 1-bit unknown wire and the callee read garbage.
    // (SelectFromUnpackedInFunction / 2DUnpackedFunctionArgument.)
    if (!name_map.count(ref_name)) {
        // Probe the array's low bound — usually 0, but a `[N:1]` declaration
        // (CVA6 perf_counters) starts at 1.
        int wa_low = -1;
        for (int probe = 0; probe <= 64; probe++)
            if (name_map.count(ref_name + "[" + std::to_string(probe) + "]")) {
                wa_low = probe;
                break;
            }
        if (wa_low >= 0) {
            std::string gs = get_current_gen_scope();
            RTLIL::SigSpec arr;
            for (int i = wa_low; ; i++) {
                std::string en = ref_name + "[" + std::to_string(i) + "]";
                RTLIL::Wire* ew = nullptr;
                if (!gs.empty() && name_map.count(gs + "." + en))
                    ew = name_map[gs + "." + en];
                else if (name_map.count(en))
                    ew = name_map[en];
                if (!ew) break;
                arr.append(RTLIL::SigSpec(ew));
            }
            if (arr.size() > 0) {
                log("    ref_obj: whole unpacked array %s -> %d-bit element concat\n",
                    ref_name.c_str(), arr.size());
                return arr;
            }
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

        // A ref bound directly to a folded CONSTANT: Surelog pre-evaluates
        // computed interface localparams (e.g. `CFG_BUS_SIZ = $clog2(...)` ->
        // UINT:2) and binds the bare-name ref straight to that constant.  Return
        // it so range bounds like `[CFG_BUS_SIZ-1:0]` fold and struct fields get
        // their true width (else the field collapses to 1 bit).
        if (actual->UhdmType() == uhdmconstant) {
            return import_constant(any_cast<const constant*>(actual));
        }
        
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
        
        // A COMPUTED interface localparam referenced by bare name: Surelog
        // substitutes `sub.CFG_BUS_BYT` -> `CFG_BUS_BYT` and binds the ref
        // directly to its value OPERATION (e.g. `CFG.BUS.DAT/8`).  Fold it via
        // import_expression — its `CFG.BUS.DAT` operand routes through
        // eval_param_struct_field (base CFG's own Actual_group is the interface's
        // struct parameter).  Needed for the tcb_lite_lib_logsize2byteena
        // `$clog2(sub.CFG_BUS_BYT)` part-select bound.
        if (actual->UhdmType() == uhdmoperation) {
            bool saved_fcf = force_const_fold;
            force_const_fold = true;
            RTLIL::SigSpec v = import_expression(any_cast<const expr*>(actual), input_mapping);
            force_const_fold = saved_fcf;
            if (v.is_fully_const()) return v;
        }

        if (actual->VpiType() == vpiParameter) {
            const parameter* param = any_cast<const parameter*>(actual);
            std::string param_name = std::string(param->VpiName());

            // For parameterized modules, prefer the module's actual parameter value
            // over the base module's VpiValue (which may be the unelaborated default)
            RTLIL::Const param_value;
            RTLIL::IdString p_id = RTLIL::escape_id(param_name);
            // `module` is null when importing a PACKAGE parameter's value
            // expression (no RTLIL module context) — guard the lookup, else a
            // package parameter that references another parameter segfaults
            // (ibex_tracer_pkg).
            // An EMPTY (zero-width) entry is not a value.  A struct-typed
            // parameter whose initialiser could not be folded lands here as a
            // width-0 constant, and consuming it zero-extends the whole struct
            // to 0.  Fall through to the VpiValue / Expr / param_assign paths,
            // which at least have a chance of resolving it.
            if (module && module->parameter_default_values.count(p_id) &&
                module->parameter_default_values.at(p_id).size() > 0) {
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
                            if (value_part == "1" && param_width > 1) {
                                // Surelog stamps the `'1` unbased-unsized fill
                                // as a bare "BIN:1" (the fill-constant
                                // signature — VpiSize -1 on constants); on a
                                // wider-typed parameter it must REPLICATE to
                                // all-ones, not zero-extend.  fpnew's
                                // `FpFmtConfig = '1` came through as 5'b00001
                                // and super_format() saw one enabled format.
                                param_value = RTLIL::Const(RTLIL::State::S1,
                                                           param_width);
                            } else if (bin_const.size() != param_width) {
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
                        // A MODULE parameter's VpiParent is the module_inst, not
                        // a param_assign, so this fallback never fired for one --
                        // its initialiser lives in the instance's
                        // Param_assigns().  Find it by name.
                        if ((!parent || parent->UhdmType() != uhdmparam_assign) &&
                            current_instance) {
                            if (auto mi = dynamic_cast<const UHDM::module_inst*>(current_instance))
                                if (mi->Param_assigns())
                                    for (auto pa2 : *mi->Param_assigns())
                                        if (auto l = dynamic_cast<const UHDM::parameter*>(pa2->Lhs()))
                                            if (std::string(l->VpiName()) == param_name) {
                                                parent = pa2; break;
                                            }
                        }
                        if (parent && parent->UhdmType() == uhdmparam_assign) {
                            const param_assign* pa = any_cast<const param_assign*>(parent);
                            if (pa && pa->Rhs()) {
                                // A COMPUTED interface localparam (e.g.
                                // `localparam CFG_BUS_SIZ = $clog2($clog2(CFG.BUS.DAT/8)+1)`)
                                // has its value expression chained through the OWNING
                                // interface's other localparams and its CFG struct
                                // parameter.  Force-fold so the whole $clog2 chain
                                // (recursing through this same param_assign path and
                                // routing `CFG.BUS.*` accesses through
                                // eval_iface_param_field) collapses to a constant width.
                                bool saved_fcf = force_const_fold;
                                force_const_fold = true;
                                RTLIL::SigSpec expr_val = import_expression(
                                    any_cast<const expr*>(pa->Rhs()));
                                force_const_fold = saved_fcf;
                                if (expr_val.is_fully_const()) {
                                    param_value = expr_val.as_const();
                                }
                            }
                        } else if (auto scp = dynamic_cast<const UHDM::scope*>(parent)) {
                            // PACKAGE/scope parameter (e.g. a struct param like
                            // `parameter page_addr_t SeedInfoPageSel = '{...}`):
                            // VpiValue/Expr are empty, the value lives in the
                            // enclosing scope's Param_assigns() keyed by Lhs name.
                            if (scp->Param_assigns()) {
                                for (auto pa : *scp->Param_assigns()) {
                                    if (pa->Lhs() &&
                                        std::string(pa->Lhs()->VpiName()) == param_name &&
                                        pa->Rhs()) {
                                        RTLIL::SigSpec ev = import_expression(
                                            any_cast<const expr*>(pa->Rhs()));
                                        if (ev.is_fully_const())
                                            param_value = ev.as_const();
                                        break;
                                    }
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
    
    // Unbound reference to an interface localparam (`CFG_BUS_BYT = CFG.BUS.DAT/8`,
    // `CFG_BUS_SIZ = $clog2($clog2(CFG_BUS_BYT)+1)`): the ref lives in the
    // interface's shared req_t typespec (`logic [CFG_BUS_SIZ-1:0] siz`) and
    // carries no Actual_group, so it isn't caught by the Actual_group->parameter
    // path above.  When a module reaches the interface only through a modport
    // PORT (r5p_degu with `tcb_lite_if.man tcb_lsu`, synthesised standalone) the
    // name resolves to nothing and becomes an undriven wire.  Surelog now
    // exposes the interface's elaborated param_assigns on the interface_inst
    // (NetlistElaboration elab_interface_); search the interface instance(s)
    // reachable from the current scope for a same-named parameter and fold it.
    bool ref_is_iface_localparam = false;
    if (current_instance) {
        std::vector<const UHDM::interface_inst*> ifaces;
        if (auto ii = dynamic_cast<const UHDM::interface_inst*>(current_instance))
            ifaces.push_back(ii);
        if (auto mi = dynamic_cast<const UHDM::module_inst*>(current_instance)) {
            if (mi->Interfaces())
                for (auto ii : *mi->Interfaces()) ifaces.push_back(ii);
            // A modport PORT exposes its interface via the port's Low_conn (the
            // modport, whose parent is the interface instance); no High_conn
            // exists when the module is synthesised standalone.
            if (mi->Ports())
                for (auto p : *mi->Ports()) {
                    const UHDM::any* lc = p->Low_conn();
                    if (lc && lc->UhdmType() == uhdmref_obj)
                        if (auto a = any_cast<const UHDM::ref_obj*>(lc)->Actual_group())
                            lc = a;
                    const UHDM::interface_inst* ii = nullptr;
                    if (lc && lc->UhdmType() == uhdminterface_inst)
                        ii = any_cast<const UHDM::interface_inst*>(lc);
                    else if (lc && lc->UhdmType() == uhdmmodport) {
                        auto mp = any_cast<const UHDM::modport*>(lc);
                        if (mp && mp->VpiParent() &&
                            mp->VpiParent()->UhdmType() == uhdminterface_inst)
                            ii = any_cast<const UHDM::interface_inst*>(mp->VpiParent());
                    }
                    if (ii) ifaces.push_back(ii);
                }
        }
        for (auto ii : ifaces) {
            // Only trust a Surelog-FOLDED constant here.  When the interface's
            // CFG default is itself unresolved at interface-elaboration time
            // (a package localparam struct like `TCB_LITE_CFG_DEF`), Surelog
            // leaves the localparam Rhs as the raw `CFG.BUS.DAT/8` expression;
            // folding that here would hit the unresolved `CFG.BUS.DAT` and
            // silently yield a wrong 0 — worse than the honest undriven wire.
            const UHDM::constant* rc = nullptr;
            if (ii->Param_assigns())
                for (auto pa : *ii->Param_assigns())
                    if (pa->Lhs() && std::string(pa->Lhs()->VpiName()) == ref_name) {
                        // A same-named interface localparam exists: this ref is a
                        // compile-time interface constant (`CFG_BUS_SIZ`), not a
                        // signal — record that even when its Rhs is a non-folded
                        // expression, so the fall-through warning can be silenced.
                        ref_is_iface_localparam = true;
                        if (auto r = pa->Rhs())
                            if (r->UhdmType() == uhdmconstant) {
                                rc = any_cast<const UHDM::constant*>(r); break;
                            }
                    }
            if (rc) {
                RTLIL::SigSpec v = import_constant(rc);
                if (v.is_fully_const()) {
                    log("    ref_obj: interface localparam %s -> %d\n",
                        ref_name.c_str(), v.as_const().as_int());
                    return v;
                }
            }
        }
    }

    // An interface localparam whose Rhs Surelog left as a non-folded expression
    // (`CFG_BUS_SIZ = $clog2(...)`) is resolved as a constant width through the
    // typespec path elsewhere; don't cry "unknown signal" for it (rp32 degu
    // submodules reaching the interface only through a bare port placeholder).
    if (ref_is_iface_localparam) {
        if (mode_debug)
            log("    ref_obj '%s' is an interface localparam (constant width via "
                "typespec); not a signal\n", ref_name.c_str());
    } else {
        log_warning("Reference to unknown signal: %s\n", ref_name.c_str());
    }
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
        } else if (input_mapping && input_mapping->count(base_signal_name) &&
                   (!comb_lhs_keep_base ||
                    !module->wire(RTLIL::escape_id(base_signal_name)))) {
            // Function-inline (legacy) path: a part-select of a function param
            // or local (e.g. op[6:2] in rp32's dec32) — the base signal lives in
            // input_mapping, not as a module wire.  Without this it resolves to
            // the wrong wire / 0 (bit-selects and full refs already work).
            // Skipped for a WRITE TARGET (comb_lhs_keep_base) whose base IS a
            // real module wire: the base must stay the target wire —
            // substituting the in-flight comb VALUE here turned
            // `endian_data[31:0] = …` after `endian_data = ctrl.data` into a
            // write at ctrl.data's struct offset (CVA6 store_unit corrupted
            // bit 39 of the AMO operand).  Function LOCALS have no module
            // wire, so they still resolve through input_mapping
            // (function_mixed's `result[2*i] = x[i]`).
            base = input_mapping->at(base_signal_name);
            log("      PartSelect: base '%s' from input_mapping (width=%d)\n",
                base_signal_name.c_str(), base.size());
        } else if (uhdm_part->Actual_group() &&
                   uhdm_part->Actual_group()->VpiType() == vpiParameter) {
            // A part-select whose BASE is a parameter — most importantly a
            // generate-scope genvar, which the elaborated model represents as a
            // per-scope `parameter` (e.g. genblk1[0].i).  part_select extends
            // ref_obj, so it carries Actual_group() -> that parameter, exactly
            // like the bare ref import_ref_obj resolves.  Without this the base
            // "i" finds no `\i` wire and collapses to 0, so `sig[expr | i[1:0]]`
            // silently drops the genvar term.  This is the rp32
            // tcb_lite_lib_logsize2byteena read-data byte-remux
            // (man_rdt[(~prefix_or(i[OFF-1:0]) & rsp_off) | i[OFF-1:0]]): every
            // byte read man_rdt[0] instead of man_rdt[i], so the fetched
            // instruction never reached the CPU.
            const parameter* p = any_cast<const parameter*>(uhdm_part->Actual_group());
            // Prefer the module's ELABORATED parameter value (command-line /
            // instance override) over the UHDM parameter's raw VpiValue, which
            // for a parameterized module is the unelaborated default — same rule
            // as import_ref_obj.  Only fall back to VpiValue for a gen-scope
            // genvar (not a module parameter, so absent from the map).
            RTLIL::IdString p_id = RTLIL::escape_id(std::string(p->VpiName()));
            if (module->parameter_default_values.count(p_id)) {
                base = RTLIL::SigSpec(module->parameter_default_values.at(p_id));
                log("      PartSelect: base '%s' from module parameter (width=%d)\n",
                    base_signal_name.c_str(), base.size());
            } else {
                std::string vs = std::string(p->VpiValue());
                int bw = 32;
                if (p->Typespec() && p->Typespec()->Actual_typespec()) {
                    int tw = get_width_from_typespec(p->Typespec()->Actual_typespec(),
                                                     current_instance);
                    if (tw > 0) bw = tw;
                }
                if (!vs.empty())
                    base = RTLIL::SigSpec(RTLIL::Const(parse_vpi_value_to_int(vs), bw));
                log("      PartSelect: base '%s' from genvar/parameter = %s (width=%d)\n",
                    base_signal_name.c_str(), vs.c_str(), bw);
            }
        }
        if (base.empty() && input_mapping &&
            input_mapping->count(base_signal_name) &&
            (!comb_lhs_keep_base ||
             !module->wire(RTLIL::escape_id(base_signal_name)))) {
            // Function argument sliced inside the function body (`data[hi:lo]`
            // in repData64) — the base is the call argument in input_mapping,
            // not a module wire.  (Write targets keep a real wire base — see
            // the comb_lhs_keep_base rule above.)
            base = input_mapping->at(base_signal_name);
        }
        if (base.empty()) {
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
            } else if (package_parameter_map.count(base_signal_name)) {
                // A package localparam sliced directly, e.g. CVA6 csr_regfile
                // `ariane_pkg::SMODE_STATUS_WRITE_MASK[CVA6Cfg.XLEN-1:0]` — the
                // base is a compile-time package constant, not a signal.
                base = RTLIL::SigSpec(package_parameter_map.at(base_signal_name));
                log("      Resolved '%s' as package parameter for part select (width=%d)\n",
                    base_signal_name.c_str(), base.size());
            } else if (RTLIL::Wire* e0 =
                           (name_map.count(base_signal_name + "[0]")
                                ? name_map[base_signal_name + "[0]"]
                                : module->wire(RTLIL::escape_id(base_signal_name + "[0]")))) {
                // Element-array part-select: `mem[hi:lo]` where `mem` is an
                // UNPACKED array split into per-element wires \mem[0]..\mem[N-1]
                // (no flat \mem wire).  Resolve to the concatenation of the
                // selected element wires (element `lo` at the LSB).  Both the LHS
                // and RHS of `mem[N-1:1] <= mem[N-2:0]` take this path, so the
                // element-wise shift lines up (MemorySlice).
                (void)e0;
                int el = -1, er = -1;
                {
                    // Constant bounds per LRM — fold parameter arithmetic
                    // (same rule as the main bound eval below).
                    bool saved_fcf = force_const_fold;
                    force_const_fold = true;
                    if (auto le = uhdm_part->Left_range()) {
                        RTLIL::SigSpec s = import_expression(le, input_mapping);
                        if (s.is_fully_const()) el = s.as_const().as_int();
                    }
                    if (auto re = uhdm_part->Right_range()) {
                        RTLIL::SigSpec s = import_expression(re, input_mapping);
                        if (s.is_fully_const()) er = s.as_const().as_int();
                    }
                    force_const_fold = saved_fcf;
                }
                std::string gs = get_current_gen_scope();
                auto elem_wire = [&](int i) -> RTLIL::Wire* {
                    std::string en = base_signal_name + "[" + std::to_string(i) + "]";
                    if (!gs.empty() && name_map.count(gs + "." + en)) return name_map[gs + "." + en];
                    if (name_map.count(en)) return name_map[en];
                    return module->wire(RTLIL::escape_id(en));
                };
                if (el >= 0 && er >= 0) {
                    int lo = std::min(el, er), hi = std::max(el, er);
                    RTLIL::SigSpec concat;
                    bool ok = true;
                    for (int i = lo; i <= hi; i++) {
                        if (RTLIL::Wire* w = elem_wire(i)) concat.append(RTLIL::SigSpec(w));
                        else { ok = false; break; }
                    }
                    if (ok && concat.size() > 0) {
                        log("    part_select: element-array %s[%d:%d] → %d-bit concat\n",
                            base_signal_name.c_str(), el, er, concat.size());
                        return concat;
                    }
                }
                std::string gen_scope = get_current_gen_scope();
                log_warning("Base signal '%s' not found in module or generate scope %s\n",
                    base_signal_name.c_str(), gen_scope.c_str());
                return RTLIL::SigSpec();
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
    if (input_mapping && !base_signal_name.empty() &&
        !(comb_lhs_keep_base && base.is_wire())) {
        auto im = input_mapping->find(base_signal_name);
        if (im != input_mapping->end() && im->second.size() == base.size())
            base = im->second;
    }

    log("      Base signal width: %d\n", base.size());

    // Get range.  Part-select bounds are CONSTANT expressions per the LRM
    // (variable ranges are only legal in `+:`/`-:` indexed part-selects), so
    // evaluate them under force_const_fold: a parameter-built bound like
    // `lfsr_q[WIDTH-1:1]` otherwise imports as a $sub CELL (the module-body
    // fold gate rejects it), the bound reads non-const, and the fallback
    // below silently returned the WHOLE base — hpdcache_lfsr's shift
    // `{1'b0, lfsr_q[WIDTH-1:1]}` collapsed to identity and the victim-sel
    // LFSR never shifted.
    int left = -1, right = -1;
    {
        bool saved_fcf = force_const_fold;
        force_const_fold = true;
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
        force_const_fold = saved_fcf;
    }
    
    if (left >= 0 && right >= 0) {
        int width = abs(left - right) + 1;
        int offset = std::min(left, right);

        // Packed-ARRAY base (`ras_t [DEPTH-1:0] stack`): the part-select
        // indexes ELEMENTS of the outer packed dimension, not bits — scale by
        // the element width and map through the declared range
        // (low/high/direction).  Without this the CVA6 ras stack shift
        // `stack_d[DEPTH-1:1] = stack_q[DEPTH-2:0]` moved single BITS instead
        // of 9-bit struct elements.  Plain vectors (elem_w 1) keep bit math.
        {
            const UHDM::ref_typespec* rts = nullptr;
            if (auto ag = uhdm_part->Actual_group()) {
                if (auto v = dynamic_cast<const UHDM::variables*>(ag)) rts = v->Typespec();
                else if (auto n = dynamic_cast<const UHDM::net*>(ag)) rts = n->Typespec();
            }
            // The part_select often carries no Actual_group — recover the base
            // net/variable's typespec by NAME from the current instance.
            if (!rts && !base_signal_name.empty()) {
                if (auto mi = dynamic_cast<const UHDM::module_inst*>(
                        current_instance ? current_instance
                                         : dynamic_cast<const UHDM::module_inst*>(inst))) {
                    if (mi->Nets())
                        for (auto n0 : *mi->Nets())
                            if (auto n = dynamic_cast<const UHDM::net*>(n0))
                                if (std::string(n->VpiName()) == base_signal_name &&
                                    n->Typespec()) { rts = n->Typespec(); break; }
                    if (!rts && mi->Variables())
                        for (auto v0 : *mi->Variables())
                            if (auto v = dynamic_cast<const UHDM::variables*>(v0))
                                if (std::string(v->VpiName()) == base_signal_name &&
                                    v->Typespec()) { rts = v->Typespec(); break; }
                }
            }
            const UHDM::typespec* at = rts ? rts->Actual_typespec() : nullptr;
            const UHDM::VectorOfrange* pranges = nullptr;
            const UHDM::ref_typespec* elem_rts = nullptr;
            // Elaborated `packed_array_var` Actual_group: the var carries no
            // Typespec, but its own Ranges() (already constant-folded) and
            // Elements()[0]'s typespec give the outer dim + element type.
            if (auto pav = dynamic_cast<const UHDM::packed_array_var*>(
                    uhdm_part->Actual_group())) {
                pranges = pav->Ranges();
                if (pav->Elements() && !pav->Elements()->empty())
                    if (auto ev = dynamic_cast<const UHDM::expr*>((*pav->Elements())[0]))
                        elem_rts = ev->Typespec();
            }
            if (at) {
                if (auto pt = dynamic_cast<const UHDM::packed_array_typespec*>(at)) {
                    pranges = pt->Ranges();
                    elem_rts = pt->Elem_typespec();
                } else if (auto lt = dynamic_cast<const UHDM::logic_typespec*>(at)) {
                    // Typedef'd packed array (`logic_typespec` with
                    // Elem_typespec) — only when an element type exists;
                    // a plain multi-range logic vector stays bit-indexed.
                    if (lt->Elem_typespec()) {
                        pranges = lt->Ranges();
                        elem_rts = lt->Elem_typespec();
                    }
                }
            }
            if (pranges && !pranges->empty() && elem_rts &&
                elem_rts->Actual_typespec()) {
                int elem_w = get_width_from_typespec(elem_rts->Actual_typespec(), inst);
                int inner_w = 1;
                for (size_t ri = 1; ri < pranges->size(); ri++) {
                    auto rn = (*pranges)[ri];
                    RTLIL::SigSpec il = import_expression(rn->Left_expr(), input_mapping);
                    RTLIL::SigSpec ir = import_expression(rn->Right_expr(), input_mapping);
                    if (il.is_fully_const() && ir.is_fully_const())
                        inner_w *= std::abs(il.as_const().as_int() -
                                            ir.as_const().as_int()) + 1;
                }
                if (elem_w > 0) elem_w *= inner_w;
                auto r0 = (*pranges)[0];
                RTLIL::SigSpec rl = import_expression(r0->Left_expr(), input_mapping);
                RTLIL::SigSpec rr = import_expression(r0->Right_expr(), input_mapping);
                if (elem_w > 1 && rl.is_fully_const() && rr.is_fully_const()) {
                    int rli = rl.as_const().as_int(), rri = rr.as_const().as_int();
                    int decl_low = std::min(rli, rri), decl_high = std::max(rli, rri);
                    bool decl_asc = rli < rri;
                    int nelem = decl_high - decl_low + 1;
                    int ilo = std::min(left, right), ihi = std::max(left, right);
                    // Only when the base really is the whole array (not an
                    // already-sliced redirect) and the select is in range.
                    if (base.size() == elem_w * nelem &&
                        ilo >= decl_low && ihi <= decl_high) {
                        offset = decl_asc ? (decl_high - ihi) * elem_w
                                          : (ilo - decl_low) * elem_w;
                        width = (ihi - ilo + 1) * elem_w;
                        log("    part_select: packed-array element range [%d:%d] "
                            "(elem_w=%d) -> bits [%d+:%d]\n",
                            left, right, elem_w, offset, width);
                    }
                }
            }
        }

        // A packed multi-dim array declared `logic [N:0][W-1:0]` has a
        // MULTI-RANGE logic_typespec and no Elem_typespec, so the scaling above
        // cannot fire — but import_port/import_net already tagged the wire with
        // the geometry that import_bit_select uses for a single element.  Reuse
        // it so an element RANGE scales too: `issue_pointer[NrIssuePorts-1:0]`
        // must select whole elements, not the low bits (CVA6 scoreboard's
        // rvfi_issue_pointer_o came out as {0, arr[1:0]} instead of arr[5:0]).
        if (width == std::abs(left - right) + 1 && base.is_wire()) {
            RTLIL::Wire* bw = base.as_wire();
            auto ew_id = RTLIL::escape_id("packed_elem_width");
            auto ol_id = RTLIL::escape_id("packed_outer_left");
            auto or_id = RTLIL::escape_id("packed_outer_right");
            if (bw && bw->attributes.count(ew_id) &&
                bw->attributes.count(ol_id) && bw->attributes.count(or_id)) {
                int ew = bw->attributes.at(ew_id).as_int();
                int ol = bw->attributes.at(ol_id).as_int();
                int orr = bw->attributes.at(or_id).as_int();
                int decl_low = std::min(ol, orr), decl_high = std::max(ol, orr);
                int nelem = decl_high - decl_low + 1;
                int ilo = std::min(left, right), ihi = std::max(left, right);
                if (ew > 1 && base.size() == ew * nelem &&
                    ilo >= decl_low && ihi <= decl_high) {
                    offset = (ol < orr) ? (decl_high - ihi) * ew
                                        : (ilo - decl_low) * ew;
                    width = (ihi - ilo + 1) * ew;
                    log("    part_select: packed-array element range [%d:%d] via "
                        "wire attrs (elem_w=%d) -> bits [%d+:%d]\n",
                        left, right, ew, offset, width);
                }
            }
        }

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
// A bit-select's index (and its own internals) are SELF-DETERMINED: the
// enclosing expression's context width must not leak in.  With a 1-bit LHS
// (`ifmt_of_after_round[ifmt] = ~rounded_int_res[INT_WIDTH-2+op_mod_q2]`,
// fpnew_cast_multi's overflow detect) the index add materialized at width 1
// and the constant 14 clipped to 1'0 — the read landed on bit op_mod
// instead of 14+op_mod and every int-to-int cast spuriously took the
// overflow-special path (result forced to all-ones).
RTLIL::SigSpec UhdmImporter::import_bit_select(const bit_select* uhdm_bit, const UHDM::scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    int saved_ctx = expression_context_width;
    expression_context_width = 0;
    RTLIL::SigSpec r = import_bit_select_inner(uhdm_bit, inst, input_mapping);
    expression_context_width = saved_ctx;
    return r;
}

RTLIL::SigSpec UhdmImporter::import_bit_select_inner(const bit_select* uhdm_bit, const UHDM::scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
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
    // Handles both constant and dynamic indices.  The low bound is usually 0,
    // but a `[N:1]` declaration (CVA6 perf_counters
    // `generic_counter_q[MHPMCounterNum:1]`) starts at 1 — probe for the first
    // declared element instead of requiring `[0]`.
    if (!module->memories.count(mem_id)) {
        int arr_low = -1;
        for (int probe = 0; probe <= 64; probe++)
            if (module->wire(RTLIL::escape_id(
                    signal_name + "[" + std::to_string(probe) + "]"))) {
                arr_low = probe;
                break;
            }
        RTLIL::Wire* first_elem = arr_low < 0 ? nullptr
            : module->wire(RTLIL::escape_id(
                  signal_name + "[" + std::to_string(arr_low) + "]"));
        if (first_elem) {
            int elem_w = first_elem->width;
            // Count elements from the low bound up
            int num_elems = 0;
            while (module->wire(RTLIL::escape_id(
                       signal_name + "[" + std::to_string(arr_low + num_elems) + "]")))
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
                // Constant index outside the array bounds reads X — SV leaves an
                // out-of-range access unspecified (verilog/mem_bounds.sv reads
                // `mem[-1]` and asserts it is all-X via $countbits).
                if (num_elems > 0 && (i < arr_low || i >= arr_low + num_elems))
                    return RTLIL::SigSpec(RTLIL::State::Sx, elem_w);
            } else {
                // Dynamic index — build mux chain over DECLARED indices.
                int last = arr_low + num_elems - 1;
                int idx_w = GetSize(idx);
                // Can the index address a non-existent element?  If the
                // index width can represent a value >= num_elems, an
                // out-of-range read is possible and needs an explicit
                // fall-through value.  Otherwise every representable index
                // is valid and the last element serves as the default.
                bool oob_possible = (idx_w >= 31) || (arr_low > 0) ||
                                    ((1LL << idx_w) > (long long)num_elems);
                RTLIL::SigSpec result;
                int start;
                if (oob_possible) {
                    // An out-of-range index reads X — SystemVerilog leaves it
                    // unspecified, and that is what the Yosys Verilog frontend
                    // and Verilator do too.  Emitting a defined 0 here was
                    // wrong: it is a concrete value that disagrees with the
                    // other tools' unspecified result (mem2reg_bounds_tern's
                    // OOB read), whereas X is a don't-care that any value
                    // refines, so formal equivalence holds against either.
                    result = RTLIL::SigSpec(RTLIL::State::Sx, elem_w);
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

                for (int i = start; i >= arr_low; i--) {
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
            // The module's ELABORATED parameter value first: the Param_assigns
            // Rhs can be a garbage Surelog clone stamp, which
            // reeval_stamped_param_assign has already corrected in
            // parameter_default_values (stamped_gen_param's UT[k] reads).
            {
                RTLIL::IdString p_id = RTLIL::escape_id(signal_name);
                if (module && module->parameter_default_values.count(p_id) &&
                    module->parameter_default_values.at(p_id).size() > 1) {
                    param_value = module->parameter_default_values.at(p_id);
                    got = true;
                }
            }
            const UHDM::module_inst* pmod =
                dynamic_cast<const UHDM::module_inst*>(current_instance);
            if (!got && pmod && pmod->Param_assigns()) {
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
                {
                    // Compute the element width from the parameter's
                    // typespec ranges.  For a packed multi-range
                    // logic_typespec the OUTER range count divides the
                    // total width to give the slot width that `P[i]`
                    // extracts.  For a plain 1-D parameter (single
                    // range or int_typespec) `P[i]` is just bit `i`.
                    int elem_w = 1;
                    int outer_low = 0;
                    int outer_high = 0;
                    bool outer_ascending = false;
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
                            } else if (ats->UhdmType() == uhdmarray_typespec) {
                                // UNPACKED array parameter: `logic [W-1:0] DAM
                                // [N-1:0]`.  `DAM[i]` selects a whole W-bit
                                // ELEMENT, not a single bit.  The array_typespec's
                                // Range is the unpacked dimension (N elements);
                                // the element width is total/N.  Without this
                                // elem_w stays 1 and `DAM[i]` returns a single x
                                // bit — collapsing an x-wildcard address-decode
                                // mask to all-x so `adr ==? DAM[i]` folds to 1 for
                                // every address (rp32 tcb_lite_lib_decoder DAM).
                                auto arr = dynamic_cast<const UHDM::array_typespec*>(ats);
                                if (arr && arr->Ranges() && !arr->Ranges()->empty()) {
                                    packed_multidim = true;
                                    auto r0 = (*arr->Ranges())[0];
                                    RTLIL::SigSpec ls = import_expression(r0->Left_expr());
                                    RTLIL::SigSpec rs2 = import_expression(r0->Right_expr());
                                    if (ls.is_fully_const() && rs2.is_fully_const()) {
                                        int l = ls.as_int(), r = rs2.as_int();
                                        int arr_size = std::abs(l - r) + 1;
                                        outer_low = std::min(l, r);
                                        if (arr_size > 0 && total % arr_size == 0)
                                            elem_w = total / arr_size;
                                    }
                                }
                            } else if (ats->UhdmType() == uhdmpacked_array_typespec) {
                                // PACKED array parameter (e.g. fpnew's
                                // fmt_unit_types_t = ut_e [0:4]): `P[i]`
                                // selects a whole element; ascending ranges
                                // put element `low` at the MSBs.
                                auto pat = dynamic_cast<const UHDM::packed_array_typespec*>(ats);
                                if (pat && pat->Ranges() && !pat->Ranges()->empty()) {
                                    packed_multidim = true;
                                    auto r0 = (*pat->Ranges())[0];
                                    RTLIL::SigSpec ls = import_expression(r0->Left_expr());
                                    RTLIL::SigSpec rs2 = import_expression(r0->Right_expr());
                                    if (ls.is_fully_const() && rs2.is_fully_const()) {
                                        int l = ls.as_int(), r = rs2.as_int();
                                        int arr_size = std::abs(l - r) + 1;
                                        outer_low = std::min(l, r);
                                        outer_high = std::max(l, r);
                                        outer_ascending = (l < r);
                                        if (arr_size > 0 && total % arr_size == 0)
                                            elem_w = total / arr_size;
                                    }
                                }
                            }
                        }
                    }
                    (void)packed_multidim;
                    if (index.is_fully_const()) {
                        int idx = index.as_const().as_int();
                        int slot = outer_ascending ? (outer_high - idx)
                                                   : (idx - outer_low);
                        int off = slot * elem_w;
                        if (off >= 0 && off + elem_w <= total) {
                            RTLIL::SigSpec full(param_value);
                            RTLIL::SigSpec slice = full.extract(off, elem_w);
                            if (mode_debug)
                                log("    Bit-select on parameter %s[%d]: extracted %d bits @off %d\n",
                                    signal_name.c_str(), idx, elem_w, off);
                            return slice;
                        }
                    } else {
                        // DYNAMIC index into a parameter constant
                        // (`FmtUnitTypes[dst_fmt_i]`): extract the element
                        // with a $shiftx over the constant.  slot is the
                        // element offset in ELEMENTS from the RTLIL LSB.
                        int iw = std::max(GetSize(index), 32);
                        RTLIL::SigSpec idx_ext = index;
                        idx_ext.extend_u0(iw, false);
                        RTLIL::SigSpec slot;
                        if (outer_ascending)
                            slot = module->Sub(NEW_ID,
                                RTLIL::SigSpec(RTLIL::Const(outer_high, iw)),
                                idx_ext);
                        else
                            slot = module->Sub(NEW_ID, idx_ext,
                                RTLIL::SigSpec(RTLIL::Const(outer_low, iw)));
                        RTLIL::SigSpec off = module->Mul(NEW_ID, slot,
                            RTLIL::SigSpec(RTLIL::Const(elem_w, iw)));
                        RTLIL::Wire* out = module->addWire(NEW_ID, elem_w);
                        module->addShiftx(NEW_ID, RTLIL::SigSpec(param_value),
                                          off, out);
                        if (mode_debug)
                            log("    Dynamic bit-select on parameter %s: $shiftx elem_w=%d\n",
                                signal_name.c_str(), elem_w);
                        return RTLIL::SigSpec(out);
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
                    // Unpacked-array param `logic [2:0] mat [3:0]`: `mat[i]`
                    // selects the i-th element (W bits), not bit i.  Derive W
                    // from the param's unpacked dimension on the bit_select's
                    // Actual_group (SelectFromUnpackedInFunction).
                    int elem_w = 1, outer_lo = 0;
                    if (auto ag = uhdm_bit->Actual_group()) {
                        UHDM::VectorOfrange* rngs = nullptr;
                        if (auto lv = dynamic_cast<const UHDM::logic_var*>(ag)) rngs = lv->Ranges();
                        else if (auto io = dynamic_cast<const UHDM::io_decl*>(ag)) rngs = io->Ranges();
                        else if (auto av = dynamic_cast<const UHDM::array_var*>(ag)) rngs = av->Ranges();
                        if (rngs && !rngs->empty()) {
                            auto r0 = (*rngs)[0];
                            RTLIL::SigSpec l = import_expression(r0->Left_expr());
                            RTLIL::SigSpec rr = import_expression(r0->Right_expr());
                            if (l.is_fully_const() && rr.is_fully_const()) {
                                int osz = std::abs(l.as_const().as_int() - rr.as_const().as_int()) + 1;
                                if (osz > 0 && it->second.size() % osz == 0) {
                                    elem_w = it->second.size() / osz;
                                    outer_lo = std::min(l.as_const().as_int(), rr.as_const().as_int());
                                }
                            }
                        }
                    }
                    int off = (idx - outer_lo) * elem_w;
                    if (off >= 0 && off + elem_w <= it->second.size()) {
                        return it->second.extract(off, elem_w);
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
    if (in_always_ff_body_mode && !comb_lhs_keep_base) {
        auto bt = ff_blocking_temps.find(signal_name);
        if (bt != ff_blocking_temps.end() && bt->second.size() == base.size())
            base = bt->second;
    }
    // SSA always_ff (ff_simple_eval) / always_comb thread same-cycle blocking
    // values through input_mapping; a bit-select of such a value must read the
    // in-flight value too (mirrors import_ref_obj; PR #291 missed bit-selects).
    // Skipped for a WRITE TARGET (comb_lhs_keep_base): the base must stay the wire
    // so `arr[idx]` writes the wire slice, not a constant bit of its value.
    if (input_mapping && !signal_name.empty() && !comb_lhs_keep_base) {
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
    // Packed array of a (packed) struct/enum: `filter_ctl_t [1:0] a` is a
    // packed_array_var whose flat wire carries no packed_elem_width attribute, so
    // `a[i]` would wrongly extract a single bit.  Derive the element width from
    // the packed_array_typespec Elem_typespec (StructPackedArray: a[1] is the
    // upper 10-bit element, not bit 1).
    if (packed_elem_w <= 1 && wire) {
        // Find the packed_array_var (via wire_map) to read its Ranges()/Elements();
        // for a typedef'd packed array of struct this is the only place the outer
        // dimension and element type are both available.
        // A NET-declared packed array of a struct (`fpnew_pkg::fp_info_t [1:0]
        // info_q`) elaborates to a packed_array_NET, which this search did not
        // accept — only the VAR form.  `info_q[0]` then extracted a single BIT
        // and zero-extended it to the struct's width, so every field of CVA6
        // fpnew_noncomp's info_a/info_b read as 0 (2972/3000 cycles diverged).
        // The dynamic-index path below already handles both forms; take them
        // both here too, and prefer the bit_select's own Actual_group (the
        // declaration is right there) over searching wire_map by wire.
        const UHDM::VectorOfrange* prg = nullptr;
        const UHDM::VectorOfany* pel = nullptr;
        const UHDM::ref_typespec* pts_ref = nullptr;
        auto take_packed = [&](const UHDM::any* o) {
            if (prg) return;
            if (auto pv = dynamic_cast<const UHDM::packed_array_var*>(o)) {
                prg = pv->Ranges(); pel = pv->Elements(); pts_ref = pv->Typespec();
            } else if (auto pn = dynamic_cast<const UHDM::packed_array_net*>(o)) {
                prg = pn->Ranges(); pel = pn->Elements(); pts_ref = pn->Typespec();
            } else if (auto av = dynamic_cast<const UHDM::array_var*>(o)) {
                // UNPACKED array of (type-param'd) structs flattened to one
                // wire: the own Ranges() carry the unpacked dim and the
                // element type lives on the inner var (vpiReg).
                // cva6_hpdcache_subsystem_axi_arbiter's
                // `hpdcache_mem_resp_r_t mem_resp_read_arb [1:0]` element
                // reads collapsed to ONE BIT, zeroing the whole icache /
                // dcache read-response path (300/300 co-sim divergences).
                prg = av->Ranges();
                if (av->Variables() && !av->Variables()->empty())
                    pts_ref = (*av->Variables())[0]->Typespec();
                if (!pts_ref) pts_ref = av->Typespec();
            }
        };
        take_packed(uhdm_bit->Actual_group());
        if (!prg)
            for (auto& kv : wire_map) {
                if (kv.second != wire) continue;
                take_packed(kv.first);
                if (prg) break;
            }
        if (prg || pel || pts_ref) {
            int ew = 0;
            if (pel && !pel->empty())
                if (auto e0 = dynamic_cast<const UHDM::any*>((*pel)[0]))
                    ew = get_width(e0, inst);
            if (ew <= 0 && pts_ref)
                if (auto pts = pts_ref->Actual_typespec()) {
                    if (pts->UhdmType() == uhdmpacked_array_typespec) {
                        if (auto pat = any_cast<const UHDM::packed_array_typespec*>(pts))
                            if (pat->Elem_typespec())
                                if (auto et = pat->Elem_typespec()->Actual_typespec())
                                    ew = get_width_from_typespec(et, inst);
                    } else {
                        // Inner-var typespec of an unpacked array element
                        // (struct_typespec for mem_resp_read_arb) — its width
                        // IS the element width.  Resolve type parameters
                        // first (`mem_resp_t arb[1:0]` where mem_resp_t is a
                        // module type param bound to a struct).
                        const UHDM::typespec* rpts =
                            resolve_type_param_typespec(pts, inst);
                        ew = get_width_from_typespec(rpts ? rpts : pts, inst);
                    }
                }
            if (ew > 1 && prg && !prg->empty()) {
                auto r0 = (*prg)[0];
                RTLIL::SigSpec ls = import_expression(r0->Left_expr());
                RTLIL::SigSpec rs = import_expression(r0->Right_expr());
                if (ls.is_fully_const() && rs.is_fully_const()) {
                    packed_elem_w = ew;
                    packed_outer_l = ls.as_int();
                    packed_outer_r = rs.as_int();
                }
            }
        }
    }

    // Plain `wire [N-1:0][W-1:0]` (a logic_net, not a packed_array_var, with no
    // packed_elem_width attribute): derive the element width from the
    // bit_select's logic_typespec so `t[i]` extracts a W-bit slot, not a single
    // bit (StreamOpImplicitSliceSize: `wire [3:0][7:0] t; t[0]`).
    if (packed_elem_w <= 1 && wire && uhdm_bit->Actual_group()) {
        const UHDM::ref_typespec* rt = nullptr;
        if (auto e = dynamic_cast<const UHDM::expr*>(uhdm_bit->Actual_group()))
            rt = e->Typespec();
        if (rt && rt->Actual_typespec() &&
            rt->Actual_typespec()->UhdmType() == uhdmlogic_typespec) {
            auto lt = any_cast<const UHDM::logic_typespec*>(rt->Actual_typespec());
            if (lt && lt->Ranges() && lt->Ranges()->size() > 1) {
                auto r0 = (*lt->Ranges())[0];
                RTLIL::SigSpec ls = import_expression(r0->Left_expr());
                RTLIL::SigSpec rs = import_expression(r0->Right_expr());
                if (ls.is_fully_const() && rs.is_fully_const()) {
                    int outer_size = std::abs(ls.as_int() - rs.as_int()) + 1;
                    if (outer_size > 0 && base.size() % outer_size == 0) {
                        packed_elem_w = base.size() / outer_size;
                        packed_outer_l = ls.as_int();
                        packed_outer_r = rs.as_int();
                    }
                }
            }
        }
        // Packed array of an (anonymous) struct on a plain net:
        // `struct packed {...} [N-1:0] tags_n;` — the net's typespec is a
        // packed_array_typespec whose Elem_typespec is the struct.  Without
        // this, `tags_n[i] = {…}` wrote a SINGLE BIT instead of the 62-bit
        // element (CVA6 cva6_tlb's update path never stored an entry).
        if (packed_elem_w <= 1 && rt && rt->Actual_typespec() &&
            rt->Actual_typespec()->UhdmType() == uhdmpacked_array_typespec) {
            auto pat = any_cast<const UHDM::packed_array_typespec*>(rt->Actual_typespec());
            int ew = 0;
            if (pat->Elem_typespec() && pat->Elem_typespec()->Actual_typespec())
                ew = get_width_from_typespec(
                    pat->Elem_typespec()->Actual_typespec(), inst);
            if (ew > 1 && pat->Ranges() && !pat->Ranges()->empty()) {
                auto r0 = (*pat->Ranges())[0];
                RTLIL::SigSpec ls = import_expression(r0->Left_expr());
                RTLIL::SigSpec rs = import_expression(r0->Right_expr());
                // Only DESCENDING declarations (`[N-1:0]`, what CVA6 uses):
                // the shared const/dynamic slot math below is
                // `idx - min(l,r)`, which is only correct when element 0 sits
                // at the LSB.  An ASCENDING `[0:1]` puts element 0 at the MSB
                // (typedef_packed_enum_array), so leave those to the existing
                // paths rather than mis-scaling them here.
                if (ls.is_fully_const() && rs.is_fully_const() &&
                    ls.as_int() >= rs.as_int() && base.size() % ew == 0) {
                    packed_elem_w = ew;
                    packed_outer_l = ls.as_int();
                    packed_outer_r = rs.as_int();
                }
            }
        }
    }

    // Flattened interface unpacked-ARRAY signal (`req_t req_dly [0:DLY]`,
    // materialized as one wide wire in import_interface_instances): `req_dly[i]`
    // selects the i-th element (elem_w bits, 0-based), not bit i.
    if (packed_elem_w <= 1 && wire) {
        auto ew = iface_array_elem_width_.find(RTLIL::unescape_id(wire->name));
        if (ew != iface_array_elem_width_.end() && ew->second > 1 &&
            base.size() % ew->second == 0) {
            packed_elem_w = ew->second;
            packed_outer_l = 0;
            packed_outer_r = 0;  // 0-based; slot = idx
        }
    }

    if (index.is_fully_const()) {
        int idx = index.as_const().as_int();
        if (mode_debug)
            log("    Bit select index: %d\n", idx);

        if (packed_elem_w > 1) {
            int outer_lo = std::min(packed_outer_l, packed_outer_r);
            int outer_hi = std::max(packed_outer_l, packed_outer_r);
            // Ascending [0:N] puts element `low` at the MSBs (fpnew's
            // `pipe[1]` on `logic [0:1][2:0][31:0]` is the LSB half).
            bool asc = (packed_outer_l >= 0 && packed_outer_r >= 0 &&
                        packed_outer_l < packed_outer_r);
            int slot = asc ? (outer_hi - idx) : (idx - outer_lo);
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

    // Elaborated packed-array-of-STRUCT variable (`dtype [FifoDepth-1:0]
    // mem_q` with a type-param struct dtype — CVA6 cva6_fifo_v3): the
    // packed_array_var Actual_group carries no Typespec, but its own Ranges()
    // (constant-folded) and Elements()[0]'s typespec give the outer dimension
    // and the element type.  Without this the dynamic select `mem_q[rp_q]`
    // read/wrote ONE BIT of the array.
    if (element_width <= 1) {
        // Extract outer range + element width from an elaborated packed-array
        // VAR or NET object (`dtype [FifoDepth-1:0] mem_q` with a type-param
        // struct dtype — CVA6 ras / cva6_fifo_v3): these carry no Typespec but
        // have their own constant-folded Ranges() and Elements()[0] typespec.
        auto try_packed_obj = [&](const UHDM::any* obj) {
            const UHDM::VectorOfrange* prg = nullptr;
            const UHDM::VectorOfany* pel = nullptr;
            if (auto pav = dynamic_cast<const UHDM::packed_array_var*>(obj)) {
                prg = pav->Ranges(); pel = pav->Elements();
            } else if (auto pan = dynamic_cast<const UHDM::packed_array_net*>(obj)) {
                prg = pan->Ranges(); pel = pan->Elements();
            } else return;
            if (prg && !prg->empty()) {
                auto r0 = (*prg)[0];
                if (r0->Left_expr() && r0->Right_expr()) {
                    RTLIL::SigSpec l = import_expression(r0->Left_expr());
                    RTLIL::SigSpec r = import_expression(r0->Right_expr());
                    if (l.is_fully_const() && r.is_fully_const()) {
                        outer_left = l.as_int();
                        outer_right = r.as_int();
                    }
                }
            }
            if (pel && !pel->empty())
                if (auto ev = dynamic_cast<const UHDM::expr*>((*pel)[0]))
                    if (ev->Typespec() && ev->Typespec()->Actual_typespec()) {
                        int w = get_width_from_typespec(
                            ev->Typespec()->Actual_typespec(), inst);
                        if (w > 1) element_width = w;
                    }
        };
        try_packed_obj(uhdm_bit->Actual_group());
        // Surelog often leaves the bit_select's Actual_group null (or pointing
        // at a plain logic_net whose typespec is just the ELEMENT type after a
        // 1-element array collapse) — find the packed_array_var/net by NAME.
        if (element_width <= 1 && !signal_name.empty()) {
            auto mi = dynamic_cast<const UHDM::module_inst*>(
                current_instance ? current_instance
                                 : dynamic_cast<const UHDM::module_inst*>(inst));
            if (mi) {
                if (mi->Nets())
                    for (auto n0 : *mi->Nets())
                        if (std::string(n0->VpiName()) == signal_name) {
                            try_packed_obj(n0);
                            if (element_width > 1) break;
                        }
                if (element_width <= 1 && mi->Variables())
                    for (auto v0 : *mi->Variables())
                        if (std::string(v0->VpiName()) == signal_name) {
                            try_packed_obj(v0);
                            if (element_width > 1) break;
                        }
            }
        }
    }

    // Fall back to UHDM typespec detection if no wire attributes
    if (element_width <= 1) {
        if (auto actual_group = uhdm_bit->Actual_group()) {
            const UHDM::ref_typespec* net_ref_ts = nullptr;
            if (auto logic_net = dynamic_cast<const UHDM::logic_net*>(actual_group)) {
                net_ref_ts = logic_net->Typespec();
            } else if (auto logic_var = dynamic_cast<const UHDM::logic_var*>(actual_group)) {
                net_ref_ts = logic_var->Typespec();
            } else if (auto pav = dynamic_cast<const UHDM::packed_array_var*>(actual_group)) {
                // A signal declared with a packed-array TYPE (`rt_t rt_i`,
                // where `rt_t = id_t [DEPTH-1:0]`) elaborates to a
                // packed_array_var/net, not a logic_var/net.  Only the logic_*
                // forms were consulted here, so the element width stayed 1 and
                // `rt_i[idx]` degenerated to an unscaled BIT select — reading
                // bit `idx` instead of the element at `idx * ELEM_W`.  Correct
                // only for index 0 (CVA6 hpdcache_mem_resp_demux's routing
                // select was wrong for 3 of its 4 index values).
                net_ref_ts = pav->Typespec();
            } else if (auto pan = dynamic_cast<const UHDM::packed_array_net*>(actual_group)) {
                net_ref_ts = pan->Typespec();
            }
            if (net_ref_ts && net_ref_ts->Actual_typespec()) {
                auto ts = net_ref_ts->Actual_typespec();
                if (ts->UhdmType() == uhdmpacked_array_typespec) {
                    // Packed array typespec (`ras_t [DEPTH-1:0]` on a net):
                    // outer range + element type width.
                    auto pt = dynamic_cast<const UHDM::packed_array_typespec*>(ts);
                    if (pt->Ranges() && !pt->Ranges()->empty()) {
                        auto r0 = (*pt->Ranges())[0];
                        if (r0->Left_expr() && r0->Right_expr()) {
                            RTLIL::SigSpec l = import_expression(r0->Left_expr());
                            RTLIL::SigSpec r = import_expression(r0->Right_expr());
                            if (l.is_fully_const() && r.is_fully_const()) {
                                outer_left = l.as_int();
                                outer_right = r.as_int();
                            }
                        }
                    }
                    if (pt->Elem_typespec() && pt->Elem_typespec()->Actual_typespec()) {
                        int w = get_width_from_typespec(
                            pt->Elem_typespec()->Actual_typespec(), inst);
                        if (w > 1) element_width = w;
                    }
                }
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
        // A function argument (`repData64(input logic [..] data, ...)` used as
        // `data[offset*8+:16]`): the base is passed via input_mapping, not a
        // module wire (CVA6 wt_dcache_wbuffer repData64 — else "Base signal
        // 'data' not found").  Prefer it so the slice reads the call argument.
        // Skipped for a WRITE TARGET (comb_lhs_keep_base) with a real module
        // wire — same rule as import_part_select: the base must stay the
        // target wire; function locals (no wire) still use input_mapping.
        if (input_mapping && input_mapping->count(base_signal_name) &&
            (!comb_lhs_keep_base ||
             !module->wire(RTLIL::escape_id(base_signal_name)))) {
            base = input_mapping->at(base_signal_name);
        } else
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
                } else if (package_parameter_map.count(base_signal_name)) {
                    // Package localparam sliced with a dynamic/indexed range,
                    // e.g. `ariane_pkg::SMODE_STATUS_WRITE_MASK[XLEN-1:0]`.
                    base = RTLIL::SigSpec(package_parameter_map.at(base_signal_name));
                } else {
                    std::string gen_scope = get_current_gen_scope();
                    log_warning("Base signal '%s' not found in module or generate scope %s\n",
                        base_signal_name.c_str(), gen_scope.c_str());
                    // Return a correctly-SIZED undef (the slice width is known
                    // from Width_expr), not an empty SigSpec.  An empty RHS
                    // assigned to a wire produces a malformed process action
                    // (lhs non-empty, rhs empty) that later crashes yosys
                    // `proc_prune` (rhs[i] out_of_range) on the full CVA6 design.
                    int uw = 1;
                    if (uhdm_indexed->Width_expr()) {
                        RTLIL::SigSpec ws = import_expression(uhdm_indexed->Width_expr(), input_mapping);
                        if (ws.is_fully_const() && ws.as_const().as_int() > 0)
                            uw = ws.as_const().as_int();
                    }
                    return RTLIL::SigSpec(RTLIL::State::Sx, uw);
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

        // The LOW bit of the slice depends on the direction:
        //   `+:` -> [offset +: width]  = [offset+width-1 : offset], low = offset
        //   `-:` -> [offset -: width]  = [offset : offset-width+1], low = offset-width+1
        // Validate against the ACTUAL low bit — the old check `offset+width >
        // base.size()` is only right for `+:` and wrongly rejected e.g.
        // `a[5-:4]` on an 8-bit `a` (5+4=9>8) -> returned empty -> 0
        // (IndexedPartSelect c).
        bool pos = uhdm_indexed->VpiIndexedPartSelectType() == vpiPosIndexed;
        int low = pos ? offset : (offset - width + 1);
        if (low < 0 || width <= 0 || low + width > base.size()) {
            log_warning("Invalid indexed part select: low=%d, width=%d, base_size=%d\n",
                low, width, base.size());
            return RTLIL::SigSpec();
        }
        return base.extract(low, width);
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

// XMR read resolution (github #450): expose the child signal `sig` as an OUTPUT
// PORT of `cell`'s module and wire it to the parent's `\<inst>.<sig>` reader.
// This makes the source survive `opt` (a port is kept) and flatten connect it
// to the reader — matching what slang produces for `monitor_flag =
// u_processor.internal_ready`.
void UhdmImporter::resolve_xmr_read(RTLIL::Module* mod, RTLIL::Cell* cell, const std::string& sig) {
    if (!mod || !cell || sig.empty()) return;
    RTLIL::Module* child = design->module(cell->type);
    if (!child) return;
    RTLIL::Wire* cw = child->wire(RTLIL::escape_id(sig));
    if (!cw) return;
    if (!cw->port_output && !cw->port_input) {
        cw->port_output = true;
        child->fixup_ports();
    }
    std::string inst = cell->name.str();
    if (!inst.empty() && inst[0] == '\\') inst = inst.substr(1);
    std::string pn = inst + "." + sig;
    RTLIL::Wire* pw = mod->wire(RTLIL::escape_id(pn));
    if (!pw) pw = mod->addWire(RTLIL::escape_id(pn), cw->width);
    if (!cell->hasPort(RTLIL::escape_id(sig)))
        cell->setPort(RTLIL::escape_id(sig), pw);
}

// Import hierarchical path (e.g., bus.a, interface.signal)
// `PARAM[idx].field` for a parameter that is an unpacked array of structs.
//
// Surelog keeps such a parameter's value in the enclosing scope's param_assign
// (an assignment pattern of assignment patterns), not in VpiValue/Expr, and the
// element is a struct rather than a plain vector -- so neither the wire-based
// element/field paths nor the scalar parameter path applies.  Evaluate the
// whole array to one constant, then cut the requested field out of the
// requested element.  A non-constant index selects between the per-element
// field slices.
RTLIL::SigSpec UhdmImporter::import_param_array_elem_field(
        const bit_select* bs, const std::vector<std::string>& fields,
        const scope* inst,
        const std::map<std::string, RTLIL::SigSpec>* input_mapping,
        const RTLIL::SigSpec* idx_in) {
    if (!bs || fields.empty())
        return RTLIL::SigSpec();
    const UHDM::any* actual = bs->Actual_group();
    auto param = actual ? dynamic_cast<const UHDM::parameter*>(actual) : nullptr;
    if (!param)
        return RTLIL::SigSpec();

    // The initialiser: Expr() when Surelog put it there, otherwise the
    // param_assign the enclosing package/module holds for this name.
    const UHDM::expr* rhs = dynamic_cast<const UHDM::expr*>(param->Expr());
    if (!rhs) {
        std::string pname = std::string(param->VpiName());
        const UHDM::any* parent = param->VpiParent();
        if (parent && parent->UhdmType() == uhdmparam_assign) {
            if (auto pa = any_cast<const UHDM::param_assign*>(parent))
                rhs = dynamic_cast<const UHDM::expr*>(pa->Rhs());
        } else if (auto sc = dynamic_cast<const UHDM::instance*>(parent)) {
            if (sc->Param_assigns())
                for (auto pa : *sc->Param_assigns())
                    if (pa->Lhs() && std::string(pa->Lhs()->VpiName()) == pname)
                        rhs = dynamic_cast<const UHDM::expr*>(pa->Rhs());
        }
    }
    if (!rhs)
        return RTLIL::SigSpec();

    // The initialiser may just NAME another parameter -- a wrapper writes
    // `parameter copro_issue_resp_t CoproInstr[NbInstr] =
    // cvxif_instr_pkg::CoproInstr`, and the array literal lives on the package
    // parameter.  Follow the reference to the declaration that actually holds
    // the pattern.
    for (int hop = 0; hop < 4 && rhs && rhs->UhdmType() == uhdmref_obj; hop++) {
        auto r = any_cast<const UHDM::ref_obj*>(rhs);
        auto rp = r ? dynamic_cast<const UHDM::parameter*>(r->Actual_group())
                    : nullptr;
        if (!rp) break;
        const UHDM::expr* nxt = dynamic_cast<const UHDM::expr*>(rp->Expr());
        if (!nxt) {
            std::string rn = std::string(rp->VpiName());
            const UHDM::any* rpar = rp->VpiParent();
            if (rpar && rpar->UhdmType() == uhdmparam_assign) {
                if (auto pa = any_cast<const UHDM::param_assign*>(rpar))
                    nxt = dynamic_cast<const UHDM::expr*>(pa->Rhs());
            } else if (auto rsc = dynamic_cast<const UHDM::instance*>(rpar)) {
                if (rsc->Param_assigns())
                    for (auto pa : *rsc->Param_assigns())
                        if (pa->Lhs() && std::string(pa->Lhs()->VpiName()) == rn)
                            nxt = dynamic_cast<const UHDM::expr*>(pa->Rhs());
            }
        }
        if (!nxt) break;
        rhs = nxt;
        param = rp;   // widths/typespec come from the declaration we landed on
    }

    // How many elements: the initialiser's own operand count is the most
    // reliable source -- the parameter's range can be written in terms of
    // another parameter (`[NbInstr]`).
    int nelem = 0;
    if (rhs->UhdmType() == uhdmoperation)
        if (auto ops = any_cast<const UHDM::operation*>(rhs)->Operands())
            nelem = (int)ops->size();
    if (nelem <= 0)
        return RTLIL::SigSpec();

    // Import the array literal at its NATURAL width.  The ambient context
    // width belongs to the field being read (1 bit for `.accept`, 8 for
    // `.tag`), and letting it size the whole-array pattern truncates it -- the
    // element width then comes out as 1 or 2 bits and the read is nonsense.
    bool saved_fcf = force_const_fold;
    int saved_ctx = expression_context_width;
    force_const_fold = true;
    expression_context_width = 0;
    RTLIL::SigSpec all = import_expression(rhs, input_mapping);
    expression_context_width = saved_ctx;
    force_const_fold = saved_fcf;
    if (all.size() <= 0 || all.size() % nelem != 0)
        return RTLIL::SigSpec();
    int elem_w = all.size() / nelem;

    // Field offset within the element struct, counting from the LSB (members
    // are declared MSB-first).
    const UHDM::struct_typespec* st = nullptr;
    if (auto rt = param->Typespec())
        if (auto ats = rt->Actual_typespec()) {
            const UHDM::typespec* et = nullptr;
            if (ats->UhdmType() == uhdmarray_typespec) {
                auto arr = any_cast<const UHDM::array_typespec*>(ats);
                if (arr->Elem_typespec())
                    et = arr->Elem_typespec()->Actual_typespec();
            } else if (ats->UhdmType() == uhdmpacked_array_typespec) {
                // PACKED array of structs — fpnew_pkg's
                // `fp_encoding_t [0:NUM_FP_FORMATS-1] FP_ENCODINGS`: the
                // element struct hangs off the packed_array_typespec the same
                // way (bias() read FP_ENCODINGS[fmt].exp_bits as 0 without
                // this, folding every FP bias to -1).
                auto parr = any_cast<const UHDM::packed_array_typespec*>(ats);
                if (parr->Elem_typespec())
                    et = parr->Elem_typespec()->Actual_typespec();
            } else {
                et = dynamic_cast<const UHDM::typespec*>(ats);
            }
            st = et ? dynamic_cast<const UHDM::struct_typespec*>(et) : nullptr;
            // The element type can be a TYPE PARAMETER whose default has been
            // erased to plain `logic` (`parameter type copro_issue_resp_t =
            // logic`, bound at the instance to the package's struct).  The
            // erased default has no members, so the field offsets cannot be
            // computed from it -- resolve it to the type the instance actually
            // binds.
            if (!st && et) {
                const UHDM::typespec* bound = resolve_type_param_typespec(et, inst);
                if (bound && bound != et)
                    st = dynamic_cast<const UHDM::struct_typespec*>(bound);
            }
        }
    if (!st || !st->Members())
        return RTLIL::SigSpec();

    // Walk the whole field chain, not just one level: the decoder reads
    // `CoproInstr[i].resp.accept`, so stopping after `resp` leaves the access
    // unresolved and the value falls back to zero.
    int field_offset = 0, field_width = 0;
    for (size_t f = 0; f < fields.size(); f++) {
        if (!st || !st->Members())
            return RTLIL::SigSpec();
        int off = 0, w = 0;
        bool found = false;
        const UHDM::struct_typespec* next = nullptr;
        for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
            auto m = (*st->Members())[i];
            const UHDM::any* mats = nullptr;
            int mw = 0;
            if (auto mts = m->Typespec())
                if ((mats = mts->Actual_typespec()))
                    mw = get_width_from_typespec(mats, inst);
            if (std::string(m->VpiName()) == fields[f]) {
                w = mw; found = true;
                next = mats ? dynamic_cast<const UHDM::struct_typespec*>(mats)
                            : nullptr;
                break;
            }
            off += mw;
        }
        if (!found || w <= 0)
            return RTLIL::SigSpec();
        field_offset += off;
        field_width = w;
        st = next;
    }
    if (field_width <= 0 || field_offset + field_width > elem_w)
        return RTLIL::SigSpec();

    // The assignment pattern is concatenated with element 0 FIRST, and a
    // Verilog concatenation puts its first operand in the HIGH bits -- so
    // element 0 lives at the top of the flattened value, not the bottom.
    // Indexing from the bottom silently reverses the array: the decoder table
    // still matched, but against the wrong entries.
    auto slice_of = [&](int idx) {
        return all.extract((nelem - 1 - idx) * elem_w + field_offset, field_width);
    };

    RTLIL::SigSpec idx_sig;
    if (idx_in)
        idx_sig = *idx_in;      // caller already evaluated it (loop unrolling)
    else if (bs->VpiIndex())
        idx_sig = import_expression(bs->VpiIndex(), input_mapping);
    if (idx_sig.size() > 0 && idx_sig.is_fully_const()) {
        int idx = idx_sig.as_const().as_int();
        if (idx < 0 || idx >= nelem)
            return RTLIL::SigSpec();
        if (mode_debug)
            log("    param array elem field: %s[%d].%s -> %d bits\n",
                std::string(param->VpiName()).c_str(), idx,
                fields.back().c_str(), field_width);
        return slice_of(idx);
    }
    if (idx_sig.size() == 0)
        return RTLIL::SigSpec();

    // Runtime index: mux the per-element field slices.  Built as a chain so the
    // out-of-range index yields the same 'x' a select would.
    RTLIL::SigSpec result = RTLIL::SigSpec(RTLIL::State::Sx, field_width);
    for (int idx = nelem - 1; idx >= 0; idx--) {
        RTLIL::SigSpec eq = module->Eq(NEW_ID, idx_sig,
                                       RTLIL::Const(idx, idx_sig.size()));
        result = module->Mux(NEW_ID, result, slice_of(idx), eq);
    }
    if (mode_debug)
        log("    param array elem field: %s[<dyn>].%s -> %d-bit mux of %d\n",
            std::string(param->VpiName()).c_str(), fields.back().c_str(),
            field_width, nelem);
    return result;
}

RTLIL::SigSpec UhdmImporter::import_hier_path(const hier_path* uhdm_hier, const scope* inst, const std::map<std::string, RTLIL::SigSpec>* input_mapping) {
    if (mode_debug)
        log("    Importing hier_path\n");

    // Guard: import_hier_path dereferences `module` (e.g. module->cell()) while
    // resolving cell/instance references.  type_param_signature() computes port
    // widths via get_width()->import_expression() BEFORE the RTLIL module is
    // created, so `module` can be null here — bail out safely instead of
    // crashing (CVA6 axi_shim ports have a cast in their range that reaches
    // this path during name computation).
    if (!module)
        return RTLIL::SigSpec();

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

    // Substitute unrolled-loop variables into bracketed selects of the path
    // name (`Cfg.ExecuteRegionAddrBase[k]` with loop_values[k]=1 →
    // `...[1]`): downstream string-driven member resolution
    // (calculate_struct_member_offset) parses only literal indices, so a
    // symbolic loop index made the whole member access unresolvable inside
    // an unrolled function loop (CVA6 is_inside_execute_regions).
    if (!loop_values.empty() && path_name.find('[') != std::string::npos) {
        std::string subst;
        size_t p = 0;
        while (p < path_name.size()) {
            size_t ob = path_name.find('[', p);
            if (ob == std::string::npos) {
                subst += path_name.substr(p);
                break;
            }
            size_t cb = path_name.find(']', ob);
            if (cb == std::string::npos) {
                subst += path_name.substr(p);
                break;
            }
            subst += path_name.substr(p, ob - p + 1);
            std::string idx = path_name.substr(ob + 1, cb - ob - 1);
            auto lv = loop_values.find(idx);
            if (lv != loop_values.end())
                subst += std::to_string(lv->second);
            else
                subst += idx;
            subst += "]";
            p = cb + 1;
        }
        path_name = subst;
    }

    if (mode_debug)
        log("    hier_path: VpiName='%s', VpiFullName='%s', using='%s'\n",
            std::string(name_view).c_str(), std::string(full_name_view).c_str(), path_name.c_str());

    // Primary path: fold an interface-port parameter member (`sub.CFG.HSK.DLY`,
    // `sub.CFG.BUS.DAT`) to a constant directly from the hier_path's
    // Actual_group chain — Surelog binds the `CFG` element to the interface
    // `parameter` object, so its struct value can be indexed by the trailing
    // field chain.  This is robust regardless of where the interface instance
    // sits in the hierarchy (an array element, a parent's port), replacing the
    // fragile name/parent-chain search below.
    if (auto fs = fold_iface_param_via_chain(uhdm_hier); fs.size() > 0) {
        if (mode_debug)
            log("    hier_path: %s -> %d-bit constant via Actual_group chain\n",
                path_name.c_str(), fs.size());
        return fs;
    }

    // `TBL[i].field` where TBL is a PARAMETER that is an unpacked array of a
    // struct type (cvxif's `parameter copro_issue_resp_t CoproInstr[NbInstr]`).
    // There is no wire to select from: the whole array is a constant, and the
    // value lives in the enclosing scope's param_assign rather than in the
    // parameter's VpiValue/Expr.  Without this the read produced X, which after
    // synthesis reads as the field simply being zero.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 2) {
        auto& pe_pa = *uhdm_hier->Path_elems();
        if (pe_pa[0]->UhdmType() == uhdmbit_select) {
            // The LAST element may itself be a bit_select -- the field is a
            // vector and a bit of it is taken
            // (`CoproInstr[i].resp.register_read[2]`).  Treating that as "not a
            // field chain" abandoned the whole access, which is what still
            // fed `issue_ready_o` from a zero.
            std::vector<std::string> fields;
            const bit_select* tail_sel = nullptr;
            for (size_t i = 1; i < pe_pa.size(); i++) {
                if (pe_pa[i]->UhdmType() == uhdmref_obj) {
                    fields.push_back(
                        std::string(any_cast<const ref_obj*>(pe_pa[i])->VpiName()));
                } else if (pe_pa[i]->UhdmType() == uhdmbit_select &&
                           i + 1 == pe_pa.size()) {
                    tail_sel = any_cast<const bit_select*>(pe_pa[i]);
                    fields.push_back(std::string(tail_sel->VpiName()));
                } else {
                    fields.clear(); break;
                }
            }
            if (!fields.empty()) {
                RTLIL::SigSpec r = import_param_array_elem_field(
                    any_cast<const bit_select*>(pe_pa[0]), fields, inst,
                    input_mapping);
                if (r.size() > 0) {
                    if (!tail_sel)
                        return r;
                    RTLIL::SigSpec bi = tail_sel->VpiIndex()
                        ? import_expression(tail_sel->VpiIndex(), input_mapping)
                        : RTLIL::SigSpec();
                    if (bi.size() > 0 && bi.is_fully_const()) {
                        int b = bi.as_const().as_int();
                        if (b >= 0 && b < r.size())
                            return r.extract(b, 1);
                    } else if (bi.size() > 0) {
                        RTLIL::Wire* yw = module->addWire(NEW_ID, 1);
                        module->addShiftx(NEW_ID, r, bi, yw, false);
                        return RTLIL::SigSpec(yw);
                    }
                }
            }
        }
    }


    // Nested interface struct-parameter field: `s.CFG.BUS.DAT` where `s` is a
    // modport port and `CFG` is a (nested struct) parameter on the connected
    // interface.  eval_iface_param_field walks the field chain to a constant.
    // Needed for a memory width `logic [s.CFG.BUS.DAT-1:0] mem [...]` (the degu
    // SoC's r5p_soc_memory) — resolving it via the bare 2-element param handler
    // below would stop at `CFG` (the whole struct) and never reach `.BUS.DAT`.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 2 &&
        current_instance) {
        std::string v = eval_iface_param_field(uhdm_hier, current_instance);
        // Surelog inlines a PARENT interface ref (`sub.CFG.BUS.DAT`) into a CHILD
        // paramod's port ranges — tcb_dev_gpio/uart get `[sub.CFG.BUS.DAT-1:0]`
        // via `.SYS_DAT(sub.CFG.BUS.DAT)`, but `sub` is the parent
        // (tcb_lite_dev_gpio) interface port, not visible in the child.  Walk up
        // the instance-parent chain so the interface connection is reachable.
        for (const UHDM::any* p = current_instance->VpiParent();
             v.empty() && p; p = p->VpiParent()) {
            if (auto pm = dynamic_cast<const module_inst*>(p)) {
                v = eval_iface_param_field(uhdm_hier, pm);
                if (!v.empty())
                    log("    hier_path: %s -> %s via parent %s interface param\n",
                        path_name.c_str(), v.c_str(),
                        std::string(pm->VpiName()).c_str());
            }
        }
        if (!v.empty()) {
            int iv = atoi(v.c_str());
            log("    hier_path: %s -> %d via interface struct parameter\n",
                path_name.c_str(), iv);
            return RTLIL::SigSpec(RTLIL::Const(iv, 32));
        }
        // WHOLE-STRUCT form (`man.CFG.BUS`, `man.CFG`): the field is a struct,
        // not a scalar — build a constant SigSpec from its members.  Used by the
        // interface parameter-consistency assertions
        // (`assert (man.CFG.BUS == sub.CFG.BUS)` in the TCB register/demux).
        RTLIL::SigSpec ss = eval_iface_param_struct(uhdm_hier, current_instance);
        if (ss.size() > 0) {
            if (mode_debug)
                log("    hier_path: %s -> %d-bit interface struct parameter\n",
                    path_name.c_str(), ss.size());
            return ss;
        }
    }
    // Bare `CFG.HSK.DLY` — an interface's own struct parameter substituted into a
    // signal width without a modport prefix (tcb_lite_if `[CFG.HSK.DLY-1:0]`).
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 2 &&
        current_instance) {
        std::string v = eval_bare_iface_param_field(uhdm_hier, current_instance);
        // Walk up instance parents too (bare `CFG.HSK.DLY` inlined from an
        // interface array bound into a child that only reaches the interface
        // through a parent's port).
        for (const UHDM::any* p = current_instance->VpiParent();
             v.empty() && p; p = p->VpiParent()) {
            if (auto pm = dynamic_cast<const module_inst*>(p))
                v = eval_bare_iface_param_field(uhdm_hier, pm);
        }
        if (!v.empty()) {
            int iv = atoi(v.c_str());
            log("    hier_path: %s -> %d via bare interface struct parameter\n",
                path_name.c_str(), iv);
            return RTLIL::SigSpec(RTLIL::Const(iv, 32));
        }
    }
    // `CFG.BUS.DAT` where the base is a struct-typed PARAMETER directly (Surelog
    // inlines `sub.CFG.BUS.DAT` into a device paramod's port ranges, substituting
    // the interface's `CFG` parameter for `sub.CFG`).  Resolves without needing
    // current_instance, so it also fixes port-width evaluation where the width
    // helper runs with no instance context (degu SoC tcb_dev_gpio sys_wdt/sys_rdt).
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 2) {
        int fw = 32;  // field's declared width; bit fields must fold to 1 bit
                      // so self-determined contexts (`{CVA6Cfg.RVB,
                      // CVA6Cfg.RVZiCond}` case selector) keep their SV width
        std::string v = eval_param_struct_field(uhdm_hier, &fw);
        if (!v.empty()) {
            int iv = atoi(v.c_str());
            log("    hier_path: %s -> %d via struct parameter field (w=%d)\n",
                path_name.c_str(), iv, fw);
            return RTLIL::SigSpec(RTLIL::Const(iv, fw > 0 ? fw : 32));
        }
    }
    // Cross-module reference (XMR) READ: `u_processor.internal_ready` where
    // `u_processor` is a child INSTANCE in this module and `internal_ready` is
    // an INTERNAL signal of it (github #450).  Yosys can't resolve this through
    // the normal synth flow: the source is opt'd away (unused WITHIN the child)
    // and a plain parent wire collides with the flattened name.  Resolve it the
    // way slang does — expose the child signal as an OUTPUT PORT and wire the
    // cell through — so the source survives opt and drives the reader after
    // flatten.  Only fires when the first element is genuinely a cell instance
    // (interface-port `sub.clk` and struct-field `s.f` reads fall through: their
    // base is a wire/port, not a cell).
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& xpe = *uhdm_hier->Path_elems();
        if (xpe[0]->UhdmType() == uhdmref_obj &&
            xpe[1]->UhdmType() == uhdmref_obj) {
            std::string inst = std::string(any_cast<const ref_obj*>(xpe[0])->VpiName());
            std::string sig  = std::string(any_cast<const ref_obj*>(xpe[1])->VpiName());
            RTLIL::Cell* xcell = inst.empty() ? nullptr
                               : module->cell(RTLIL::escape_id(inst));
            RTLIL::Module* xchild = xcell ? design->module(xcell->type) : nullptr;
            if (xchild && !sig.empty()) {
                if (xchild->wire(RTLIL::escape_id(sig))) {
                    resolve_xmr_read(module, xcell, sig);
                    log("    XMR read %s.%s: exposed child output port\n",
                        inst.c_str(), sig.c_str());
                    return RTLIL::SigSpec(module->wire(RTLIL::escape_id(inst + "." + sig)));
                }
            } else if (!xcell && !inst.empty() && !sig.empty() &&
                       !module->wire(RTLIL::escape_id(inst)) &&
                       any_cast<const ref_obj*>(xpe[0])->Actual_group() &&
                       any_cast<const ref_obj*>(xpe[0])->Actual_group()->UhdmType()
                           == uhdmmodule_inst) {
                // The cell doesn't exist yet — cont_assigns are imported BEFORE
                // instances.  The first element resolves to a MODULE INSTANCE
                // (not a parameter `CFG.field`, struct, or interface — those
                // resolve elsewhere), so this is a genuine XMR.
                // Record it + create the reader wire now and RETURN it (rather
                // than falling through, which would leave a spurious same-named
                // signal in this module); resolve the child port + drive the
                // reader at the end of import_design once every cell exists.
                pending_xmr_reads_.push_back({module, inst, sig});
                int xw = 1;
                if (auto ag = any_cast<const ref_obj*>(xpe[1])->Actual_group()) {
                    int w = get_width(ag, current_instance);
                    if (w > 0) xw = w;
                }
                std::string pn = inst + "." + sig;
                RTLIL::Wire* pw = module->wire(RTLIL::escape_id(pn));
                if (!pw) pw = module->addWire(RTLIL::escape_id(pn), xw);
                log("    XMR read %s.%s: deferred (cell not yet created, width=%d)\n",
                    inst.c_str(), sig.c_str(), xw);
                return RTLIL::SigSpec(pw);
            }
        }
    }

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
            // Built-in enum methods `e.first()` / `e.last()` / `e.num()`:
            // these are compile-time constants of the enum TYPE (independent of
            // e's runtime value), so they have no user `Function()` (fdef null).
            if (!fdef && uhdm_hier->Path_elems()->size() >= 2 &&
                (func_name == "first" || func_name == "last" || func_name == "num")) {
                const UHDM::enum_typespec* ets = nullptr;
                auto base_elem = (*uhdm_hier->Path_elems())[0];
                const UHDM::any* actual = base_elem;
                if (auto ro = dynamic_cast<const UHDM::ref_obj*>(base_elem))
                    if (ro->Actual_group()) actual = ro->Actual_group();
                if (auto av = dynamic_cast<const UHDM::expr*>(actual))
                    if (auto rt = av->Typespec())
                        if (auto at = rt->Actual_typespec())
                            if (at->UhdmType() == uhdmenum_typespec)
                                ets = any_cast<const UHDM::enum_typespec*>(at);
                if (ets && ets->Enum_consts() && !ets->Enum_consts()->empty()) {
                    auto& consts = *ets->Enum_consts();
                    if (func_name == "num")
                        return RTLIL::SigSpec(RTLIL::Const((int)consts.size(), 32));
                    int width = get_width_from_typespec(ets, inst);
                    if (width <= 0) width = 32;
                    auto ec = (func_name == "first") ? consts.front() : consts.back();
                    int64_t v = parse_vpi_value_to_int(std::string(ec->VpiValue()));
                    log("    enum method %s.%s() -> %lld (%d-bit)\n",
                        std::string(base_elem->VpiName()).c_str(), func_name.c_str(),
                        (long long)v, width);
                    return RTLIL::SigSpec(RTLIL::Const(v, width));
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

    // Interface-signal struct member: `s.req.adr` (single port) or
    // `arr[0].req.adr` (array element) — "s"/"arr[0]" is an interface, "<>.req"
    // is the flattened interface signal wire (a packed struct), and the remaining
    // elements ("adr", ...) are struct members.  The interface flattens `req` to
    // a wire named "<iface>.req"; the general handler below keys off the bare
    // base (a 1-bit placeholder), so resolve the "<iface>.<sig>" join as the base
    // and walk the struct members from the recorded signal typespec.  Detect by
    // name_map carrying the 2-element join (a plain union path like `dec.r.rd`
    // has no "dec.r" wire, so this stays specific to interfaces).
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 3) {
        auto& pe = *uhdm_hier->Path_elems();
        // pe[0] may be a ref_obj (single port "s") OR a bit_select (array element
        // "arr[0]"); pe[1..] must be plain member refs.
        bool rest_ref = true;
        for (size_t i = 1; i < pe.size(); i++)
            if (pe[i]->UhdmType() != uhdmref_obj) { rest_ref = false; break; }
        std::string base;
        if (rest_ref) {
            if (pe[0]->UhdmType() == uhdmref_obj) {
                base = std::string(any_cast<const ref_obj*>(pe[0])->VpiName());
            } else if (pe[0]->UhdmType() == uhdmbit_select) {
                auto bs = any_cast<const bit_select*>(pe[0]);
                std::string bn = std::string(bs->VpiName());
                int idx = -1;
                if (bs->VpiIndex()) {
                    RTLIL::SigSpec is = import_expression(bs->VpiIndex());
                    if (is.is_fully_const()) idx = is.as_const().as_int();
                }
                if (idx >= 0) base = bn + "[" + std::to_string(idx) + "]";
            }
        }
        if (!base.empty()) {
            std::string sig   = std::string(any_cast<const ref_obj*>(pe[1])->VpiName());
            std::string wname = base + "." + sig;          // "s.req" / "arr[0].req"
            if (name_map.count(wname) && iface_signal_struct_ts_.count(wname)) {
                RTLIL::SigSpec base_sig = RTLIL::SigSpec(name_map[wname]);
                // The path element pe[1] carries no typespec/Actual_group, so use
                // the struct/union typespec recorded when the field wire was made.
                const UHDM::typespec* cur_ts = iface_signal_struct_ts_[wname];
                if (cur_ts) {
                    int off = 0, field_w = 0;
                    bool ok = true;
                    for (size_t lvl = 2; lvl < pe.size() && ok; lvl++) {
                        std::string mname =
                            std::string(any_cast<const ref_obj*>(pe[lvl])->VpiName());
                        const UHDM::VectorOftypespec_member* members = nullptr;
                        bool is_struct = false;
                        if (cur_ts->UhdmType() == uhdmstruct_typespec) {
                            members = any_cast<const UHDM::struct_typespec*>(cur_ts)->Members();
                            is_struct = true;
                        } else if (cur_ts->UhdmType() == uhdmunion_typespec) {
                            members = any_cast<const UHDM::union_typespec*>(cur_ts)->Members();
                        }
                        if (!members) { ok = false; break; }
                        int moff = 0, mw = 0;
                        const UHDM::typespec* mts = nullptr;
                        bool found = false;
                        for (int i = (int)members->size() - 1; i >= 0; i--) {
                            auto m = (*members)[i];
                            int w = 0;
                            const UHDM::typespec* ts2 = nullptr;
                            if (auto mt = m->Typespec())
                                if (auto a2 = mt->Actual_typespec()) {
                                    ts2 = a2;
                                    w = get_width_from_typespec(a2, inst);
                                }
                            if (std::string(m->VpiName()) == mname) {
                                mw = w; mts = ts2; found = true; break;
                            }
                            if (is_struct) moff += w;
                        }
                        if (!found) { ok = false; break; }
                        off += moff; field_w = mw; cur_ts = mts;
                    }
                    // A member resolved to zero width (`sub.req.ctl` with
                    // CFG.BUS.CTL==0, `sub.rsp.sts` with STS==0) is a legitimate
                    // empty field — return an empty SigSpec so the enclosing
                    // no-op assignment (`man.req.ctl = sub.req.ctl`) drops out
                    // silently instead of falling through to the "Could not
                    // resolve struct member" warning.
                    if (ok && field_w == 0 && off <= base_sig.size()) {
                        log("    hier_path: interface signal struct member %s.* -> zero-width field\n",
                            wname.c_str());
                        return RTLIL::SigSpec();
                    }
                    if (ok && field_w > 0 && off + field_w <= base_sig.size()) {
                        log("    hier_path: interface signal struct member %s.* -> [%d+:%d]\n",
                            wname.c_str(), off, field_w);
                        return base_sig.extract(off, field_w);
                    }
                }
            }
        }
    }

    // Packed union/struct member that is itself a PACKED ARRAY, read with an
    // ELEMENT select: `csr_map.a[csr_ctl.adr]` (rp32 r5p_csr's CSR read) —
    // Path_elems = [ref_obj(base), bit_select(member, idx)].  The generic
    // walker returned the WHOLE base: the read collapsed to a 131072-bit mux
    // Verilator refuses to build and csr_rdt stuck at element [fff].
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pe_ua = *uhdm_hier->Path_elems();
        if (pe_ua[0]->UhdmType() == uhdmref_obj &&
            pe_ua[1]->UhdmType() == uhdmbit_select) {
            auto rb  = any_cast<const ref_obj*>(pe_ua[0]);
            auto mbs = any_cast<const bit_select*>(pe_ua[1]);
            std::string ua_base(rb->VpiName());
            std::string ua_member(mbs->VpiName());
            RTLIL::Wire* bw = name_map.count(ua_base)
                                  ? name_map[ua_base]
                                  : module->wire(RTLIL::escape_id(ua_base));
            // Base typespec (struct or union) from the ref's actual.
            const UHDM::typespec* bts = nullptr;
            if (const any* ag = rb->Actual_group()) {
                const UHDM::ref_typespec* rt = nullptr;
                if (auto nn = dynamic_cast<const UHDM::net*>(ag)) rt = nn->Typespec();
                else if (auto vv = dynamic_cast<const UHDM::variables*>(ag)) rt = vv->Typespec();
                if (rt) bts = rt->Actual_typespec();
            }
            const UHDM::VectorOftypespec_member* ua_members = nullptr;
            if (bts) {
                if (auto ust = any_cast<const UHDM::union_typespec*>(bts))
                    ua_members = ust->Members();
                else if (auto sst = any_cast<const UHDM::struct_typespec*>(bts))
                    ua_members = sst->Members();
            }
            const UHDM::typespec* mts = nullptr;
            if (ua_members)
                for (auto m : *ua_members)
                    if (std::string(m->VpiName()) == ua_member && m->Typespec()) {
                        mts = m->Typespec()->Actual_typespec();
                        break;
                    }
            // Member must be a packed ARRAY: outer range + element width.
            const UHDM::VectorOfrange* mrgs = nullptr;
            if (mts) {
                if (auto lt = any_cast<const UHDM::logic_typespec*>(mts)) {
                    if (lt->Ranges() && lt->Ranges()->size() >= 2)
                        mrgs = lt->Ranges();
                } else if (auto pt =
                               any_cast<const UHDM::packed_array_typespec*>(mts)) {
                    mrgs = pt->Ranges();
                }
            }
            if (bw && mrgs && !mrgs->empty() && mbs->VpiIndex()) {
                int moff = 0, mw = 0;
                bool ok = calculate_struct_member_offset(bts, ua_member, inst,
                                                         moff, mw);
                RTLIL::SigSpec ls = ok ? import_expression((*mrgs)[0]->Left_expr())
                                       : RTLIL::SigSpec();
                RTLIL::SigSpec rs = ok ? import_expression((*mrgs)[0]->Right_expr())
                                       : RTLIL::SigSpec();
                if (ok && mw > 0 && moff + mw <= bw->width &&
                    ls.is_fully_const() && rs.is_fully_const()) {
                    int l = ls.as_int(), r = rs.as_int();
                    int n = std::abs(l - r) + 1;
                    if (n > 0 && mw % n == 0) {
                        int elem_w = mw / n;
                        bool asc = l < r;
                        RTLIL::SigSpec ix =
                            import_expression(mbs->VpiIndex(), input_mapping);
                        if (ix.is_fully_const()) {
                            int iv = ix.as_const().as_int();
                            int pos = asc ? (std::max(l, r) - iv)
                                          : (iv - std::min(l, r));
                            if (pos >= 0 && pos < n) {
                                log("    hier_path: packed-array member elem "
                                    "%s.%s[%d] -> \%s[%d +: %d]\n",
                                    ua_base.c_str(), ua_member.c_str(), iv,
                                    ua_base.c_str(), moff + pos * elem_w, elem_w);
                                return RTLIL::SigSpec(bw, moff + pos * elem_w,
                                                      elem_w);
                            }
                        } else {
                            // Dynamic index: element read via $shiftx on the
                            // member slice, position honouring the declared
                            // bounds and direction.
                            int shw = std::max(32, ix.size() + 7);
                            RTLIL::SigSpec rel = ix;
                            rel.extend_u0(shw, false);
                            if (asc) {
                                RTLIL::Wire* pw = module->addWire(NEW_ID, shw);
                                module->addSub(NEW_ID,
                                    RTLIL::SigSpec(RTLIL::Const(std::max(l, r), shw)),
                                    rel, pw, true);
                                rel = RTLIL::SigSpec(pw);
                            } else if (std::min(l, r) != 0) {
                                RTLIL::Wire* pw = module->addWire(NEW_ID, shw);
                                module->addSub(NEW_ID, rel,
                                    RTLIL::SigSpec(RTLIL::Const(std::min(l, r), shw)),
                                    pw, true);
                                rel = RTLIL::SigSpec(pw);
                            }
                            RTLIL::Wire* sh = module->addWire(NEW_ID, shw);
                            module->addMul(NEW_ID, rel,
                                RTLIL::SigSpec(RTLIL::Const(elem_w, shw)), sh, true);
                            RTLIL::Wire* yw = module->addWire(NEW_ID, elem_w);
                            RTLIL::Cell* sx = module->addShiftx(NEW_ID,
                                RTLIL::SigSpec(bw, moff, mw),
                                RTLIL::SigSpec(sh), yw);
                            add_src_attribute(sx->attributes, uhdm_hier);
                            log("    hier_path: packed-array member DYNAMIC elem "
                                "%s.%s[expr] -> shiftx over %d bits, elem %d\n",
                                ua_base.c_str(), ua_member.c_str(), mw, elem_w);
                            return RTLIL::SigSpec(yw);
                        }
                    }
                }
            }
        }
    }

    // General packed union/struct member chain `base.m1.m2...field` where each
    // level is a struct or union member (rp32 dec32: `op.r.opcode.opc` — union
    // -> struct -> struct -> enum field; and imm_i_f's `op.imm_11_0` — a simple
    // struct member — both on the param `op`).  Resolve the base via
    // name_map/input_mapping and walk the typespec chain, accumulating the bit
    // offset (union members share bits so contribute 0; struct members add the
    // offset of the members below them, LSB-first).  Only fires when every level
    // is a plain member ref AND the base resolves to a struct/union — otherwise
    // it falls through to the dedicated handlers below.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 2) {
        auto& pec = *uhdm_hier->Path_elems();
        bool all_ref = true;
        for (auto e : pec)
            if (e->UhdmType() != uhdmref_obj) { all_ref = false; break; }
        bool base_in_im = all_ref && input_mapping &&
            input_mapping->count(
                std::string(any_cast<const ref_obj*>(pec[0])->VpiName()));
        // Fire for any deep (>=4) member chain, OR for a param/local base
        // (input_mapping) at any depth >=2 — the function-inline path's simple
        // `op.imm_11_0` member reads.  For shallow module-wire bases the
        // dedicated handlers below stay in charge.
        if (all_ref && (pec.size() >= 4 || base_in_im)) {
            auto base_ref = any_cast<const ref_obj*>(pec[0]);
            std::string base_name = std::string(base_ref->VpiName());
            // Prefer the in-flight blocking value (input_mapping /
            // current_comb_values) over the module wire: a struct-field read
            // `s.f` after an earlier same-block write to `s` must see the
            // written value, not the final \s net (which the read then drives —
            // a combinational loop; Ibex ibex_cs_registers mstatus_d.mpp).
            RTLIL::SigSpec base_sig;
            if (input_mapping && input_mapping->count(base_name))
                base_sig = input_mapping->at(base_name);
            else if (name_map.count(base_name))
                base_sig = RTLIL::SigSpec(name_map[base_name]);

            // Base typespec (union or struct).
            const UHDM::typespec* cur_ts = nullptr;
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
                // A struct declared as a NET (`p::areq_t o;` in a module) is a
                // struct_net, which was missing here — the typespec came back
                // null, the member walk bailed, and the whole access fell
                // through to the handlers below, which resolve against the
                // module WIRE instead of the in-flight value.  For a field read
                // inside the same always_comb that writes the struct, that wire
                // is driven by this very process: a combinational loop, which
                // yosys breaks by leaving the field driven by itself (CVA6
                // pmp_data_if's fetch_exception.cause).
                else if (a->UhdmType() == uhdmstruct_net)
                    rts = any_cast<const UHDM::struct_net*>(a)->Typespec();
                else if (a->UhdmType() == uhdmio_decl)
                    rts = any_cast<const UHDM::io_decl*>(a)->Typespec();
            }
            if (!rts) rts = base_ref->Typespec();
            if (rts) cur_ts = rts->Actual_typespec();

            if (!base_sig.empty() && cur_ts) {
                int off = 0, field_w = 0;
                bool ok = true;
                for (size_t lvl = 1; lvl < pec.size() && ok; lvl++) {
                    std::string mname =
                        std::string(any_cast<const ref_obj*>(pec[lvl])->VpiName());
                    const UHDM::VectorOftypespec_member* members = nullptr;
                    bool is_struct = false;
                    if (cur_ts->UhdmType() == uhdmstruct_typespec) {
                        members = any_cast<const UHDM::struct_typespec*>(cur_ts)->Members();
                        is_struct = true;
                    } else if (cur_ts->UhdmType() == uhdmunion_typespec) {
                        members = any_cast<const UHDM::union_typespec*>(cur_ts)->Members();
                    }
                    if (!members) { ok = false; break; }
                    int moff = 0, mw = 0;
                    const UHDM::typespec* mts = nullptr;
                    bool found = false;
                    for (int i = (int)members->size() - 1; i >= 0; i--) {
                        auto m = (*members)[i];
                        int w = 0;
                        const UHDM::typespec* ts2 = nullptr;
                        if (auto mt = m->Typespec())
                            if (auto a2 = mt->Actual_typespec()) {
                                ts2 = a2;
                                w = get_width_from_typespec(a2, inst);
                            }
                        if (std::string(m->VpiName()) == mname) {
                            mw = w; mts = ts2; found = true; break;
                        }
                        if (is_struct) moff += w;
                    }
                    if (!found) { ok = false; break; }
                    off += moff;
                    field_w = mw;
                    cur_ts = mts;
                }
                if (ok && field_w > 0 && off + field_w <= base_sig.size()) {
                    return base_sig.extract(off, field_w);
                }
            }
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
            // Function-inline (legacy) path: the base may be a param/local in
            // input_mapping rather than a module wire (rp32 dec32: op.r.rd).
            RTLIL::SigSpec base_sig;
            if (base_wire) base_sig = RTLIL::SigSpec(base_wire);
            else if (input_mapping && input_mapping->count(base_name))
                base_sig = input_mapping->at(base_name);

            // Chase the base ref's typespec to the union_typespec; pick
            // the matching member; chase that to its struct_typespec.
            const UHDM::union_typespec* ut = nullptr;
            if (!base_sig.empty()) {
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
                    else if (a->UhdmType() == uhdmio_decl)
                        rts = any_cast<const UHDM::io_decl*>(a)->Typespec();
                }
                if (!rts) rts = base_ref->Typespec();
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

            if (!base_sig.empty() && st && st->Members()) {
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
                    field_off + field_w <= base_sig.size()) {
                    log("    hier_path: union+struct %s.%s.%s -> [%d+:%d]\n",
                        base_name.c_str(), union_member.c_str(),
                        field_name.c_str(), field_off, field_w);
                    return base_sig.extract(field_off, field_w);
                }
            }
        }

        // `struct.member[idx].field` — Path_elems
        // [ref_obj(struct), bit_select(member[idx]), ref_obj(field)] where
        // `member` is a packed array of a (packed) struct (StructOfArrayOfStructs:
        // `ast_alert_o.alerts_ack[0].p`).  Resolve the bit slice:
        //   member_offset + idx*element_width + field_offset, width field_width.
        if (pe3[0]->UhdmType() == uhdmref_obj &&
            pe3[1]->UhdmType() == uhdmbit_select &&
            pe3[2]->UhdmType() == uhdmref_obj) {
            auto base_ref = any_cast<const ref_obj*>(pe3[0]);
            const bit_select* memsel = any_cast<const bit_select*>(pe3[1]);
            std::string base_name = std::string(base_ref->VpiName());
            std::string member_name = std::string(memsel->VpiName());
            std::string field_name = std::string(any_cast<const ref_obj*>(pe3[2])->VpiName());
            RTLIL::Wire* base_wire = name_map.count(base_name) ? name_map[base_name] : nullptr;

            // Outer struct typespec from the base variable.
            const UHDM::struct_typespec* outer_st = nullptr;
            if (base_wire && base_ref->Actual_group()) {
                const UHDM::ref_typespec* rts = nullptr;
                if (auto v = dynamic_cast<const UHDM::variables*>(base_ref->Actual_group()))
                    rts = v->Typespec();
                else if (auto n = dynamic_cast<const UHDM::net*>(base_ref->Actual_group()))
                    rts = n->Typespec();
                if (rts && rts->Actual_typespec() &&
                    rts->Actual_typespec()->UhdmType() == uhdmstruct_typespec)
                    outer_st = any_cast<const UHDM::struct_typespec*>(rts->Actual_typespec());
            }

            if (base_wire && outer_st && outer_st->Members()) {
                // Member offset (LSB-first) + the member's packed-array typespec.
                int member_off = 0;
                const UHDM::typespec* member_ts = nullptr;
                bool found_member = false;
                for (int i = (int)outer_st->Members()->size() - 1; i >= 0; i--) {
                    auto m = (*outer_st->Members())[i];
                    const UHDM::typespec* mts = nullptr;
                    if (auto r = m->Typespec()) mts = r->Actual_typespec();
                    int mw = mts ? get_width_from_typespec(mts, inst) : 0;
                    if (std::string(m->VpiName()) == member_name) {
                        member_ts = mts;
                        found_member = true;
                        break;
                    }
                    member_off += mw;
                }
                // Inner struct + element width from the member's packed_array_typespec.
                const UHDM::struct_typespec* inner_st = nullptr;
                int elem_w = 0;
                if (member_ts && member_ts->UhdmType() == uhdmpacked_array_typespec) {
                    auto pat = any_cast<const UHDM::packed_array_typespec*>(member_ts);
                    if (pat->Elem_typespec())
                        if (auto et = pat->Elem_typespec()->Actual_typespec())
                            if (et->UhdmType() == uhdmstruct_typespec) {
                                inner_st = any_cast<const UHDM::struct_typespec*>(et);
                                elem_w = get_width_from_typespec(et, inst);
                            }
                }
                int idx = 0;
                bool idx_const = true;
                if (memsel->VpiIndex()) {
                    RTLIL::SigSpec is = import_expression(memsel->VpiIndex(), input_mapping);
                    if (is.is_fully_const()) idx = is.as_const().as_int();
                    else idx_const = false;
                }
                // A NON-constant index used to leave idx at 0 and return the
                // slice for element 0 — silently reading the wrong element.
                // CVA6 issue_read_operands' `fwd_i.sbe[idx_hzd_rs1[i]].fu`
                // always read entry 0, so rs1_is_not_csr was wrong whenever the
                // hazard pointed anywhere else.  Decline instead and let the
                // dynamic-index resolver further down handle it.
                if (idx_const && found_member && inner_st &&
                    inner_st->Members() && elem_w > 0) {
                    int field_off = 0, field_w = 0;
                    bool found_field = false;
                    for (int i = (int)inner_st->Members()->size() - 1; i >= 0; i--) {
                        auto m = (*inner_st->Members())[i];
                        int mw = 0;
                        if (auto r = m->Typespec())
                            if (auto a = r->Actual_typespec())
                                mw = get_width_from_typespec(a, inst);
                        if (std::string(m->VpiName()) == field_name) {
                            field_w = mw; found_field = true; break;
                        }
                        field_off += mw;
                    }
                    int total = member_off + idx * elem_w + field_off;
                    if (found_field && field_w > 0 && total + field_w <= base_wire->width) {
                        log("    hier_path: %s.%s[%d].%s -> %s[%d+:%d]\n",
                            base_name.c_str(), member_name.c_str(), idx,
                            field_name.c_str(), base_wire->name.c_str(), total, field_w);
                        return RTLIL::SigSpec(base_wire).extract(total, field_w);
                    }
                }
            }
        }
    }

    // Interface-ARRAY element plain-field access (`man[i].vld` where `man` is an
    // array-of-modports port `man[N-1:0]` and `vld` is a plain interface signal).
    // Path_elems = [bit_select(man[i]), ref_obj(vld)] — the MIRROR of the
    // `bus.field[bits]` case below.  import_port created the per-element wire
    // `\man[i].vld`; resolve directly to it.  Without this the generic walker
    // builds a spurious instance-prefixed `\drv.man[i].vld` that does not match
    // the port wire, so the demultiplexer's `assign man[i].vld = ...` (in a
    // genvar loop) never drives tcb_per[i].vld and the degu SoC's peripheral bus
    // is dead.  Works for both reads and the assign LHS.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pe_af = *uhdm_hier->Path_elems();
        if (pe_af[0]->UhdmType() == uhdmbit_select &&
            pe_af[1]->UhdmType() == uhdmref_obj) {
            auto bs = any_cast<const bit_select*>(pe_af[0]);
            std::string base_name = std::string(bs->VpiName());
            std::string field_name =
                std::string(any_cast<const ref_obj*>(pe_af[1])->VpiName());
            int idx = -1;
            if (bs->VpiIndex()) {
                RTLIL::SigSpec is = import_expression(bs->VpiIndex(), input_mapping);
                if (is.is_fully_const()) idx = is.as_const().as_int();
            }
            if (idx >= 0 && !field_name.empty()) {
                std::string wname =
                    base_name + "[" + std::to_string(idx) + "]." + field_name;
                RTLIL::Wire* w = name_map.count(wname) ? name_map[wname]
                    : module->wire(RTLIL::escape_id(wname));
                if (w) {
                    log("    hier_path: interface-array element field %s -> wire %s\n",
                        wname.c_str(), w->name.c_str());
                    return RTLIL::SigSpec(w);
                }
            }
        }
    }

    // Interface-ARRAY element STRUCT-FIELD access (`man[i].req.lck` where `man`
    // is an array-of-modports port, `req` is a packed-struct interface signal,
    // and `lck` is one of its fields).  Path_elems = [bit_select(man[i]),
    // ref_obj(req), ref_obj(lck)].  import_port created `\man[idx].req` (the
    // whole struct); resolve `man[idx].req` to that wire and slice the field via
    // its struct typespec.  Covers the demultiplexer's `assign man[i].req.<field>
    // = ...` (genvar i folds per gen_req[i]) AND constant reads `m[0].req.<f>`;
    // without it both hit the generic fallback's "Could not resolve struct
    // member access" and stay X (degu SoC bus fabric request routing).
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 3) {
        auto& pe_sf = *uhdm_hier->Path_elems();
        if (pe_sf[0]->UhdmType() == uhdmbit_select &&
            pe_sf[1]->UhdmType() == uhdmref_obj &&
            pe_sf[2]->UhdmType() == uhdmref_obj) {
            auto bs = any_cast<const bit_select*>(pe_sf[0]);
            std::string base  = std::string(bs->VpiName());
            std::string sig   = std::string(any_cast<const ref_obj*>(pe_sf[1])->VpiName());
            std::string field = std::string(any_cast<const ref_obj*>(pe_sf[2])->VpiName());
            int idx = -1;
            if (bs->VpiIndex()) {
                RTLIL::SigSpec is = import_expression(bs->VpiIndex(), input_mapping);
                if (is.is_fully_const()) idx = is.as_const().as_int();
            }
            if (idx >= 0 && !sig.empty() && !field.empty()) {
                std::string wname = base + "[" + std::to_string(idx) + "]." + sig;
                RTLIL::Wire* w = name_map.count(wname) ? name_map[wname]
                    : module->wire(RTLIL::escape_id(wname));
                const UHDM::typespec* ts = nullptr;
                if (iface_signal_struct_ts_.count(wname))
                    ts = iface_signal_struct_ts_[wname];
                // Interface-ARRAY ports often don't resolve interface_type, so
                // the struct typespec wasn't recorded — get it from the `req`
                // ref_obj path element directly (its own typespec, else its
                // Actual_group net's typespec).
                if (!ts) {
                    auto rref = any_cast<const ref_obj*>(pe_sf[1]);
                    if (rref->Typespec() && rref->Typespec()->Actual_typespec())
                        ts = rref->Typespec()->Actual_typespec();
                    if (!ts && rref->Actual_group()) {
                        if (auto nn = dynamic_cast<const UHDM::net*>(rref->Actual_group()))
                            if (nn->Typespec()) ts = nn->Typespec()->Actual_typespec();
                    }
                }
                if (w && !ts) {
                    // Fall back to the wire's own UHDM struct typespec.
                    for (auto& pr : wire_map) {
                        if (pr.second != w) continue;
                        const UHDM::ref_typespec* rt = nullptr;
                        if (auto ln = dynamic_cast<const UHDM::logic_net*>(pr.first)) rt = ln->Typespec();
                        else if (auto no = dynamic_cast<const UHDM::net*>(pr.first)) rt = no->Typespec();
                        if (rt) ts = rt->Actual_typespec();
                        break;
                    }
                }
                if (w && ts) {
                    int off = 0, mw = 0;
                    if (calculate_struct_member_offset(ts, field, inst, off, mw)) {
                        if (off + mw <= w->width) {
                            log("    hier_path: iface-array struct field %s.%s -> \\%s[%d +: %d]\n",
                                wname.c_str(), field.c_str(), wname.c_str(), off, mw);
                            return RTLIL::SigSpec(w, off, mw);
                        }
                        log_warning("UHDM: iface-array struct slice %s.%s out of bounds "
                                    "(off=%d w=%d, wire \\%s width=%d)\n",
                                    wname.c_str(), field.c_str(), off, mw, wname.c_str(), w->width);
                    }
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

    // Packed-struct member PART-SELECT (`dec.fn3[1:0]` where `dec` is a
    // packed-struct net/var flattened to one wire and `fn3` is a member).
    // Path_elems = [ref_obj(base), part_select(field[hi:lo])].  Resolve the
    // member's offset from the base's struct typespec, then apply the
    // field-local part-select on top.  Without this the generic walker below
    // collapses `field[hi:lo]` to a single bit inside a module that HAS an
    // interface port (there the field ref resolves its typespec via the
    // interface's struct copy) — truncating rp32 r5p_lsu's
    // `tcb.req.siz = dec.fn3[1:0]` to 1 bit so a word store wrote only 1 byte.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2 &&
        (*uhdm_hier->Path_elems())[0]->UhdmType() == uhdmref_obj &&
        (*uhdm_hier->Path_elems())[1]->UhdmType() == uhdmpart_select) {
        auto& pe = *uhdm_hier->Path_elems();
        std::string base = std::string(any_cast<const ref_obj*>(pe[0])->VpiName());
        const part_select* ps = any_cast<const part_select*>(pe[1]);
        std::string field = ps ? std::string(ps->VpiName()) : std::string();
        RTLIL::Wire* base_wire = name_map.count(base) ? name_map[base]
                                  : module->wire(RTLIL::escape_id(base));        // Only a genuine packed-struct base (not an interface signal, handled
        // above) with an in-module wire and constant field-local ranges.
        if (base_wire && !field.empty() && !name_map.count(base + "." + field) &&
            ps->Left_range() && ps->Right_range()) {
            const UHDM::ref_typespec* rts = nullptr;
            // The base ref_obj's Actual_group() is often null for a port; use
            // the ref_obj's own Typespec (it names the packed-struct type).
            auto bref = any_cast<const ref_obj*>(pe[0]);
            if (bref->Typespec()) rts = bref->Typespec();
            if (!rts) {
                if (auto a = bref->Actual_group()) {
                    if (auto v = dynamic_cast<const UHDM::variables*>(a)) rts = v->Typespec();
                    else if (auto n = dynamic_cast<const UHDM::net*>(a)) rts = n->Typespec();
                }
            }
            // Inside a module that has an INTERFACE port, Surelog leaves the base
            // ref_obj's typespec/Actual_group null.  Recover the packed-struct
            // type by name from the module's Nets/Variables (rp32 r5p_lsu's
            // `dec` port + interface tcb port).
            if (!rts) {
                auto mi = dynamic_cast<const UHDM::module_inst*>(current_instance);
                if (mi) {
                    if (mi->Variables())
                        for (auto v : *mi->Variables())
                            if (std::string(v->VpiName()) == base && v->Typespec())
                                { rts = v->Typespec(); break; }
                    if (!rts && mi->Nets())
                        for (auto n : *mi->Nets())
                            if (auto nn = dynamic_cast<const UHDM::net*>(n))
                                if (std::string(nn->VpiName()) == base && nn->Typespec())
                                    { rts = nn->Typespec(); break; }
                    if (!rts && mi->Ports())
                        for (auto pp : *mi->Ports())
                            if (std::string(pp->VpiName()) == base) {
                                if (pp->Typespec()) rts = pp->Typespec();
                                break;
                            }
                }
            }            if (rts && rts->Actual_typespec() &&
                (rts->Actual_typespec()->UhdmType() == uhdmstruct_typespec ||
                 rts->Actual_typespec()->UhdmType() == uhdmunion_typespec)) {
                auto ats = rts->Actual_typespec();
                int off = 0, w = 0;
                int saved_ctx = expression_context_width;
                expression_context_width = 0;
                RTLIL::SigSpec ls = import_expression(ps->Left_range(), input_mapping);
                RTLIL::SigSpec rs = import_expression(ps->Right_range(), input_mapping);
                expression_context_width = saved_ctx;
                bool okoff = calculate_struct_member_offset(ats, field, inst, off, w);
                // A packed-ARRAY member (`logic4 [2:0] vector3x4`, element width
                // 4) indexes the part-select in ELEMENT units, so scale the
                // offset/width by the element width and by the array's declared
                // low bound.  A plain vector member (`logic [2:0] fn3`) has no
                // inner dimensions → element width 1 (plain bit indices), which
                // reduces to the previous behaviour.  The member's packed dims
                // come in three shapes: multi-range (`bit [5:0][7:0]` — logic OR
                // bit typespec), Elem_typespec (`logic4 [2:0]`), or a
                // packed_array_typespec (`bit3l_t [0:7][1:0]`) — element width =
                // product of the inner ranges times the Elem_typespec width.
                // An ASCENDING outer range (`bit [0:7][7:0]`) puts the LEFT
                // index at the MSB, so the bit offset counts down from the
                // declared high index instead of up from the low one.
                int elem_w = 1, decl_low = 0, decl_high = 0;
                bool decl_asc = false;
                if (ats->UhdmType() == uhdmstruct_typespec) {
                    auto st = any_cast<const UHDM::struct_typespec*>(ats);
                    if (st->Members())
                        for (auto m : *st->Members()) {
                            if (std::string(m->VpiName()) != field) continue;
                            const UHDM::typespec* mat = nullptr;
                            if (auto mts = m->Typespec()) mat = mts->Actual_typespec();
                            const UHDM::VectorOfrange* mranges = nullptr;
                            const UHDM::ref_typespec* elem_rts = nullptr;
                            if (mat) {
                                if (auto lt = dynamic_cast<const UHDM::logic_typespec*>(mat)) {
                                    mranges = lt->Ranges();
                                    elem_rts = lt->Elem_typespec();
                                } else if (auto bt = dynamic_cast<const UHDM::bit_typespec*>(mat)) {
                                    mranges = bt->Ranges();
                                } else if (auto pt = dynamic_cast<const UHDM::packed_array_typespec*>(mat)) {
                                    mranges = pt->Ranges();
                                    elem_rts = pt->Elem_typespec();
                                } else if (auto at = dynamic_cast<const UHDM::array_typespec*>(mat)) {
                                    // Unpacked array member inside a packed
                                    // struct (`bit [7:0] a [7:0]`) — Yosys
                                    // packs it, indexed like a packed dim.
                                    mranges = at->Ranges();
                                    elem_rts = at->Elem_typespec();
                                }
                            }
                            if (mranges && !mranges->empty()) {
                                auto r0 = (*mranges)[0];
                                RTLIL::SigSpec rl = import_expression(r0->Left_expr(), input_mapping);
                                RTLIL::SigSpec rr = import_expression(r0->Right_expr(), input_mapping);
                                if (rl.is_fully_const() && rr.is_fully_const()) {
                                    int rli = rl.as_const().as_int();
                                    int rri = rr.as_const().as_int();
                                    decl_low = std::min(rli, rri);
                                    decl_high = std::max(rli, rri);
                                    decl_asc = rli < rri;
                                }
                                int inner_w = 1;
                                for (size_t ri = 1; ri < mranges->size(); ri++) {
                                    auto rn = (*mranges)[ri];
                                    RTLIL::SigSpec il = import_expression(rn->Left_expr(), input_mapping);
                                    RTLIL::SigSpec ir = import_expression(rn->Right_expr(), input_mapping);
                                    if (il.is_fully_const() && ir.is_fully_const())
                                        inner_w *= std::abs(il.as_const().as_int() -
                                                            ir.as_const().as_int()) + 1;
                                }
                                elem_w = inner_w;
                                if (elem_rts && elem_rts->Actual_typespec()) {
                                    int ew = get_width_from_typespec(
                                        elem_rts->Actual_typespec(), inst);
                                    if (ew > 0) elem_w *= ew;
                                }
                            }
                            break;
                        }
                }
                if (elem_w < 1) elem_w = 1;
                if (okoff &&
                    w > 0 && ls.is_fully_const() && rs.is_fully_const()) {
                    int l = ls.as_const().as_int(), r = rs.as_const().as_int();
                    int lo = std::min(l, r), hi = std::max(l, r), cnt = hi - lo + 1;
                    int bit_lo = decl_asc ? (decl_high - hi) * elem_w
                                          : (lo - decl_low) * elem_w;
                    int sw = cnt * elem_w;
                    if (bit_lo >= 0 && bit_lo + sw <= w &&
                        off + bit_lo + sw <= base_wire->width) {
                        log("    hier_path: packed-struct %s.%s[%d:%d] (elem_w=%d) -> %s[%d+:%d]\n",
                            base.c_str(), field.c_str(), l, r, elem_w,
                            base_wire->name.c_str(), off + bit_lo, sw);
                        return RTLIL::SigSpec(base_wire).extract(off + bit_lo, sw);
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

                // Struct-typed PARAMETER member access (`Info.x` where `Info` is
                // a parameter of packed-struct type, e.g.
                // `parameter part_info_t Info = part_info_t'(16); ... Info.x`).
                // Parameters have no wire, so resolve the value at compile time
                // and slice the field (OutputSizeWith...).
                {
                    auto base_ref = any_cast<const ref_obj*>(pe2[0]);
                    const UHDM::parameter* param = nullptr;
                    if (auto a = base_ref->Actual_group())
                        if (a->UhdmType() == uhdmparameter)
                            param = any_cast<const UHDM::parameter*>(a);
                    if (param) {
                        RTLIL::SigSpec pval;
                        // Prefer the already-resolved value: param_assigns are
                        // processed in declaration order, so a struct param
                        // `Info` is resolved before `NumScrmblBlocks = Info.x`.
                        RTLIL::IdString pid = RTLIL::escape_id(base);
                        if (module && module->parameter_default_values.count(pid))
                            pval = RTLIL::SigSpec(module->parameter_default_values.at(pid));
                        // Package parameter (`some_package::LovingHome.bunn1_t`):
                        // its resolved value lives in package_parameter_map keyed
                        // by the fully-qualified `pkg::name` (UnionParameter).
                        if (pval.empty() && package_parameter_map.count(base))
                            pval = RTLIL::SigSpec(package_parameter_map.at(base));
                        if (pval.empty()) {
                            std::string vs = std::string(param->VpiValue());
                            if (!vs.empty())
                                pval = RTLIL::SigSpec(extract_const_from_value(vs));
                            else if (param->VpiParent() &&
                                     param->VpiParent()->UhdmType() == uhdmparam_assign) {
                                auto pa = any_cast<const UHDM::param_assign*>(param->VpiParent());
                                if (auto re = dynamic_cast<const UHDM::expr*>(pa->Rhs()))
                                    pval = import_expression(re);
                            }
                        }
                        const UHDM::typespec* ats = nullptr;
                        if (param->Typespec()) ats = param->Typespec()->Actual_typespec();
                        if (!pval.empty() && pval.is_fully_const() && ats &&
                            (ats->UhdmType() == uhdmstruct_typespec ||
                             ats->UhdmType() == uhdmunion_typespec)) {
                            int off = 0, w = 0;
                            if (calculate_struct_member_offset(ats, field, inst, off, w) &&
                                w > 0 && off + w <= pval.size()) {
                                log("    hier_path: struct param %s.%s -> [%d+:%d]\n",
                                    base.c_str(), field.c_str(), off, w);
                                return pval.extract(off, w);
                            }
                        }
                    }
                }

                // Packed-struct member access (`alert_rx_i.ping_p` where
                // `alert_rx_i` is a packed-struct net/var flattened to a single
                // wire).  Resolve the member slice from the base's typespec —
                // this is independent of wire_map population order, so it works
                // in the instance-port-connection context where the generic
                // walker below fails (StructMemberAsModuleInput).
                if (auto base_wire = (name_map.count(base) ? name_map[base]
                                       : module->wire(RTLIL::escape_id(base)))) {
                    auto base_ref = any_cast<const ref_obj*>(pe2[0]);
                    const UHDM::ref_typespec* rts = nullptr;
                    if (auto a = base_ref->Actual_group()) {
                        if (auto v = dynamic_cast<const UHDM::variables*>(a)) rts = v->Typespec();
                        else if (auto n = dynamic_cast<const UHDM::net*>(a)) rts = n->Typespec();
                    }
                    if (rts && rts->Actual_typespec()) {
                        auto ats = rts->Actual_typespec();
                        if (ats->UhdmType() == uhdmstruct_typespec ||
                            ats->UhdmType() == uhdmunion_typespec) {
                            int off = 0, w = 0;
                            if (calculate_struct_member_offset(ats, field, inst, off, w) &&
                                w > 0 && off + w <= base_wire->width) {
                                log("    hier_path: packed-struct %s → %s[%d+:%d]\n",
                                    full.c_str(), base_wire->name.c_str(), off, w);
                                return RTLIL::SigSpec(base_wire).extract(off, w);
                            }
                        }
                    }
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
    // sig[i][j]...[.field[hi:lo]] — element access (any index DYNAMIC, any
    // number of unpacked dims) on a struct array flattened to one wide wire
    // (CVA6 store_buffer `commit_queue_q[ptr].cbo_op`, bht/btb
    // `q[upd_pc][upd_row].sat`): shift the slice out of the flat wire at
    // Σ (idx_k − low_k)·stride_k + field_off.  Constant single-index shapes
    // are handled by earlier branches; without this the read fell through to
    // "Could not resolve" and returned X.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 2) {
        auto& peN = *uhdm_hier->Path_elems();
        // Leading run of bit_selects carrying the BASE name (indices), then
        // an optional trailing ref_obj (field), part_select (field[hi:lo]),
        // or bit_select of a DIFFERENT name (field[i] — bht's
        // `bht_q[index][i].saturation_counter[1]`).
        std::string run_base = peN[0]->UhdmType() == uhdmbit_select
            ? std::string(any_cast<const bit_select*>(peN[0])->VpiName())
            : std::string();
        size_t nsel = 0;
        while (nsel < peN.size() && peN[nsel]->UhdmType() == uhdmbit_select) {
            // Part of the index run when named as the base — either the bare
            // name or the accumulated select text (`bht_q[index]`); a FIELD
            // bit_select carries the field's own name instead.
            std::string bn = std::string(
                any_cast<const bit_select*>(peN[nsel])->VpiName());
            if (!bn.empty() && bn != run_base &&
                bn.rfind(run_base + "[", 0) != 0) break;
            nsel++;
        }
        const bit_select* fbs2 = nullptr;   // trailing field bit_select
        // The tail may name a NESTED field path, not just one field:
        // `mem_n[idx].sbe.rd` (CVA6 scoreboard) is
        // [bit_select, ref_obj(sbe), ref_obj(rd)].  Accept a run of ref_objs,
        // optionally closed by a part_select / bit_select / var_select on the
        // final field.  Restricting the tail to a SINGLE element left the whole
        // path unresolved ("Could not resolve struct member access") and the
        // access silently read/wrote X.
        size_t ntail = peN.size() - nsel;
        bool tail_ok = (nsel == peN.size());
        if (!tail_ok && ntail >= 1) {
            tail_ok = true;
            for (size_t t = nsel; t + 1 < peN.size(); t++)
                if (peN[t]->UhdmType() != uhdmref_obj) { tail_ok = false; break; }
            if (tail_ok) {
                UHDM_OBJECT_TYPE lt = peN[peN.size() - 1]->UhdmType();
                tail_ok = (lt == uhdmref_obj || lt == uhdmpart_select ||
                           lt == uhdmbit_select || lt == uhdmvar_select);
            }
        }
        if (mode_debug)
            log("    Nidx probe: nsel=%zu total=%zu tail_ok=%d run_base='%s'\n",
                nsel, peN.size(), tail_ok ? 1 : 0, run_base.c_str());
        if (nsel >= 1 && tail_ok) {
            const bit_select* bs0 = any_cast<const bit_select*>(peN[0]);
            // Names of every field level in the tail, outermost first, and the
            // LAST element (which alone may carry a part/bit/var select).
            std::vector<std::string> ftail_names;
            for (size_t t = nsel; t < peN.size(); t++)
                ftail_names.push_back(std::string(peN[t]->VpiName()));
            const size_t flast = peN.size() - 1;
            const ref_obj* fr = (nsel < peN.size() &&
                                 peN[flast]->UhdmType() == uhdmref_obj)
                                    ? any_cast<const ref_obj*>(peN[flast]) : nullptr;
            const part_select* fps = (nsel < peN.size() &&
                                      peN[flast]->UhdmType() == uhdmpart_select)
                                         ? any_cast<const part_select*>(peN[flast]) : nullptr;
            if (nsel < peN.size() && peN[flast]->UhdmType() == uhdmbit_select)
                fbs2 = any_cast<const bit_select*>(peN[flast]);
            // Multi-index field select (`tags_q[i].is_page[2-x][0:0]`,
            // CVA6 cva6_tlb page_match): the field is a var_select whose
            // Indexes() carry per-dim selects; the LAST one may be a
            // part_select node.
            const UHDM::var_select* fvs =
                (nsel < peN.size() && peN[nsel]->UhdmType() == uhdmvar_select)
                    ? any_cast<const UHDM::var_select*>(peN[nsel]) : nullptr;
            std::string base_name = bs0 ? std::string(bs0->VpiName()) : std::string();
            RTLIL::Wire* base_flat = (!base_name.empty() && name_map.count(base_name))
                                         ? name_map[base_name]
                                         : (!base_name.empty()
                                               ? module->wire(RTLIL::escape_id(base_name))
                                               : nullptr);
            std::vector<std::pair<int,int>> dims;
            const UHDM::struct_typespec* st = nullptr;
            int elem_w = 0;
            bool geom_ok = base_flat &&
                flat_struct_array_geom(base_name, bs0->Actual_group(), inst,
                                       dims, &st, &elem_w);
            if (mode_debug)
                log("    Nidx probe2: base_flat=%d geom=%d dims=%zu elem_w=%d\n",
                    base_flat ? 1 : 0, geom_ok ? 1 : 0, dims.size(), elem_w);
            if (geom_ok && nsel <= dims.size() && elem_w > 0) {
                // Import the index expressions; note whether ANY is dynamic
                // (all-constant single-index shapes are already handled by
                // earlier branches, but multi-index constants land here too).
                std::vector<RTLIL::SigSpec> idxs;
                bool any_dyn = false, idx_ok = true;
                for (size_t k = 0; k < nsel; k++) {
                    auto bsk = any_cast<const bit_select*>(peN[k]);
                    if (!bsk || !bsk->VpiIndex()) { idx_ok = false; break; }
                    RTLIL::SigSpec ix = import_expression(bsk->VpiIndex(), input_mapping);
                    if (ix.size() == 0) { idx_ok = false; break; }
                    if (!ix.is_fully_const()) any_dyn = true;
                    idxs.push_back(ix);
                }
                // Result width before any field selection: the slice at the
                // deepest indexed level.
                int level_w = elem_w;
                for (size_t k = nsel; k < dims.size(); k++) level_w *= dims[k].first;
                // Field offset/width within the ELEMENT (only meaningful when
                // all dims are consumed).
                int field_offset = 0, field_width = level_w;
                RTLIL::SigSpec dyn_field_idx;      // dynamic field index, if any
                int dyn_field_stride = 0, dyn_field_low = 0;
                bool field_ok = true;
                const UHDM::typespec* field_ts = nullptr;
                if ((fr || fps || fbs2 || fvs) && st && st->Members() && nsel == dims.size()) {
                    field_offset = 0; field_width = 0;
                    bool found_field = false;
                    // Descend EVERY level of the field path (`.sbe.rd`), adding
                    // each level's offset within its own struct.  A single-name
                    // lookup only ever resolved `.field`.
                    const UHDM::struct_typespec* cur_st = st;
                    for (size_t fi = 0; fi < ftail_names.size(); fi++) {
                        const std::string& field_name = ftail_names[fi];
                        if (!cur_st || !cur_st->Members()) { found_field = false; break; }
                        found_field = false;
                        for (int i2 = (int)cur_st->Members()->size() - 1; i2 >= 0; i2--) {
                            auto m = (*cur_st->Members())[i2];
                            int mw = 0;
                            const UHDM::typespec* ats_r = nullptr;
                            if (auto mts = m->Typespec())
                                if (auto ats = mts->Actual_typespec()) {
                                    ats_r = resolve_type_param_typespec(ats, inst);
                                    mw = get_width_from_typespec(ats_r, inst);
                                }
                            if (std::string(m->VpiName()) == field_name) {
                                field_width = mw;
                                field_ts = ats_r;
                                found_field = true;
                                break;
                            }
                            field_offset += mw;
                        }
                        if (!found_field) break;
                        cur_st = field_ts && field_ts->UhdmType() == uhdmstruct_typespec
                                     ? any_cast<const UHDM::struct_typespec*>(field_ts)
                                     : nullptr;
                    }
                    field_ok = found_field && field_width > 0;
                    // Constant part-select window of the field (0-based).
                    if (field_ok && fps && fps->Left_range() && fps->Right_range()) {
                        RTLIL::SigSpec ls = import_expression(fps->Left_range(), input_mapping);
                        RTLIL::SigSpec rs = import_expression(fps->Right_range(), input_mapping);
                        if (ls.is_fully_const() && rs.is_fully_const()) {
                            int l = ls.as_const().as_int(), r = rs.as_const().as_int();
                            int lo = std::min(l, r), w = std::abs(l - r) + 1;
                            if (lo >= 0 && lo + w <= field_width) {
                                field_offset += lo;
                                field_width = w;
                            } else field_ok = false;
                        } else field_ok = false;
                    }
                    // BIT/element select of the field (`.sat_cnt[1]`).
                    if (field_ok && fbs2 && fbs2->VpiIndex()) {
                        RTLIL::SigSpec ixf = import_expression(fbs2->VpiIndex(), input_mapping);
                        if (ixf.is_fully_const()) {
                            int b = ixf.as_const().as_int();
                            if (b >= 0 && b < field_width) {
                                field_offset += b;
                                field_width = 1;
                            } else field_ok = false;
                        } else {
                            // DYNAMIC field index
                            // (`.saturation_counter[read_history[i]]`, CVA6
                            // bht2lvl).  This used to give up, which dropped the
                            // whole continuous assign: `bht_prediction_o[i].taken`
                            // was left UNDRIVEN while its `.valid` sibling was
                            // fine.  The shiftx path below already sums
                            // field_offset + Σ (idx_k − low_k)·stride_k, so the
                            // field index just contributes one more term.
                            // Element stride comes from the field's OUTER packed
                            // dim; the remaining width is one element.
                            int fcount = 0, flow = 0;
                            if (field_ts) {
                                const UHDM::VectorOfrange* rgs = nullptr;
                                if (field_ts->UhdmType() == uhdmlogic_typespec)
                                    rgs = any_cast<const UHDM::logic_typespec*>(field_ts)->Ranges();
                                else if (field_ts->UhdmType() == uhdmpacked_array_typespec)
                                    rgs = any_cast<const UHDM::packed_array_typespec*>(field_ts)->Ranges();
                                if (rgs && !rgs->empty()) {
                                    RTLIL::SigSpec l = import_expression((*rgs)[0]->Left_expr(), input_mapping);
                                    RTLIL::SigSpec rr = import_expression((*rgs)[0]->Right_expr(), input_mapping);
                                    if (l.is_fully_const() && rr.is_fully_const()) {
                                        fcount = std::abs(l.as_const().as_int() - rr.as_const().as_int()) + 1;
                                        flow = std::min(l.as_const().as_int(), rr.as_const().as_int());
                                    }
                                }
                            }
                            if (fcount > 1 && field_width % fcount == 0) {
                                dyn_field_idx = ixf;
                                dyn_field_low = flow;
                                dyn_field_stride = field_width / fcount;
                                field_width = dyn_field_stride;
                            } else field_ok = false;
                        }
                    }
                    // Multi-index select of a MULTI-DIM PACKED field
                    // (`.is_page[2-x][0:0]` — CVA6 cva6_tlb page_match, genvar
                    // indices fold to constants).  Walk the field's declared
                    // packed dims; each Indexes() entry consumes one dim
                    // (stride = product of remaining dim widths), and a
                    // trailing part_select entry windows the current dim.
                    if (field_ok && fvs && fvs->Exprs()) {
                        // Collect (size, low) per dim, outer→inner.
                        std::vector<std::pair<int,int>> fdims;
                        const UHDM::any* cur = field_ts;
                        while (cur) {
                            const UHDM::VectorOfrange* rgs = nullptr;
                            const UHDM::any* next = nullptr;
                            if (cur->UhdmType() == uhdmlogic_typespec) {
                                auto lt2 = any_cast<const UHDM::logic_typespec*>(cur);
                                rgs = lt2->Ranges();
                                if (lt2->Elem_typespec())
                                    next = lt2->Elem_typespec()->Actual_typespec();
                            } else if (cur->UhdmType() == uhdmpacked_array_typespec) {
                                auto pt2 = any_cast<const UHDM::packed_array_typespec*>(cur);
                                rgs = pt2->Ranges();
                                if (pt2->Elem_typespec())
                                    next = pt2->Elem_typespec()->Actual_typespec();
                            }
                            if (rgs)
                                for (auto r : *rgs) {
                                    RTLIL::SigSpec l = import_expression(r->Left_expr(), input_mapping);
                                    RTLIL::SigSpec rr = import_expression(r->Right_expr(), input_mapping);
                                    if (l.is_fully_const() && rr.is_fully_const())
                                        fdims.push_back({std::abs(l.as_const().as_int() -
                                                                  rr.as_const().as_int()) + 1,
                                                         std::min(l.as_const().as_int(),
                                                                  rr.as_const().as_int())});
                                    else { field_ok = false; break; }
                                }
                            cur = next;
                            if (!field_ok) break;
                        }
                        // The walk is only bit-accurate when the collected dims
                        // fully tile the field (innermost dim = bit range).
                        {
                            long prod = 1;
                            for (auto& d : fdims) prod *= d.first;
                            if (prod != field_width) field_ok = false;
                        }
                        size_t di = 0;
                        for (auto sel : *fvs->Exprs()) {
                            if (!field_ok) break;
                            if (di >= fdims.size()) { field_ok = false; break; }
                            // stride of dim di = product of inner dim widths
                            // (in bits within the field)
                            int stride = 1;
                            for (size_t d2 = di + 1; d2 < fdims.size(); d2++)
                                stride *= fdims[d2].first;
                            if (sel->UhdmType() == uhdmpart_select) {
                                auto ps2 = any_cast<const UHDM::part_select*>(sel);
                                RTLIL::SigSpec l = import_expression(ps2->Left_range(), input_mapping);
                                RTLIL::SigSpec rr = import_expression(ps2->Right_range(), input_mapping);
                                if (l.is_fully_const() && rr.is_fully_const()) {
                                    int lo = std::min(l.as_const().as_int(), rr.as_const().as_int());
                                    int w = std::abs(l.as_const().as_int() -
                                                     rr.as_const().as_int()) + 1;
                                    int rel = lo - fdims[di].second;
                                    if (rel >= 0 && rel + w <= fdims[di].first) {
                                        field_offset += rel * stride;
                                        field_width = w * stride;
                                    } else field_ok = false;
                                } else field_ok = false;
                            } else {
                                RTLIL::SigSpec ix = import_expression(
                                    any_cast<const expr*>(sel), input_mapping);
                                if (ix.is_fully_const()) {
                                    int iv = ix.as_const().as_int() - fdims[di].second;
                                    if (iv >= 0 && iv < fdims[di].first) {
                                        field_offset += iv * stride;
                                        field_width = stride;
                                    } else field_ok = false;  // OOB → X fallback
                                } else if (dyn_field_stride == 0) {
                                    // DYNAMIC per-dim index
                                    // (`.saturation_counter[read_history[i]][1]`,
                                    // CVA6 bht2lvl).  Bailing here dropped the
                                    // whole continuous assign, leaving
                                    // `bht_prediction_o[i].taken` UNDRIVEN while
                                    // its `.valid` sibling was fine.  The shiftx
                                    // path below already sums the constant
                                    // field_offset with the index-run terms, so
                                    // this dim just adds one more.  A LATER dim
                                    // can still fold a constant on top, because
                                    // field_offset stays additive.
                                    dyn_field_idx = ix;
                                    dyn_field_low = fdims[di].second;
                                    dyn_field_stride = stride;
                                    field_width = stride;
                                } else field_ok = false;  // two dynamic dims — not handled
                            }
                            di++;
                        }
                    }
                } else if (fr || fps || fbs2 || fvs) {
                    field_ok = false;  // field on a partial (row) slice — bail
                }
                if (idx_ok && field_ok && dyn_field_stride > 0) any_dyn = true;
                if (idx_ok && field_ok && any_dyn) {
                    // strides: stride_k = elem_w * product(sizes[k+1..])
                    std::vector<int> strides(nsel, elem_w);
                    for (size_t k = 0; k < nsel; k++)
                        for (size_t k2 = k + 1; k2 < dims.size(); k2++)
                            strides[k] *= dims[k2].first;
                    int shamt_w = 32;
                    for (auto& ix : idxs) shamt_w = std::max(shamt_w, ix.size() + 6);
                    RTLIL::SigSpec acc = RTLIL::SigSpec(RTLIL::Const(field_offset, shamt_w));
                    for (size_t k = 0; k < nsel; k++) {
                        RTLIL::SigSpec ix = idxs[k];
                        ix.extend_u0(shamt_w, false);
                        if (dims[k].second != 0) {
                            RTLIL::Wire* pw = module->addWire(NEW_ID, shamt_w);
                            module->addSub(NEW_ID, ix,
                                RTLIL::SigSpec(RTLIL::Const(dims[k].second, shamt_w)), pw, true);
                            ix = RTLIL::SigSpec(pw);
                        }
                        RTLIL::Wire* mw2 = module->addWire(NEW_ID, shamt_w);
                        module->addMul(NEW_ID, ix,
                            RTLIL::SigSpec(RTLIL::Const(strides[k], shamt_w)), mw2, true);
                        RTLIL::Wire* aw = module->addWire(NEW_ID, shamt_w);
                        module->addAdd(NEW_ID, acc, RTLIL::SigSpec(mw2), aw, true);
                        acc = RTLIL::SigSpec(aw);
                    }
                    if (dyn_field_stride > 0) {
                        RTLIL::SigSpec fx = dyn_field_idx;
                        fx.extend_u0(shamt_w, false);
                        if (dyn_field_low != 0) {
                            RTLIL::Wire* pw = module->addWire(NEW_ID, shamt_w);
                            module->addSub(NEW_ID, fx,
                                RTLIL::SigSpec(RTLIL::Const(dyn_field_low, shamt_w)), pw, true);
                            fx = RTLIL::SigSpec(pw);
                        }
                        RTLIL::Wire* fm = module->addWire(NEW_ID, shamt_w);
                        module->addMul(NEW_ID, fx,
                            RTLIL::SigSpec(RTLIL::Const(dyn_field_stride, shamt_w)), fm, true);
                        RTLIL::Wire* fa = module->addWire(NEW_ID, shamt_w);
                        module->addAdd(NEW_ID, acc, RTLIL::SigSpec(fm), fa, true);
                        acc = RTLIL::SigSpec(fa);
                    }
                    RTLIL::Wire* out = module->addWire(NEW_ID, field_width);
                    RTLIL::Cell* sx = module->addCell(NEW_ID, ID($shiftx));
                    sx->setParam(ID::A_SIGNED, 0);
                    sx->setParam(ID::B_SIGNED, 0);
                    sx->setParam(ID::A_WIDTH, base_flat->width);
                    sx->setParam(ID::B_WIDTH, shamt_w);
                    sx->setParam(ID::Y_WIDTH, field_width);
                    sx->setPort(ID::A, RTLIL::SigSpec(base_flat));
                    sx->setPort(ID::B, acc);
                    sx->setPort(ID::Y, out);
                    add_src_attribute(sx->attributes, uhdm_hier);
                    log("    hier_path: dynamic %s[%zu dims] -> shiftx (w=%d)\n",
                        base_name.c_str(), nsel, field_width);
                    return RTLIL::SigSpec(out);
                }
                if (idx_ok && field_ok && !any_dyn && nsel == dims.size() &&
                    (nsel >= 2 || fvs)) {
                    // All-constant MULTI-index element (or field) read: plain
                    // slice of the flat wire.
                    int off = field_offset;
                    std::vector<int> strides(nsel, elem_w);
                    for (size_t k = 0; k < nsel; k++)
                        for (size_t k2 = k + 1; k2 < dims.size(); k2++)
                            strides[k] *= dims[k2].first;
                    bool in_range = true;
                    for (size_t k = 0; k < nsel; k++) {
                        int iv = idxs[k].as_const().as_int();
                        if (iv < dims[k].second ||
                            iv >= dims[k].second + dims[k].first) { in_range = false; break; }
                        off += (iv - dims[k].second) * strides[k];
                    }
                    if (in_range && off >= 0 && off + field_width <= base_flat->width) {
                        log("    hier_path: const multi-index %s -> [%d+:%d]\n",
                            base_name.c_str(), off, field_width);
                        return RTLIL::SigSpec(base_flat).extract(off, field_width);
                    }
                }
            }
        }
    }

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
                
                // Also check VpiFullName of the ref_obj itself (fallback).
                // NEVER for a struct-FIELD ref (Actual_group is a
                // typespec_member): its VpiFullName is the bare field name
                // hoisted to module scope (`work@t.sat`), which can COLLIDE
                // with a same-named local variable — bht's `.sat` field read
                // resolved to the local `sat` wire and corrupted the update.
                // The guard above was documented but never implemented: a
                // struct-FIELD ref still fell through here, and CVA6
                // instr_queue has BOTH a `.instr`/`.cf` struct field and
                // module-level wires named `instr`/`cf`.  The continuous
                // assigns `instr_data_in[i].instr = instr[...]` then resolved
                // their LHS to the SOURCE array \instr, leaving instr_data_in
                // undriven and multi-driving \instr -- 140 driver-driver
                // conflicts that opt_clean resolved to constants, so the whole
                // frontend fetch datapath came out zero.
                bool field_ref = ref->Actual_group() &&
                                 ref->Actual_group()->UhdmType() == uhdmtypespec_member;
                std::string_view ref_full_name = field_ref ? std::string_view()
                                                           : ref->VpiFullName();
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

    // Unpacked-array-of-struct element + SCALAR struct member: `arr[i].field`
    // where `field` is a plain (non-array) struct member.  Path_elems =
    // [bit_select(arr[i]), ref_obj(field)] (NestedPatternPassedAsPort:
    // `region_attrs_i[0].phase`).  Resolves to
    //   base_wire[ (i - outer_low)*elem_w + field_off +: field_w ].
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2 &&
        (*uhdm_hier->Path_elems())[0]->UhdmType() == uhdmbit_select &&
        (*uhdm_hier->Path_elems())[1]->UhdmType() == uhdmref_obj) {
        auto& pe = *uhdm_hier->Path_elems();
        const bit_select* bs = any_cast<const bit_select*>(pe[0]);
        std::string base_name = std::string(bs->VpiName());
        std::string field_name = std::string(pe[1]->VpiName());
        if (base_name != field_name && bs->VpiIndex()) {
            RTLIL::Wire* base_wire = name_map.count(base_name)
                ? name_map[base_name] : module->wire(RTLIL::escape_id(base_name));
            // Find the array_typespec for `base_name`.  The bit_select's
            // Actual_group is the array_var on a local variable, but for a
            // flattened struct-array PORT it is null — fall back to the port/net
            // typespec from the enclosing module instance.
            const UHDM::array_typespec* ats = nullptr;
            if (auto av = dynamic_cast<const UHDM::array_var*>(bs->Actual_group())) {
                if (av->Typespec())
                    if (auto a0 = av->Typespec()->Actual_typespec())
                        if (a0->UhdmType() == uhdmarray_typespec)
                            ats = any_cast<const UHDM::array_typespec*>(a0);
            }
            if (!ats) {
                if (auto mi = dynamic_cast<const UHDM::module_inst*>(inst)) {
                    auto ts_of = [&](const UHDM::ref_typespec* rt) -> const UHDM::array_typespec* {
                        if (rt && rt->Actual_typespec() &&
                            rt->Actual_typespec()->UhdmType() == uhdmarray_typespec)
                            return any_cast<const UHDM::array_typespec*>(rt->Actual_typespec());
                        return nullptr;
                    };
                    if (mi->Ports())
                        for (auto p : *mi->Ports())
                            if (std::string(p->VpiName()) == base_name && p->Typespec())
                                { ats = ts_of(p->Typespec()); break; }
                    if (!ats && mi->Nets())
                        for (auto n : *mi->Nets())
                            if (std::string(n->VpiName()) == base_name && n->Typespec())
                                { ats = ts_of(n->Typespec()); break; }
                }
            }
            const UHDM::struct_typespec* st = nullptr;
            int outer_low = 0;
            if (ats) {
                if (ats->Ranges() && !ats->Ranges()->empty()) {
                    auto r = (*ats->Ranges())[0];
                    RTLIL::SigSpec l = import_expression(r->Left_expr(), input_mapping);
                    RTLIL::SigSpec rr = import_expression(r->Right_expr(), input_mapping);
                    if (l.is_fully_const() && rr.is_fully_const())
                        outer_low = std::min(l.as_const().as_int(), rr.as_const().as_int());
                }
                if (ats->Elem_typespec())
                    if (auto et = ats->Elem_typespec()->Actual_typespec())
                        if (et->UhdmType() == uhdmstruct_typespec)
                            st = any_cast<const UHDM::struct_typespec*>(et);
            }
            RTLIL::SigSpec idx = import_expression(bs->VpiIndex(), input_mapping);
            if (base_wire && st && st->Members() && idx.is_fully_const()) {
                int i_idx = idx.as_const().as_int();
                int elem_w = 0;
                for (auto m : *st->Members())
                    if (auto mts = m->Typespec())
                        if (auto a = mts->Actual_typespec())
                            elem_w += get_width_from_typespec(a, inst);
                // field offset from struct LSB (last member = LSB).
                int field_off = 0, field_w = 0; bool found = false;
                for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                    auto m = (*st->Members())[i];
                    int mw = 0;
                    if (auto mts = m->Typespec())
                        if (auto a = mts->Actual_typespec())
                            mw = get_width_from_typespec(a, inst);
                    if (std::string(m->VpiName()) == field_name) {
                        field_w = mw; found = true; break;
                    }
                    field_off += mw;
                }
                if (found && field_w > 0 && elem_w > 0) {
                    int off = (i_idx - outer_low) * elem_w + field_off;
                    if (off >= 0 && off + field_w <= base_wire->width) {
                        log("    hier_path: %s[%d].%s → %s[%d+:%d]\n",
                            base_name.c_str(), i_idx, field_name.c_str(),
                            base_wire->name.c_str(), off, field_w);
                        return RTLIL::SigSpec(base_wire).extract(off, field_w);
                    }
                }
            }
        }
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
                    RTLIL::Wire* base_flat_wire = name_map.count(base_name)
                                                    ? name_map[base_name]
                                                    : module->wire(RTLIL::escape_id(base_name));

                    // The element value: a dedicated per-element wire (UNPACKED
                    // array of structs) or an element_width-bit slice of the
                    // single packed wire (PACKED array of structs).
                    RTLIL::SigSpec element_sig;
                    const UHDM::struct_typespec* st = nullptr;

                    if (name_map.count(elem_name)) {
                        element_sig = RTLIL::SigSpec(name_map[elem_name]);
                        // struct typespec via the inner struct_net of the array_net.
                        if (base_flat_wire) {
                            for (auto& kv : wire_map) {
                                if (kv.second != base_flat_wire) continue;
                                if (auto sn = dynamic_cast<const UHDM::struct_net*>(kv.first))
                                    if (auto rts = sn->Typespec())
                                        if (auto ats = rts->Actual_typespec())
                                            if (ats->UhdmType() == uhdmstruct_typespec)
                                                st = any_cast<const UHDM::struct_typespec*>(ats);
                                if (st) break;
                            }
                        }
                    } else if (base_flat_wire) {
                        // PACKED array of structs (packed_array_var): the element
                        // type is the first struct_var in Elements().
                        // ExpressionInIndex: `sram_otp_key_o[0].nonce`.
                        if (auto pav = dynamic_cast<const UHDM::packed_array_var*>(bs->Actual_group())) {
                            if (pav->Elements() && !pav->Elements()->empty())
                                if (auto sv = dynamic_cast<const UHDM::struct_var*>(pav->Elements()->at(0)))
                                    if (auto rts = sv->Typespec())
                                        if (auto ats = rts->Actual_typespec())
                                            if (ats->UhdmType() == uhdmstruct_typespec)
                                                st = any_cast<const UHDM::struct_typespec*>(ats);
                            // Typedef'd packed array (`typedef a[5:0] b`): Elements()
                            // is empty; resolve the struct via the packed_array_typespec
                            // Elem_typespec chain (TypedefPackedDimensions).
                            if (!st && pav->Typespec())
                                if (auto pts = pav->Typespec()->Actual_typespec())
                                    if (pts->UhdmType() == uhdmpacked_array_typespec)
                                        if (auto pat = any_cast<const UHDM::packed_array_typespec*>(pts))
                                            if (pat->Elem_typespec())
                                                if (auto et = pat->Elem_typespec()->Actual_typespec())
                                                    if (et->UhdmType() == uhdmstruct_typespec)
                                                        st = any_cast<const UHDM::struct_typespec*>(et);
                        }
                        // Typedef'd *unpacked* array (`typedef a b[5:0]`): `c` is an
                        // array_var whose array_typespec flattens to the same wide
                        // wire — resolve the struct via array_typespec Elem_typespec
                        // (TypedefVariableDimensions).
                        if (!st)
                            if (auto av = dynamic_cast<const UHDM::array_var*>(bs->Actual_group()))
                                if (av->Typespec())
                                    if (auto ats = av->Typespec()->Actual_typespec())
                                        if (ats->UhdmType() == uhdmarray_typespec)
                                            if (auto at = any_cast<const UHDM::array_typespec*>(ats))
                                                if (at->Elem_typespec())
                                                    if (auto et = at->Elem_typespec()->Actual_typespec())
                                                        if (et->UhdmType() == uhdmstruct_typespec)
                                                            st = any_cast<const UHDM::struct_typespec*>(et);
                        if (st) {
                            int elem_w = get_width_from_typespec(st, inst);
                            int off = elem_idx * elem_w;
                            if (elem_w > 0 && off >= 0 && off + elem_w <= base_flat_wire->width)
                                element_sig = RTLIL::SigSpec(base_flat_wire).extract(off, elem_w);
                        }
                    }

                    if (!element_sig.empty() && st && st->Members()) {
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
                            field_offset + field_width <= element_sig.size()) {
                            return element_sig.extract(field_offset, field_width);
                        }
                    }
                }
            }
        }
    }

    // PACKED array of structs declared through a NET whose typespec is a
    // packed_array_typespec (`typedef entry_t [N-1:0] dir_t; dir_t dir_q;` —
    // hpdcache_flush's flush_dir_q): the branches above discover the element
    // struct only from packed_array_var/array_var Actual_groups or per-element
    // wires, so both the genvar read `dir_q[gen_i].nline` and the DYNAMIC read
    // `dir_q[ack_ptr].nline` fell through to X (flush_ack_nline_o undriven,
    // 298/300 co-sim divergences).  Resolve the struct via the net/variable
    // typespec and slice — constant index directly, dynamic index through a
    // $shiftx of the flat wire.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() == 2) {
        auto& pePN = *uhdm_hier->Path_elems();
        if (pePN[0]->UhdmType() == uhdmbit_select &&
            pePN[1]->UhdmType() == uhdmref_obj) {
            const bit_select* bs = any_cast<const bit_select*>(pePN[0]);
            const ref_obj*    fr = any_cast<const ref_obj*>(pePN[1]);
            std::string base_name = bs ? std::string(bs->VpiName()) : "";
            std::string field_name = fr ? std::string(fr->VpiName()) : "";
            RTLIL::Wire* bwire = name_map.count(base_name)
                ? name_map[base_name]
                : module->wire(RTLIL::escape_id(base_name));
            if (bs && fr && bs->VpiIndex() && bwire &&
                base_name != field_name && !field_name.empty()) {
                // Element struct + outer range from a packed_array_typespec
                // reached through the Actual_group's or the instance
                // net/variable's typespec.
                const UHDM::struct_typespec* st = nullptr;
                int outer_low = 0, outer_high = 0;
                bool ascending = false, have_range = false;
                auto try_pat = [&](const UHDM::typespec* t) {
                    if (!t || t->UhdmType() != uhdmpacked_array_typespec) return;
                    auto pat = any_cast<const UHDM::packed_array_typespec*>(t);
                    if (pat->Elem_typespec())
                        if (auto et = pat->Elem_typespec()->Actual_typespec())
                            if (et->UhdmType() == uhdmstruct_typespec)
                                st = any_cast<const UHDM::struct_typespec*>(et);
                    if (st && pat->Ranges() && !pat->Ranges()->empty()) {
                        auto r0 = (*pat->Ranges())[0];
                        if (r0->Left_expr() && r0->Right_expr()) {
                            RTLIL::SigSpec l = import_expression(r0->Left_expr());
                            RTLIL::SigSpec r = import_expression(r0->Right_expr());
                            if (l.is_fully_const() && r.is_fully_const()) {
                                int li = l.as_const().as_int();
                                int ri = r.as_const().as_int();
                                outer_low = std::min(li, ri);
                                outer_high = std::max(li, ri);
                                ascending = li < ri;
                                have_range = true;
                            }
                        }
                    }
                };
                // UNPACKED array_var of (type-param'd) structs: the element
                // struct lives on the inner var (vpiReg) and the unpacked dim
                // on the var's own Ranges() — same shape as the whole-element
                // read fix (`hpdcache_mem_resp_r_t mem_resp_read_arb [1:0]`,
                // then `arb[0].id`-style field reads).
                auto try_av = [&](const UHDM::any* o) {
                    auto av = dynamic_cast<const UHDM::array_var*>(o);
                    if (!av || st) return;
                    const UHDM::ref_typespec* irt = nullptr;
                    if (av->Variables() && !av->Variables()->empty())
                        irt = (*av->Variables())[0]->Typespec();
                    if (irt && irt->Actual_typespec()) {
                        const UHDM::typespec* rts2 = resolve_type_param_typespec(
                            irt->Actual_typespec(), inst);
                        if (rts2 && rts2->UhdmType() == uhdmstruct_typespec)
                            st = any_cast<const UHDM::struct_typespec*>(rts2);
                    }
                    if (st && av->Ranges() && !av->Ranges()->empty()) {
                        auto r0 = (*av->Ranges())[0];
                        if (r0->Left_expr() && r0->Right_expr()) {
                            RTLIL::SigSpec l = import_expression(r0->Left_expr());
                            RTLIL::SigSpec r = import_expression(r0->Right_expr());
                            if (l.is_fully_const() && r.is_fully_const()) {
                                int li = l.as_const().as_int();
                                int ri = r.as_const().as_int();
                                outer_low = std::min(li, ri);
                                outer_high = std::max(li, ri);
                                ascending = li < ri;
                                have_range = true;
                            }
                        }
                    }
                };
                if (auto e = dynamic_cast<const UHDM::expr*>(bs->Actual_group()))
                    if (e->Typespec()) try_pat(e->Typespec()->Actual_typespec());
                if (!st) try_av(bs->Actual_group());
                if (!st) {
                    auto mi = dynamic_cast<const UHDM::module_inst*>(
                        inst ? inst : (const UHDM::scope*)current_instance);
                    if (mi && mi->Nets())
                        for (auto n : *mi->Nets())
                            if (std::string(n->VpiName()) == base_name &&
                                n->Typespec()) {
                                try_pat(n->Typespec()->Actual_typespec());
                                break;
                            }
                    if (mi && !st && mi->Variables())
                        for (auto v : *mi->Variables())
                            if (std::string(v->VpiName()) == base_name) {
                                if (v->Typespec())
                                    try_pat(v->Typespec()->Actual_typespec());
                                try_av(v);
                                break;
                            }
                }
                if (st && st->Members()) {
                    int elem_w = get_width_from_typespec(st, inst);
                    int field_off = 0, field_w = 0;
                    bool found = false;
                    for (int i = (int)st->Members()->size() - 1; i >= 0; i--) {
                        auto m = (*st->Members())[i];
                        int mw = 0;
                        if (auto mts = m->Typespec())
                            if (auto a = mts->Actual_typespec())
                                mw = get_width_from_typespec(a, inst);
                        if (std::string(m->VpiName()) == field_name) {
                            field_w = mw; found = true; break;
                        }
                        field_off += mw;
                    }
                    if (found && field_w > 0 && elem_w > 0 &&
                        elem_w * ((bwire->width) / elem_w) == bwire->width) {
                        RTLIL::SigSpec idx_s =
                            import_expression(bs->VpiIndex(), input_mapping);
                        if (idx_s.is_fully_const()) {
                            int k = idx_s.as_const().as_int();
                            int pos = ascending ? (outer_high - k)
                                                : (k - outer_low);
                            if (!have_range) pos = k;
                            int off = pos * elem_w + field_off;
                            if (pos >= 0 && off + field_w <= bwire->width) {
                                log("    hier_path: %s[%d].%s (packed net) -> "
                                    "[%d+:%d]\n", base_name.c_str(), k,
                                    field_name.c_str(), off, field_w);
                                return RTLIL::SigSpec(bwire)
                                    .extract(off, field_w);
                            }
                        } else if (idx_s.size() > 0) {
                            RTLIL::SigSpec sh = idx_s;
                            sh.extend_u0(32, false);
                            if (have_range && ascending)
                                sh = module->Sub(NEW_ID,
                                    RTLIL::SigSpec(RTLIL::Const(outer_high, 32)),
                                    sh, false);
                            else if (have_range && outer_low != 0)
                                sh = module->Sub(NEW_ID, sh,
                                    RTLIL::Const(outer_low, 32), false);
                            if (elem_w > 1)
                                sh = module->Mul(NEW_ID, sh,
                                    RTLIL::Const(elem_w, 32), false);
                            if (field_off > 0)
                                sh = module->Add(NEW_ID, sh,
                                    RTLIL::Const(field_off, 32), false);
                            RTLIL::Wire* rw = module->addWire(NEW_ID, field_w);
                            module->addShiftx(NEW_ID, RTLIL::SigSpec(bwire),
                                              sh, RTLIL::SigSpec(rw));
                            log("    hier_path: %s[dyn].%s (packed net) -> "
                                "$shiftx %d bits\n", base_name.c_str(),
                                field_name.c_str(), field_w);
                            return RTLIL::SigSpec(rw);
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
        // `a.b[base +: width]` / `a.b[base -: width]` — INDEXED part-select of a
        // struct MEMBER.  Path_elems: [ref_obj(struct), indexed_part_select(member)].
        // Resolve the member's offset within the struct wire, then slice.
        // (IndexedPartSelectOfMember `a.b[0+:8]` — the struct-member-access
        // fallback couldn't parse `b[0+:8]`.)
        if (pe_ips[0]->UhdmType() == uhdmref_obj &&
            pe_ips[1]->UhdmType() == uhdmindexed_part_select) {
            const ref_obj* ro = any_cast<const ref_obj*>(pe_ips[0]);
            const indexed_part_select* ips = any_cast<const indexed_part_select*>(pe_ips[1]);
            if (ro && ips && ips->Base_expr() && ips->Width_expr()) {
                std::string struct_name = std::string(ro->VpiName());
                std::string field_name = std::string(ips->VpiName());
                RTLIL::Wire* base_wire = name_map.count(struct_name)
                    ? name_map[struct_name]
                    : module->wire(RTLIL::escape_id(struct_name));
                // Struct typespec via the ref_obj's resolved variable.
                const UHDM::typespec* ts = nullptr;
                if (auto actual = ro->Actual_group())
                    if (auto e = dynamic_cast<const UHDM::expr*>(actual))
                        if (auto rt = e->Typespec())
                            ts = rt->Actual_typespec();
                int field_offset = 0, field_width = 0;
                if (base_wire && ts &&
                        calculate_struct_member_offset(ts, field_name, inst,
                                                       field_offset, field_width)) {
                    RTLIL::SigSpec base_sig = import_expression(ips->Base_expr(), input_mapping);
                    RTLIL::SigSpec width_sig = import_expression(ips->Width_expr(), input_mapping);
                    if (base_sig.is_fully_const() && width_sig.is_fully_const()) {
                        int b = base_sig.as_const().as_int();
                        int w = width_sig.as_const().as_int();
                        bool pos = ips->VpiIndexedPartSelectType() == vpiPosIndexed;
                        int low = field_offset + (pos ? b : (b - w + 1));
                        if (w > 0 && low >= 0 && low + w <= base_wire->width)
                            return RTLIL::SigSpec(base_wire).extract(low, w);
                    }
                }
            }
        }
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
                    else if (auto po = dynamic_cast<const UHDM::port*>(kv.first))
                        rts = po->Typespec();
                    if (rts) {
                        if (auto ats = rts->Actual_typespec()) {
                            // A `parameter type` typed net keeps the
                            // DECLARATION DEFAULT — substitute the instance
                            // binding (CVA6 cva6_ptw shared_tlb_update_o:
                            // tlb_update_cva6_t; without this the [x][y]
                            // indices of .is_page[x][y] were DROPPED by the
                            // string fallback and the write hit the whole
                            // field).
                            const UHDM::typespec* r =
                                resolve_type_param_typespec(ats, inst);
                            if (r && r->UhdmType() == uhdmstruct_typespec)
                                st = any_cast<const UHDM::struct_typespec*>(r);
                        }
                    }
                    if (st) break;
                }
                // Base ref's own typespec as a fallback (the wire_map object
                // may be a port with no typespec).
                if (!st && base_ref->Actual_group()) {
                    if (auto e = dynamic_cast<const UHDM::expr*>(base_ref->Actual_group())) {
                        if (e->Typespec() && e->Typespec()->Actual_typespec()) {
                            const UHDM::typespec* r = resolve_type_param_typespec(
                                e->Typespec()->Actual_typespec(), inst);
                            if (r && r->UhdmType() == uhdmstruct_typespec)
                                st = any_cast<const UHDM::struct_typespec*>(r);
                        }
                    }
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
                            mts_actual = resolve_type_param_typespec(ats, inst);
                            mw = get_width_from_typespec(mts_actual, inst);
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
                                int sub_width = slice_width / rsize;
                                auto idx_expr = (*vs->Exprs())[d];
                                // An index that is itself a PART-SELECT (`key[0][31:0]`
                                // — PartSelectInFor) selects a contiguous RANGE of
                                // this dimension's elements rather than one, so its
                                // slice keeps `count` elements at the low element's
                                // position.
                                if (idx_expr->UhdmType() == uhdmpart_select) {
                                    auto ps = any_cast<const part_select*>(idx_expr);
                                    RTLIL::SigSpec pls = import_expression(ps->Left_range(), input_mapping);
                                    RTLIL::SigSpec prs = import_expression(ps->Right_range(), input_mapping);
                                    if (!pls.is_fully_const() || !prs.is_fully_const()) { ok = false; break; }
                                    int plo = std::min(pls.as_int(), prs.as_int());
                                    int phi = std::max(pls.as_int(), prs.as_int());
                                    int lowpos = rasc ? (rr - phi) : (plo - rr);
                                    abs_start += lowpos * sub_width;
                                    slice_width = (phi - plo + 1) * sub_width;
                                } else if (idx_expr->UhdmType() == uhdmindexed_part_select) {
                                    // `key[0][i*32 +: 32]` (the loop var `i` is
                                    // const after unrolling) — IndexedPartSelectInFor.
                                    auto ips = any_cast<const indexed_part_select*>(idx_expr);
                                    RTLIL::SigSpec bs = import_expression(ips->Base_expr(), input_mapping);
                                    RTLIL::SigSpec ws = import_expression(ips->Width_expr(), input_mapping);
                                    if (!bs.is_fully_const() || !ws.is_fully_const()) { ok = false; break; }
                                    int base = bs.as_int(), w = ws.as_int();
                                    int e_lo, e_hi;
                                    if (ips->VpiIndexedPartSelectType() == 1) {  // +:
                                        e_lo = base; e_hi = base + w - 1;
                                    } else {                                     // -:
                                        e_hi = base; e_lo = base - w + 1;
                                    }
                                    int p1 = rasc ? (rr - e_lo) : (e_lo - rr);
                                    int p2 = rasc ? (rr - e_hi) : (e_hi - rr);
                                    abs_start += std::min(p1, p2) * sub_width;
                                    slice_width = w * sub_width;
                                } else {
                                    RTLIL::SigSpec idx_sig =
                                        import_expression(idx_expr, input_mapping);
                                    if (!idx_sig.is_fully_const()) { ok = false; break; }
                                    int idx = idx_sig.as_const().as_int();
                                    int pos = rasc ? (rr - idx) : (idx - rr);
                                    abs_start += pos * sub_width;
                                    slice_width = sub_width;
                                }
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
        
        // Same gen-scope qualification as the resolver below: a struct
        // declared inside a generate block is registered as
        // `<gen_scope>.<name>`.
        std::string base_key = base_name;
        if (!name_map.count(base_key)) {
            const std::string gs = get_current_gen_scope();
            if (!gs.empty() && name_map.count(gs + "." + base_name))
                base_key = gs + "." + base_name;
        }
        // Check if the base wire exists
        if (name_map.count(base_key)) {
            RTLIL::Wire* base_wire = name_map[base_key];
            
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

                // Walk a struct/union typespec's members for `member_name`.
                auto find_member_slice = [&](const UHDM::typespec* ts,
                                             int& bit_offset,
                                             int& member_width) -> bool {
                    if (!ts) return false;
                    bool is_union = ts->UhdmType() == uhdmunion_typespec;
                    if (!is_union && ts->UhdmType() != uhdmstruct_typespec)
                        return false;
                    const VectorOftypespec_member* members = is_union
                        ? any_cast<const UHDM::union_typespec*>(ts)->Members()
                        : any_cast<const UHDM::struct_typespec*>(ts)->Members();
                    if (!members) return false;
                    bit_offset = 0;
                    // Iterate members in reverse (MSB to LSB for packed structs)
                    for (int i = members->size() - 1; i >= 0; i--) {
                        auto member_spec = (*members)[i];
                        int w = 1;
                        if (auto member_ts = member_spec->Typespec()) {
                            if (auto actual_ts = member_ts->Actual_typespec())
                                w = get_width_from_typespec(actual_ts, inst);
                        } else {
                            w = get_width(member_spec, inst);
                        }
                        if (std::string(member_spec->VpiName()) == member_name) {
                            member_width = w;
                            return true;
                        }
                        if (!is_union) bit_offset += w;
                    }
                    return false;
                };

                int mem_off = 0, mem_w = 0;
                bool found_member = false;
                if (base_ref_typespec) {
                    base_typespec = base_ref_typespec->Actual_typespec();
                    found_member = find_member_slice(base_typespec, mem_off, mem_w);
                    if (!found_member && mode_debug)
                        log("    Base wire typespec is not a struct/union (UhdmType=%s)\n",
                            base_typespec ? UhdmName(base_typespec->UhdmType()).c_str() : "null");
                } else if (mode_debug) {
                    log("    Base wire has no typespec\n");
                }

                // `parameter type` port/net: the base's own typespec is the
                // UNBOUND declaration default (`parameter type exception_t =
                // logic` → a plain logic_typespec), so the member walk above
                // fails even though the wire has its bound width.  Recover the
                // BOUND struct from the elaborated instance's type parameters,
                // disambiguated by total width == wire width (branch_unit's
                // exception_t(203) and bp_resolve_t(134) both contain `valid`).
                // Without this the whole struct-field write stream degraded to
                // 1-bit-x actions and `update 1'x $0\<sig>` — 12 undriven
                // struct outputs across CVA6 (branch_unit resolved_branch_o /
                // branch_exception_o, decoder instruction_o, mmu icache_areq_o,
                // wt_dcache_ctrl req_port_o, cvxif drivers, btb_d).
                if (!found_member) {
                    if (auto mi = dynamic_cast<const UHDM::module_inst*>(current_instance)) {
                        if (mi->Parameters()) {
                            for (auto p : *mi->Parameters()) {
                                auto tp = dynamic_cast<const UHDM::type_parameter*>(p);
                                if (!tp || !tp->Typespec()) continue;
                                auto ats = tp->Typespec()->Actual_typespec();
                                if (!ats) continue;
                                if (ats->UhdmType() != uhdmstruct_typespec &&
                                    ats->UhdmType() != uhdmunion_typespec) continue;
                                int total = get_width_from_typespec(ats, inst);
                                if (total != base_wire->width) continue;
                                if (find_member_slice(ats, mem_off, mem_w)) {
                                    if (mode_debug)
                                        log("    Resolved '%s.%s' via type-parameter %s (bound struct, width %d)\n",
                                            base_name.c_str(), member_name.c_str(),
                                            std::string(tp->VpiName()).c_str(), total);
                                    found_member = true;
                                    break;
                                }
                            }
                        }
                    }
                }

                if (found_member) {
                    if (mode_debug)
                        log("    Found packed member: offset=%d, width=%d\n", mem_off, mem_w);
                    return RTLIL::SigSpec(base_wire, mem_off, mem_w);
                }
            } else if (mode_debug) {
                log("    Could not find UHDM object for base wire '%s'\n", base_name.c_str());
            }
        }
        }  // End of single-level struct member handling
    }

    // Nested struct-field access ending in a PART-SELECT with computed bounds:
    //   sub.req.adr[ADR-1 : sub.CFG_BUS_OFF]          (r5p_soc_memory address),
    //   sub.req.byteena[off +: n]                     (indexed form),
    //   sub.req_dly[DLY].adr[$clog2(BYT)-1:0]         (array-indexed element;
    //                                                  tcb_lite_lib_logsize2byteena).
    // Path_elems: struct-member ref_objs and/or array bit_selects, then a
    // part_select / indexed_part_select.  The size()==3 handler above only fires
    // for a LOCAL struct wire whose base name is a plain wire; here the base is an
    // interface signal flattened to e.g. `sub.req_dly`, so the slice would
    // otherwise fall through to the "could not resolve" fallback and collapse to
    // X.  The bounds may be non-constant expressions (a $clog2 module localparam,
    // an interface localparam) that import_expression folds.
    if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 2) {
        auto& pe = *uhdm_hier->Path_elems();
        bool is_ps  = pe.back()->UhdmType() == uhdmpart_select;
        bool is_ips = pe.back()->UhdmType() == uhdmindexed_part_select;
        bool last_ref = pe.back()->UhdmType() == uhdmref_obj;
        bool is_bitsel = pe.back()->UhdmType() == uhdmbit_select;
        if (is_ps || is_ips || last_ref || is_bitsel) {
            bool ok_segs = true;
            bool has_bit_select = false;
            std::vector<std::string> names;
            std::vector<const UHDM::expr*> seg_idx;  // array index per segment
            for (size_t i = 0; i + 1 < pe.size(); i++) {
                if (pe[i]->UhdmType() == uhdmref_obj) {
                    names.push_back(std::string(pe[i]->VpiName()));
                    seg_idx.push_back(nullptr);
                } else if (pe[i]->UhdmType() == uhdmbit_select) {
                    has_bit_select = true;
                    auto bs = any_cast<const bit_select*>(pe[i]);
                    names.push_back(std::string(bs->VpiName()));
                    seg_idx.push_back(bs->VpiIndex());
                } else { ok_segs = false; break; }
            }
            // Whole-field read of an array element (`sub.req_dly[DLY].siz`) — the
            // last element is a plain field ref_obj, not a select.  Only fire when
            // an array bit_select is present, so plain member accesses handled by
            // other paths (e.g. `sub.req.adr`) are left untouched.
            bool is_whole = last_ref && has_bit_select;
            // Bit-select of a struct FIELD (`sub.req.byt[N]`): the last element is
            // a bit_select whose base is a vector field (not an array element).
            const bit_select* fbs = is_bitsel ? any_cast<const bit_select*>(pe.back()) : nullptr;
            const part_select* ps = is_ps ? any_cast<const part_select*>(pe.back()) : nullptr;
            const indexed_part_select* ips = is_ips ? any_cast<const indexed_part_select*>(pe.back()) : nullptr;
            bool have_ranges = is_ps ? (ps->Left_range() && ps->Right_range())
                             : is_ips ? (ips->Base_expr() && ips->Width_expr())
                             : is_bitsel ? (fbs->VpiIndex() != nullptr)
                             : is_whole;
            if (ok_segs && have_ranges) {
                names.push_back(std::string(pe.back()->VpiName()));  // sliced field
                seg_idx.push_back(nullptr);
                // Longest-prefix flattened wire: an interface struct signal
                // flattens to e.g. `sub.req_dly`; the trailing names index into
                // its element struct type.
                RTLIL::Wire* base_wire = nullptr;
                size_t split = 0;
                std::string base_prefix;
                for (size_t k = names.size(); k >= 1; k--) {
                    std::string cand;
                    for (size_t j = 0; j < k; j++) { if (j) cand += "."; cand += names[j]; }
                    if (name_map.count(cand)) { base_wire = name_map[cand]; split = k; base_prefix = cand; break; }
                    if (k == 1) break;
                }
                if (base_wire) {
                    bool off_ok = true;
                    // Element struct typespec of base_wire (needed for the field
                    // walk AND the array-element stride).  Authoritative source:
                    // the struct/union typespec recorded for this interface signal
                    // during modport flattening (module.cpp import_port) — the
                    // generic fallbacks below can otherwise pick a stale/foreign
                    // typespec (e.g. a union) for an interface struct signal like
                    // `tcb_ifu.rsp`.
                    const typespec* ts = nullptr;
                    if (!base_prefix.empty() && iface_signal_struct_ts_.count(base_prefix))
                        ts = iface_signal_struct_ts_[base_prefix];
                    for (auto& kv : wire_map) {
                        if (ts) break;
                        if (kv.second != base_wire) continue;
                        const ref_typespec* rts = nullptr;
                        if (auto ln = dynamic_cast<const UHDM::logic_net*>(kv.first))   rts = ln->Typespec();
                        else if (auto lv = dynamic_cast<const UHDM::logic_var*>(kv.first))  rts = lv->Typespec();
                        else if (auto sv = dynamic_cast<const UHDM::struct_var*>(kv.first)) rts = sv->Typespec();
                        else if (auto sn = dynamic_cast<const UHDM::struct_net*>(kv.first)) rts = sn->Typespec();
                        else if (auto uv = dynamic_cast<const UHDM::union_var*>(kv.first))  rts = uv->Typespec();
                        if (rts) ts = rts->Actual_typespec();
                        if (ts) break;
                    }
                    if (!ts && split >= 1) {
                        if (auto e = dynamic_cast<const expr*>(pe[split-1]))
                            if (auto rt = e->Typespec()) ts = rt->Actual_typespec();
                        if (!ts) {
                            const any* ag = nullptr;
                            if (auto lr = dynamic_cast<const ref_obj*>(pe[split-1])) ag = lr->Actual_group();
                            else if (auto bsel = dynamic_cast<const bit_select*>(pe[split-1])) ag = bsel->Actual_group();
                            if (ag) {
                                const ref_typespec* rts = nullptr;
                                if (auto ln = dynamic_cast<const UHDM::logic_net*>(ag))   rts = ln->Typespec();
                                else if (auto sn = dynamic_cast<const UHDM::struct_net*>(ag)) rts = sn->Typespec();
                                else if (auto lv = dynamic_cast<const UHDM::logic_var*>(ag))  rts = lv->Typespec();
                                else if (auto sv = dynamic_cast<const UHDM::struct_var*>(ag)) rts = sv->Typespec();
                                else if (auto uv = dynamic_cast<const UHDM::union_var*>(ag))  rts = uv->Typespec();
                                if (rts) ts = rts->Actual_typespec();
                            }
                        }
                    }
                    // A flattened interface ARRAY signal (`sub.req_dly`) is absent
                    // from wire_map and its bit_select/field refs carry no
                    // typespec.  Resolve the element struct type from the
                    // interface itself: modport port names[0] -> interface_inst ->
                    // net names[split-1] -> (array_typespec Elem_typespec ->)
                    // struct_typespec.  (tcb_lite_lib_logsize2byteena reads
                    // `sub.req_dly[DLY].siz` / `.ndn` this way.)
                    if (!ts && split >= 2) {
                        const interface_inst* iface = nullptr;
                        if (auto mi = dynamic_cast<const module_inst*>(inst))
                            if (mi->Ports())
                                for (auto p : *mi->Ports()) {
                                    if (std::string(p->VpiName()) != names[0]) continue;
                                    const any* lc = p->Low_conn();
                                    if (lc && lc->UhdmType() == uhdmref_obj)
                                        if (auto a = any_cast<const ref_obj*>(lc)->Actual_group()) lc = a;
                                    if (lc && lc->UhdmType() == uhdmmodport) {
                                        auto mp = any_cast<const modport*>(lc);
                                        if (mp && mp->VpiParent() &&
                                            mp->VpiParent()->UhdmType() == uhdminterface_inst)
                                            iface = any_cast<const interface_inst*>(mp->VpiParent());
                                    }
                                    break;
                                }
                        auto net_struct_ts = [&](const interface_inst* ii) -> const typespec* {
                            if (!ii || !ii->Nets()) return nullptr;
                            for (auto n : *ii->Nets()) {
                                if (std::string(n->VpiName()) != names[split-1]) continue;
                                const ref_typespec* rts = nullptr;
                                if (auto ln = dynamic_cast<const UHDM::logic_net*>(n)) rts = ln->Typespec();
                                else if (auto sn = dynamic_cast<const UHDM::struct_net*>(n)) rts = sn->Typespec();
                                if (!rts) return nullptr;
                                const typespec* a = rts->Actual_typespec();
                                if (a && a->UhdmType() == uhdmarray_typespec)
                                    if (auto et = any_cast<const UHDM::array_typespec*>(a)->Elem_typespec())
                                        a = et->Actual_typespec();
                                return a;
                            }
                            return nullptr;
                        };
                        ts = net_struct_ts(iface);
                        // The elaborated interface copy may carry an array_net
                        // without the struct typespec; fall back to the definition
                        // in AllInterfaces, which keeps the element struct type.
                        if (!ts && iface && uhdm_design && uhdm_design->AllInterfaces()) {
                            std::string dn = std::string(iface->VpiDefName());
                            for (auto ii : *uhdm_design->AllInterfaces())
                                if (std::string(ii->VpiDefName()) == dn) {
                                    ts = net_struct_ts(ii);
                                    if (ts) break;
                                }
                        }
                    }
                    // A PACKED-array base (`scoreboard_entry_t [N-1:0]
                    // commit_instr_i` port): descend to the ELEMENT struct so
                    // the field walk below works and elem_w becomes the
                    // element stride (commit_stage `commit_instr_i[0].ex.valid`
                    // read X without this).  Also accept the elaborated
                    // packed_array_var/net objects' Elements()[0] typespec.
                    if (ts && ts->UhdmType() == uhdmpacked_array_typespec) {
                        auto pt = any_cast<const UHDM::packed_array_typespec*>(ts);
                        if (pt->Elem_typespec() && pt->Elem_typespec()->Actual_typespec())
                            ts = pt->Elem_typespec()->Actual_typespec();
                    }
                    if (!ts && split >= 1) {
                        auto elem_ts_of = [&](const UHDM::any* obj) -> const typespec* {
                            const UHDM::VectorOfany* pel = nullptr;
                            if (auto pv = dynamic_cast<const UHDM::packed_array_var*>(obj))
                                pel = pv->Elements();
                            else if (auto pn = dynamic_cast<const UHDM::packed_array_net*>(obj))
                                pel = pn->Elements();
                            if (pel && !pel->empty())
                                if (auto ev = dynamic_cast<const UHDM::expr*>((*pel)[0]))
                                    if (ev->Typespec())
                                        return ev->Typespec()->Actual_typespec();
                            return nullptr;
                        };
                        if (auto mi2 = dynamic_cast<const UHDM::module_inst*>(
                                current_instance ? (const UHDM::scope*)current_instance : inst)) {
                            if (mi2->Nets())
                                for (auto n0 : *mi2->Nets())
                                    if (std::string(n0->VpiName()) == names[split-1])
                                        { ts = elem_ts_of(n0); break; }
                            if (!ts && mi2->Variables())
                                for (auto v0 : *mi2->Variables())
                                    if (std::string(v0->VpiName()) == names[split-1])
                                        { ts = elem_ts_of(v0); break; }
                        }
                    }
                    // Field offset within the element struct.
                    int field_offset = 0, field_width = base_wire->width;
                    const typespec* final_field_ts = nullptr;
                    if (split < names.size()) {
                        std::string remaining;
                        for (size_t j = split; j < names.size(); j++) {
                            if (!remaining.empty()) remaining += ".";
                            remaining += names[j];
                        }
                        off_ok = ts && calculate_struct_member_offset(
                                           ts, remaining, inst, field_offset, field_width,
                                           &final_field_ts);
                    }
                    // Array-element offset from any bit_select in the matched
                    // prefix (`sub.req_dly[DLY]`).  Stride = the element struct
                    // width; for the collapsed 1-element interface array this is
                    // the whole base wire and any index resolves to offset 0.
                    // Index and bound sub-expressions may be computed
                    // (`$clog2(sub.CFG_BUS_BYT)-1`); force constant folding so the
                    // arithmetic reduces to a literal instead of emitting cells.
                    bool saved_fcf = force_const_fold;
                    force_const_fold = true;
                    int elem_off = 0;
                    int elem_w = ts ? get_width_from_typespec(const_cast<typespec*>(ts), inst) : 0;
                    if (elem_w <= 0) elem_w = base_wire->width;
                    for (size_t i = 0; i < split && off_ok; i++) {
                        if (!seg_idx[i]) continue;
                        RTLIL::SigSpec ix = import_expression(seg_idx[i], input_mapping);
                        if (!ix.is_fully_const()) { off_ok = false; break; }
                        elem_off += ix.as_const().as_int() * elem_w;
                    }
                    // The select indices are in the field's DECLARED coordinates
                    // (a `logic [24:20] rs2` field selects `rs2[22:20]`, not
                    // `[2:0]`), and a packed-ARRAY member indexes in ELEMENT
                    // units.  Read the final member's declared outer range
                    // (low/high/direction) and element width so the index maps
                    // to a field-relative bit offset.  Fields declared [N-1:0]
                    // (decl_low 0, elem_w 1) reduce to the previous 0-based
                    // math.  Without this, `instr.rftype.rs2[22:20]` through a
                    // packed UNION overshot the bounds check and collapsed to a
                    // single bit via the decodeHierPath fallback (CVA6 decoder
                    // FCVT source-format check accepted illegal encodings).
                    int decl_low = 0, decl_high = 0, sel_elem_w = 1;
                    bool decl_asc = false, have_decl = false;
                    if (final_field_ts) {
                        const UHDM::VectorOfrange* mranges = nullptr;
                        const UHDM::ref_typespec* elem_rts = nullptr;
                        if (auto lt = dynamic_cast<const UHDM::logic_typespec*>(final_field_ts)) {
                            mranges = lt->Ranges();
                            elem_rts = lt->Elem_typespec();
                        } else if (auto bt = dynamic_cast<const UHDM::bit_typespec*>(final_field_ts)) {
                            mranges = bt->Ranges();
                        } else if (auto pt = dynamic_cast<const UHDM::packed_array_typespec*>(final_field_ts)) {
                            mranges = pt->Ranges();
                            elem_rts = pt->Elem_typespec();
                        } else if (auto at = dynamic_cast<const UHDM::array_typespec*>(final_field_ts)) {
                            mranges = at->Ranges();
                            elem_rts = at->Elem_typespec();
                        }
                        if (mranges && !mranges->empty()) {
                            auto r0 = (*mranges)[0];
                            RTLIL::SigSpec rl = import_expression(r0->Left_expr(), input_mapping);
                            RTLIL::SigSpec rr = import_expression(r0->Right_expr(), input_mapping);
                            if (rl.is_fully_const() && rr.is_fully_const()) {
                                int rli = rl.as_const().as_int();
                                int rri = rr.as_const().as_int();
                                decl_low = std::min(rli, rri);
                                decl_high = std::max(rli, rri);
                                decl_asc = rli < rri;
                                have_decl = true;
                            }
                            int inner_w = 1;
                            for (size_t ri = 1; ri < mranges->size(); ri++) {
                                auto rn = (*mranges)[ri];
                                RTLIL::SigSpec il = import_expression(rn->Left_expr(), input_mapping);
                                RTLIL::SigSpec ir = import_expression(rn->Right_expr(), input_mapping);
                                if (il.is_fully_const() && ir.is_fully_const())
                                    inner_w *= std::abs(il.as_const().as_int() -
                                                        ir.as_const().as_int()) + 1;
                            }
                            sel_elem_w = inner_w;
                            if (elem_rts && elem_rts->Actual_typespec()) {
                                int ew = get_width_from_typespec(
                                    elem_rts->Actual_typespec(), inst);
                                if (ew > 0) sel_elem_w *= ew;
                            }
                            if (sel_elem_w < 1) sel_elem_w = 1;
                        }
                    }
                    // Map an index range [ilo..ihi] (declared coordinates) to the
                    // field-relative bit offset of its LSB.
                    auto idx_to_bit_lo = [&](int ilo, int ihi) -> int {
                        if (!have_decl) return ilo * sel_elem_w;
                        return decl_asc ? (decl_high - ihi) * sel_elem_w
                                        : (ilo - decl_low) * sel_elem_w;
                    };
                    // Compute the slice's LSB position and length for each form.
                    int lsb = 0, len = 0;
                    bool bounds_ok = false;
                    if (is_ps) {
                        RTLIL::SigSpec ls = import_expression(ps->Left_range(), input_mapping);
                        RTLIL::SigSpec rs = import_expression(ps->Right_range(), input_mapping);
                        if (ls.is_fully_const() && rs.is_fully_const()) {
                            int l = ls.as_int(), r = rs.as_int();
                            int ilo = std::min(l, r), ihi = std::max(l, r);
                            lsb = idx_to_bit_lo(ilo, ihi);
                            len = (ihi - ilo + 1) * sel_elem_w;
                            bounds_ok = true;
                        }
                    } else if (is_ips) {
                        RTLIL::SigSpec bs = import_expression(ips->Base_expr(), input_mapping);
                        RTLIL::SigSpec ws = import_expression(ips->Width_expr(), input_mapping);
                        if (bs.is_fully_const() && ws.is_fully_const()) {
                            int base = bs.as_int(), w = ws.as_int();
                            // vpiPosIndexed `[base +: w]` -> [base + w-1 : base];
                            // otherwise `[base -: w]` -> [base : base - w + 1].
                            int ilo = (ips->VpiIndexedPartSelectType() == vpiPosIndexed)
                                          ? base : base - w + 1;
                            lsb = idx_to_bit_lo(ilo, ilo + w - 1);
                            len = w * sel_elem_w;
                            bounds_ok = true;
                        }
                    } else if (is_bitsel) {
                        // Bit-select of a vector struct field: one bit at the
                        // field-relative index.  Only valid when the bit_select's
                        // base is a struct FIELD (a remaining member after the base
                        // wire) — a bare array-element bit_select (`sub.req_dly[0]`)
                        // has no remaining field and is left to other handlers.
                        RTLIL::SigSpec ix = import_expression(fbs->VpiIndex(), input_mapping);
                        if (split < names.size() && ix.is_fully_const()) {
                            int ib = ix.as_const().as_int();
                            lsb = idx_to_bit_lo(ib, ib);
                            len = sel_elem_w;
                            bounds_ok = true;
                        }
                    } else {
                        // Whole-field read: the entire field.
                        lsb = 0;
                        len = field_width;
                        bounds_ok = true;
                    }
                    force_const_fold = saved_fcf;
                    if (off_ok && bounds_ok && len > 0) {
                        int abs_start = elem_off + field_offset + lsb;
                        if (abs_start >= 0 && abs_start + len <= base_wire->width) {
                            if (mode_debug)
                                log("    Nested struct-field part-select: %s → "
                                    "%s[%d+:%d]\n", path_name.c_str(),
                                    base_wire->name.c_str(), abs_start, len);
                            return RTLIL::SigSpec(base_wire).extract(abs_start, len);
                        }
                    }
                }
            }
        }
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
        // A struct declared INSIDE a generate block is registered under its
        // gen-scope-qualified name (`gen_op[0].value`), but the member path
        // carries the bare name — so the lookup missed and the whole access
        // resolved to X.  CVA6 fpnew_classifier declares `fp_t value;` in a
        // genvar block and reads `value.exponent`; every classification folded
        // to a constant because the field read was X.  Same class as the lzc
        // gen-scope prefix fix, at the struct-member site.
        // NB keep `struct_name` as the PATH prefix — later code slices
        // path_name by its length — and look the wire up under a separate key.
        std::string struct_key = struct_name;
        if (!name_map.count(struct_key)) {
            const std::string gs = get_current_gen_scope();
            if (!gs.empty() && name_map.count(gs + "." + struct_name))
                struct_key = gs + "." + struct_name;
        }
        if (name_map.count(struct_key)) {
            RTLIL::Wire* struct_wire = name_map[struct_key];
            
            // Find the UHDM object for the struct wire
            const any* struct_uhdm_obj = nullptr;
            for (auto& pair : wire_map) {
                if (pair.second == struct_wire) {
                    struct_uhdm_obj = pair.first;
                    break;
                }
            }
            
            const ref_typespec* ref_ts = nullptr;
            if (struct_uhdm_obj) {
                // Get the typespec
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
            }
            const typespec* ts = (ref_ts && ref_ts->Actual_typespec())
                                     ? ref_ts->Actual_typespec() : nullptr;
            // Fallback for a LOCAL struct variable absent from wire_map (its
            // wire exists in name_map but the UHDM object was not recorded):
            // read the typespec from the base ref_obj's Actual_group (the
            // variable's own declaration).  A local `dec_t idu_dec` reading
            // `idu_dec.gpr.rs1` (degu core decode) resolves this way.
            if (!ts && uhdm_hier->Path_elems() && !uhdm_hier->Path_elems()->empty()) {
                if (auto r = dynamic_cast<const ref_obj*>((*uhdm_hier->Path_elems())[0]))
                    if (auto ag = r->Actual_group()) {
                        const ref_typespec* rt = nullptr;
                        if (auto sv = dynamic_cast<const UHDM::struct_var*>(ag)) rt = sv->Typespec();
                        else if (auto uv = dynamic_cast<const UHDM::union_var*>(ag)) rt = uv->Typespec();
                        else if (auto lv = dynamic_cast<const UHDM::logic_var*>(ag)) rt = lv->Typespec();
                        else if (auto n = dynamic_cast<const UHDM::net*>(ag)) rt = n->Typespec();
                        if (rt) ts = rt->Actual_typespec();
                    }
            }
            // A `parameter type` struct port (e.g. CVA6 perf_counters
            // `bp_resolve_t resolved_branch_i`): the port/net typespec is the
            // generic default (`logic`), but the elaborated instance carries a
            // `struct_var`/`union_var` of the SAME name with the real struct
            // type.  Look it up by name so the member offset resolves.
            auto is_struct_ts = [](const typespec* t) {
                return t && (t->UhdmType() == uhdmstruct_typespec ||
                             t->UhdmType() == uhdmunion_typespec);
            };
            auto struct_var_ts = [](const any* a) -> const typespec* {
                const ref_typespec* rt = nullptr;
                if (auto sv = dynamic_cast<const UHDM::struct_var*>(a)) rt = sv->Typespec();
                else if (auto uv = dynamic_cast<const UHDM::union_var*>(a)) rt = uv->Typespec();
                return rt ? rt->Actual_typespec() : nullptr;
            };
            if (!is_struct_ts(ts) && current_instance) {
                // Local struct_var of the same name (elaborated instance).
                if (current_instance->Variables())
                    for (auto v : *current_instance->Variables())
                        if (std::string(v->VpiName()) == struct_name)
                            if (auto t = struct_var_ts(v)) { ts = t; break; }
                // `parameter type` struct PORT: its typespec is the generic
                // default, but the port's Low_conn actual is the real
                // struct_var (CVA6 perf_counters bp_resolve_t).
                if (!is_struct_ts(ts) && current_instance->Ports())
                    for (auto p : *current_instance->Ports()) {
                        if (std::string(p->VpiName()) != struct_name) continue;
                        if (auto lc = p->Low_conn())
                            if (lc->UhdmType() == uhdmref_obj)
                                if (auto a = any_cast<const UHDM::ref_obj*>(lc)->Actual_group())
                                    if (auto t = struct_var_ts(a)) { ts = t; break; }
                    }
            }
            if (ts) {
                // Calculate bit offset for struct member access
                std::string remaining_path = path_name.substr(struct_name.length() + 1);
                // The member's trailing index can be an EXPRESSION, not a
                // literal.  CVA6 fpnew_classifier's `value.mantissa[MAN_BITS-1]`
                // arrives here as the TEXT `mantissa[23 - 1]`, and the resolver
                // below parses only the LEADING integer — selecting bit 23
                // instead of 22, so `is_signalling` read the wrong mantissa bit
                // and every signalling NaN was classified as quiet.
                //
                // The hier_path's own trailing `bit_select` carries the index as
                // a real expression, so fold that and rewrite the bracket with
                // the result.  Only the TEXT is rewritten: whether the index
                // means a BIT or an ARRAY ELEMENT stays the resolver's decision
                // (`rsp.rdata[0]` must still yield the whole 64-bit element).
                if (!remaining_path.empty() && remaining_path.back() == ']' &&
                    uhdm_hier->Path_elems() &&
                    uhdm_hier->Path_elems()->size() >= 2) {
                    auto bs = dynamic_cast<const UHDM::bit_select*>(
                        uhdm_hier->Path_elems()->back());
                    const UHDM::expr* idx = bs ? bs->VpiIndex() : nullptr;
                    size_t ob = remaining_path.find_last_of('[');
                    if (idx && idx->UhdmType() != uhdmconstant &&
                        ob != std::string::npos) {
                        RTLIL::SigSpec iv = import_expression(idx);
                        if (iv.is_fully_const()) {
                            remaining_path = remaining_path.substr(0, ob + 1) +
                                             std::to_string(iv.as_const().as_int()) +
                                             "]";
                            if (mode_debug)
                                log("    folded member index -> '%s'\n",
                                    remaining_path.c_str());
                        }
                    }
                }
                // A trailing bit range on the member — `rsp.rdata[0][32 +: 32]`
                // (CVA6 cva6_hpdcache_if_adapter's AMO response) — was left in
                // the member NAME.  calculate_struct_member_offset then
                // resolved `rdata[0]` and returned that element's FULL width,
                // so the range was dropped and the resulting chunk ran past the
                // end of the struct wire, aborting yosys with
                // "Assert `chunk_.offset + chunk_.width <= chunk_.wire->width'".
                // Split the range off, resolve the member without it, then
                // apply it to the member's slice.
                int sub_lsb = 0, sub_width = 0;
                bool have_sub = false;
                {
                    size_t ob = remaining_path.find_last_of('[');
                    if (ob != std::string::npos &&
                        remaining_path.back() == ']') {
                        std::string sel = remaining_path.substr(
                            ob + 1, remaining_path.size() - ob - 2);
                        int a = 0, b = 0;
                        if (sscanf(sel.c_str(), "%d+:%d", &a, &b) == 2) {
                            sub_lsb = a; sub_width = b; have_sub = true;
                        } else if (sscanf(sel.c_str(), "%d-:%d", &a, &b) == 2) {
                            sub_width = b; sub_lsb = a - b + 1; have_sub = true;
                        } else if (sscanf(sel.c_str(), "%d:%d", &a, &b) == 2) {
                            sub_lsb = std::min(a, b);
                            sub_width = std::abs(a - b) + 1;
                            have_sub = true;
                        }
                        if (have_sub)
                            remaining_path = remaining_path.substr(0, ob);
                    }
                }
                int bit_offset = 0;
                int member_width = 0;
                if (calculate_struct_member_offset(ts, remaining_path, inst, bit_offset, member_width)) {
                    if (have_sub) {
                        if (sub_lsb < 0 || sub_width <= 0 ||
                            sub_lsb + sub_width > member_width) {
                            log_warning("UHDM: range [%d +: %d] out of range for "
                                        "%d-bit member '%s'\n",
                                        sub_lsb, sub_width, member_width,
                                        remaining_path.c_str());
                            have_sub = false;
                        } else {
                            bit_offset += sub_lsb;
                            member_width = sub_width;
                        }
                    }
                    if (mode_debug)
                        log("    Calculated struct member '%s' offset=%d, width=%d\n",
                            path_name.c_str(), bit_offset, member_width);
                    if (bit_offset >= 0 && member_width > 0 &&
                        bit_offset + member_width <= struct_wire->width)
                        return RTLIL::SigSpec(struct_wire, bit_offset, member_width);
                    log_warning("UHDM: struct member '%s' slice [%d +: %d] exceeds "
                                "the %d-bit wire — leaving unresolved\n",
                                path_name.c_str(), bit_offset, member_width,
                                struct_wire->width);
                }
            }
        }
        
        // If the base of this hier_path binds to a `parameter` (an interface /
        // struct config parameter such as `CFG.BUS.ADR`), this is NOT an
        // unresolved signal: it is a compile-time constant whose scalar width is
        // resolved through the typespec path.  When a submodule takes the
        // interface as a bare port placeholder (rp32 r5p_lsu/r5p_bru/...), the
        // value-folding helpers can't reach the interface scope, but the width
        // is still correct — so downgrade this false "unresolved" alarm to a
        // debug log.  A genuine signal struct-access failure still warns.
        bool base_is_param = false;
        if (uhdm_hier->Path_elems() && !uhdm_hier->Path_elems()->empty()) {
            if (auto r0 = dynamic_cast<const ref_obj*>((*uhdm_hier->Path_elems())[0])) {
                if (auto a0 = r0->Actual_group())
                    base_is_param = (a0->UhdmType() == uhdmparameter);
                else {
                    // UNBOUND base ref (Surelog's binder misses references deep
                    // inside named begin scopes — hpdcache_ctrl_pe's
                    // `HPDcacheCfg.u.lowLatency` in hpdcache_ctrl_comb came
                    // through with no Actual at all): match by NAME against the
                    // instance's parameters so the constant-folding paths below
                    // still get their chance.
                    std::string bn(r0->VpiName());
                    auto mi0 =
                        dynamic_cast<const UHDM::module_inst*>(current_instance);
                    if (!bn.empty() && mi0 && mi0->Parameters()) {
                        for (auto p0 : *mi0->Parameters())
                            if (std::string(p0->VpiName()) == bn) {
                                base_is_param = true;
                                break;
                            }
                    }
                }
            }
        }
        if (base_is_param) {
            // Typespec-member VALUE annotations first: when Surelog's
            // compile-time evaluation of a struct-returning config function
            // (hpdcacheBuildConfig(hpdcacheSetConfig())) resolves the member
            // values, it annotates the function-arg typespec CLONE's members
            // with their constants, and the parameter's struct typespec routes
            // to that clone.  Walk the member path and return the annotated
            // constant.  This must run BEFORE the ExprEval reduction below:
            // the elaborated dut-instance parameter can carry a GARBAGE value
            // (BIN:0 through an opaque anonymous struct_var RHS at the
            // instantiation hand-off), which reduceExpr confidently returns as
            // an all-zero whole-struct constant — hpdcache_ctrl_pe read
            // HPDcacheCfg.u.lowLatency as 0 that way (the ~1% cex).
            {
                const UHDM::parameter* bp = nullptr;
                if (auto r0 = dynamic_cast<const ref_obj*>(
                        (*uhdm_hier->Path_elems())[0])) {
                    bp = dynamic_cast<const UHDM::parameter*>(r0->Actual_group());
                    if (!bp) {
                        std::string bn(r0->VpiName());
                        auto mi0 = dynamic_cast<const UHDM::module_inst*>(
                            current_instance);
                        if (!bn.empty() && mi0 && mi0->Parameters())
                            for (auto p0 : *mi0->Parameters())
                                if (std::string(p0->VpiName()) == bn) {
                                    bp = dynamic_cast<const UHDM::parameter*>(p0);
                                    break;
                                }
                    }
                }
                const UHDM::typespec* ts2 =
                    (bp && bp->Typespec()) ? bp->Typespec()->Actual_typespec()
                                           : nullptr;
                size_t dot0 = path_name.find('.');
                if (ts2 && dot0 != std::string::npos) {
                    std::string rest = path_name.substr(dot0 + 1);
                    const UHDM::expr* val = nullptr;
                    while (!rest.empty() && ts2 &&
                           ts2->UhdmType() == uhdmstruct_typespec) {
                        size_t d = rest.find('.');
                        std::string part = rest.substr(0, d);
                        rest = (d == std::string::npos) ? std::string()
                                                        : rest.substr(d + 1);
                        auto sts2 = any_cast<const UHDM::struct_typespec*>(ts2);
                        const UHDM::typespec_member* mem = nullptr;
                        if (sts2->Members())
                            for (auto m : *sts2->Members())
                                if (std::string(m->VpiName()) == part) {
                                    mem = m;
                                    break;
                                }
                        if (!mem) break;
                        if (rest.empty()) {
                            val = mem->Actual_value();
                            if (!val) val = mem->Default_value();
                            break;
                        }
                        ts2 = mem->Typespec() ? mem->Typespec()->Actual_typespec()
                                              : nullptr;
                    }
                    if (val && val->UhdmType() == uhdmconstant) {
                        RTLIL::SigSpec cv =
                            import_constant(any_cast<const constant*>(val));
                        if (cv.is_fully_const() && cv.is_fully_def()) {
                            if (width > cv.size()) cv.extend_u0(width);
                            if (mode_debug)
                                log("    hier_path '%s' folded via typespec-member "
                                    "annotation -> %s\n",
                                    path_name.c_str(),
                                    cv.as_const().as_string().c_str());
                            return cv;
                        }
                    } else if (auto vexpr = dynamic_cast<const expr*>(val)) {
                        // The annotation can be a foldable EXPRESSION —
                        // CVA6's NonIdempotentLength member carries a CAST of
                        // a constant (`1024'(...)`-shape, vpiCastOp).  Import
                        // it; SV assignment widening zero-extends to the
                        // member width.
                        bool saved_fcf2 = force_const_fold;
                        force_const_fold = true;
                        RTLIL::SigSpec cv = import_expression(vexpr);
                        force_const_fold = saved_fcf2;
                        if (cv.is_fully_const() && cv.is_fully_def() &&
                            cv.size() > 0) {
                            if (width > cv.size()) cv.extend_u0(width);
                            if (mode_debug)
                                log("    hier_path '%s' folded via typespec-member "
                                    "annotation expr (%d bits)\n",
                                    path_name.c_str(), cv.size());
                            return cv;
                        }
                    }
                }
            }
            // A struct-typed parameter FIELD used in an expression
            // (`Cfg.XLEN_ALIGN_BYTES` as a shift amount / replication count in
            // CVA6 wt_dcache_wbuffer): Surelog leaves the hier_path unfolded and
            // the struct-member path above only resolves its WIDTH.  Reduce the
            // whole hier_path to its constant VALUE via ExprEval — the same
            // evaluator that already resolves `Cfg.XLEN` for port widths.
            // Without this the field returns an all-X constant whose as_int()
            // feeds const_shl a garbage width -> std::vector::_M_fill_insert.
            {
                ExprEval eval;
                bool invalidValue = false;
                if (expr* res = eval.reduceExpr(
                        const_cast<hier_path*>(uhdm_hier), invalidValue,
                        current_instance ? (const any*)current_instance : (const any*)inst,
                        uhdm_hier->VpiParent(), true)) {
                    if (!invalidValue && res->UhdmType() == uhdmconstant) {
                        RTLIL::SigSpec cv =
                            import_constant(any_cast<const constant*>(res));
                        if (cv.is_fully_const() && cv.is_fully_def()) {
                            if (mode_debug)
                                log("    hier_path '%s' folded to constant %s via ExprEval\n",
                                    path_name.c_str(), cv.as_const().as_string().c_str());
                            return cv;
                        }
                    }
                }
            }
            // Second chance for a struct-VALUE parameter field
            // (INTERRUPTS.S_TIMER → `(XLEN'(1)<<(XLEN-1)) | 5`): reduceExpr
            // fails on the hier_path in a re-passed context, and
            // decodeHierPath's MEMBER return proved UNRELIABLE (it handed
            // back the same member for every field — all INTERRUPTS.* folded
            // to 0x1).  Resolve the field's expression DIRECTLY from the
            // parameter's assignment pattern: find the elaborated instance's
            // param_assign for the base parameter, walk the pattern's
            // tagged_patterns for the matching field name, fold that expr.
            {
                const UHDM::parameter* base_param = nullptr;
                if (uhdm_hier->Path_elems() && !uhdm_hier->Path_elems()->empty())
                    if (auto r0 = dynamic_cast<const ref_obj*>((*uhdm_hier->Path_elems())[0]))
                        base_param = dynamic_cast<const UHDM::parameter*>(r0->Actual_group());
                size_t dot1 = path_name.find('.');
                std::string field_name = (dot1 != std::string::npos &&
                                          path_name.find('.', dot1 + 1) == std::string::npos)
                                             ? path_name.substr(dot1 + 1)
                                             : std::string();
                const UHDM::module_inst* mi =
                    dynamic_cast<const UHDM::module_inst*>(current_instance);
                if (base_param && !field_name.empty() && mi && mi->Param_assigns()) {
                    const UHDM::any* prhs = nullptr;
                    for (auto pa : *mi->Param_assigns())
                        if (pa->Lhs() && std::string(pa->Lhs()->VpiName()) ==
                                             std::string(base_param->VpiName())) {
                            prhs = pa->Rhs();
                            break;
                        }
                    if (prhs && prhs->UhdmType() == uhdmoperation) {
                        auto pop = any_cast<const operation*>(prhs);
                        if (pop->VpiOpType() == vpiAssignmentPatternOp && pop->Operands()) {
                            // Elaborated patterns often carry BARE field
                            // expressions in struct DECLARATION ORDER (tags
                            // stripped).  Find the struct definition from the
                            // instance's type parameters (the unique one
                            // containing this field), then index positionally.
                            bool any_tagged = false;
                            for (auto o : *pop->Operands())
                                if (o->UhdmType() == uhdmtagged_pattern) { any_tagged = true; break; }
                            if (!any_tagged && mi->Parameters()) {
                                const UHDM::struct_typespec* sts = nullptr;
                                int fidx = -1, nmem = 0;
                                bool ambiguous = false;
                                for (auto p2 : *mi->Parameters()) {
                                    auto tp2 = dynamic_cast<const UHDM::type_parameter*>(p2);
                                    if (!tp2 || !tp2->Typespec()) continue;
                                    auto ats2 = dynamic_cast<const UHDM::struct_typespec*>(
                                        tp2->Typespec()->Actual_typespec());
                                    if (!ats2 || !ats2->Members()) continue;
                                    int i2 = 0;
                                    for (auto m2 : *ats2->Members()) {
                                        if (std::string(m2->VpiName()) == field_name) {
                                            if (sts && sts != ats2) ambiguous = true;
                                            sts = ats2; fidx = i2;
                                            nmem = (int)ats2->Members()->size();
                                        }
                                        i2++;
                                    }
                                }
                                if (sts && !ambiguous && fidx >= 0 &&
                                    (int)pop->Operands()->size() == nmem) {
                                    auto fe = dynamic_cast<const expr*>(
                                        (*pop->Operands())[fidx]);
                                    if (fe) {
                                        bool saved_fcf = force_const_fold;
                                        int saved_ctx = expression_context_width;
                                        force_const_fold = true;
                                        expression_context_width = 0;
                                        RTLIL::SigSpec v = import_expression(fe, input_mapping);
                                        expression_context_width = saved_ctx;
                                        force_const_fold = saved_fcf;
                                        if (!v.empty() && v.is_fully_const() &&
                                            v.is_fully_def()) {
                                            // NB: do NOT shrink to `width` —
                                            // it may be the garbage default 1
                                            // from the failed typespec dig
                                            // (truncated 0x8000000000000005
                                            // to 1'b1).  Return the folded
                                            // value at its natural size.
                                            if (width > v.size())
                                                v.extend_u0(width);
                                            if (mode_debug)
                                                log("    hier_path '%s' folded via positional pattern member %d\n",
                                                    path_name.c_str(), fidx);
                                            return v;
                                        }
                                    }
                                }
                            }
                            for (auto o : *pop->Operands()) {
                                if (o->UhdmType() != uhdmtagged_pattern) continue;
                                auto tp = any_cast<const UHDM::tagged_pattern*>(o);
                                std::string fname;
                                if (tp->Typespec() && tp->Typespec()->Actual_typespec())
                                    fname = std::string(
                                        tp->Typespec()->Actual_typespec()->VpiName());
                                if (fname != field_name || !tp->Pattern()) continue;
                                bool saved_fcf = force_const_fold;
                                int saved_ctx = expression_context_width;
                                force_const_fold = true;
                                expression_context_width = 0;
                                RTLIL::SigSpec v = import_expression(
                                    any_cast<const expr*>(tp->Pattern()), input_mapping);
                                expression_context_width = saved_ctx;
                                force_const_fold = saved_fcf;
                                if (!v.empty() && v.is_fully_const() && v.is_fully_def()) {
                                    if (width > 0 && v.size() < width)
                                        v.extend_u0(width);
                                    if (mode_debug)
                                        log("    hier_path '%s' folded via assignment-pattern member '%s'\n",
                                            path_name.c_str(), field_name.c_str());
                                    return v;
                                }
                                break;
                            }
                        }
                    }
                }
            }
            if (mode_debug)
                log("    hier_path '%s' is an interface/struct parameter field; "
                    "width=%d resolved via typespec (constant, no signal)\n",
                    path_name.c_str(), width);
        } else {
            // Function-inlining fallback: the base is a struct-typed function
            // ARGUMENT bound to a constant (CVA6's
            // `is_inside_execute_regions(Cfg, ...)` where Cfg is the folded
            // CVA6Cfg parameter).  There is no module wire for `Cfg`, but the
            // call context holds the constant value and the io_decl carries
            // the struct typespec — slice the member (array-element selects
            // like `ExecuteRegionAddrBase[0]` included) out of the constant.
            if (FunctionCallContext* fctx = getCurrentFunctionContext()) {
                size_t dp = path_name.find('.');
                if (dp != std::string::npos && fctx->func_def &&
                    fctx->func_def->Io_decls()) {
                    std::string bn = path_name.substr(0, dp);
                    std::string mpath = path_name.substr(dp + 1);
                    auto cit = fctx->const_wire_values.find(bn);
                    const UHDM::typespec* ats = nullptr;
                    for (auto iod : *fctx->func_def->Io_decls())
                        if (std::string(iod->VpiName()) == bn && iod->Typespec()) {
                            ats = iod->Typespec()->Actual_typespec();
                            break;
                        }
                    if (cit != fctx->const_wire_values.end() && ats) {
                        int off = 0, w = 0;
                        if (calculate_struct_member_offset(ats, mpath,
                                current_instance, off, w) &&
                            w > 0 && off + w <= cit->second.size()) {
                            if (mode_debug)
                                log("    hier_path '%s' folded from const function arg '%s' [%d +: %d]\n",
                                    path_name.c_str(), bn.c_str(), off, w);
                            return cit->second.extract(off, w);
                        }
                    }
                }
            }
            // Log a warning and return an unconnected signal
            // `s.arr[i].sub.f` — a base struct whose FIELD is an array of
            // structs, indexed, then a FURTHER nested field path:
            // [ref_obj(s), bit_select(arr,i), ref_obj(sub), ref_obj(f)].
            // The one-level form resolves elsewhere; this multi-level tail had
            // no handler and fell through to X, so CVA6
            // issue_read_operands' `fwd_i.sbe[i].ex.valid` read as X/0 and
            // fwd_res_valid came out all-zero, killing every rs2 forward.
            // size 3 is `s.arr[i].f` (one field level) and size >=4 adds
            // further levels.  Both reach here only after every other branch
            // has declined — for a CONSTANT index the size-3 form is already
            // handled elsewhere, so in practice this catches the DYNAMIC index
            // (CVA6 issue_read_operands' `fwd_i.sbe[idx_hzd_rs1[i]].fu`, which
            // read as X and left rs1_is_not_csr wrong).
            if (uhdm_hier->Path_elems() && uhdm_hier->Path_elems()->size() >= 3) {
                auto& peA = *uhdm_hier->Path_elems();
                bool tail_ref = peA[0]->UhdmType() == uhdmref_obj &&
                                peA[1]->UhdmType() == uhdmbit_select;
                for (size_t t = 2; tail_ref && t < peA.size(); t++)
                    if (peA[t]->UhdmType() != uhdmref_obj) tail_ref = false;
                if (tail_ref) {
                    auto bref = any_cast<const ref_obj*>(peA[0]);
                    auto abs  = any_cast<const bit_select*>(peA[1]);
                    std::string bname = std::string(bref->VpiName());
                    RTLIL::Wire* bw = name_map.count(bname)
                                          ? name_map[bname]
                                          : module->wire(RTLIL::escape_id(bname));
                    const UHDM::typespec* bts = nullptr;
                    if (auto rt = bref->Typespec()) bts = rt->Actual_typespec();
                    if (!bts)
                        if (auto ag = bref->Actual_group())
                            if (auto e = dynamic_cast<const UHDM::expr*>(ag))
                                if (auto rt2 = e->Typespec())
                                    bts = rt2->Actual_typespec();
                    if (bts) bts = resolve_type_param_typespec(bts, inst);
                    RTLIL::SigSpec idx_s;
                    if (abs->VpiIndex())
                        idx_s = import_expression(abs->VpiIndex(), input_mapping);
                    if (bw && bts && bts->UhdmType() == uhdmstruct_typespec &&
                        !idx_s.empty()) {
                        // Offset of the ARRAY field within the base struct.
                        auto st = any_cast<const UHDM::struct_typespec*>(bts);
                        std::string fname = std::string(abs->VpiName());
                        int off = 0, fw = 0;
                        const UHDM::typespec* fts = nullptr;
                        bool ok = false;
                        if (st->Members())
                            for (int m2 = (int)st->Members()->size() - 1; m2 >= 0; m2--) {
                                auto m = (*st->Members())[m2];
                                int mw = 0;
                                const UHDM::typespec* mts = nullptr;
                                if (auto r = m->Typespec())
                                    if ((mts = r->Actual_typespec())) {
                                        mts = resolve_type_param_typespec(mts, inst);
                                        mw = get_width_from_typespec(mts, inst);
                                    }
                                if (std::string(m->VpiName()) == fname) {
                                    fw = mw; fts = mts; ok = true; break;
                                }
                                off += mw;
                            }
                        // Element geometry of that array field.
                        const UHDM::typespec* ets = nullptr;
                        int nelem = 0, decl_l = 0, decl_r = 0;
                        if (ok && fts) {
                            const UHDM::VectorOfrange* rg = nullptr;
                            if (fts->UhdmType() == uhdmpacked_array_typespec) {
                                auto pa = any_cast<const UHDM::packed_array_typespec*>(fts);
                                rg = pa->Ranges();
                                if (pa->Elem_typespec())
                                    ets = pa->Elem_typespec()->Actual_typespec();
                            } else if (fts->UhdmType() == uhdmlogic_typespec) {
                                auto lt = any_cast<const UHDM::logic_typespec*>(fts);
                                rg = lt->Ranges();
                                if (lt->Elem_typespec())
                                    ets = lt->Elem_typespec()->Actual_typespec();
                            }
                            if (rg && !rg->empty()) {
                                auto r0 = (*rg)[0];
                                RTLIL::SigSpec l = import_expression(r0->Left_expr(), input_mapping);
                                RTLIL::SigSpec r = import_expression(r0->Right_expr(), input_mapping);
                                if (l.is_fully_const() && r.is_fully_const()) {
                                    decl_l = l.as_const().as_int();
                                    decl_r = r.as_const().as_int();
                                    nelem = std::abs(decl_l - decl_r) + 1;
                                }
                            }
                        }
                        if (ok && ets) ets = resolve_type_param_typespec(ets, inst);
                        if (ok && nelem > 0 && fw % nelem == 0 && ets) {
                            int elem_w = fw / nelem;
                            int lo = std::min(decl_l, decl_r);
                            int hi = std::max(decl_l, decl_r);
                            int idx = idx_s.is_fully_const()
                                          ? idx_s.as_const().as_int() : lo;
                            if (idx >= lo && idx <= hi) {
                                // Elements are laid out MSB-first for a
                                // descending declaration, as elsewhere.
                                int eoff = (decl_l < decl_r) ? (hi - idx) * elem_w
                                                             : (idx - lo) * elem_w;
                                int total = off + eoff;
                                // Descend the remaining field names.
                                const UHDM::struct_typespec* cur =
                                    ets->UhdmType() == uhdmstruct_typespec
                                        ? any_cast<const UHDM::struct_typespec*>(ets)
                                        : nullptr;
                                int lw = elem_w;
                                bool good = true;
                                for (size_t t = 2; t < peA.size() && good; t++) {
                                    std::string nm = std::string(peA[t]->VpiName());
                                    good = false;
                                    if (!cur || !cur->Members()) break;
                                    int loff = 0;
                                    for (int m2 = (int)cur->Members()->size() - 1;
                                         m2 >= 0; m2--) {
                                        auto m = (*cur->Members())[m2];
                                        int mw = 0;
                                        const UHDM::typespec* mts = nullptr;
                                        if (auto r = m->Typespec())
                                            if ((mts = r->Actual_typespec())) {
                                                mts = resolve_type_param_typespec(mts, inst);
                                                mw = get_width_from_typespec(mts, inst);
                                            }
                                        if (std::string(m->VpiName()) == nm) {
                                            total += loff; lw = mw; good = mw > 0;
                                            cur = (mts && mts->UhdmType() == uhdmstruct_typespec)
                                                      ? any_cast<const UHDM::struct_typespec*>(mts)
                                                      : nullptr;
                                            break;
                                        }
                                        loff += mw;
                                    }
                                }
                                if (good && lw > 0 && idx_s.is_fully_const() &&
                                    total + lw <= bw->width) {
                                    log("    hier_path '%s' -> \\%s [%d +: %d] "
                                        "(struct array field, nested tail)\n",
                                        path_name.c_str(), bname.c_str(), total, lw);
                                    return RTLIL::SigSpec(bw).extract(total, lw);
                                }
                                // DYNAMIC element index: the field offset is
                                // fixed, the element offset is not — shift the
                                // whole base by idx*elem_w and take the slice.
                                // CVA6 issue_read_operands reads
                                // `fwd_i.sbe[idx_hzd_rs1[i]].fu` this way.
                                if (good && lw > 0 && !idx_s.is_fully_const()) {
                                    RTLIL::SigSpec sh = idx_s;
                                    sh.extend_u0(32, false);
                                    if (lo != 0)
                                        sh = module->Sub(NEW_ID, sh,
                                                         RTLIL::Const(lo, 32), false);
                                    if (decl_l < decl_r) {
                                        // Ascending declaration: element k sits
                                        // (hi-k) slots from the base.
                                        sh = module->Sub(NEW_ID,
                                                RTLIL::SigSpec(RTLIL::Const(hi - lo, 32)),
                                                sh, false);
                                    }
                                    if (elem_w > 1)
                                        sh = module->Mul(NEW_ID, sh,
                                                RTLIL::Const(elem_w, 32), false);
                                    int fixed = total - ((decl_l < decl_r)
                                                    ? (hi - idx) : (idx - lo)) * elem_w;
                                    if (fixed > 0)
                                        sh = module->Add(NEW_ID, sh,
                                                RTLIL::Const(fixed, 32), false);
                                    RTLIL::Wire* ow = module->addWire(NEW_ID, lw);
                                    module->addShiftx(NEW_ID, RTLIL::SigSpec(bw), sh, ow);
                                    log("    hier_path '%s' -> \\%s dynamic elem "
                                        "(elem_w=%d, field_off=%d, w=%d)\n",
                                        path_name.c_str(), bname.c_str(), elem_w,
                                        fixed, lw);
                                    return RTLIL::SigSpec(ow);
                                }
                            }
                        }
                    }
                }
            }
            log_warning("UHDM: Could not resolve struct member access '%s'\n", path_name.c_str());
        }
        return RTLIL::SigSpec(RTLIL::State::Sx, width);
    }
    
    // Create the wire with the determined width
    if (mode_debug)
        log("    Creating wire '%s' with width=%d\n", path_name.c_str(), width);
    
    RTLIL::Wire* wire = create_wire(path_name, width);
    return RTLIL::SigSpec(wire);
}

// Calculate bit offset and width for struct member access
bool UhdmImporter::flat_struct_array_geom(const std::string& base_name,
                                          const UHDM::any* actual_group,
                                          const UHDM::scope* inst,
                                          std::vector<std::pair<int,int>>& dims,
                                          const UHDM::struct_typespec** st_out,
                                          int* elem_w_out) {
    dims.clear();
    const UHDM::struct_typespec* st = nullptr;
    const UHDM::VectorOfrange* rngs = nullptr;

    auto inner_struct = [&](const UHDM::any* n0) -> const UHDM::struct_typespec* {
        const UHDM::ref_typespec* rts = nullptr;
        if (auto sn = dynamic_cast<const UHDM::struct_net*>(n0)) rts = sn->Typespec();
        else if (auto sv = dynamic_cast<const UHDM::struct_var*>(n0)) rts = sv->Typespec();
        else if (auto e = dynamic_cast<const UHDM::expr*>(n0)) rts = e->Typespec();
        if (rts && rts->Actual_typespec() &&
            rts->Actual_typespec()->UhdmType() == uhdmstruct_typespec)
            return any_cast<const UHDM::struct_typespec*>(rts->Actual_typespec());
        return nullptr;
    };
    auto try_obj = [&](const UHDM::any* obj) {
        if (st) return;
        if (auto an = dynamic_cast<const UHDM::array_net*>(obj)) {
            if (an->Nets() && !an->Nets()->empty())
                st = inner_struct((*an->Nets())[0]);
            if (st) rngs = an->Ranges();
        } else if (auto av = dynamic_cast<const UHDM::array_var*>(obj)) {
            if (av->Variables() && !av->Variables()->empty())
                st = inner_struct((*av->Variables())[0]);
            if (st) rngs = av->Ranges();
        } else if (auto pv = dynamic_cast<const UHDM::packed_array_var*>(obj)) {
            if (pv->Elements() && !pv->Elements()->empty())
                st = inner_struct((*pv->Elements())[0]);
            if (st) rngs = pv->Ranges();
        } else if (auto pn = dynamic_cast<const UHDM::packed_array_net*>(obj)) {
            if (pn->Elements() && !pn->Elements()->empty())
                st = inner_struct((*pn->Elements())[0]);
            if (st) rngs = pn->Ranges();
        } else if (auto e = dynamic_cast<const UHDM::expr*>(obj)) {
            // Plain net/var whose OWN typespec is a packed_array_typespec of
            // a struct — the shape an ANONYMOUS `struct packed {...} [N-1:0]`
            // declaration produces (CVA6 cva6_tlb tags_q/content_q).
            const UHDM::ref_typespec* rts = e->Typespec();
            if (rts && rts->Actual_typespec() &&
                rts->Actual_typespec()->UhdmType() == uhdmpacked_array_typespec) {
                auto pat = any_cast<const UHDM::packed_array_typespec*>(
                    rts->Actual_typespec());
                if (pat->Elem_typespec() && pat->Elem_typespec()->Actual_typespec()) {
                    const UHDM::typespec* ets = resolve_type_param_typespec(
                        pat->Elem_typespec()->Actual_typespec(), inst);
                    if (ets && ets->UhdmType() == uhdmstruct_typespec) {
                        st = any_cast<const UHDM::struct_typespec*>(ets);
                        rngs = pat->Ranges();
                    }
                }
            }
        }
    };
    try_obj(actual_group);
    auto mi = dynamic_cast<const UHDM::module_inst*>(
        current_instance ? (const UHDM::scope*)current_instance : inst);
    if (!st && mi) {
        if (mi->Array_nets())
            for (auto an : *mi->Array_nets())
                if (std::string(an->VpiName()) == base_name) { try_obj(an); break; }
        if (!st && mi->Array_vars())
            for (auto av : *mi->Array_vars())
                if (std::string(av->VpiName()) == base_name) { try_obj(av); break; }
        if (!st && mi->Nets())
            for (auto n0 : *mi->Nets())
                if (std::string(n0->VpiName()) == base_name) { try_obj(n0); break; }
        if (!st && mi->Variables())
            for (auto v0 : *mi->Variables())
                if (std::string(v0->VpiName()) == base_name) { try_obj(v0); break; }
    }
    if (!st || !rngs || rngs->empty()) return false;
    for (auto r : *rngs) {
        if (!r->Left_expr() || !r->Right_expr()) return false;
        RTLIL::SigSpec l = import_expression(r->Left_expr());
        RTLIL::SigSpec rr = import_expression(r->Right_expr());
        if (!l.is_fully_const() || !rr.is_fully_const()) return false;
        int li = l.as_const().as_int(), ri = rr.as_const().as_int();
        dims.push_back({std::abs(li - ri) + 1, std::min(li, ri)});
    }
    // Width eval needs an instance for parameterized member ranges
    // (`[2**CVA6Cfg.BHTHist-1:0]`); with none the member collapses to 1 bit
    // and every write stride is wrong (bht2lvl wrote entry pc*10 instead of
    // pc*40).  Fall back to current_instance like the module lookup above.
    int ew = get_width_from_typespec(
        st, inst ? inst : (const UHDM::scope*)current_instance);
    if (ew <= 0) return false;
    if (st_out) *st_out = st;
    if (elem_w_out) *elem_w_out = ew;
    return true;
}

bool UhdmImporter::calculate_struct_member_offset(const typespec* ts, const std::string& member_path,
                                                 const scope* inst, int& bit_offset, int& member_width,
                                                 const typespec** final_member_ts) {
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
    for (const auto& raw_part : path_parts) {
        // A part may carry packed bit/element selects (`l[2][1]`, `k[2]`).
        // Match on the BARE member name; the indices add a within-member bit
        // offset after the member is located (DotRange).
        std::string member_name = raw_part;
        std::vector<int> sel_idxs;
        if (size_t br = raw_part.find('['); br != std::string::npos) {
            member_name = raw_part.substr(0, br);
            size_t p = br;
            while (p < raw_part.size() && raw_part[p] == '[') {
                size_t e = raw_part.find(']', p);
                if (e == std::string::npos) break;
                try { sel_idxs.push_back(std::stoi(raw_part.substr(p + 1, e - p - 1))); }
                catch (...) { sel_idxs.clear(); break; }
                p = e + 1;
            }
        }
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
                // Found the member.  Resolve a `parameter type` DECLARATION
                // DEFAULT to the instance-bound type so the NEXT path level
                // can descend into the bound struct's members (cva6_tlb's
                // anonymous struct member `pte_cva6_t pte` defaults to a
                // 1-bit logic — content_q[i].pte.g returned X).
                if (auto ref_ts = member->Typespec()) {
                    if (auto actual_ts = ref_ts->Actual_typespec()) {
                        found_member_ts = resolve_type_param_typespec(actual_ts, inst);
                        member_width = get_width_from_typespec(found_member_ts, inst);
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

        // Apply any packed bit/element selects on this member (`l[2][1]`).
        // Walk the member's logic_typespec dims and add the row-major bit
        // offset; the remaining (unindexed) dims give the resulting width.
        if (!sel_idxs.empty() && found_member_ts) {
            struct MDim { int size; int low; bool asc; };
            std::vector<MDim> dims; // outer->inner
            bool dim_ok = true;
            auto push_rgs = [&](const UHDM::VectorOfrange* rgs) {
                if (!rgs) return;
                for (auto r : *rgs) {
                    RTLIL::SigSpec l = import_expression(r->Left_expr());
                    RTLIL::SigSpec rr = import_expression(r->Right_expr());
                    if (l.is_fully_const() && rr.is_fully_const()) {
                        int li = l.as_const().as_int(), ri = rr.as_const().as_int();
                        dims.push_back({std::abs(li - ri) + 1,
                                        std::min(li, ri), li < ri});
                    } else dim_ok = false;
                }
            };
            const UHDM::any* cur = found_member_ts;
            int hops = 0;
            while (cur && hops++ < 8) {
                if (cur->UhdmType() == uhdmlogic_typespec) {
                    auto lt = any_cast<const UHDM::logic_typespec*>(cur);
                    // Typedef-alias duplication: Surelog copies the aliased
                    // array's range onto the alias level, so the SAME range
                    // appears at two consecutive hops — skip this level's
                    // ranges when the bounds equal the element's own
                    // outermost range (stamped_gen_param's row_t chain
                    // produced dims {2}{3}{3}{2} for a {2}{3}{2} type).
                    bool dup = false;
                    const UHDM::logic_typespec* el2 = nullptr;
                    if (lt->Elem_typespec() && lt->Elem_typespec()->Actual_typespec())
                        el2 = dynamic_cast<const UHDM::logic_typespec*>(
                            lt->Elem_typespec()->Actual_typespec());
                    if (el2 && el2->Elem_typespec() && lt->Ranges() &&
                        !lt->Ranges()->empty() && el2->Ranges() &&
                        !el2->Ranges()->empty()) {
                        auto ro = (*lt->Ranges())[0];
                        auto ri = (*el2->Ranges())[0];
                        RTLIL::SigSpec ol = import_expression(ro->Left_expr());
                        RTLIL::SigSpec orr = import_expression(ro->Right_expr());
                        RTLIL::SigSpec il = import_expression(ri->Left_expr());
                        RTLIL::SigSpec ir = import_expression(ri->Right_expr());
                        if (ol.is_fully_const() && orr.is_fully_const() &&
                            il.is_fully_const() && ir.is_fully_const() &&
                            ol.as_int() == il.as_int() &&
                            orr.as_int() == ir.as_int())
                            dup = true;
                    }
                    if (!dup) push_rgs(lt->Ranges());
                    cur = (lt->Elem_typespec() && lt->Elem_typespec()->Actual_typespec())
                          ? lt->Elem_typespec()->Actual_typespec() : nullptr;
                } else if (cur->UhdmType() == uhdmpacked_array_typespec) {
                    // fpnew's fmt_unit_types_t [0:3] member — the old
                    // logic_typespec-only walk saw no dims at all and the
                    // element select failed.
                    auto pt = any_cast<const UHDM::packed_array_typespec*>(cur);
                    push_rgs(pt->Ranges());
                    cur = (pt->Elem_typespec() && pt->Elem_typespec()->Actual_typespec())
                          ? pt->Elem_typespec()->Actual_typespec() : nullptr;
                } else {
                    const UHDM::typespec* tsp =
                        dynamic_cast<const UHDM::typespec*>(cur);
                    const UHDM::typespec* bound =
                        tsp ? resolve_type_param_typespec(tsp, inst) : nullptr;
                    if (bound && bound != cur) { cur = bound; continue; }
                    // Leaf (enum/struct): its width is the innermost stride.
                    int lw = get_width_from_typespec(cur, inst);
                    if (lw > 1) dims.push_back({lw, 0, false});
                    break;
                }
            }
            if (!dim_ok || dims.size() < sel_idxs.size())
                return false;
            int leaf_w = 1;
            for (size_t d = sel_idxs.size(); d < dims.size(); d++) leaf_w *= dims[d].size;
            int within = 0;
            for (size_t k = 0; k < sel_idxs.size(); k++) {
                int inner = 1;
                for (size_t d = k + 1; d < dims.size(); d++) inner *= dims[d].size;
                int pos = sel_idxs[k] - dims[k].low;
                // ASCENDING range ([0:N-1]): index low is the LEFTMOST
                // element, i.e. the MSB end of the packed value.
                if (dims[k].asc) pos = dims[k].size - 1 - pos;
                within += pos * inner;
            }
            bit_offset += within;
            member_width = leaf_w;
            found_member_ts = nullptr; // sliced to a leaf — no further nesting
        }

        // For the next iteration, use the member's typespec
        current_ts = found_member_ts;
    }

    if (final_member_ts) *final_member_ts = current_ts;

    return member_width > 0;
}

YOSYS_NAMESPACE_END