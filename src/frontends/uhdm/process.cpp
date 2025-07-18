/*
 * Process and statement handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog processes
 * (always blocks) and statements.
 */

#include "uhdm2rtlil.h"

YOSYS_NAMESPACE_BEGIN
PRIVATE_NAMESPACE_BEGIN

using namespace UHDM;

// Import a process statement (always block)
void UhdmImporter::import_process(const process_stmt* uhdm_process) {
    int proc_type = uhdm_process->VpiProcessType();
    
    if (mode_debug)
        log("  Importing process type: %d\n", proc_type);
    
    RTLIL::Process* yosys_proc = new RTLIL::Process;
    yosys_proc->name = NEW_ID;
    module->processes[yosys_proc->name] = yosys_proc;
    
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
    UhdmClocking clocking(this, uhdm_process->Stmt());\n    \n    // Create sync rule\n    RTLIL::SyncRule sync;\n    sync.type = clocking.posedge_clk ? RTLIL::SyncType::STp : RTLIL::SyncType::STn;\n    sync.signal = clocking.clock_sig;\n    \n    // Handle reset if present\n    if (clocking.has_reset) {\n        // Create async reset sync rule\n        RTLIL::SyncRule reset_sync;\n        reset_sync.type = clocking.negedge_reset ? RTLIL::SyncType::STn : RTLIL::SyncType::STp;\n        reset_sync.signal = clocking.reset_sig;\n        \n        // Import reset actions\n        if (auto stmt = uhdm_process->Stmt()) {\n            import_statement_sync(stmt, &reset_sync, true);\n        }\n        \n        yosys_proc->syncs.push_back(reset_sync);\n    }\n    \n    // Import main statement\n    if (auto stmt = uhdm_process->Stmt()) {\n        import_statement_sync(stmt, &sync, false);\n    }\n    \n    yosys_proc->syncs.push_back(sync);\n}\n\n// Import always_comb block\nvoid UhdmImporter::import_always_comb(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc) {\n    if (mode_debug)\n        log(\"    Importing always_comb block\\n\");\n    \n    // Combinational logic - no sync rules needed\n    if (auto stmt = uhdm_process->Stmt()) {\n        import_statement_comb(stmt, yosys_proc);\n    }\n}\n\n// Import always block\nvoid UhdmImporter::import_always(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc) {\n    if (mode_debug)\n        log(\"    Importing always block\\n\");\n    \n    // Determine if clocked or combinational based on sensitivity list\n    bool is_clocked = false;\n    \n    if (auto stmt = uhdm_process->Stmt()) {\n        if (auto sens_list = stmt->Sensitivity_list()) {\n            for (auto sens : *sens_list) {\n                if (sens->VpiType() == vpiPosedge || sens->VpiType() == vpiNegedge) {\n                    is_clocked = true;\n                    break;\n                }\n            }\n        }\n    }\n    \n    if (is_clocked) {\n        import_always_ff(uhdm_process, yosys_proc);\n    } else {\n        import_always_comb(uhdm_process, yosys_proc);\n    }\n}\n\n// Import initial block\nvoid UhdmImporter::import_initial(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc) {\n    if (mode_debug)\n        log(\"    Importing initial block\\n\");\n    \n    // Initial blocks are for simulation only - create init sync rule\n    RTLIL::SyncRule sync;\n    sync.type = RTLIL::SyncType::STi;\n    \n    if (auto stmt = uhdm_process->Stmt()) {\n        import_statement_sync(stmt, &sync, false);\n    }\n    \n    yosys_proc->syncs.push_back(sync);\n}\n\n// Import statement for synchronous context\nvoid UhdmImporter::import_statement_sync(const stmt* uhdm_stmt, RTLIL::SyncRule* sync, bool is_reset) {\n    if (!uhdm_stmt)\n        return;\n    \n    int stmt_type = uhdm_stmt->VpiType();\n    \n    switch (stmt_type) {\n        case vpiBegin:\n            import_begin_block_sync(static_cast<const begin*>(uhdm_stmt), sync, is_reset);\n            break;\n        case vpiAssignment:\n            import_assignment_sync(static_cast<const assignment*>(uhdm_stmt), sync);\n            break;\n        case vpiIf:\n            import_if_stmt_sync(static_cast<const if_stmt*>(uhdm_stmt), sync, is_reset);\n            break;\n        case vpiCase:\n            import_case_stmt_sync(static_cast<const case_stmt*>(uhdm_stmt), sync, is_reset);\n            break;\n        default:\n            log_warning(\"Unsupported statement type in sync context: %d\\n\", stmt_type);\n            break;\n    }\n}\n\n// Import statement for combinational context\nvoid UhdmImporter::import_statement_comb(const stmt* uhdm_stmt, RTLIL::Process* proc) {\n    if (!uhdm_stmt)\n        return;\n    \n    int stmt_type = uhdm_stmt->VpiType();\n    \n    switch (stmt_type) {\n        case vpiBegin:\n            import_begin_block_comb(static_cast<const begin*>(uhdm_stmt), proc);\n            break;\n        case vpiAssignment:\n            import_assignment_comb(static_cast<const assignment*>(uhdm_stmt), proc);\n            break;\n        case vpiIf:\n            import_if_stmt_comb(static_cast<const if_stmt*>(uhdm_stmt), proc);\n            break;\n        case vpiCase:\n            import_case_stmt_comb(static_cast<const case_stmt*>(uhdm_stmt), proc);\n            break;\n        default:\n            log_warning(\"Unsupported statement type in comb context: %d\\n\", stmt_type);\n            break;\n    }\n}\n\n// Import begin block for sync context\nvoid UhdmImporter::import_begin_block_sync(const begin* uhdm_begin, RTLIL::SyncRule* sync, bool is_reset) {\n    if (uhdm_begin->Stmts()) {\n        for (auto stmt : *uhdm_begin->Stmts()) {\n            import_statement_sync(stmt, sync, is_reset);\n        }\n    }\n}\n\n// Import begin block for comb context\nvoid UhdmImporter::import_begin_block_comb(const begin* uhdm_begin, RTLIL::Process* proc) {\n    if (uhdm_begin->Stmts()) {\n        for (auto stmt : *uhdm_begin->Stmts()) {\n            import_statement_comb(stmt, proc);\n        }\n    }\n}\n\n// Import assignment for sync context\nvoid UhdmImporter::import_assignment_sync(const assignment* uhdm_assign, RTLIL::SyncRule* sync) {\n    RTLIL::SigSpec lhs = import_expression(uhdm_assign->Lhs());\n    RTLIL::SigSpec rhs = import_expression(uhdm_assign->Rhs());\n    \n    if (lhs.size() != rhs.size()) {\n        if (rhs.size() < lhs.size()) {\n            // Zero extend\n            rhs.extend_u0(lhs.size());\n        } else {\n            // Truncate\n            rhs = rhs.extract(0, lhs.size());\n        }\n    }\n    \n    sync->actions.push_back(RTLIL::SigSig(lhs, rhs));\n}\n\n// Import assignment for comb context\nvoid UhdmImporter::import_assignment_comb(const assignment* uhdm_assign, RTLIL::Process* proc) {\n    RTLIL::SigSpec lhs = import_expression(uhdm_assign->Lhs());\n    RTLIL::SigSpec rhs = import_expression(uhdm_assign->Rhs());\n    \n    if (lhs.size() != rhs.size()) {\n        if (rhs.size() < lhs.size()) {\n            rhs.extend_u0(lhs.size());\n        } else {\n            rhs = rhs.extract(0, lhs.size());\n        }\n    }\n    \n    proc->root_case.actions.push_back(RTLIL::SigSig(lhs, rhs));\n}\n\n// Import if statement for sync context\nvoid UhdmImporter::import_if_stmt_sync(const if_stmt* uhdm_if, RTLIL::SyncRule* sync, bool is_reset) {\n    // For sync context, we need to create case structure\n    log_warning(\"If statements in sync context not yet fully implemented\\n\");\n}\n\n// Import if statement for comb context\nvoid UhdmImporter::import_if_stmt_comb(const if_stmt* uhdm_if, RTLIL::Process* proc) {\n    // For comb context, we need to create case structure\n    log_warning(\"If statements in comb context not yet fully implemented\\n\");\n}\n\n// Import case statement for sync context\nvoid UhdmImporter::import_case_stmt_sync(const case_stmt* uhdm_case, RTLIL::SyncRule* sync, bool is_reset) {\n    log_warning(\"Case statements in sync context not yet implemented\\n\");\n}\n\n// Import case statement for comb context\nvoid UhdmImporter::import_case_stmt_comb(const case_stmt* uhdm_case, RTLIL::Process* proc) {\n    log_warning(\"Case statements in comb context not yet implemented\\n\");\n}\n\nPRIVATE_NAMESPACE_END\nYOSYS_NAMESPACE_END