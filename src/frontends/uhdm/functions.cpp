// Function support for UHDM to RTLIL conversion
// This file contains all function-related code including:
// - Function call evaluation (compile-time and runtime)
// - Recursive function support
// - Function output parameters
// - Function inlining and process generation

#include "uhdm2rtlil.h"
#include <uhdm/uhdm.h>
#include <uhdm/function.h>
#include <uhdm/func_call.h>
#include <uhdm/assignment.h>
#include <uhdm/operation.h>
#include <uhdm/constant.h>
#include <uhdm/ref_obj.h>
#include <uhdm/if_else.h>
#include <uhdm/if_stmt.h>
#include <uhdm/begin.h>
#include <uhdm/named_begin.h>
#include <uhdm/io_decl.h>
#include <uhdm/logic_var.h>
#include <uhdm/integer_var.h>
#include <uhdm/ref_typespec.h>
#include <uhdm/logic_typespec.h>
#include <uhdm/integer_typespec.h>
#include <uhdm/case_stmt.h>
#include <uhdm/case_item.h>
#include <uhdm/for_stmt.h>

YOSYS_NAMESPACE_BEGIN

// Evaluate function call at compile time (for initial blocks)
RTLIL::Const UhdmImporter::evaluate_function_call(const UHDM::function* func_def, 
                                                  const std::vector<RTLIL::Const>& const_args,
                                                  std::map<std::string, RTLIL::Const>& output_params) {
    if (!func_def) {
        log_error("Function definition is null in evaluate_function_call\n");
        return RTLIL::Const();
    }
    
    std::string func_name = std::string(func_def->VpiName());
    log("Evaluating function %s at compile time\n", func_name.c_str());
    
    // Create local variable map and initialize with parameters
    std::map<std::string, RTLIL::Const> local_vars;
    
    // Map input parameters to their values
    int arg_idx = 0;
    if (func_def->Io_decls()) {
        for (auto io : *func_def->Io_decls()) {
            if (io->VpiDirection() == vpiInput && arg_idx < (int)const_args.size()) {
                std::string param_name = std::string(io->VpiName());
                local_vars[param_name] = const_args[arg_idx++];
                log("  Setting input parameter %s = %s\n", param_name.c_str(), 
                    const_args[arg_idx-1].as_string().c_str());
            } else if (io->VpiDirection() == vpiOutput) {
                // Initialize output parameters
                std::string param_name = std::string(io->VpiName());
                int width = 32; // Default to 32-bit for integers
                // TODO: Get actual width from io declaration
                local_vars[param_name] = RTLIL::Const(0, width);
            }
        }
    }
    
    // Initialize function return value
    local_vars[func_name] = RTLIL::Const(0, 32); // Default 32-bit
    
    // Evaluate the function body
    if (func_def->Stmt()) {
        RTLIL::Const result = evaluate_function_stmt(func_def->Stmt(), local_vars, func_name);
        // The function might have modified its return value
        if (local_vars.count(func_name)) {
            result = local_vars[func_name];
        }
    }
    
    // Extract output parameters
    if (func_def->Io_decls()) {
        for (auto io : *func_def->Io_decls()) {
            if (io->VpiDirection() == vpiOutput) {
                std::string param_name = std::string(io->VpiName());
                if (local_vars.count(param_name)) {
                    output_params[param_name] = local_vars[param_name];
                    log("  Output parameter %s = %s\n", param_name.c_str(),
                        local_vars[param_name].as_string().c_str());
                }
            }
        }
    }
    
    // Return the function's result
    if (local_vars.count(func_name)) {
        log("  Function result = %s\n", local_vars[func_name].as_string().c_str());
        return local_vars[func_name];
    }
    
    return RTLIL::Const(0, 32);
}

// Helper to evaluate statements during compile-time function evaluation
RTLIL::Const UhdmImporter::evaluate_function_stmt(const UHDM::any* stmt,
                                                  std::map<std::string, RTLIL::Const>& local_vars,
                                                  const std::string& func_name) {
    if (!stmt) return RTLIL::Const();
    
    int stmt_type = stmt->VpiType();
    
    switch (stmt_type) {
        case vpiAssignment: {
            const assignment* assign = any_cast<const assignment*>(stmt);
            
            // Get LHS name
            std::string lhs_name;
            if (assign->Lhs() && assign->Lhs()->VpiType() == vpiRefObj) {
                const ref_obj* ref = any_cast<const ref_obj*>(assign->Lhs());
                lhs_name = std::string(ref->VpiName());
            }
            
            // Evaluate RHS
            RTLIL::Const rhs_value;
            if (assign->Rhs()) {
                if (assign->Rhs()->VpiType() == vpiOperation) {
                    const operation* op = any_cast<const operation*>(assign->Rhs());
                    // Evaluate the operation
                    rhs_value = evaluate_operation_const(op, local_vars);
                } else if (assign->Rhs()->VpiType() == vpiConstant) {
                    const constant* c = any_cast<const constant*>(assign->Rhs());
                    // Import the constant
                    RTLIL::SigSpec sig = import_constant(c);
                    if (sig.is_fully_const()) {
                        rhs_value = sig.as_const();
                    }
                } else if (assign->Rhs()->VpiType() == vpiRefObj) {
                    const ref_obj* ref = any_cast<const ref_obj*>(assign->Rhs());
                    std::string var_name = std::string(ref->VpiName());
                    if (local_vars.count(var_name)) {
                        rhs_value = local_vars[var_name];
                    }
                } else if (assign->Rhs()->VpiType() == vpiFuncCall) {
                    // Handle recursive function calls
                    const func_call* fc = any_cast<const func_call*>(assign->Rhs());
                    rhs_value = evaluate_recursive_function_call(fc, local_vars);
                }
            }
            
            // Perform assignment
            if (!lhs_name.empty()) {
                local_vars[lhs_name] = rhs_value;
                log("    Assigned %s = %s\n", lhs_name.c_str(), rhs_value.as_string().c_str());
            }
            
            return rhs_value;
        }
        
        case vpiIf:
        case vpiIfElse: {
            const if_else* ie = any_cast<const if_else*>(stmt);
            
            // Evaluate condition
            RTLIL::Const cond_value;
            if (ie->VpiCondition()) {
                if (ie->VpiCondition()->VpiType() == vpiOperation) {
                    const operation* op = any_cast<const operation*>(ie->VpiCondition());
                    cond_value = evaluate_operation_const(op, local_vars);
                } else if (ie->VpiCondition()->VpiType() == vpiRefObj) {
                    const ref_obj* ref = any_cast<const ref_obj*>(ie->VpiCondition());
                    std::string var_name = std::string(ref->VpiName());
                    if (local_vars.count(var_name)) {
                        cond_value = local_vars[var_name];
                    }
                }
            }
            
            // Execute appropriate branch
            if (!cond_value.is_fully_zero()) {
                // Execute then branch
                if (ie->VpiStmt()) {
                    return evaluate_function_stmt(ie->VpiStmt(), local_vars, func_name);
                }
            } else {
                // Execute else branch
                if (ie->VpiElseStmt()) {
                    return evaluate_function_stmt(ie->VpiElseStmt(), local_vars, func_name);
                }
            }
            break;
        }
        
        case vpiBegin:
        case vpiNamedBegin: {
            // Execute all statements in the block
            VectorOfany* stmts = begin_block_stmts(stmt);
            if (stmts) {
                RTLIL::Const last_result;
                for (auto s : *stmts) {
                    last_result = evaluate_function_stmt(s, local_vars, func_name);
                }
                return last_result;
            }
            break;
        }
    }
    
    return RTLIL::Const();
}

// Helper to evaluate operations with constant values
RTLIL::Const UhdmImporter::evaluate_operation_const(const operation* op,
                                                    const std::map<std::string, RTLIL::Const>& local_vars) {
    if (!op) return RTLIL::Const();
    
    int op_type = op->VpiOpType();
    auto operands = op->Operands();
    
    if (!operands || operands->empty()) {
        return RTLIL::Const();
    }
    
    // Evaluate operands
    std::vector<RTLIL::Const> operand_values;
    for (auto operand : *operands) {
        RTLIL::Const val;
        if (operand->VpiType() == vpiConstant) {
            const constant* c = any_cast<const constant*>(operand);
            RTLIL::SigSpec sig = import_constant(c);
            if (sig.is_fully_const()) {
                val = sig.as_const();
            }
        } else if (operand->VpiType() == vpiRefObj) {
            const ref_obj* ref = any_cast<const ref_obj*>(operand);
            std::string var_name = std::string(ref->VpiName());
            if (local_vars.count(var_name)) {
                val = local_vars.at(var_name);
            }
        } else if (operand->VpiType() == vpiOperation) {
            const operation* sub_op = any_cast<const operation*>(operand);
            val = evaluate_operation_const(sub_op, local_vars);
        } else if (operand->VpiType() == vpiFuncCall) {
            // Handle function calls in expressions
            const func_call* fc = any_cast<const func_call*>(operand);
            val = evaluate_recursive_function_call(fc, local_vars);
        }
        operand_values.push_back(val);
    }
    
    // Perform the operation
    switch (op_type) {
        case vpiAddOp:
            if (operand_values.size() >= 2) {
                // Perform addition
                int result = operand_values[0].as_int() + operand_values[1].as_int();
                return RTLIL::Const(result, 32);
            }
            break;
            
        case vpiSubOp:
            if (operand_values.size() >= 2) {
                // Perform subtraction
                int result = operand_values[0].as_int() - operand_values[1].as_int();
                return RTLIL::Const(result, 32);
            }
            break;
            
        case vpiMultOp:
            if (operand_values.size() >= 2) {
                // Perform multiplication
                int result = operand_values[0].as_int() * operand_values[1].as_int();
                return RTLIL::Const(result, 32);
            }
            break;
            
        case vpiEqOp:
            if (operand_values.size() >= 2) {
                // Perform equality comparison
                bool result = operand_values[0].as_int() == operand_values[1].as_int();
                return RTLIL::Const(result ? 1 : 0, 1);
            }
            break;
            
        // Add more operations as needed
        default:
            log_warning("Unsupported operation type %d in compile-time evaluation\n", op_type);
            break;
    }
    
    return RTLIL::Const();
}

// Helper to handle recursive function calls
RTLIL::Const UhdmImporter::evaluate_recursive_function_call(const func_call* fc,
                                                           const std::map<std::string, RTLIL::Const>& parent_vars) {
    if (!fc) return RTLIL::Const();
    
    const function* func_def = fc->Function();
    if (!func_def) {
        log_warning("Function definition not found for recursive call\n");
        return RTLIL::Const();
    }
    
    // Collect argument values
    std::vector<RTLIL::Const> arg_values;
    if (fc->Tf_call_args()) {
        for (auto arg : *fc->Tf_call_args()) {
            RTLIL::Const val;
            if (arg->VpiType() == vpiConstant) {
                const constant* c = any_cast<const constant*>(arg);
                RTLIL::SigSpec sig = import_constant(c);
                if (sig.is_fully_const()) {
                    val = sig.as_const();
                }
            } else if (arg->VpiType() == vpiRefObj) {
                const ref_obj* ref = any_cast<const ref_obj*>(arg);
                std::string var_name = std::string(ref->VpiName());
                if (parent_vars.count(var_name)) {
                    val = parent_vars.at(var_name);
                }
            } else if (arg->VpiType() == vpiOperation) {
                const operation* op = any_cast<const operation*>(arg);
                val = evaluate_operation_const(op, parent_vars);
            }
            arg_values.push_back(val);
        }
    }
    
    // Recursively evaluate the function
    std::map<std::string, RTLIL::Const> output_params;
    return evaluate_function_call(func_def, arg_values, output_params);
}

YOSYS_NAMESPACE_END