/*
 * UHDM to RTLIL Translation Frontend for Yosys
 * 
 * This header defines the main structures and classes for translating
 * UHDM (Universal Hardware Data Model) to Yosys RTLIL format.
 * 
 * Architecture inspired by Yosys Verific frontend.
 */

#ifndef UHDM2RTLIL_H
#define UHDM2RTLIL_H

#include "kernel/yosys.h"
#include "kernel/sigtools.h"
#include "kernel/celltypes.h"
#include "kernel/log.h"

#include <uhdm/uhdm.h>
#include <uhdm/Serializer.h>
#include <uhdm/vpi_user.h>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Forward declarations
struct UhdmImporter;

// Clock and reset information for sequential logic
struct UhdmClocking {
    RTLIL::Module *module = nullptr;
    RTLIL::SigBit clock_sig = State::Sx;
    RTLIL::SigBit reset_sig = State::Sx;
    bool posedge_clk = true;
    bool negedge_reset = true;
    bool has_reset = false;
    
    UhdmClocking() {}
    UhdmClocking(UhdmImporter *importer, const any* sens_list);
    
    // Helper methods for analyzing sensitivity lists
    void analyze_sensitivity_list(UhdmImporter *importer, const VectorOfany* sensitivity);
    
    // Helper methods for creating flip-flops with proper clocking
    RTLIL::Cell *addDff(IdString name, SigSpec sig_d, SigSpec sig_q, Const init_value = Const());
    RTLIL::Cell *addAdff(IdString name, SigSpec sig_d, SigSpec sig_q, Const arst_value);
};

// Main importer class for UHDM to RTLIL conversion
struct UhdmImporter {
    RTLIL::Design *design;
    RTLIL::Module *module;
    
    // Maps for tracking UHDM objects to RTLIL equivalents
    std::map<const any*, RTLIL::SigBit> net_map;
    std::map<const any*, RTLIL::Wire*> wire_map;
    std::map<std::string, RTLIL::Wire*> name_map;
    
    // Import modes and options
    bool mode_keep_names = true;
    bool mode_debug = false;
    bool mode_formal = false;
    
    UhdmImporter(RTLIL::Design *design, bool keep_names = true, bool debug = false);
    
    // Main import functions
    void import_design(Design* uhdm_design);
    void import_module(const Module* uhdm_module);
    void import_port(const port* uhdm_port);
    void import_net(const net* uhdm_net);
    void import_process(const process_stmt* uhdm_process);
    void import_continuous_assign(const cont_assign* uhdm_assign);
    void import_instance(const module_inst* uhdm_inst);
    
    // Signal and wire management
    RTLIL::SigBit get_sig_bit(const any* uhdm_obj);
    RTLIL::SigSpec get_sig_spec(const any* uhdm_obj, int width = 1);
    RTLIL::Wire* get_wire(const any* uhdm_obj, int width = 1);
    RTLIL::Wire* create_wire(const std::string& name, int width = 1);
    
    // Expression handling
    RTLIL::SigSpec import_expression(const expr* uhdm_expr);
    RTLIL::SigSpec import_constant(const constant* uhdm_const);
    RTLIL::SigSpec import_operation(const operation* uhdm_op);
    RTLIL::SigSpec import_ref_obj(const ref_obj* uhdm_ref);
    
    // Statement handling
    void import_statement(const stmt* uhdm_stmt, RTLIL::Process* proc = nullptr);
    void import_assignment(const assignment* uhdm_assign, RTLIL::Process* proc);
    void import_if_stmt(const if_stmt* uhdm_if, RTLIL::Process* proc);
    void import_case_stmt(const case_stmt* uhdm_case, RTLIL::Process* proc);
    void import_for_stmt(const for_stmt* uhdm_for, RTLIL::Process* proc);
    void import_while_stmt(const while_stmt* uhdm_while, RTLIL::Process* proc);
    
    // Process-specific import functions
    void import_always_ff(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_always_comb(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_always(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_initial(const process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    
    // Statement import for different contexts
    void import_statement_sync(const stmt* uhdm_stmt, RTLIL::SyncRule* sync, bool is_reset);
    void import_statement_comb(const stmt* uhdm_stmt, RTLIL::Process* proc);
    void import_begin_block_sync(const begin* uhdm_begin, RTLIL::SyncRule* sync, bool is_reset);
    void import_begin_block_comb(const begin* uhdm_begin, RTLIL::Process* proc);
    void import_assignment_sync(const assignment* uhdm_assign, RTLIL::SyncRule* sync);
    void import_assignment_comb(const assignment* uhdm_assign, RTLIL::Process* proc);
    void import_if_stmt_sync(const if_stmt* uhdm_if, RTLIL::SyncRule* sync, bool is_reset);
    void import_if_stmt_comb(const if_stmt* uhdm_if, RTLIL::Process* proc);
    void import_case_stmt_sync(const case_stmt* uhdm_case, RTLIL::SyncRule* sync, bool is_reset);
    void import_case_stmt_comb(const case_stmt* uhdm_case, RTLIL::Process* proc);
    
    // Additional expression types
    RTLIL::SigSpec import_part_select(const part_select* uhdm_part);
    RTLIL::SigSpec import_bit_select(const bit_select* uhdm_bit);
    RTLIL::SigSpec import_concat(const concat* uhdm_concat);
    
    // Utility functions
    RTLIL::IdString new_id(const std::string& name);
    std::string get_name(const any* uhdm_obj);
    int get_width(const any* uhdm_obj);
    void import_attributes(dict<RTLIL::IdString, RTLIL::Const> &attributes, const any* uhdm_obj);
};

// Specialized importers for different aspects
struct UhdmModuleImporter;
struct UhdmMemoryImporter;
struct UhdmFsmImporter;

YOSYS_NAMESPACE_END

#endif