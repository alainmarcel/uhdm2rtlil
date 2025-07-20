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

#include <uhdm/uhdm.h>
#include <uhdm/Serializer.h>
#include <uhdm/vpi_user.h>
#include <uhdm/uhdm_types.h>
#include <uhdm/stmt.h>
#include <uhdm/expr.h>
#include <uhdm/constant.h>
#include <uhdm/operation.h>
#include <uhdm/ref_obj.h>

#include "kernel/yosys.h"
#include "kernel/sigtools.h"
#include "kernel/celltypes.h"
#include "kernel/log.h"

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
    UhdmClocking(UhdmImporter *importer, const UHDM::any* sens_list);
    
    // Helper methods for analyzing sensitivity lists
    void analyze_sensitivity_list(UhdmImporter *importer, const UHDM::VectorOfany* sensitivity);
    
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
    void import_design(UHDM::design* uhdm_design);
    void import_module(const UHDM::module_inst* uhdm_module);
    void import_port(const UHDM::port* uhdm_port);
    void import_net(const UHDM::net* uhdm_net);
    void import_process(const UHDM::process_stmt* uhdm_process);
    void import_continuous_assign(const UHDM::cont_assign* uhdm_assign);
    void import_instance(const UHDM::module_inst* uhdm_inst);
    
    // Signal and wire management
    RTLIL::SigBit get_sig_bit(const UHDM::any* uhdm_obj);
    RTLIL::SigSpec get_sig_spec(const UHDM::any* uhdm_obj, int width = 1);
    RTLIL::Wire* get_wire(const UHDM::any* uhdm_obj, int width = 1);
    RTLIL::Wire* create_wire(const std::string& name, int width = 1);
    
    // Expression handling
    RTLIL::SigSpec import_expression(const UHDM::expr* uhdm_expr);
    RTLIL::SigSpec import_constant(const UHDM::constant* uhdm_const);
    RTLIL::SigSpec import_operation(const UHDM::operation* uhdm_op);
    RTLIL::SigSpec import_ref_obj(const UHDM::ref_obj* uhdm_ref);
    
    // Statement handling
    void import_statement(const UHDM::any* uhdm_stmt, RTLIL::Process* proc = nullptr);
    void import_assignment(const UHDM::assignment* uhdm_assign, RTLIL::Process* proc);
    void import_if_stmt(const UHDM::if_stmt* uhdm_if, RTLIL::Process* proc);
    void import_case_stmt(const UHDM::case_stmt* uhdm_case, RTLIL::Process* proc);
    void import_for_stmt(const UHDM::for_stmt* uhdm_for, RTLIL::Process* proc);
    void import_while_stmt(const UHDM::while_stmt* uhdm_while, RTLIL::Process* proc);
    
    // Process-specific import functions
    void import_always_ff(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_always_comb(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_always(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_initial(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    
    // Statement import for different contexts
    void import_statement_sync(const UHDM::any* uhdm_stmt, RTLIL::SyncRule* sync, bool is_reset);
    void import_statement_comb(const UHDM::any* uhdm_stmt, RTLIL::Process* proc);
    void import_begin_block_sync(const UHDM::begin* uhdm_begin, RTLIL::SyncRule* sync, bool is_reset);
    void import_begin_block_comb(const UHDM::begin* uhdm_begin, RTLIL::Process* proc);
    void import_assignment_sync(const UHDM::assignment* uhdm_assign, RTLIL::SyncRule* sync);
    void import_assignment_comb(const UHDM::assignment* uhdm_assign, RTLIL::Process* proc);
    void import_if_stmt_sync(const UHDM::if_stmt* uhdm_if, RTLIL::SyncRule* sync, bool is_reset);
    void import_if_stmt_comb(const UHDM::if_stmt* uhdm_if, RTLIL::Process* proc);
    void import_case_stmt_sync(const UHDM::case_stmt* uhdm_case, RTLIL::SyncRule* sync, bool is_reset);
    void import_case_stmt_comb(const UHDM::case_stmt* uhdm_case, RTLIL::Process* proc);
    
    // Additional expression types
    RTLIL::SigSpec import_part_select(const UHDM::part_select* uhdm_part);
    RTLIL::SigSpec import_bit_select(const UHDM::bit_select* uhdm_bit);
    RTLIL::SigSpec import_concat(const UHDM::operation* uhdm_concat);
    
    // Utility functions
    RTLIL::IdString new_id(const std::string& name);
    std::string get_name(const UHDM::any* uhdm_obj);
    int get_width(const UHDM::any* uhdm_obj);
    void import_attributes(dict<RTLIL::IdString, RTLIL::Const> &attributes, const UHDM::any* uhdm_obj);
    void import_memory_objects(const UHDM::module_inst* uhdm_module);
    void add_src_attribute(dict<RTLIL::IdString, RTLIL::Const>& attributes, const UHDM::any* uhdm_obj);
    std::string get_src_attribute(const UHDM::any* uhdm_obj);
    
    // Signal name extraction from UHDM
    bool extract_signal_names_from_process(const UHDM::any* stmt, 
                                         std::string& output_signal, 
                                         std::string& input_signal,
                                         std::string& clock_signal, 
                                         std::string& reset_signal);
};

// Specialized importers for different aspects
struct UhdmModuleImporter;
struct UhdmMemoryImporter;
struct UhdmFsmImporter;

YOSYS_NAMESPACE_END

#endif