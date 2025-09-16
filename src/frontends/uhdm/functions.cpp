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
            
        case vpiLeOp:  // Less than or equal (<=)
            if (operand_values.size() >= 2) {
                // Perform less-than-or-equal comparison
                bool result = operand_values[0].as_int() <= operand_values[1].as_int();
                return RTLIL::Const(result ? 1 : 0, 1);
            }
            break;
            
        case vpiLtOp:  // Less than (<)
            if (operand_values.size() >= 2) {
                // Perform less-than comparison
                bool result = operand_values[0].as_int() < operand_values[1].as_int();
                return RTLIL::Const(result ? 1 : 0, 1);
            }
            break;
            
        case vpiGeOp:  // Greater than or equal (>=)
            if (operand_values.size() >= 2) {
                // Perform greater-than-or-equal comparison
                bool result = operand_values[0].as_int() >= operand_values[1].as_int();
                return RTLIL::Const(result ? 1 : 0, 1);
            }
            break;
            
        case vpiGtOp:  // Greater than (>)
            if (operand_values.size() >= 2) {
                // Perform greater-than comparison
                bool result = operand_values[0].as_int() > operand_values[1].as_int();
                return RTLIL::Const(result ? 1 : 0, 1);
            }
            break;
            
        case vpiNeqOp:  // Not equal (!=)
            if (operand_values.size() >= 2) {
                // Perform not-equal comparison
                bool result = operand_values[0].as_int() != operand_values[1].as_int();
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


RTLIL::SigSpec UhdmImporter::extract_function_return_value(const any* stmt, const std::string& func_name, int width) {
    if (!stmt) {
        return RTLIL::SigSpec(RTLIL::State::Sx, width);
    }
    
    // Handle different statement types
    switch (stmt->UhdmType()) {
        case uhdmassignment: {
            const assignment* assign = any_cast<const assignment*>(stmt);
            if (assign && assign->Lhs()) {
                const ref_obj* lhs = any_cast<const ref_obj*>(assign->Lhs());
                if (lhs && std::string(lhs->VpiName()) == func_name) {
                    // This is an assignment to the function name - the return value
                    if (assign->Rhs()) {
                        return import_expression(any_cast<const expr*>(assign->Rhs()));
                    }
                }
            }
            break;
        }
        case uhdmbegin:
        case uhdmnamed_begin: {
            // Look for assignments in begin/end blocks
            const begin* bg = any_cast<const begin*>(stmt);
            if (bg && bg->Stmts()) {
                for (auto s : *bg->Stmts()) {
                    RTLIL::SigSpec ret = extract_function_return_value(s, func_name, width);
                    if (!ret.is_fully_undef()) {
                        return ret;
                    }
                }
            }
            break;
        }
        case uhdmif_else: {
            // For if/else, we'd need to handle both branches
            // For now, just try to extract from the if branch
            const if_else* ie = any_cast<const if_else*>(stmt);
            if (ie && ie->VpiStmt()) {
                return extract_function_return_value(ie->VpiStmt(), func_name, width);
            }
            break;
        }
        default:
            // For other statement types, return undefined
            break;
    }
    
    return RTLIL::SigSpec(RTLIL::State::Sx, width);
}

// Generate a process block for a function call
RTLIL::Process* UhdmImporter::generate_function_process(const function* func_def, const std::string& func_name,
                                                        const std::vector<RTLIL::SigSpec>& args, RTLIL::Wire* result_wire,
                                                        const func_call* fc) {
    // Create a unique process for this function call
    // Using incr_autoidx() for all temp wire numbering instead of local counter
    
    // Generate process name
    std::string proc_name;
    
    // Extract source location information
    std::string src_attr = fc ? get_src_attribute(fc) : get_src_attribute(func_def);
    std::string filename = "dut.sv"; // Default filename
    int call_line = 1; // Default line number
    
    // Parse the source attribute to extract filename and line number
    if (!src_attr.empty()) {
        size_t colon_pos = src_attr.find(':');
        if (colon_pos != std::string::npos) {
            filename = src_attr.substr(0, colon_pos);
            size_t dot_pos = src_attr.find('.', colon_pos);
            if (dot_pos != std::string::npos) {
                std::string line_str = src_attr.substr(colon_pos + 1, dot_pos - colon_pos - 1);
                call_line = std::stoi(line_str);
            }
        }
    }
    

    // Create temporary wires for function call context
    // Use Yosys global autoidx counter to match Verilog frontend naming
    // The Verilog frontend creates two contexts: one for the external result and one for internal wires
    std::string func_result_id = stringf("%s$func$%s:%d$%d", func_name.c_str(), filename.c_str(), call_line, incr_autoidx());
    std::string func_call_id = stringf("%s$func$%s:%d$%d", func_name.c_str(), filename.c_str(), call_line, incr_autoidx());

    // Use the call site line number for the process name (matching Verilog frontend)
    proc_name = stringf("$proc$%s:%d$%d", filename.c_str(), call_line, incr_autoidx());
    RTLIL::Process* proc = module->addProcess(RTLIL::escape_id(proc_name));
    
    // Add source attribute from function call location
    if (fc) {
        add_src_attribute(proc->attributes, fc);
    }
    
    // Create the root case for the process  
    proc->root_case = RTLIL::CaseRule();
    RTLIL::CaseRule* root_case = &proc->root_case;
    
    // Add placeholder empty assignments (the Verilog frontend does this for some reason)
    for (int i = 0; i < 5; i++) {
        root_case->actions.push_back(RTLIL::SigSig(RTLIL::SigSpec(), RTLIL::SigSpec()));
    }
    
    // Map function inputs to temporary wires
    std::map<std::string, RTLIL::SigSpec> input_mapping;
    std::vector<RTLIL::Wire*> arg_temp_wires;
    
    // Track local variable widths from function declaration
    std::map<std::string, int> local_var_widths;
    
    // Process local variables from function definition
    if (func_def->Variables()) {
        for (auto var : *func_def->Variables()) {
            std::string var_name = std::string(var->VpiName());
            int var_width = 1; // Default width
            
            // Check for integer variables (always 32-bit in Verilog)
            if (var->UhdmType() == uhdminteger_var) {
                var_width = 32;  // Integer variables are always 32-bit signed
            }
            // Try to get the actual width from the variable's typespec
            else if (var->UhdmType() == uhdmlogic_var) {
                const logic_var* lv = any_cast<const logic_var*>(var);
                if (lv && lv->Typespec()) {
                    const ref_typespec* rts = lv->Typespec();
                    if (rts && rts->Actual_typespec()) {
                        const typespec* actual_ts = rts->Actual_typespec();
                        // Check if it's a logic typespec with ranges
                        if (actual_ts->UhdmType() == uhdmlogic_typespec) {
                            const logic_typespec* lts = any_cast<const logic_typespec*>(actual_ts);
                            if (lts && lts->Ranges()) {
                                for (auto range : *lts->Ranges()) {
                                    // Need to evaluate range expressions with parameters available
                                    // Pass nullptr for input_mapping to use module parameters
                                    RTLIL::SigSpec left_sig = import_expression(any_cast<const expr*>(range->Left_expr()), nullptr);
                                    RTLIL::SigSpec right_sig = import_expression(any_cast<const expr*>(range->Right_expr()), nullptr);
                                    if (left_sig.is_fully_const() && right_sig.is_fully_const()) {
                                        int left_val = left_sig.as_int();
                                        int right_val = right_sig.as_int();
                                        var_width = std::abs(left_val - right_val) + 1;
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            local_var_widths[var_name] = var_width;
            if (mode_debug) {
                log("UHDM: Function %s local variable %s width=%d\n", 
                    func_name.c_str(), var_name.c_str(), var_width);
            }
        }
    }
    
    if (func_def->Io_decls() && !args.empty()) {
        int arg_idx = 0;
        for (auto io_decl : *func_def->Io_decls()) {
            if (arg_idx < args.size()) {
                std::string io_name = std::string(io_decl->VpiName());
                // Get the actual width from the parameter declaration, not from the argument
                int width = 32; // Default for integer
                
                // Check if this is an integer parameter
                if (io_decl->Typespec()) {
                    const ref_typespec* rts = io_decl->Typespec();
                    if (rts && rts->Actual_typespec()) {
                        const typespec* actual_ts = rts->Actual_typespec();
                        // Integer types are always 32-bit
                        if (actual_ts->UhdmType() == uhdminteger_typespec) {
                            width = 32;
                            if (mode_debug) {
                                log("UHDM: Function parameter %s is integer type, using width=32\n", io_name.c_str());
                            }
                        } else {
                            // For non-integer types, still use the actual argument width
                            width = args[arg_idx].size();
                            if (mode_debug) {
                                log("UHDM: Function parameter %s is not integer (type=%d), using arg width=%d\n", 
                                    io_name.c_str(), actual_ts->UhdmType(), width);
                            }
                        }
                    } else {
                        // No actual typespec
                        width = args[arg_idx].size();
                        if (mode_debug) {
                            log("UHDM: Function parameter %s has no actual typespec, using arg width=%d\n", 
                                io_name.c_str(), width);
                        }
                    }
                } else {
                    // Fallback to argument width if no typespec
                    width = args[arg_idx].size();
                    if (mode_debug) {
                        log("UHDM: Function parameter %s has no typespec, using arg width=%d\n", 
                            io_name.c_str(), width);
                    }
                }
                
                int direction = io_decl->VpiDirection();
                
                // VpiDirection: 1=input, 2=output, 3=inout
                if (direction == 1) {
                    // Input parameter - create temp wire and copy input value
                    std::string temp_name = stringf("$0\\%s.%s$%d", 
                        func_call_id.c_str(), io_name.c_str(), incr_autoidx());
                    RTLIL::Wire* temp_wire = module->addWire(RTLIL::escape_id(temp_name), width);
                    
                    // Add source attribute to temp wire
                    if (fc) {
                        add_src_attribute(temp_wire->attributes, fc);
                    }
                    
                    arg_temp_wires.push_back(temp_wire);
                    
                    // Add assignment from actual argument to temp wire
                    root_case->actions.push_back(RTLIL::SigSig(temp_wire, args[arg_idx]));
                    
                    // Map input parameter to temp wire for use in function body
                    input_mapping[io_name] = temp_wire;
                } else if (direction == 2) {
                    // Output parameter - map directly to the output wire
                    // Assignments to this parameter in the function body will
                    // directly update the output wire
                    input_mapping[io_name] = args[arg_idx];
                    if (mode_debug) {
                        log("UHDM: Mapping output parameter %s to wire with width %d\n", 
                            io_name.c_str(), width);
                    }
                } else if (direction == 3) {
                    // Inout parameter - needs both input and output handling
                    // For now, treat like output
                    input_mapping[io_name] = args[arg_idx];
                }
                
                arg_idx++;
            }
        }
    }
    
    // Create temporary result wires with proper naming using autoidx
    std::string temp_result2_name = stringf("$0\\%s.$result$%d", 
        func_call_id.c_str(), incr_autoidx());
    std::string temp_result1_name = stringf("$1\\%s.$result$%d", 
        func_call_id.c_str(), incr_autoidx());
    
    RTLIL::Wire* temp_result2_wire = module->addWire(RTLIL::escape_id(temp_result2_name), result_wire->width);
    RTLIL::Wire* temp_result1_wire = module->addWire(RTLIL::escape_id(temp_result1_name), result_wire->width);
    
    // Add source attributes to these wires
    if (fc) {
        add_src_attribute(temp_result2_wire->attributes, fc);
        add_src_attribute(temp_result1_wire->attributes, fc);
    }
    
    // Add assignment chaining for results
    root_case->actions.push_back(RTLIL::SigSig(temp_result2_wire, temp_result1_wire));
    
    std::string temp_result_final_name = stringf("$0\\%s.$result$%d",
        func_result_id.c_str(), incr_autoidx());
    RTLIL::Wire* temp_result_final_wire = module->addWire(RTLIL::escape_id(temp_result_final_name), result_wire->width);
    
    // Add source attribute to final result wire
    if (fc) {
        add_src_attribute(temp_result_final_wire->attributes, fc);
    }
    
    root_case->actions.push_back(RTLIL::SigSig(temp_result_final_wire, temp_result1_wire));
    
    // Create the main function result wire (using func_result_id for proper source location)
    std::string result_var = stringf("%s.$result", func_result_id.c_str());
    RTLIL::Wire* func_result_wire = module->wire(RTLIL::escape_id(result_var));
    if (!func_result_wire) {
        func_result_wire = module->addWire(RTLIL::escape_id(result_var), result_wire->width);
    }
    
    // Prescan the function to identify which variables are used as return values
    std::set<std::string> return_vars;
    scan_for_return_variables(func_def->Stmt(), func_name, return_vars, func_def);
    
    // Check if the function actually assigns to its return value
    bool has_return_assignment = false;
    scan_for_direct_return_assignment(func_def->Stmt(), func_name, has_return_assignment);
    
    // If function doesn't assign to its return value, initialize result to 0
    // This prevents proc_init errors when called from initial blocks
    if (!has_return_assignment) {
        log("UHDM: Function %s doesn't assign to its return value, initializing to 0\n", func_name.c_str());
        root_case->actions.push_back(RTLIL::SigSig(temp_result1_wire, RTLIL::SigSpec(0, result_wire->width)));
    }
    
    // Always add the function name itself as a return variable
    // This handles direct assignments like fsm_function = IDLE
    input_mapping[func_name] = temp_result1_wire;
    log("UHDM: Mapping function name '%s' to result wire\n", func_name.c_str());
    
    // Also add any actual local variables that are assigned to the function name
    // The prescanning found these intermediate variables
    // We already filtered out input parameters in scan_for_return_variables
    for (const auto& var : return_vars) {
        input_mapping[var] = temp_result1_wire;
        log("UHDM: Mapping return variable '%s' to result wire for function %s\n",
            var.c_str(), func_name.c_str());
    }
    
    // Process the function body into switches
    int func_temp_counter = 0; // Not used anymore, kept for compatibility
    log("UHDM: Processing function body for %s\n", func_name.c_str());
    if (func_def->Stmt()) {
        log("UHDM: Function has statement of type %d\n", func_def->Stmt()->VpiType());
    } else {
        log("UHDM: Function has no statement body!\n");
    }
    process_stmt_to_case(func_def->Stmt(), root_case, temp_result1_wire, input_mapping, func_name, func_temp_counter, func_call_id, local_var_widths);
    
    // Create nosync wires for the function context (these get set to 'x)
    std::string result_wire_name = stringf("\\%s.$result", func_call_id.c_str());
    
    RTLIL::Wire* nosync_result = module->wire(RTLIL::escape_id(result_wire_name));
    if (!nosync_result) {
        nosync_result = module->addWire(RTLIL::escape_id(result_wire_name), result_wire->width);
        nosync_result->attributes[RTLIL::escape_id("\\nosync")] = RTLIL::Const(1);
        // Add source attribute
        if (fc) {
            add_src_attribute(nosync_result->attributes, fc);
        }
    }
    
    // Create nosync wires for output parameters only (input parameters don't need them)
    std::vector<RTLIL::Wire*> nosync_arg_wires;
    if (func_def->Io_decls()) {
        for (auto io_decl : *func_def->Io_decls()) {
            int direction = io_decl->VpiDirection();
            // Skip input parameters (direction=1) - they don't need nosync wires with X assignments
            if (direction == 1) {
                continue;
            }
            
            std::string io_name = std::string(io_decl->VpiName());
            std::string nosync_name = stringf("\\%s.%s", func_call_id.c_str(), io_name.c_str());
            
            // Determine width from the corresponding argument
            int width = 1;
            int idx = 0;
            for (auto io : *func_def->Io_decls()) {
                if (io == io_decl && idx < args.size()) {
                    width = args[idx].size();
                    break;
                }
                idx++;
            }
            
            RTLIL::Wire* nosync_wire = module->wire(RTLIL::escape_id(nosync_name));
            if (!nosync_wire) {
                nosync_wire = module->addWire(RTLIL::escape_id(nosync_name), width);
                nosync_wire->attributes[RTLIL::escape_id("\\nosync")] = RTLIL::Const(1);
                // Add source attribute
                if (fc) {
                    add_src_attribute(nosync_wire->attributes, fc);
                }
            }
            nosync_arg_wires.push_back(nosync_wire);
        }
    }
    
    // Create nosync wires for local variables
    std::vector<RTLIL::Wire*> nosync_local_wires;
    for (const auto& [var_name, var_width] : local_var_widths) {
        std::string nosync_name = stringf("\\%s.%s", func_call_id.c_str(), var_name.c_str());
        
        RTLIL::Wire* nosync_wire = module->wire(RTLIL::escape_id(nosync_name));
        if (!nosync_wire) {
            nosync_wire = module->addWire(RTLIL::escape_id(nosync_name), var_width);
            nosync_wire->attributes[RTLIL::escape_id("\\nosync")] = RTLIL::Const(1);
            // Add source attribute
            if (fc) {
                add_src_attribute(nosync_wire->attributes, fc);
            }
        }
        nosync_local_wires.push_back(nosync_wire);
    }
    
    // Add sync rule to update outputs (matching Verilog frontend exactly)
    RTLIL::SyncRule* sync = new RTLIL::SyncRule;
    sync->type = RTLIL::STa;  // Always
    
    // Main result assignment - only update the function result wire directly from temp result
    sync->actions.push_back(RTLIL::SigSig(func_result_wire, temp_result_final_wire));
    
    // Set nosync wires to 'x (matching Verilog frontend order exactly)
    sync->actions.push_back(RTLIL::SigSig(nosync_result, RTLIL::SigSpec(RTLIL::State::Sx, nosync_result->width)));
    // All argument nosync wires (including state)
    for (auto nosync_wire : nosync_arg_wires) {
        sync->actions.push_back(RTLIL::SigSig(nosync_wire, RTLIL::SigSpec(RTLIL::State::Sx, nosync_wire->width)));
    }
    // All local variable nosync wires
    for (auto nosync_wire : nosync_local_wires) {
        sync->actions.push_back(RTLIL::SigSig(nosync_wire, RTLIL::SigSpec(RTLIL::State::Sx, nosync_wire->width)));
    }
    
    proc->syncs.push_back(sync);
    
    // Connect the internal function result wire to the external result wire
    module->connect(result_wire, func_result_wire);
    
    return proc;
}


// Helper function to check if a function directly assigns to its return value
void UhdmImporter::scan_for_direct_return_assignment(const any* stmt, const std::string& func_name, 
                                                     bool& found) {
    if (!stmt || found) return;
    
    int type = stmt->UhdmType();
    switch(type) {
    case uhdmassignment: {
        const assignment* assign = any_cast<const assignment*>(stmt);
        if (assign && assign->Lhs()) {
            if (assign->Lhs()->UhdmType() == uhdmref_obj) {
                const ref_obj* lhs_ref = any_cast<const ref_obj*>(assign->Lhs());
                if (lhs_ref && std::string(lhs_ref->VpiName()) == func_name) {
                    found = true;
                    return;
                }
            }
        }
        break;
    }
    
    case uhdmbegin: {
        const begin* bg = any_cast<const begin*>(stmt);
        if (bg && bg->Stmts()) {
            for (auto s : *bg->Stmts()) {
                scan_for_direct_return_assignment(s, func_name, found);
                if (found) return;
            }
        }
        break;
    }
    
    case uhdmnamed_begin: {
        const named_begin* nbg = any_cast<const named_begin*>(stmt);
        if (nbg && nbg->Stmts()) {
            for (auto s : *nbg->Stmts()) {
                scan_for_direct_return_assignment(s, func_name, found);
                if (found) return;
            }
        }
        break;
    }
    
    case uhdmif_else: {
        const if_else* ie = any_cast<const if_else*>(stmt);
        if (ie) {
            if (ie->VpiStmt()) {
                scan_for_direct_return_assignment(ie->VpiStmt(), func_name, found);
            }
            if (!found && ie->VpiElseStmt()) {
                scan_for_direct_return_assignment(ie->VpiElseStmt(), func_name, found);
            }
        }
        break;
    }
    
    case uhdmcase_stmt: {
        const case_stmt* cs = any_cast<const case_stmt*>(stmt);
        if (cs && cs->Case_items()) {
            for (auto item : *cs->Case_items()) {
                const case_item* ci = any_cast<const case_item*>(item);
                if (ci && ci->Stmt()) {
                    scan_for_direct_return_assignment(ci->Stmt(), func_name, found);
                    if (found) return;
                }
            }
        }
        break;
    }
    
    case uhdmfor_stmt: {
        const for_stmt* fs = any_cast<const for_stmt*>(stmt);
        if (fs && fs->VpiStmt()) {
            scan_for_direct_return_assignment(fs->VpiStmt(), func_name, found);
        }
        break;
    }
    
    default:
        break;
    }
}

// Helper function to scan a statement and find variables assigned to the function name
void UhdmImporter::scan_for_return_variables(const any* stmt, const std::string& func_name, 
                                              std::set<std::string>& return_vars, const function* func_def) {
    if (!stmt) return;
    
    int type = stmt->UhdmType();
    switch(type) {
    case uhdmassignment: {
        const assignment* assign = any_cast<const assignment*>(stmt);
        if (assign && assign->Lhs() && assign->Rhs()) {
            // Check if LHS is the function name
            if (assign->Lhs()->UhdmType() == uhdmref_obj) {
                const ref_obj* lhs_ref = any_cast<const ref_obj*>(assign->Lhs());
                if (lhs_ref && std::string(lhs_ref->VpiName()) == func_name) {
                    // RHS is being assigned to function name - track what it is
                    // Track intermediate variables that are assigned to the function
                    if (assign->Rhs()->UhdmType() == uhdmref_obj) {
                        const ref_obj* rhs_ref = any_cast<const ref_obj*>(assign->Rhs());
                        if (rhs_ref) {
                            std::string var_name = std::string(rhs_ref->VpiName());
                            // Check if this is a local variable (not an input parameter)
                            // by seeing if it's NOT already in input_mapping
                            // Input parameters would have been mapped already
                            bool is_input_param = false;
                            if (func_def && func_def->Io_decls()) {
                                for (auto io : *func_def->Io_decls()) {
                                    if (std::string(io->VpiName()) == var_name) {
                                        is_input_param = true;
                                        break;
                                    }
                                }
                            }
                            
                            // Also check if this is a parameter (constant) 
                            // Parameters should not be treated as return variables
                            bool is_parameter = false;
                            
                            // Check if the ref_obj has Actual_group pointing to a parameter
                            if (rhs_ref->Actual_group() && rhs_ref->Actual_group()->VpiType() == vpiParameter) {
                                is_parameter = true;
                            }
                            
                            // Also check module parameters
                            RTLIL::IdString param_id = RTLIL::escape_id(var_name);
                            if (module && module->parameter_default_values.count(param_id)) {
                                is_parameter = true;
                            }
                            
                            if (!is_input_param && !is_parameter) {
                                return_vars.insert(var_name);
                                if (mode_debug) {
                                    log("UHDM: Found return variable '%s' for function %s\n", 
                                        var_name.c_str(), func_name.c_str());
                                }
                            } else if (is_parameter && mode_debug) {
                                log("UHDM: Skipping parameter '%s' in function %s (not a return variable)\n",
                                    var_name.c_str(), func_name.c_str());
                            }
                        }
                    }
                }
            }
        }
        break;
    }
    
    case uhdmbegin: {
        const begin* bg = any_cast<const begin*>(stmt);
        if (bg && bg->Stmts()) {
            for (auto s : *bg->Stmts()) {
                scan_for_return_variables(s, func_name, return_vars, func_def);
            }
        }
        break;
    }
    
    case uhdmnamed_begin: {
        const named_begin* nbg = any_cast<const named_begin*>(stmt);
        if (nbg && nbg->Stmts()) {
            for (auto s : *nbg->Stmts()) {
                scan_for_return_variables(s, func_name, return_vars, func_def);
            }
        }
        break;
    }
    
    case uhdmif_else: {
        const if_else* ie = any_cast<const if_else*>(stmt);
        if (ie) {
            if (ie->VpiStmt()) {
                scan_for_return_variables(ie->VpiStmt(), func_name, return_vars, func_def);
            }
            if (ie->VpiElseStmt()) {
                scan_for_return_variables(ie->VpiElseStmt(), func_name, return_vars, func_def);
            }
        }
        break;
    }
    
    case uhdmcase_stmt: {
        const case_stmt* cs = any_cast<const case_stmt*>(stmt);
        if (cs && cs->Case_items()) {
            for (auto item : *cs->Case_items()) {
                const case_item* ci = any_cast<const case_item*>(item);
                if (ci && ci->Stmt()) {
                    scan_for_return_variables(ci->Stmt(), func_name, return_vars, func_def);
                }
            }
        }
        break;
    }
    
    case uhdmfor_stmt: {
        const for_stmt* fs = any_cast<const for_stmt*>(stmt);
        if (fs && fs->VpiStmt()) {
            scan_for_return_variables(fs->VpiStmt(), func_name, return_vars, func_def);
        }
        break;
    }
    
    // Add other statement types as needed
    default:
        break;
    }
}


YOSYS_NAMESPACE_END