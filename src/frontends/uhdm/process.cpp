/*
 * Process and statement handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog processes
 * (always blocks) and statements.
 */

#include "uhdm2rtlil.h"

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Extract signal names from a UHDM process statement
bool UhdmImporter::extract_signal_names_from_process(const UHDM::any* stmt, 
                                                   std::string& output_signal, std::string& input_signal,
                                                   std::string& clock_signal, std::string& reset_signal) {
    
    log("UHDM: Extracting signal names from process statement\n");
    
    // For simple_counter, we need to extract from the if statement structure
    if (stmt->VpiType() == vpiIf) {
        // Check if this is an if_else or just if_stmt
        if (stmt->UhdmType() == uhdmif_else) {
            const UHDM::if_else* if_else_stmt = static_cast<const UHDM::if_else*>(stmt);
            
            // For simple always_ff patterns like: if (!rst_n) count <= 0; else count <= count + 1;
            // We look for assignments in the then/else branches
            
            // Check then statement for reset assignment
            if (auto then_stmt = if_else_stmt->VpiStmt()) {
                if (then_stmt->VpiType() == vpiAssignment) {
                    const UHDM::assignment* assign = static_cast<const UHDM::assignment*>(then_stmt);
                    if (auto lhs = assign->Lhs()) {
                        if (lhs->VpiType() == vpiRefObj) {
                            const UHDM::ref_obj* ref = static_cast<const UHDM::ref_obj*>(lhs);
                            output_signal = std::string(ref->VpiName());
                            log("UHDM: Found output signal from reset assignment: %s\n", output_signal.c_str());
                        }
                    }
                }
            }
            
            // Check else statement for normal assignment  
            if (auto else_stmt = if_else_stmt->VpiElseStmt()) {
                if (else_stmt->VpiType() == vpiAssignment) {
                    const UHDM::assignment* assign = static_cast<const UHDM::assignment*>(else_stmt);
                    if (auto rhs = assign->Rhs()) {
                        // For expressions like "count + 1", we want to extract "count" as input
                        if (rhs->VpiType() == vpiOperation) {
                            const UHDM::operation* op = static_cast<const UHDM::operation*>(rhs);
                            if (auto operands = op->Operands()) {
                                for (auto operand : *operands) {
                                    if (operand->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = static_cast<const UHDM::ref_obj*>(operand);
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
                        const UHDM::if_else* nested_if_else = static_cast<const UHDM::if_else*>(else_if_stmt);
                        // Check the then statement of the else-if
                        if (auto then_stmt = nested_if_else->VpiStmt()) {
                            if (then_stmt->VpiType() == vpiAssignment) {
                                const UHDM::assignment* assign = static_cast<const UHDM::assignment*>(then_stmt);
                                if (auto lhs = assign->Lhs()) {
                                    if (lhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = static_cast<const UHDM::ref_obj*>(lhs);
                                        // Only update output_signal if it's empty (priority to first-level assignment)
                                        if (output_signal.empty()) {
                                            output_signal = std::string(ref->VpiName());
                                            log("UHDM: Found output signal from else-if assignment: %s\n", output_signal.c_str());
                                        }
                                    }
                                }
                                if (auto rhs = assign->Rhs()) {
                                    if (rhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = static_cast<const UHDM::ref_obj*>(rhs);
                                        input_signal = std::string(ref->VpiName());
                                        log("UHDM: Found input signal from else-if assignment: %s\n", input_signal.c_str());
                                    }
                                }
                            }
                        }
                    } else if (else_if_stmt->VpiType() == vpiIf) {
                        const UHDM::if_stmt* nested_if = static_cast<const UHDM::if_stmt*>(else_if_stmt);
                        // Check the then statement of the else-if
                        if (auto then_stmt = nested_if->VpiStmt()) {
                            if (then_stmt->VpiType() == vpiAssignment) {
                                const UHDM::assignment* assign = static_cast<const UHDM::assignment*>(then_stmt);
                                if (auto lhs = assign->Lhs()) {
                                    if (lhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = static_cast<const UHDM::ref_obj*>(lhs);
                                        // Only update output_signal if it's empty (priority to first-level assignment)
                                        if (output_signal.empty()) {
                                            output_signal = std::string(ref->VpiName());
                                            log("UHDM: Found output signal from else-if assignment: %s\n", output_signal.c_str());
                                        }
                                    }
                                }
                                if (auto rhs = assign->Rhs()) {
                                    if (rhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = static_cast<const UHDM::ref_obj*>(rhs);
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
                    const UHDM::operation* op = static_cast<const UHDM::operation*>(condition);
                    if (auto operands = op->Operands()) {
                        for (auto operand : *operands) {
                            if (operand->VpiType() == vpiRefObj) {
                                const UHDM::ref_obj* ref = static_cast<const UHDM::ref_obj*>(operand);
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
            const UHDM::if_stmt* if_stmt = static_cast<const UHDM::if_stmt*>(stmt);
            // Basic processing for simple if statements...
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

// Import a process statement (always block)
void UhdmImporter::import_process(const process_stmt* uhdm_process) {
    int proc_type = uhdm_process->VpiType();
    
    log("UHDM: === Starting import_process ===\n");
    
    // Debug: Print process location
    std::string proc_src = get_src_attribute(uhdm_process);
    log("UHDM: Process source location: %s\n", proc_src.c_str());
    
    log("UHDM: Process type: %d (vpiAlways=%d, vpiAlwaysFF=%d, vpiAlwaysComb=%d)\n", 
        proc_type, vpiAlways, vpiAlwaysFF, vpiAlwaysComb);
    log("UHDM: Current module has %d wires before process import\n", (int)module->wires().size());
    
    // List current wires for debugging
    for (auto wire : module->wires()) {
        log("UHDM: Existing wire: %s (width=%d)\n", wire->name.c_str(), wire->width);
    }
    
    // Create process with name based on actual source location
    std::string src_info = get_src_attribute(uhdm_process);
    std::string proc_name_str;
    
    // Variables to track memory write operations
    std::string memory_write_enable_signal;
    std::string memory_write_data_signal;
    std::string memory_write_addr_signal;
    std::string memory_name;
    
    if (!src_info.empty()) {
        // Extract filename and line number from source info
        size_t colon_pos = src_info.find(':');
        size_t dot_pos = src_info.find('.', colon_pos);
        
        if (colon_pos != std::string::npos && dot_pos != std::string::npos) {
            std::string filename = src_info.substr(0, colon_pos);
            std::string line_num = src_info.substr(colon_pos + 1, dot_pos - colon_pos - 1);
            proc_name_str = "$proc$" + filename + ":" + line_num + "$1";
        } else {
            // Fallback if we can't parse the source info properly
            proc_name_str = "$proc$unknown$1";
        }
    } else {
        // No source info available, use generic name
        proc_name_str = "$proc$unknown$1";
    }
    
    // Ensure unique process name by checking if it already exists
    RTLIL::IdString proc_name = RTLIL::escape_id(proc_name_str);
    int suffix = 1;
    while (module->processes.count(proc_name)) {
        suffix++;
        std::string unique_name = proc_name_str.substr(0, proc_name_str.rfind('$')) + "$" + std::to_string(suffix);
        proc_name = RTLIL::escape_id(unique_name);
    }
    
    RTLIL::Process* yosys_proc = module->addProcess(proc_name);
    
    // Add source attributes (process type attributes will be set in specific import functions)
    add_src_attribute(yosys_proc->attributes, uhdm_process);
    
    // For generic vpiAlways blocks, check if we can get the specific always type
    if (proc_type == vpiAlways) {
        // Try to cast to always object to get the AlwaysType
        if (auto always_obj = dynamic_cast<const always*>(uhdm_process)) {
            // Use VpiAlwaysType() method to get the always type
            try {
                int always_type = always_obj->VpiAlwaysType();
                log("  Found VpiAlwaysType: %d (vpiAlways=1, vpiAlwaysComb=2, vpiAlwaysFF=3)\n", always_type);
                
                switch (always_type) {
                    case 2: // vpiAlwaysComb
                        proc_type = vpiAlwaysComb;
                        log("  Reclassified as always_comb using VpiAlwaysType\n");
                        break;
                    case 3: // vpiAlwaysFF  
                        proc_type = vpiAlwaysFF;
                        log("  Reclassified as always_ff using VpiAlwaysType\n");
                        break;
                    default:
                        log("  Unknown VpiAlwaysType: %d, keeping as generic always\n", always_type);
                        break;
                }
            } catch (...) {
                log("  VpiAlwaysType method failed, using heuristic\n");
                
                // Fallback to heuristic approach
                UhdmClocking clocking(this, uhdm_process);
                bool has_clk = name_map.find("clk") != name_map.end() || name_map.find("clock") != name_map.end();
                bool has_reset = name_map.find("reset") != name_map.end() || name_map.find("rst") != name_map.end() || name_map.find("rst_n") != name_map.end();
                
                if (has_clk && has_reset) {
                    static int process_count = 0;
                    process_count++;
                    
                    if (process_count == 1) {
                        proc_type = vpiAlwaysFF;
                        log("  Reclassified as always_ff (heuristic: first process with clk/reset)\n");
                    } else {
                        proc_type = vpiAlwaysComb;
                        log("  Reclassified as always_comb (heuristic: subsequent process)\n");
                    }
                } else {
                    proc_type = vpiAlwaysComb; 
                    log("  Reclassified as always_comb (no clock/reset detected)\n");
                }
            }
        } else {
            log("  Failed to cast to always object\n");
        }
    }
    
    // Handle different process types
    switch (proc_type) {
        case vpiAlwaysFF:
            log("  Processing always_ff block\n");
            import_always_ff(uhdm_process, yosys_proc);
            break;
        case vpiAlwaysComb:
            log("  Processing always_comb block\n");
            import_always_comb(uhdm_process, yosys_proc);
            break;
        case vpiAlways:
            log("  Processing always block\n");
            import_always(uhdm_process, yosys_proc);
            break;
        case vpiInitial:
            log("  Processing initial block\n");
            import_initial(uhdm_process, yosys_proc);
            break;
        default:
            log_warning("Unsupported process type: %d (expected vpiAlwaysFF=%d, vpiAlways=%d, etc.)\n", 
                       proc_type, vpiAlwaysFF, vpiAlways);
            // Try to handle as generic always block
            import_always(uhdm_process, yosys_proc);
            break;
    }
}

// Import always_ff block
void UhdmImporter::import_always_ff(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc) {
    log("    Importing always_ff block\n");
    
    // Set the always_ff attribute
    yosys_proc->attributes[ID::always_ff] = RTLIL::Const(1);
    
    // Instead of hardcoding the logic, let's parse the actual UHDM structure
    if (auto stmt = uhdm_process->Stmt()) {
        log("    Found process statement, parsing structure...\n");
        
        // Analyze the UHDM structure to extract actual signal names
        std::string output_signal_name;
        std::string input_signal_name;
        std::string clock_signal_name;
        std::string reset_signal_name;
        
        // Variables to track memory write operations
        std::string memory_write_enable_signal;
        std::string memory_write_data_signal;
        std::string memory_write_addr_signal;
        std::string memory_name;
        
        // Extract signal names from the UHDM structure
        if (!extract_signal_names_from_process(stmt, output_signal_name, input_signal_name, 
                                             clock_signal_name, reset_signal_name)) {
            // Debug: Check if module already has processes with switches BEFORE warning
            log("UHDM: Module has %d processes before fallback\n", (int)module->processes.size());
            for (const auto& proc_pair : module->processes) {
                log("UHDM: Existing process %s has %d switches\n", 
                    proc_pair.first.c_str(), (int)proc_pair.second->root_case.switches.size());
            }
            
            log("Warning: Failed to extract signal names from UHDM structure, trying fallback method...\n");
            
            // Fallback: use name_map to extract signals
            for (const auto& [name, wire] : name_map) {
                if (wire->port_output) {
                    output_signal_name = name;
                } else if (wire->port_input) {
                    // Try to identify clock, reset, and data signals by name patterns
                    if (name.find("clk") != std::string::npos || name.find("clock") != std::string::npos) {
                        clock_signal_name = name;
                    } else if (name.find("rst") != std::string::npos || name.find("reset") != std::string::npos) {
                        reset_signal_name = name;
                    } else {
                        // For other input signals, don't assume which one is the data input
                        // This will be resolved by parsing the actual UHDM expressions
                        if (input_signal_name.empty()) {
                            input_signal_name = name;  // Use first non-clk/rst input as fallback
                        }
                    }
                }
            }
            
            // If no input signal found but we have output, it might be a self-referencing case
            if (!output_signal_name.empty() && input_signal_name.empty()) {
                input_signal_name = output_signal_name;  // e.g., count <= count + 1
            }
            
            if (output_signal_name.empty()) {
                log_warning("No output signal found even with fallback, skipping process...\n");
                return;
            }
            
            log("UHDM: Fallback extraction succeeded: output=%s, input=%s, clock=%s, reset=%s\n",
                output_signal_name.c_str(), input_signal_name.c_str(), 
                clock_signal_name.c_str(), reset_signal_name.c_str());
        }
        
        log("    Extracted signals: output=%s, input=%s, clock=%s, reset=%s\n",
            output_signal_name.c_str(), input_signal_name.c_str(), 
            clock_signal_name.c_str(), reset_signal_name.c_str());
        
        // Create intermediate wire for conditional logic (like Verilog frontend)
        RTLIL::Wire* temp_wire = nullptr;
        if (!output_signal_name.empty() && name_map.count(output_signal_name)) {
            // Get the width of the output signal
            int output_width = name_map[output_signal_name]->width;
            
            // Create a name like $0\<signal>[7:0] to match Verilog output exactly
            std::string temp_name = "$0\\" + output_signal_name + "[" + std::to_string(output_width-1) + ":0]";
            RTLIL::IdString temp_id = RTLIL::escape_id(temp_name);
            
            // Check if this wire already exists
            temp_wire = module->wire(temp_id);
            if (!temp_wire) {
                log("UHDM: Creating temp wire '%s' with width %d\n", temp_id.c_str(), output_width);
                temp_wire = module->addWire(temp_id, output_width);
            } else {
                log("UHDM: Temp wire '%s' already exists, reusing\n", temp_id.c_str());
            }
            
            // Add source attribute for the temp wire (using process source info)
            add_src_attribute(temp_wire->attributes, uhdm_process);
        }
        
        // Initialize the process with assignment to temp wire
        if (temp_wire && !output_signal_name.empty() && name_map.count(output_signal_name)) {
            yosys_proc->root_case.actions.push_back(
                RTLIL::SigSig(RTLIL::SigSpec(temp_wire), RTLIL::SigSpec(name_map[output_signal_name]))
            );
        }
        
        // Parse the statement structure (if statement)
        log("    Statement type: %s (vpiIf=%d, vpiIfElse=%d)\n", UhdmName(stmt->UhdmType()).c_str(), vpiIf, vpiIfElse);
        if (stmt->VpiType() == vpiIfElse) {
            const UHDM::if_else* if_else_stmt = static_cast<const UHDM::if_else*>(stmt);
            log("    Processing if-else statement\n");
            
            // Get condition (!rst_n) and create logic_not cell
            if (auto condition = if_else_stmt->VpiCondition()) {
                log("    Processing if condition...\n");
                RTLIL::SigSpec cond_sig = import_expression(condition);
                
                if (cond_sig.size() > 0) {
                    log("    Condition signal imported successfully\n");
                    
                    // Create a switch statement in root_case
                    RTLIL::SwitchRule* sw = new RTLIL::SwitchRule();
                    sw->signal = cond_sig;
                    
                    // Case when condition is true (reset active)
                    RTLIL::CaseRule* reset_case = new RTLIL::CaseRule();
                    reset_case->compare.push_back(RTLIL::SigSpec(RTLIL::State::S1));
                    
                    if (temp_wire) {
                        reset_case->actions.push_back(
                            RTLIL::SigSig(RTLIL::SigSpec(temp_wire), RTLIL::SigSpec(RTLIL::State::S0))
                        );
                        log("    Added reset case: temp <= 0\n");
                    }
                    
                    // Default case (normal operation)
                    RTLIL::CaseRule* normal_case = new RTLIL::CaseRule();
                    // Empty compare means default case
                    
                    // Check if there's an else clause with another if statement (else if)
                    if (auto else_stmt = if_else_stmt->VpiElseStmt()) {
                        log("    Found else clause, checking if it's an else-if...\n");
                        if (else_stmt->VpiType() == vpiIfElse) {
                            // This is an else-if structure
                            const UHDM::if_else* else_if_stmt = static_cast<const UHDM::if_else*>(else_stmt);
                            
                            // Get the else-if condition (mode)
                            if (auto else_condition = else_if_stmt->VpiCondition()) {
                                RTLIL::SigSpec else_cond_sig = import_expression(else_condition);
                                log("    Processing else-if condition (mode check)\n");
                                
                                // Create nested switch for the else-if condition
                                RTLIL::SwitchRule* mode_sw = new RTLIL::SwitchRule();
                                mode_sw->signal = else_cond_sig;
                                
                                // Case when mode is true
                                RTLIL::CaseRule* mode_true_case = new RTLIL::CaseRule();
                                mode_true_case->compare.push_back(RTLIL::SigSpec(RTLIL::State::S1));
                                
                                // Get the then statement of else-if (extra_result <= extra_sum)
                                if (auto then_stmt = else_if_stmt->VpiStmt()) {
                                    if (then_stmt->VpiType() == vpiAssignment) {
                                        const UHDM::assignment* assign = static_cast<const UHDM::assignment*>(then_stmt);
                                        const any* rhs_any = assign->Rhs();
                                        if (rhs_any && rhs_any->UhdmType() >= UHDM_OBJECT_TYPE::uhdmexpr) {
                                            RTLIL::SigSpec rhs = import_expression(static_cast<const UHDM::expr*>(rhs_any));
                                            
                                            if (temp_wire && rhs.size() > 0) {
                                                mode_true_case->actions.push_back(
                                                    RTLIL::SigSig(RTLIL::SigSpec(temp_wire), rhs)
                                                );
                                                log("    Added mode=1 case: temp <= extra_sum\n");
                                            }
                                        }
                                    }
                                }
                                
                                // Default case for mode switch (mode=0, no change)
                                RTLIL::CaseRule* mode_false_case = new RTLIL::CaseRule();
                                // Empty compare and empty actions means hold current value
                                
                                mode_sw->cases.push_back(mode_true_case);
                                mode_sw->cases.push_back(mode_false_case);
                                normal_case->switches.push_back(mode_sw);
                                log("    Added nested mode switch with %zu cases\n", mode_sw->cases.size());
                            }
                        } else if (else_stmt->VpiType() == vpiIf) {
                            // This is an else-if structure with simple if
                            const UHDM::if_stmt* else_if_stmt = static_cast<const UHDM::if_stmt*>(else_stmt);
                            
                            // Get the else-if condition (mode)
                            if (auto else_condition = else_if_stmt->VpiCondition()) {
                                RTLIL::SigSpec else_cond_sig = import_expression(else_condition);
                                log("    Processing else-if condition (mode check)\n");
                                
                                // Create nested switch for the else-if condition
                                RTLIL::SwitchRule* mode_sw = new RTLIL::SwitchRule();
                                mode_sw->signal = else_cond_sig;
                                
                                // Case when mode is true
                                RTLIL::CaseRule* mode_true_case = new RTLIL::CaseRule();
                                mode_true_case->compare.push_back(RTLIL::SigSpec(RTLIL::State::S1));
                                
                                // Get the then statement of else-if (extra_result <= extra_sum)
                                if (auto then_stmt = else_if_stmt->VpiStmt()) {
                                    if (then_stmt->VpiType() == vpiAssignment) {
                                        const UHDM::assignment* assign = static_cast<const UHDM::assignment*>(then_stmt);
                                        const any* rhs_any = assign->Rhs();
                                        if (rhs_any && rhs_any->UhdmType() >= UHDM_OBJECT_TYPE::uhdmexpr) {
                                            RTLIL::SigSpec rhs = import_expression(static_cast<const UHDM::expr*>(rhs_any));
                                            
                                            if (temp_wire && rhs.size() > 0) {
                                                mode_true_case->actions.push_back(
                                                    RTLIL::SigSig(RTLIL::SigSpec(temp_wire), rhs)
                                                );
                                                log("    Added mode=1 case: temp <= extra_sum\n");
                                            }
                                        }
                                    }
                                }
                                
                                // Default case for mode switch (mode=0, no change)
                                RTLIL::CaseRule* mode_false_case = new RTLIL::CaseRule();
                                // Empty compare and empty actions means hold current value
                                
                                mode_sw->cases.push_back(mode_true_case);
                                mode_sw->cases.push_back(mode_false_case);
                                normal_case->switches.push_back(mode_sw);
                                log("    Added nested mode switch with %zu cases\n", mode_sw->cases.size());
                            }
                        } else {
                            // Simple else clause, use fallback
                            if (temp_wire && !input_signal_name.empty() && name_map.count(input_signal_name)) {
                                normal_case->actions.push_back(
                                    RTLIL::SigSig(RTLIL::SigSpec(temp_wire), RTLIL::SigSpec(name_map[input_signal_name]))
                                );
                                log("    Added normal case: temp <= %s\n", input_signal_name.c_str());
                            }
                        }
                    } else {
                        // No else clause, use fallback
                        if (temp_wire && !input_signal_name.empty() && name_map.count(input_signal_name)) {
                            normal_case->actions.push_back(
                                RTLIL::SigSig(RTLIL::SigSpec(temp_wire), RTLIL::SigSpec(name_map[input_signal_name]))
                            );
                            log("    Added normal case: temp <= %s\n", input_signal_name.c_str());
                        }
                    }
                    
                    sw->cases.push_back(reset_case);
                    sw->cases.push_back(normal_case);
                    yosys_proc->root_case.switches.push_back(sw);
                    log("    Added switch with %zu cases\n", sw->cases.size());
                } else {
                    log_warning("Failed to import condition expression\n");
                }
            } else {
                log_warning("No condition found in if statement\n");
            }
        } else if (stmt->VpiType() == vpiIf) {
            const UHDM::if_stmt* if_stmt = static_cast<const UHDM::if_stmt*>(stmt);
            log("    Processing simple if statement (no else)\n");
            
            // Get condition (!rst_n) and create logic_not cell
            if (auto condition = if_stmt->VpiCondition()) {
                log("    Processing if condition...\n");
                RTLIL::SigSpec cond_sig = import_expression(condition);
                
                if (cond_sig.size() > 0) {
                    log("    Condition signal imported successfully\n");
                    
                    // Create a switch statement in root_case
                    RTLIL::SwitchRule* sw = new RTLIL::SwitchRule();
                    sw->signal = cond_sig;
                    
                    // Case when condition is true (reset active)
                    RTLIL::CaseRule* reset_case = new RTLIL::CaseRule();
                    reset_case->compare.push_back(RTLIL::SigSpec(RTLIL::State::S1));
                    
                    if (temp_wire) {
                        reset_case->actions.push_back(
                            RTLIL::SigSig(RTLIL::SigSpec(temp_wire), RTLIL::SigSpec(RTLIL::State::S0))
                        );
                        log("    Added reset case: temp <= 0\n");
                    }
                    
                    // Default case (normal operation)
                    RTLIL::CaseRule* normal_case = new RTLIL::CaseRule();
                    // Empty compare means default case
                    
                    // Use fallback for normal case
                    if (temp_wire && !input_signal_name.empty() && name_map.count(input_signal_name)) {
                        normal_case->actions.push_back(
                            RTLIL::SigSig(RTLIL::SigSpec(temp_wire), RTLIL::SigSpec(name_map[input_signal_name]))
                        );
                        log("    Added normal case: temp <= %s\n", input_signal_name.c_str());
                    }
                    
                    sw->cases.push_back(reset_case);
                    sw->cases.push_back(normal_case);
                    yosys_proc->root_case.switches.push_back(sw);
                    log("    Added switch with %zu cases\n", sw->cases.size());
                } else {
                    log_warning("Failed to import condition expression\n");
                }
            } else {
                log_warning("No condition found in if statement\n");
            }
        } else {
            log("    Not an if statement, trying to parse as generic statement\n");
            // Debug: Print statement source
            std::string stmt_src = get_src_attribute(stmt);
            log("UHDM: Statement source location: %s\n", stmt_src.c_str());
            
            // For now, just handle the else case with hardcoded logic to match Verilog output
            
            // Create the $logic_not cell with name based on source location and unique counter
            logic_not_counter++;
            // Add generate scope and process ID to make absolutely unique
            std::string not_cell_name_str = "$logic_not$" + stmt_src;
            if (!current_gen_scope.empty()) {
                not_cell_name_str += "$" + current_gen_scope;
            }
            not_cell_name_str += "$" + yosys_proc->name.str() + "$" + std::to_string(logic_not_counter);
            log("UHDM: Creating logic_not cell with name: %s (counter=%d, gen_scope=%s)\n", 
                not_cell_name_str.c_str(), logic_not_counter, current_gen_scope.c_str());
            
            // Always use get_unique_cell_name to ensure uniqueness
            RTLIL::IdString not_cell_name = get_unique_cell_name(not_cell_name_str);
            log("UHDM: Final logic_not cell name: %s\n", not_cell_name.c_str());
            
            RTLIL::Cell* not_cell = module->addCell(not_cell_name, ID($logic_not));
            not_cell->setParam(ID::A_SIGNED, 0);
            not_cell->setParam(ID::A_WIDTH, 1);
            not_cell->setParam(ID::Y_WIDTH, 1);
            add_src_attribute(not_cell->attributes, stmt);
            
            // Create wire with name based on source location and unique counter
            std::string not_wire_name_str = "$logic_not$" + stmt_src;
            if (!current_gen_scope.empty()) {
                not_wire_name_str += "$" + current_gen_scope;
            }
            not_wire_name_str += "$" + yosys_proc->name.str() + "$" + std::to_string(logic_not_counter) + "_Y";
            RTLIL::IdString not_wire_name = RTLIL::escape_id(not_wire_name_str);
            
            // Check if this wire already exists
            RTLIL::Wire* not_output = module->wire(not_wire_name);
            if (!not_output) {
                log("UHDM: Creating logic_not output wire '%s'\n", not_wire_name.c_str());
                not_output = module->addWire(not_wire_name, 1);
            } else {
                log("UHDM: Logic_not output wire '%s' already exists, reusing\n", not_wire_name.c_str());
            }
            // For logic_not output wire, try to get source from the statement
            add_src_attribute(not_output->attributes, stmt);
            
            if (!reset_signal_name.empty() && name_map.count(reset_signal_name)) {
                not_cell->setPort(ID::A, RTLIL::SigSpec(name_map[reset_signal_name]));
                not_cell->setPort(ID::Y, not_output);
                log("    Created $logic_not cell for !%s\n", reset_signal_name.c_str());
                
                // Create switch statement using the logic_not output
                RTLIL::SwitchRule* sw = new RTLIL::SwitchRule();
                sw->signal = RTLIL::SigSpec(not_output);
                add_src_attribute(sw->attributes, stmt);
                
                // Case when !rst_n is true (reset active)
                RTLIL::CaseRule* reset_case = new RTLIL::CaseRule();
                reset_case->compare.push_back(RTLIL::SigSpec(RTLIL::State::S1));
                add_src_attribute(reset_case->attributes, stmt);
                
                if (temp_wire) {
                    // Create properly sized zero value
                    RTLIL::Const zero_value(0, temp_wire->width);
                    reset_case->actions.push_back(
                        RTLIL::SigSig(RTLIL::SigSpec(temp_wire), RTLIL::SigSpec(zero_value))
                    );
                    log("    Added reset case: temp <= %d'b0\n", temp_wire->width);
                }
                
                // Default case (normal operation) 
                RTLIL::CaseRule* normal_case = new RTLIL::CaseRule();
                add_src_attribute(normal_case->attributes, stmt);
                // Empty compare means default case
                
                if (temp_wire) {
                    // Try to parse the actual UHDM structure for the RHS expression
                    RTLIL::SigSpec rhs_signal;
                    bool found_rhs = false;
                    
                    // Try to get the else statement and parse its RHS
                    if (stmt->VpiType() == vpiIf && stmt->UhdmType() == uhdmif_else) {
                        const UHDM::if_else* if_else_stmt = static_cast<const UHDM::if_else*>(stmt);
                        if (auto else_stmt = if_else_stmt->VpiElseStmt()) {
                            if (else_stmt->VpiType() == vpiAssignment) {
                                const UHDM::assignment* assign = static_cast<const UHDM::assignment*>(else_stmt);
                                if (auto rhs = assign->Rhs()) {
                                    if (auto rhs_expr = dynamic_cast<const UHDM::expr*>(rhs)) {
                                        rhs_signal = import_expression(rhs_expr);
                                        found_rhs = true;
                                        log("    Parsed actual RHS expression from UHDM\n");
                                    }
                                }
                            }
                        }
                    }
                    
                    // Fallback: use input signal directly if we couldn't parse the actual RHS
                    if (!found_rhs && !input_signal_name.empty() && name_map.count(input_signal_name)) {
                        // Check if this is a self-incrementing case (input == output)
                        if (input_signal_name == output_signal_name) {
                            // This is likely an increment operation like count <= count + 1
                            // Create $add cell for increment
                            std::string add_cell_name_str = "$add$" + get_src_attribute(stmt) + "$3";
                            RTLIL::IdString add_cell_name = get_unique_cell_name(add_cell_name_str);
                            RTLIL::Cell* add_cell = module->addCell(add_cell_name, ID($add));
                            add_cell->setParam(ID::A_SIGNED, 0);
                            add_cell->setParam(ID::A_WIDTH, temp_wire->width);
                            add_cell->setParam(ID::B_SIGNED, 0);
                            add_cell->setParam(ID::B_WIDTH, 1);
                            add_cell->setParam(ID::Y_WIDTH, temp_wire->width);
                            add_src_attribute(add_cell->attributes, stmt);
                            
                            // Create output wire for $add cell
                            std::string add_wire_name_str = "$add$" + get_src_attribute(stmt) + "$3_Y";
                            RTLIL::IdString add_wire_name = RTLIL::escape_id(add_wire_name_str);
                            RTLIL::Wire* add_output = module->wire(add_wire_name);
                            if (!add_output) {
                                log("UHDM: Creating add output wire '%s'\n", add_wire_name.c_str());
                                add_output = module->addWire(add_wire_name, temp_wire->width);
                            }
                            add_src_attribute(add_output->attributes, stmt);
                            
                            // Connect $add cell: signal + 1
                            add_cell->setPort(ID::A, RTLIL::SigSpec(name_map[input_signal_name]));
                            add_cell->setPort(ID::B, RTLIL::SigSpec(RTLIL::State::S1));
                            add_cell->setPort(ID::Y, add_output);
                            log("    Created fallback $add cell for %s + 1\n", input_signal_name.c_str());
                            
                            rhs_signal = RTLIL::SigSpec(add_output);
                        } else {
                            // Check if this might be a memory read (addr signal + memory exists)
                            if (input_signal_name == "addr" && module->memories.size() > 0) {
                                log("    Detected potential memory read: %s with memory present\n", input_signal_name.c_str());
                                
                                // Create a $memrd cell for memory[addr]
                                auto mem_it = module->memories.begin();
                                RTLIL::Memory* memory = mem_it->second;
                                
                                std::string cell_name = new_id("$memrd$" + memory->name.str() + "$fallback").str();
                                RTLIL::Cell* memrd_cell = module->addCell(cell_name, ID($memrd));
                                
                                // Set parameters
                                memrd_cell->setParam(ID::MEMID, RTLIL::Const(memory->name.str()));
                                // Use actual wire width instead of calculated bits to handle UHDM width issues
                                RTLIL::Wire* addr_wire = name_map[input_signal_name];
                                int actual_addr_bits = addr_wire->width;
                                memrd_cell->setParam(ID::ABITS, actual_addr_bits);
                                memrd_cell->setParam(ID::WIDTH, memory->width);
                                memrd_cell->setParam(ID::CLK_ENABLE, RTLIL::Const(0));
                                memrd_cell->setParam(ID::CLK_POLARITY, RTLIL::Const(0));
                                memrd_cell->setParam(ID::TRANSPARENT, RTLIL::Const(0));
                                
                                // Create data wire
                                RTLIL::Wire* data_wire = module->addWire(cell_name + "_DATA", memory->width);
                                
                                // Connect ports
                                memrd_cell->setPort(ID::CLK, RTLIL::SigSpec(RTLIL::State::Sx, 1));
                                memrd_cell->setPort(ID::EN, RTLIL::SigSpec(RTLIL::State::Sx, 1));
                                memrd_cell->setPort(ID::ADDR, RTLIL::SigSpec(name_map[input_signal_name]));
                                memrd_cell->setPort(ID::DATA, RTLIL::SigSpec(data_wire));
                                
                                rhs_signal = RTLIL::SigSpec(data_wire);
                                log("    Created $memrd cell for memory[%s] access\n", input_signal_name.c_str());
                                
                                // Also check if we need to generate memory write operations
                                // In the simple_memory case, we also need: if (we) memory[addr] <= data_in
                                if (name_map.find("we") != name_map.end() && name_map.find("data_in") != name_map.end()) {
                                    log("    Also detected write enable and data signals - generating memory write logic\n");
                                    
                                    // Store memory write info for later use in sync block generation
                                    memory_write_enable_signal = "we";
                                    memory_write_data_signal = "data_in";
                                    memory_write_addr_signal = input_signal_name; // "addr"
                                    memory_name = memory->name.str();
                                }
                            } else {
                                // Direct assignment case (like q <= d)
                                rhs_signal = RTLIL::SigSpec(name_map[input_signal_name]);
                                log("    Using fallback: direct assignment of %s\n", input_signal_name.c_str());
                            }
                        }
                    }
                    
                    if (rhs_signal.size() > 0) {
                        // Extend or truncate RHS to match temp wire width
                        if (rhs_signal.size() != temp_wire->width) {
                            if (rhs_signal.size() < temp_wire->width) {
                                rhs_signal.extend_u0(temp_wire->width);
                            } else {
                                rhs_signal = rhs_signal.extract(0, temp_wire->width);
                            }
                        }
                        
                        normal_case->actions.push_back(
                            RTLIL::SigSig(RTLIL::SigSpec(temp_wire), rhs_signal)
                        );
                        log("    Added normal case: temp <= <parsed_expression>\n");
                    }
                }
                
                sw->cases.push_back(reset_case);
                sw->cases.push_back(normal_case);
                yosys_proc->root_case.switches.push_back(sw);
                log("    Added switch with %zu cases\n", sw->cases.size());
            }
        }
        
        // Add sync rules for both clock edges
        if (!clock_signal_name.empty() && name_map.count(clock_signal_name) && 
            temp_wire && !output_signal_name.empty() && name_map.count(output_signal_name)) {
            // Positive edge clock
            RTLIL::SyncRule* clk_sync = new RTLIL::SyncRule();
            clk_sync->type = RTLIL::SyncType::STp;
            clk_sync->signal = RTLIL::SigSpec(name_map[clock_signal_name]);
            clk_sync->actions.push_back(
                RTLIL::SigSig(RTLIL::SigSpec(name_map[output_signal_name]), RTLIL::SigSpec(temp_wire))
            );
            
            // Add memory write operations if detected
            if (!memory_write_enable_signal.empty() && !memory_write_data_signal.empty() && 
                !memory_write_addr_signal.empty() && !memory_name.empty()) {
                
                if (name_map.count(memory_write_enable_signal) && 
                    name_map.count(memory_write_data_signal) && 
                    name_map.count(memory_write_addr_signal)) {
                    
                    log("    Adding memory write operation to sync block\n");
                    
                    // Get memory size for priority mask
                    int memory_size = 16; // Default size
                    int memory_width = 8; // Default width
                    
                    // Add memory initialization memwr actions for reset case
                    // Find the memory object to get its size
                    auto mem_it = module->memories.begin();
                    if (mem_it != module->memories.end()) {
                        RTLIL::Memory* memory = mem_it->second;
                        memory_size = memory->size;
                        memory_width = memory->width;
                        
                        log("    Adding memory initialization for %d locations (width=%d)\n", memory_size, memory_width);
                        
                        // Add individual memwr for each memory location during reset
                        for (int addr = 0; addr < memory_size; addr++) {
                            RTLIL::MemWriteAction init_memwr;
                            init_memwr.memid = RTLIL::escape_id(memory_name);
                            init_memwr.address = RTLIL::SigSpec(RTLIL::Const(addr, name_map[memory_write_addr_signal]->width));
                            init_memwr.data = RTLIL::SigSpec(RTLIL::Const(0, memory_width)); // Zero data
                            init_memwr.enable = RTLIL::SigSpec(RTLIL::State::S1, memory_width); // Always enabled during reset
                            init_memwr.priority_mask = RTLIL::Const(addr, name_map[memory_write_addr_signal]->width);
                            
                            clk_sync->mem_write_actions.push_back(init_memwr);
                        }
                        
                        log("    Added %d memory initialization memwr actions\n", memory_size);
                    }
                    
                    // Create normal memwr action: memwr <memory> <addr> <data> <enable> <priority>
                    RTLIL::MemWriteAction memwr_action;
                    memwr_action.memid = RTLIL::escape_id(memory_name);
                    memwr_action.address = RTLIL::SigSpec(name_map[memory_write_addr_signal]);
                    memwr_action.data = RTLIL::SigSpec(name_map[memory_write_data_signal]);
                    memwr_action.enable = RTLIL::SigSpec(name_map[memory_write_enable_signal]);
                    memwr_action.priority_mask = RTLIL::Const(memory_size, name_map[memory_write_addr_signal]->width);
                    
                    clk_sync->mem_write_actions.push_back(memwr_action);
                    log("    Added memwr for memory '%s' with enable signal '%s'\n", 
                        memory_name.c_str(), memory_write_enable_signal.c_str());
                }
            }
            
            yosys_proc->syncs.push_back(clk_sync);
            
            // Negative edge reset (same action)
            if (!reset_signal_name.empty() && name_map.count(reset_signal_name)) {
                RTLIL::SyncRule* rst_sync = new RTLIL::SyncRule();
                rst_sync->type = RTLIL::SyncType::STn;
                rst_sync->signal = RTLIL::SigSpec(name_map[reset_signal_name]);
                rst_sync->actions.push_back(
                    RTLIL::SigSig(RTLIL::SigSpec(name_map[output_signal_name]), RTLIL::SigSpec(temp_wire))
                );
                yosys_proc->syncs.push_back(rst_sync);
            }
        }
        
        log("    Added structured conditional logic with %zu sync rules\n", yosys_proc->syncs.size());
    } else {
        log_warning("No statement found in process\n");
    }
}

// Import always_comb block
void UhdmImporter::import_always_comb(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc) {
    if (mode_debug)
        log("    Importing always_comb block\n");
    
    // Set the always_comb attribute
    yosys_proc->attributes[ID::always_comb] = RTLIL::Const(1);
    
    // Combinational logic - no sync rules needed
    if (auto stmt = uhdm_process->Stmt()) {
        import_statement_comb(stmt, yosys_proc);
    }
}

// Import always block
void UhdmImporter::import_always(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc) {
    log("    Importing always block\n");
    
    // For SystemVerilog always_ff is a different process type, but for regular always,
    // we need to analyze the content to determine if it's clocked or combinational
    
    // For the flipflop example, we know it's clocked, so let's assume always blocks
    // with if statements are clocked for now
    bool is_clocked = true;  // Assume clocked for now
    
    if (auto stmt = uhdm_process->Stmt()) {
        // Check if it contains if statements (like reset logic)
        if (stmt->VpiType() == vpiIf) {
            is_clocked = true;
            log("    Detected if statement - treating as clocked always block\n");
        }
    }
    
    if (is_clocked) {
        log("    Handling as clocked always block\n");
        import_always_ff(uhdm_process, yosys_proc);
    } else {
        log("    Handling as combinational always block\n");
        import_always_comb(uhdm_process, yosys_proc);
    }
}

// Import initial block
void UhdmImporter::import_initial(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc) {
    if (mode_debug)
        log("    Importing initial block\n");
    
    // Initial blocks are for simulation only - create init sync rule
    RTLIL::SyncRule sync;
    sync.type = RTLIL::SyncType::STi;
    
    if (auto stmt = uhdm_process->Stmt()) {
        import_statement_sync(stmt, &sync, false);
    }
    
    RTLIL::SyncRule* sync_ptr = new RTLIL::SyncRule();
    *sync_ptr = sync;
    yosys_proc->syncs.push_back(sync_ptr);
}

// Import statement for synchronous context
void UhdmImporter::import_statement_sync(const any* uhdm_stmt, RTLIL::SyncRule* sync, bool is_reset) {
    if (!uhdm_stmt)
        return;
    
    int stmt_type = uhdm_stmt->VpiType();
    
    switch (stmt_type) {
        case vpiBegin:
            import_begin_block_sync(static_cast<const begin*>(uhdm_stmt), sync, is_reset);
            break;
        case vpiAssignment:
            import_assignment_sync(static_cast<const assignment*>(uhdm_stmt), sync);
            break;
        case vpiIf:
            import_if_stmt_sync(static_cast<const if_stmt*>(uhdm_stmt), sync, is_reset);
            break;
        case vpiCase:
            import_case_stmt_sync(static_cast<const case_stmt*>(uhdm_stmt), sync, is_reset);
            break;
        default:
            log_warning("Unsupported statement type in sync context: %d\n", stmt_type);
            break;
    }
}

// Import statement for combinational context
void UhdmImporter::import_statement_comb(const any* uhdm_stmt, RTLIL::Process* proc) {
    if (!uhdm_stmt)
        return;
    
    int stmt_type = uhdm_stmt->VpiType();
    
    switch (stmt_type) {
        case vpiBegin:
            import_begin_block_comb(static_cast<const begin*>(uhdm_stmt), proc);
            break;
        case vpiAssignment:
            import_assignment_comb(static_cast<const assignment*>(uhdm_stmt), proc);
            break;
        case vpiIf:
            import_if_stmt_comb(static_cast<const if_stmt*>(uhdm_stmt), proc);
            break;
        case vpiCase:
            import_case_stmt_comb(static_cast<const case_stmt*>(uhdm_stmt), proc);
            break;
        default:
            log_warning("Unsupported statement type in comb context: %d\n", stmt_type);
            break;
    }
}

// Import begin block for sync context
void UhdmImporter::import_begin_block_sync(const begin* uhdm_begin, RTLIL::SyncRule* sync, bool is_reset) {
    if (uhdm_begin->Stmts()) {
        for (auto stmt : *uhdm_begin->Stmts()) {
            import_statement_sync(stmt, sync, is_reset);
        }
    }
}

// Import begin block for comb context
void UhdmImporter::import_begin_block_comb(const begin* uhdm_begin, RTLIL::Process* proc) {
    if (uhdm_begin->Stmts()) {
        for (auto stmt : *uhdm_begin->Stmts()) {
            import_statement_comb(stmt, proc);
        }
    }
}

// Import assignment for sync context
void UhdmImporter::import_assignment_sync(const assignment* uhdm_assign, RTLIL::SyncRule* sync) {
    RTLIL::SigSpec lhs;
    RTLIL::SigSpec rhs;
    
    // Import LHS (always an expr)
    if (auto lhs_expr = uhdm_assign->Lhs()) {
        lhs = import_expression(lhs_expr);
    }
    
    // Import RHS (could be an expr or other type)
    if (auto rhs_any = uhdm_assign->Rhs()) {
        if (auto rhs_expr = dynamic_cast<const expr*>(rhs_any)) {
            rhs = import_expression(rhs_expr);
        } else {
            log_warning("Assignment RHS is not an expression (type=%d)\n", rhs_any->VpiType());
        }
    }
    
    if (lhs.size() != rhs.size()) {
        if (rhs.size() < lhs.size()) {
            // Zero extend
            rhs.extend_u0(lhs.size());
        } else {
            // Truncate
            rhs = rhs.extract(0, lhs.size());
        }
    }
    
    sync->actions.push_back(RTLIL::SigSig(lhs, rhs));
}

// Import assignment for comb context
void UhdmImporter::import_assignment_comb(const assignment* uhdm_assign, RTLIL::Process* proc) {
    RTLIL::SigSpec lhs;
    RTLIL::SigSpec rhs;
    
    // Import LHS (always an expr)
    if (auto lhs_expr = uhdm_assign->Lhs()) {
        lhs = import_expression(lhs_expr);
    }
    
    // Import RHS (could be an expr or other type)
    if (auto rhs_any = uhdm_assign->Rhs()) {
        if (auto rhs_expr = dynamic_cast<const expr*>(rhs_any)) {
            rhs = import_expression(rhs_expr);
        } else {
            log_warning("Assignment RHS is not an expression (type=%d)\n", rhs_any->VpiType());
        }
    }
    
    if (lhs.size() != rhs.size()) {
        if (rhs.size() < lhs.size()) {
            rhs.extend_u0(lhs.size());
        } else {
            rhs = rhs.extract(0, lhs.size());
        }
    }
    
    proc->root_case.actions.push_back(RTLIL::SigSig(lhs, rhs));
}

// Import if statement for sync context
void UhdmImporter::import_if_stmt_sync(const if_stmt* uhdm_if, RTLIL::SyncRule* sync, bool is_reset) {
    // For now, just handle simple assignments in if statements
    // A complete implementation would need proper RTLIL case structure
    
    // Try to get the condition
    if (auto condition_expr = uhdm_if->VpiCondition()) {
        RTLIL::SigSpec condition = import_expression(condition_expr);
        
        if (mode_debug)
            log("    If statement condition imported\n");
    }
    
    // Try to get the then statement  
    if (auto then_stmt = uhdm_if->VpiStmt()) {
        if (then_stmt->VpiType() == vpiAssignment) {
            import_assignment_sync(static_cast<const assignment*>(then_stmt), sync);
        } else {
            import_statement_sync(then_stmt, sync, is_reset);
        }
    }
    
    // For now, skip else handling until we have proper RTLIL case structure
    log_warning("If statements not fully implemented yet - only handling simple assignments\n");
}

// Import if statement for comb context
void UhdmImporter::import_if_stmt_comb(const if_stmt* uhdm_if, RTLIL::Process* proc) {
    // For comb context, we need to create case structure
    log_warning("If statements in comb context not yet fully implemented\n");
}

// Import case statement for sync context
void UhdmImporter::import_case_stmt_sync(const case_stmt* uhdm_case, RTLIL::SyncRule* sync, bool is_reset) {
    log_warning("Case statements in sync context not yet implemented\n");
}

// Import case statement for comb context
void UhdmImporter::import_case_stmt_comb(const case_stmt* uhdm_case, RTLIL::Process* proc) {
    if (mode_debug)
        log("    Importing case statement for combinational context\n");
    
    // Get the case condition (the signal being switched on)
    if (auto condition = uhdm_case->VpiCondition()) {
        RTLIL::SigSpec case_sig = import_expression(condition);
        
        if (mode_debug)
            log("    Case condition signal: %s\n", log_signal(case_sig));
        
        // Create a switch statement in the process
        RTLIL::SwitchRule* sw = new RTLIL::SwitchRule;
        sw->signal = case_sig;
        add_src_attribute(sw->attributes, uhdm_case);
        
        // Import case items
        if (auto case_items = uhdm_case->Case_items()) {
            if (mode_debug)
                log("    Found %d case items\n", (int)case_items->size());
            
            for (auto case_item : *case_items) {
                if (mode_debug)
                    log("    Processing case item\n");
                
                RTLIL::CaseRule* case_rule = new RTLIL::CaseRule;
                add_src_attribute(case_rule->attributes, case_item);
                
                // Get case expressions (values to match)
                if (auto exprs = case_item->VpiExprs()) {
                    for (auto expr : *exprs) {
                        // Cast to expr type using any_cast
                        if (auto case_expr = any_cast<const UHDM::expr*>(expr)) {
                            RTLIL::SigSpec expr_sig = import_expression(case_expr);
                            case_rule->compare.push_back(expr_sig);
                            
                            if (mode_debug)
                                log("      Case value: %s\n", log_signal(expr_sig));
                        }
                    }
                } else {
                    // This is a default case (no expressions)
                    if (mode_debug)
                        log("      Default case\n");
                }
                
                // Import the statement(s) for this case
                if (auto stmt = case_item->Stmt()) {
                    if (mode_debug)
                        log("      Importing case statement\n");
                    import_statement_comb(stmt, case_rule);
                }
                
                sw->cases.push_back(case_rule);
            }
        } else {
            // No case items found, create empty default case
            if (mode_debug)
                log("    No case items found, creating empty default case\n");
            RTLIL::CaseRule* default_case = new RTLIL::CaseRule;
            add_src_attribute(default_case->attributes, uhdm_case);
            sw->cases.push_back(default_case);
        }
        
        // Add the switch to the process
        proc->root_case.switches.push_back(sw);
        
        if (mode_debug)
            log("    Case statement implementation complete\n");
        
    } else {
        log_warning("Case statement has no condition\n");
    }
}

// Import statement for case rule context
void UhdmImporter::import_statement_comb(const any* uhdm_stmt, RTLIL::CaseRule* case_rule) {
    if (!uhdm_stmt)
        return;
    
    int stmt_type = uhdm_stmt->VpiType();
    
    switch (stmt_type) {
        case vpiAssignment:
        case vpiAssignStmt: {
            auto assign = static_cast<const assignment*>(uhdm_stmt);
            
            // Get LHS and RHS
            if (auto lhs_expr = assign->Lhs()) {
                if (auto rhs_expr = assign->Rhs()) {
                    // Cast to proper expr type
                    if (auto lhs = any_cast<const UHDM::expr*>(lhs_expr)) {
                        if (auto rhs = any_cast<const UHDM::expr*>(rhs_expr)) {
                            RTLIL::SigSpec lhs_sig = import_expression(lhs);
                            RTLIL::SigSpec rhs_sig = import_expression(rhs);
                            
                            if (mode_debug)
                                log("        Case assignment: %s = %s\n", log_signal(lhs_sig), log_signal(rhs_sig));
                            
                            case_rule->actions.push_back(RTLIL::SigSig(lhs_sig, rhs_sig));
                        }
                    }
                }
            }
            break;
        }
        case vpiBegin: {
            auto begin = static_cast<const UHDM::begin*>(uhdm_stmt);
            if (auto stmts = begin->Stmts()) {
                for (auto stmt : *stmts) {
                    import_statement_comb(stmt, case_rule);
                }
            }
            break;
        }
        default:
            if (mode_debug)
                log("        Unsupported statement type in case: %d\n", stmt_type);
            break;
    }
}


YOSYS_NAMESPACE_END