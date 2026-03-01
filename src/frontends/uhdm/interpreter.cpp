/*
 * Statement interpreter for UHDM initial blocks
 * 
 * This interpreter executes SystemVerilog statements at compile time
 * to handle complex initialization patterns like those in forgen01.v
 */

#include "uhdm2rtlil.h"
#include <uhdm/uhdm.h>
#include <limits>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Evaluate an expression to an integer value
int64_t UhdmImporter::evaluate_expression(const any* expr, 
                                         std::map<std::string, int64_t>& variables,
                                         std::map<std::string, std::vector<int64_t>>& arrays) {
    if (!expr) return 0;
    
    int expr_type = expr->UhdmType();
    
    switch (expr_type) {
        case uhdmconstant: {
            const constant* c = any_cast<const constant*>(expr);
            RTLIL::SigSpec val = import_constant(c);
            if (val.is_fully_const()) {
                return val.as_const().as_int();
            }
            return 0;
        }
        
        case uhdmref_obj: {
            const ref_obj* ref = any_cast<const ref_obj*>(expr);
            std::string name = std::string(ref->VpiName());

            auto it = variables.find(name);
            if (it != variables.end()) {
                return it->second;
            }

            // Fallback: try gen-scope hierarchical name (e.g., "gen.x" for bare "x")
            std::string gen_scope = get_current_gen_scope();
            if (!gen_scope.empty()) {
                std::string hier_name = gen_scope + "." + name;
                auto it2 = variables.find(hier_name);
                if (it2 != variables.end()) {
                    return it2->second;
                }
            }

            return 0;
        }

        case uhdmhier_path: {
            const hier_path* hp = any_cast<const hier_path*>(expr);
            std::string name = std::string(hp->VpiName());

            auto it = variables.find(name);
            if (it != variables.end()) {
                return it->second;
            }

            log_warning("Unknown hier_path variable '%s' in expression\n", name.c_str());
            return 0;
        }
        
        case uhdmoperation: {
            const operation* op = any_cast<const operation*>(expr);
            int op_type = op->VpiOpType();
            
            if (!op->Operands() || op->Operands()->empty()) {
                return 0;
            }
            
            const VectorOfany& operands = *op->Operands();
            
            switch (op_type) {
                case vpiAddOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return a + b;
                    }
                    break;
                }
                
                case vpiSubOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return a - b;
                    }
                    break;
                }
                
                case vpiMultOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return a * b;
                    }
                    break;
                }
                
                case vpiDivOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        if (b != 0) {
                            return a / b;
                        }
                    }
                    break;
                }
                
                case vpiModOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        if (b != 0) {
                            return a % b;
                        }
                    }
                    break;
                }
                
                case vpiEqOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return (a == b) ? 1 : 0;
                    }
                    break;
                }
                
                case vpiNeqOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return (a != b) ? 1 : 0;
                    }
                    break;
                }
                
                case vpiLtOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return (a < b) ? 1 : 0;
                    }
                    break;
                }
                
                case vpiLeOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return (a <= b) ? 1 : 0;
                    }
                    break;
                }
                
                case vpiGtOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return (a > b) ? 1 : 0;
                    }
                    break;
                }
                
                case vpiGeOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return (a >= b) ? 1 : 0;
                    }
                    break;
                }
                
                case vpiLogAndOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return (a && b) ? 1 : 0;
                    }
                    break;
                }
                
                case vpiLogOrOp: {
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return (a || b) ? 1 : 0;
                    }
                    break;
                }
                
                case vpiBitNegOp: { // Bitwise negation (~)
                    if (operands.size() >= 1) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        return ~a;
                    }
                    break;
                }

                case vpiPowerOp: { // Arithmetic power (2 ** x)
                    if (operands.size() >= 2) {
                        int64_t base = evaluate_expression(operands[0], variables, arrays);
                        int64_t exp = evaluate_expression(operands[1], variables, arrays);
                        int64_t result = 1;
                        for (int64_t i = 0; i < exp; i++) {
                            result *= base;
                        }
                        return result;
                    }
                    break;
                }

                case vpiLShiftOp: { // Left shift
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return a << b;
                    }
                    break;
                }

                case vpiRShiftOp: { // Right shift
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return a >> b;
                    }
                    break;
                }

                case vpiBitAndOp: { // Bitwise AND
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return a & b;
                    }
                    break;
                }

                case vpiBitOrOp: { // Bitwise OR
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return a | b;
                    }
                    break;
                }

                case vpiBitXorOp: { // Bitwise XOR
                    if (operands.size() >= 2) {
                        int64_t a = evaluate_expression(operands[0], variables, arrays);
                        int64_t b = evaluate_expression(operands[1], variables, arrays);
                        return a ^ b;
                    }
                    break;
                }

                case vpiPostIncOp: { // Post-increment operator
                    if (operands.size() >= 1) {
                        if (operands[0]->UhdmType() == uhdmref_obj) {
                            const ref_obj* ref = any_cast<const ref_obj*>(operands[0]);
                            std::string name = std::string(ref->VpiName());
                            // Resolve to gen-scope name if short name not found
                            if (variables.find(name) == variables.end()) {
                                std::string gen_scope = get_current_gen_scope();
                                if (!gen_scope.empty()) {
                                    std::string hier = gen_scope + "." + name;
                                    if (variables.find(hier) != variables.end())
                                        name = hier;
                                }
                            }
                            int64_t old_val = variables[name];
                            variables[name] = old_val + 1;
                            return old_val;
                        }
                    }
                    break;
                }
                
                default:
                    log_warning("Unsupported operation type %d in expression evaluation\n", op_type);
                    break;
            }
            break;
        }
        
        case uhdmbit_select: {
            const bit_select* bs = any_cast<const bit_select*>(expr);
            std::string array_name = std::string(bs->VpiName());
            
            if (bs->VpiIndex()) {
                int64_t index = evaluate_expression(bs->VpiIndex(), variables, arrays);
                
                auto it = arrays.find(array_name);
                if (it != arrays.end()) {
                    if (index >= 0 && index < (int64_t)it->second.size()) {
                        return it->second[index];
                    }
                }
            }
            break;
        }
        
        case uhdmfunc_call: {
            // Handle user function calls by evaluating via import_expression
            RTLIL::SigSpec result = import_expression(any_cast<const UHDM::expr*>(expr));
            if (result.is_fully_const()) {
                return result.as_const().as_int();
            }
            log_warning("Function call in interpreter did not resolve to constant\n");
            return 0;
        }

        case uhdmsys_func_call: {
            // Handle system function calls ($floor, $ceil, etc.)
            RTLIL::SigSpec result = import_expression(any_cast<const UHDM::expr*>(expr));
            if (result.is_fully_const()) {
                return result.as_const().as_int();
            }
            log_warning("System function call in interpreter did not resolve to constant\n");
            return 0;
        }

        case uhdmpart_select: {
            // Handle part selects like OUTPUT[15:8]
            RTLIL::SigSpec result = import_expression(any_cast<const UHDM::expr*>(expr));
            if (result.is_fully_const()) {
                return result.as_const().as_int();
            }
            return 0;
        }

        default:
            log_warning("Unsupported expression type %d\n", expr_type);
            break;
    }

    return 0;
}

// Interpret a statement
void UhdmImporter::interpret_statement(const any* stmt,
                                      std::map<std::string, int64_t>& variables,
                                      std::map<std::string, std::vector<int64_t>>& arrays,
                                      bool& break_flag, bool& continue_flag) {
    if (!stmt) return;
    
    int stmt_type = stmt->UhdmType();
    
    switch (stmt_type) {
        case uhdmassignment: {
            const assignment* assign = any_cast<const assignment*>(stmt);

            if (assign->Lhs() && assign->Rhs()) {
                int64_t rhs_value = evaluate_expression(assign->Rhs(), variables, arrays);

                // Resolve LHS variable name
                std::string lhs_name;
                bool is_array = false;
                int64_t array_index = 0;
                int lhs_type = assign->Lhs()->UhdmType();

                if (lhs_type == uhdmref_obj) {
                    const ref_obj* ref = any_cast<const ref_obj*>(assign->Lhs());
                    lhs_name = std::string(ref->VpiName());
                } else if (lhs_type == uhdmref_var) {
                    const ref_var* ref = any_cast<const ref_var*>(assign->Lhs());
                    lhs_name = std::string(ref->VpiName());
                } else if (lhs_type == uhdminteger_var) {
                    // For-loop variable declarations (e.g., for (integer x = ...))
                    const integer_var* iv = any_cast<const integer_var*>(assign->Lhs());
                    lhs_name = std::string(iv->VpiName());
                } else if (lhs_type == uhdmhier_path) {
                    // Hierarchical path (e.g., gen.x)
                    const hier_path* hp = any_cast<const hier_path*>(assign->Lhs());
                    lhs_name = std::string(hp->VpiName());
                } else if (lhs_type == uhdmbit_select) {
                    const bit_select* bs = any_cast<const bit_select*>(assign->Lhs());
                    lhs_name = std::string(bs->VpiName());
                    is_array = true;
                    if (bs->VpiIndex()) {
                        array_index = evaluate_expression(bs->VpiIndex(), variables, arrays);
                    }
                }

                if (!lhs_name.empty()) {
                    // Handle compound assignments (+=, -=, *=, etc.)
                    // vpiOpType 82 = simple assignment, 0 = unset
                    int op_type = assign->VpiOpType();
                    if (op_type != 82 && op_type != 0) {
                        // Read current LHS value
                        int64_t current_val = 0;
                        if (is_array) {
                            auto ait = arrays.find(lhs_name);
                            if (ait != arrays.end() && array_index >= 0 &&
                                array_index < (int64_t)ait->second.size()) {
                                current_val = ait->second[array_index];
                            }
                        } else {
                            auto vit = variables.find(lhs_name);
                            if (vit != variables.end()) {
                                current_val = vit->second;
                            } else {
                                // Try gen-scope fallback for bare name
                                std::string gen_scope = get_current_gen_scope();
                                if (!gen_scope.empty()) {
                                    std::string hier = gen_scope + "." + lhs_name;
                                    auto vit2 = variables.find(hier);
                                    if (vit2 != variables.end()) {
                                        current_val = vit2->second;
                                        lhs_name = hier; // Use the resolved name
                                    }
                                }
                            }
                        }

                        // Apply the compound operation
                        switch (op_type) {
                            case vpiAddOp: rhs_value = current_val + rhs_value; break;
                            case vpiSubOp: rhs_value = current_val - rhs_value; break;
                            case vpiMultOp: rhs_value = current_val * rhs_value; break;
                            case vpiDivOp: if (rhs_value != 0) rhs_value = current_val / rhs_value; break;
                            case vpiModOp: if (rhs_value != 0) rhs_value = current_val % rhs_value; break;
                            case vpiLShiftOp: rhs_value = current_val << rhs_value; break;
                            case vpiRShiftOp: rhs_value = current_val >> rhs_value; break;
                            case vpiBitAndOp: rhs_value = current_val & rhs_value; break;
                            case vpiBitOrOp: rhs_value = current_val | rhs_value; break;
                            case vpiBitXorOp: rhs_value = current_val ^ rhs_value; break;
                            default:
                                log_warning("Unsupported compound assignment op %d\n", op_type);
                                break;
                        }
                    } else if (!is_array) {
                        // For simple assignment, resolve bare name to gen-scope if needed
                        if (variables.find(lhs_name) == variables.end()) {
                            std::string gen_scope = get_current_gen_scope();
                            if (!gen_scope.empty()) {
                                std::string hier = gen_scope + "." + lhs_name;
                                if (variables.find(hier) != variables.end()) {
                                    lhs_name = hier;
                                }
                            }
                        }
                    }

                    // Write the value
                    if (is_array) {
                        if (arrays[lhs_name].size() <= (size_t)array_index) {
                            arrays[lhs_name].resize(array_index + 1, 0);
                        }
                        arrays[lhs_name][array_index] = rhs_value;
                        if (mode_debug) {
                            log("        Assign: %s[%lld] = %lld\n",
                                lhs_name.c_str(), (long long)array_index, (long long)rhs_value);
                        }
                    } else {
                        variables[lhs_name] = rhs_value;
                        if (mode_debug) {
                            log("        Assign: %s = %lld\n", lhs_name.c_str(), (long long)rhs_value);
                        }
                    }
                }
            }
            break;
        }
        
        case uhdmbegin: {
            const begin* begin_block = any_cast<const begin*>(stmt);
            // Save and initialize block-local variables for proper scoping
            std::map<std::string, std::pair<bool, int64_t>> saved_vars;
            if (begin_block->Variables()) {
                for (auto var : *begin_block->Variables()) {
                    std::string name = std::string(var->VpiName());
                    if (variables.count(name))
                        saved_vars[name] = {true, variables[name]};
                    else
                        saved_vars[name] = {false, 0};
                    variables[name] = 0;
                }
            }
            if (begin_block->Stmts()) {
                for (auto sub_stmt : *begin_block->Stmts()) {
                    interpret_statement(sub_stmt, variables, arrays, break_flag, continue_flag);
                    if (break_flag || continue_flag) break;
                }
            }
            // Restore scoping
            for (auto& [name, saved] : saved_vars) {
                if (saved.first)
                    variables[name] = saved.second;
                else
                    variables.erase(name);
            }
            break;
        }
        
        case uhdmnamed_begin: {
            const named_begin* named_block = any_cast<const named_begin*>(stmt);
            // Save and initialize block-local variables for proper scoping
            std::map<std::string, std::pair<bool, int64_t>> saved_vars;
            if (named_block->Variables()) {
                for (auto var : *named_block->Variables()) {
                    std::string name = std::string(var->VpiName());
                    if (variables.count(name))
                        saved_vars[name] = {true, variables[name]};
                    else
                        saved_vars[name] = {false, 0};
                    variables[name] = 0;
                }
            }
            if (named_block->Stmts()) {
                for (auto sub_stmt : *named_block->Stmts()) {
                    interpret_statement(sub_stmt, variables, arrays, break_flag, continue_flag);
                    if (break_flag || continue_flag) break;
                }
            }
            // Restore scoping
            for (auto& [name, saved] : saved_vars) {
                if (saved.first)
                    variables[name] = saved.second;
                else
                    variables.erase(name);
            }
            break;
        }
        
        case uhdmif_stmt: {
            const if_stmt* if_s = any_cast<const if_stmt*>(stmt);
            if (if_s->VpiCondition()) {
                int64_t cond_value = evaluate_expression(if_s->VpiCondition(), variables, arrays);
                if (cond_value != 0) {
                    if (if_s->VpiStmt()) {
                        interpret_statement(if_s->VpiStmt(), variables, arrays, break_flag, continue_flag);
                    }
                }
            }
            break;
        }
        
        case uhdmif_else: {
            const if_else* if_else_s = any_cast<const if_else*>(stmt);
            if (if_else_s->VpiCondition()) {
                int64_t cond_value = evaluate_expression(if_else_s->VpiCondition(), variables, arrays);
                if (cond_value != 0) {
                    if (if_else_s->VpiStmt()) {
                        interpret_statement(if_else_s->VpiStmt(), variables, arrays, break_flag, continue_flag);
                    }
                } else {
                    if (if_else_s->VpiElseStmt()) {
                        interpret_statement(if_else_s->VpiElseStmt(), variables, arrays, break_flag, continue_flag);
                    }
                }
            }
            break;
        }
        
        case uhdmfor_stmt: {
            const for_stmt* for_s = any_cast<const for_stmt*>(stmt);

            // Detect for-loop variable declarations (integer_var in ForInitStmt LHS)
            // These shadow outer variables and must be removed after the loop
            std::vector<std::string> loop_var_names;
            auto detect_loop_vars = [&](const any* init) {
                if (init && init->UhdmType() == uhdmassignment) {
                    const assignment* a = any_cast<const assignment*>(init);
                    if (a->Lhs() && a->Lhs()->UhdmType() == uhdminteger_var) {
                        const integer_var* iv = any_cast<const integer_var*>(a->Lhs());
                        loop_var_names.push_back(std::string(iv->VpiName()));
                    }
                }
            };
            if (for_s->VpiForInitStmt()) {
                detect_loop_vars(for_s->VpiForInitStmt());
            }
            if (for_s->VpiForInitStmts()) {
                for (auto init_stmt : *for_s->VpiForInitStmts()) {
                    detect_loop_vars(init_stmt);
                }
            }

            // Save any existing values that will be shadowed
            std::map<std::string, std::pair<bool, int64_t>> saved_loop_vars;
            for (auto& vname : loop_var_names) {
                auto it = variables.find(vname);
                if (it != variables.end())
                    saved_loop_vars[vname] = {true, it->second};
                else
                    saved_loop_vars[vname] = {false, 0};
            }

            // Execute init statement(s)
            if (for_s->VpiForInitStmt()) {
                interpret_statement(for_s->VpiForInitStmt(), variables, arrays, break_flag, continue_flag);
            }
            if (for_s->VpiForInitStmts()) {
                for (auto init_stmt : *for_s->VpiForInitStmts()) {
                    interpret_statement(init_stmt, variables, arrays, break_flag, continue_flag);
                }
            }

            // Execute loop
            int iteration_count = 0;
            const int MAX_ITERATIONS = 100000; // Safety limit

            while (iteration_count < MAX_ITERATIONS) {
                // Check condition
                if (for_s->VpiCondition()) {
                    int64_t cond_value = evaluate_expression(for_s->VpiCondition(), variables, arrays);
                    if (cond_value == 0) {
                        break;
                    }
                }

                // Execute body
                if (for_s->VpiStmt()) {
                    interpret_statement(for_s->VpiStmt(), variables, arrays, break_flag, continue_flag);
                }

                if (break_flag) {
                    break_flag = false;
                    break;
                }

                if (continue_flag) {
                    continue_flag = false;
                }

                // Execute increment statement(s)
                if (for_s->VpiForIncStmt()) {
                    interpret_statement(for_s->VpiForIncStmt(), variables, arrays, break_flag, continue_flag);
                }
                if (for_s->VpiForIncStmts()) {
                    for (auto inc_stmt : *for_s->VpiForIncStmts()) {
                        interpret_statement(inc_stmt, variables, arrays, break_flag, continue_flag);
                    }
                }

                iteration_count++;
            }

            if (iteration_count >= MAX_ITERATIONS) {
                log_warning("For loop exceeded maximum iterations (%d)\n", MAX_ITERATIONS);
            }

            // Remove for-loop declared variables so bare name reverts to
            // gen-scope hierarchical lookup (variable shadowing ends)
            for (auto& vname : loop_var_names) {
                auto& saved = saved_loop_vars[vname];
                if (saved.first)
                    variables[vname] = saved.second;
                else
                    variables.erase(vname);
            }
            break;
        }
        
        case uhdmoperation: {
            // Handle operations that are statements (like i++)
            evaluate_expression(stmt, variables, arrays);
            break;
        }
        
        default:
            if (mode_debug) {
                log("        Unsupported statement type %d\n", stmt_type);
            }
            break;
    }
}

YOSYS_NAMESPACE_END