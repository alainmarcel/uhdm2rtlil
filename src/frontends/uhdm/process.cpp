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
    
    if (mode_debug)
        log("  Importing process type: %d\n", proc_type);
    
    RTLIL::Process* yosys_proc = module->addProcess(NEW_ID);
    
    // Handle different process types
    switch (proc_type) {
        case vpiAlwaysFF:
            import_always_ff(uhdm_process, yosys_proc);
            break;
        case vpiAlwaysComb:
            import_always_comb(uhdm_process, yosys_proc);
            break;
        case vpiAlways:
            import_always(uhdm_process, yosys_proc);
            break;
        case vpiInitial:
            import_initial(uhdm_process, yosys_proc);
            break;
        default:
            log_warning("Unsupported process type: %d\n", proc_type);
            break;
    }
}

// Import always_ff block
void UhdmImporter::import_always_ff(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc) {
    if (mode_debug)
        log("    Importing always_ff block\n");
    
    // Create clocking from sensitivity list
    UhdmClocking clocking(this, uhdm_process->Stmt());
    
    // Create sync rule
    RTLIL::SyncRule sync;
    sync.type = clocking.posedge_clk ? RTLIL::SyncType::STp : RTLIL::SyncType::STn;
    sync.signal = clocking.clock_sig;
    
    // Handle reset if present
    if (clocking.has_reset) {
        // Create async reset sync rule
        RTLIL::SyncRule reset_sync;
        reset_sync.type = clocking.negedge_reset ? RTLIL::SyncType::STn : RTLIL::SyncType::STp;
        reset_sync.signal = clocking.reset_sig;
        
        // Import reset actions
        if (auto stmt = uhdm_process->Stmt()) {
            import_statement_sync(stmt, &reset_sync, true);
        }
        
        RTLIL::SyncRule* reset_sync_ptr = new RTLIL::SyncRule();
        *reset_sync_ptr = reset_sync;
        yosys_proc->syncs.push_back(reset_sync_ptr);
    }
    
    // Import main statement
    if (auto stmt = uhdm_process->Stmt()) {
        import_statement_sync(stmt, &sync, false);
    }
    
    RTLIL::SyncRule* sync_ptr = new RTLIL::SyncRule();
    *sync_ptr = sync;
    yosys_proc->syncs.push_back(sync_ptr);
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
    if (mode_debug)
        log("    Importing always block\n");
    
    // Determine if clocked or combinational based on sensitivity list
    bool is_clocked = false;
    
    if (auto stmt = uhdm_process->Stmt()) {
        // Sensitivity list handling would need proper UHDM API access
        // For now, assume combinational
        is_clocked = false;
    }
    
    if (is_clocked) {
        import_always_ff(uhdm_process, yosys_proc);
    } else {
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
    // For sync context, we need to create case structure
    log_warning("If statements in sync context not yet fully implemented\n");
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