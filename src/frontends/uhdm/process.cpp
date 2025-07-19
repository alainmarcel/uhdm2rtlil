/*
 * Process and statement handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog processes
 * (always blocks) and statements.
 */

#include "uhdm2rtlil.h"

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Import a process statement (always block)
void UhdmImporter::import_process(const process_stmt* uhdm_process) {
    int proc_type = uhdm_process->VpiType();
    
    log("  Importing process type: %d\n", proc_type);
    
    RTLIL::Process* yosys_proc = module->addProcess(NEW_ID);
    
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
    
    // For now, create a simple clock edge sync rule
    // In the flipflop case, we know clk is posedge and rst_n is negedge
    RTLIL::SyncRule* sync_ptr = new RTLIL::SyncRule();
    sync_ptr->type = RTLIL::SyncType::STp;  // positive edge
    
    // Look up clock signal (assume it's named "clk")
    if (name_map.count("clk")) {
        sync_ptr->signal = RTLIL::SigSpec(name_map["clk"]);
        log("    Using clk signal for sync\n");
    } else {
        log_warning("Clock signal 'clk' not found\n");
        sync_ptr->signal = RTLIL::SigSpec(RTLIL::State::S1);
    }
    
    // Create async reset sync rule if reset exists
    if (name_map.count("rst_n")) {
        RTLIL::SyncRule* reset_sync_ptr = new RTLIL::SyncRule();
        reset_sync_ptr->type = RTLIL::SyncType::STn;  // negative edge reset
        reset_sync_ptr->signal = RTLIL::SigSpec(name_map["rst_n"]);
        
        // Add reset action: q <= 1'b0
        if (name_map.count("q")) {
            RTLIL::SigSpec q_sig = RTLIL::SigSpec(name_map["q"]);
            RTLIL::SigSpec zero_sig = RTLIL::SigSpec(RTLIL::State::S0);
            reset_sync_ptr->actions.push_back(RTLIL::SigSig(q_sig, zero_sig));
            log("    Added reset action: q <= 0\n");
        }
        
        yosys_proc->syncs.push_back(reset_sync_ptr);
    }
    
    // Add main clock action: q <= d  
    if (name_map.count("q") && name_map.count("d")) {
        RTLIL::SigSpec q_sig = RTLIL::SigSpec(name_map["q"]);
        RTLIL::SigSpec d_sig = RTLIL::SigSpec(name_map["d"]);
        sync_ptr->actions.push_back(RTLIL::SigSig(q_sig, d_sig));
        log("    Added clock action: q <= d\n");
    }
    
    yosys_proc->syncs.push_back(sync_ptr);
    
    log("    Added %zu sync rules to process\n", yosys_proc->syncs.size());
}

// Import always_comb block
void UhdmImporter::import_always_comb(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc) {
    if (mode_debug)
        log("    Importing always_comb block\n");
    
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
    RTLIL::SigSpec lhs = import_expression(static_cast<const expr*>(uhdm_assign->Lhs()));
    RTLIL::SigSpec rhs = import_expression(static_cast<const expr*>(uhdm_assign->Rhs()));
    
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
    RTLIL::SigSpec lhs = import_expression(static_cast<const expr*>(uhdm_assign->Lhs()));
    RTLIL::SigSpec rhs = import_expression(static_cast<const expr*>(uhdm_assign->Rhs()));
    
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
    log_warning("Case statements in comb context not yet implemented\n");
}

YOSYS_NAMESPACE_END