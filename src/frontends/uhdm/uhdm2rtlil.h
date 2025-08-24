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
#include <uhdm/ElaboratorListener.h>
#include <uhdm/vpi_user.h>
#include <uhdm/uhdm_types.h>
#include <uhdm/stmt.h>
#include <uhdm/expr.h>
#include <uhdm/constant.h>
#include <uhdm/operation.h>
#include <uhdm/ref_obj.h>
#include <uhdm/hier_path.h>
#include <uhdm/interface_inst.h>
#include <uhdm/interface_typespec.h>
#include <uhdm/ref_typespec.h>
#include <uhdm/struct_typespec.h>
#include <uhdm/package.h>
#include <uhdm/ExprEval.h>

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
    void analyze_statement_for_clocking(UhdmImporter *importer, const UHDM::any* stmt);
    
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
    
    // Track module instances to avoid duplicates
    // Key: module_name + parameter signature
    std::set<std::string> imported_module_signatures;
    
    // Track top-level modules (those with vpiTop:1 property)
    std::set<std::string> top_level_modules;
    
    // Track interface instance parameters (interface_name -> param_name -> value)
    std::map<std::string, std::map<std::string, int>> interface_parameters;
    
    // Track package definitions and their contents
    // Key: package_name, Value: package object
    std::map<std::string, const UHDM::package*> package_map;
    
    // Track package typespecs for type resolution
    // Key: fully qualified name (package::type), Value: typespec
    std::map<std::string, const UHDM::typespec*> package_typespec_map;
    
    // Track package parameters
    // Key: fully qualified name (package::param), Value: constant value
    std::map<std::string, RTLIL::Const> package_parameter_map;
    
    // Import modes and options
    bool mode_keep_names = false;  // Use uniquify to avoid naming conflicts
    bool mode_debug = true;
    bool mode_formal = false;
    
    // Counter for unique cell names
    int logic_not_counter = 0;
    
    // Current instance context for hierarchical path resolution
    const UHDM::module_inst* current_instance = nullptr;
    const UHDM::scope* current_scope = nullptr;

    // Current generate scope for naming
    std::string current_gen_scope;
    
    // Current condition for conditional memory writes
    RTLIL::SigSpec current_condition;
    
    // UHDM design for accessing module definitions
    UHDM::design* uhdm_design = nullptr;
    
    // Context for handling async reset (maps signal name to temp wire)
    std::map<std::string, RTLIL::Wire*> current_signal_temp_wires;
    
    // Track sync assignment targets for proper if-else handling
    std::map<std::string, RTLIL::Wire*> sync_assignment_targets;
    
    // Temporary wires for combinational processes
    std::map<const UHDM::expr*, RTLIL::Wire*> current_temp_wires;
    std::map<const UHDM::expr*, RTLIL::SigSpec> current_lhs_specs;
    
    // Memory write handling for synchronous processes
    struct MemoryWriteInfo {
        RTLIL::IdString mem_id;
        RTLIL::Wire* addr_wire;
        RTLIL::Wire* data_wire;
        RTLIL::Wire* en_wire;
        int width;
    };
    std::map<std::string, MemoryWriteInfo> current_memory_writes;
    
    // Track memory writes for process generation (like Verilog frontend)
    struct ProcessMemoryWrite {
        RTLIL::IdString mem_id;
        RTLIL::SigSpec address;
        RTLIL::SigSpec data;
        RTLIL::SigSpec condition;  // Enable condition
        int iteration;  // For unrolled loops
    };
    std::vector<ProcessMemoryWrite> pending_memory_writes;
    
    // Track pending sync assignments to merge multiple updates to same signal
    std::map<RTLIL::SigSpec, RTLIL::SigSpec> pending_sync_assignments;
    
    // Current loop variable substitutions for unrolling
    std::map<std::string, int64_t> current_loop_substitutions;
    
    UhdmImporter(RTLIL::Design *design, bool keep_names = true, bool debug = false);
    
    // Main import functions
    void import_design(UHDM::design* uhdm_design);
    void import_module(const UHDM::module_inst* uhdm_module);
    void import_module_hierarchy(const UHDM::module_inst* uhdm_module, bool create_instances = true);
    void import_port(const UHDM::port* uhdm_port);
    void import_net(const UHDM::net* uhdm_net, const UHDM::instance* inst = nullptr);
    void import_process(const UHDM::process_stmt* uhdm_process);
    void import_continuous_assign(const UHDM::cont_assign* uhdm_assign);
    void import_instance(const UHDM::module_inst* uhdm_inst);
    void import_ref_module(const UHDM::ref_module* ref_mod);
    void create_parameterized_modules();
    void import_parameter(const UHDM::any* uhdm_param);
    
    // Package support
    void import_package(const UHDM::package* uhdm_package);
    
    // Interface support
    void import_interface(const UHDM::interface_inst* uhdm_interface);
    void import_interface_instances(const UHDM::module_inst* uhdm_module);
    bool module_has_interface_ports(const UHDM::module_inst* uhdm_module);
    std::string build_interface_module_name(const std::string& base_name, 
                                          const std::string& param_signature,
                                          const UHDM::module_inst* uhdm_module);
    void create_interface_module_with_width(const std::string& interface_name, int width);
    void expand_interfaces();
    void import_generate_scopes(const UHDM::module_inst* uhdm_module);
    void import_gen_scope(const UHDM::gen_scope* uhdm_scope);
    
    // Primitive gate support
    void import_primitives(const UHDM::module_inst* uhdm_module);
    void import_primitive_arrays(const UHDM::module_inst* uhdm_module);
    void import_gate(const UHDM::gate* uhdm_gate, const std::string& instance_name = "");
    void import_gate_array(const UHDM::gate_array* uhdm_gate_array);
    void import_gate_array_element(const UHDM::gate* gate_template, const std::string& instance_name, int bit_index);
    
    // Signal and wire management
    RTLIL::SigBit get_sig_bit(const UHDM::any* uhdm_obj);
    RTLIL::SigSpec get_sig_spec(const UHDM::any* uhdm_obj, int width = 1);
    RTLIL::Wire* get_wire(const UHDM::any* uhdm_obj, int width = 1);
    RTLIL::Wire* create_wire(const std::string& name, int width = 1, bool upto = false, int start_offset = 0);
    
    // Expression handling
    RTLIL::SigSpec import_expression(const UHDM::expr* uhdm_expr);
    RTLIL::SigSpec import_constant(const UHDM::constant* uhdm_const);
    RTLIL::SigSpec import_operation(const UHDM::operation* uhdm_op, const UHDM::scope* inst = nullptr);
    RTLIL::SigSpec import_ref_obj(const UHDM::ref_obj* uhdm_ref, const UHDM::scope* inst = nullptr);
    
    // Helper for evaluating expressions with variable substitution (for loop unrolling)
    RTLIL::SigSpec evaluate_expression_with_vars(const UHDM::expr* expr, 
                                                 const std::map<std::string, uint64_t>& vars,
                                                 const std::string& loop_var_name,
                                                 int64_t loop_index);
    
    // Statement handling
    void import_statement(const UHDM::any* uhdm_stmt, RTLIL::Process* proc = nullptr);
    void import_assignment(const UHDM::assignment* uhdm_assign, RTLIL::Process* proc);
    void import_if_stmt(const UHDM::if_stmt* uhdm_if, RTLIL::Process* proc);
    void import_case_stmt(const UHDM::case_stmt* uhdm_case, RTLIL::Process* proc);
    void import_for_stmt(const UHDM::for_stmt* uhdm_for, RTLIL::Process* proc);
    void import_while_stmt(const UHDM::while_stmt* uhdm_while, RTLIL::Process* proc);
    void import_if_else_comb(const UHDM::if_else* uhdm_if_else, RTLIL::Process* proc);
    
    // Loop variable substitution helpers
    void import_statement_with_loop_vars(const UHDM::any* uhdm_stmt, RTLIL::SyncRule* sync, bool is_reset,
                                         std::map<std::string, int64_t>& var_substitutions);
    RTLIL::SigSpec import_operation_with_substitution(const UHDM::operation* uhdm_op,
                                                      const std::map<std::string, int64_t>& var_substitutions);
    RTLIL::SigSpec import_indexed_part_select_with_substitution(const UHDM::indexed_part_select* ips,
                                                                const std::map<std::string, int64_t>& var_substitutions);
    
    // Process-specific import functions
    void import_always_ff(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_always_comb(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_always(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_initial(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    
    // TARGETED FIX: Memory for-loop processing
    bool is_memory_array(const UHDM::net* uhdm_net);
    bool is_memory_array(const UHDM::array_net* uhdm_array);
    bool is_memory_array(const UHDM::array_var* uhdm_array);
    void process_reset_block_for_memory(const UHDM::any* reset_stmt, RTLIL::CaseRule* reset_case);
    
    // Statement import for different contexts
    void import_statement_sync(const UHDM::any* uhdm_stmt, RTLIL::SyncRule* sync, bool is_reset);
    void import_statement_comb(const UHDM::any* uhdm_stmt, RTLIL::Process* proc);
    void import_statement_comb(const UHDM::any* uhdm_stmt, RTLIL::CaseRule* case_rule);
    void import_begin_block_sync(const UHDM::begin* uhdm_begin, RTLIL::SyncRule* sync, bool is_reset);
    void import_begin_block_comb(const UHDM::begin* uhdm_begin, RTLIL::Process* proc);
    void import_named_begin_block_sync(const UHDM::named_begin* uhdm_named, RTLIL::SyncRule* sync, bool is_reset);
    void import_named_begin_block_comb(const UHDM::named_begin* uhdm_named, RTLIL::Process* proc);
    void import_assignment_sync(const UHDM::assignment* uhdm_assign, RTLIL::SyncRule* sync);
    void import_assignment_comb(const UHDM::assignment* uhdm_assign, RTLIL::Process* proc);
    void import_assignment_comb(const UHDM::assignment* uhdm_assign, RTLIL::CaseRule* case_rule);
    void import_if_stmt_sync(const UHDM::if_stmt* uhdm_if, RTLIL::SyncRule* sync, bool is_reset);
    void import_if_stmt_comb(const UHDM::if_stmt* uhdm_if, RTLIL::Process* proc);
    void import_case_stmt_sync(const UHDM::case_stmt* uhdm_case, RTLIL::SyncRule* sync, bool is_reset);
    void import_case_stmt_comb(const UHDM::case_stmt* uhdm_case, RTLIL::Process* proc);
    
    // Additional expression types
    RTLIL::SigSpec import_part_select(const UHDM::part_select* uhdm_part, const UHDM::scope* inst = nullptr);
    RTLIL::SigSpec import_bit_select(const UHDM::bit_select* uhdm_bit, const UHDM::scope* inst = nullptr);
    RTLIL::SigSpec import_indexed_part_select(const UHDM::indexed_part_select* uhdm_indexed, const UHDM::scope* inst = nullptr);
    RTLIL::SigSpec import_concat(const UHDM::operation* uhdm_concat, const UHDM::scope* inst = nullptr);
    RTLIL::SigSpec import_hier_path(const UHDM::hier_path* uhdm_hier, const UHDM::scope* inst = nullptr);
    
    // Utility functions
    RTLIL::IdString new_id(const std::string& name);
    std::string get_name(const UHDM::any* uhdm_obj);
    int get_width(const UHDM::any* uhdm_obj, const UHDM::scope* inst = nullptr);
    void import_attributes(dict<RTLIL::IdString, RTLIL::Const> &attributes, const UHDM::any* uhdm_obj);
    void import_memory_objects(const UHDM::module_inst* uhdm_module);
    void add_src_attribute(dict<RTLIL::IdString, RTLIL::Const>& attributes, const UHDM::any* uhdm_obj);
    std::string get_src_attribute(const UHDM::any* uhdm_obj);
    RTLIL::IdString get_unique_cell_name(const std::string& base_name);
    
    // Helper to extract RTLIL::Const from UHDM Value string
    static RTLIL::Const extract_const_from_value(const std::string& value_str);
    
    // Signal name extraction from UHDM
    bool extract_signal_names_from_process(const UHDM::any* stmt, 
                                         std::string& output_signal, 
                                         std::string& input_signal,
                                         std::string& clock_signal, 
                                         std::string& reset_signal,
                                         std::vector<int>& slice_offsets,
                                         std::vector<int>& slice_widths);
    
    // Width extraction helpers
    int get_width_from_typespec(const UHDM::any* typespec, const UHDM::scope* inst = nullptr);
    bool calculate_struct_member_offset(const UHDM::typespec* ts, const std::string& member_path, 
                                       const UHDM::scope* inst, int& bit_offset, int& member_width);
    
    // Memory analysis and generation
    void analyze_and_generate_memories(const UHDM::module_inst* uhdm_module);
    void create_memory_from_array(const UHDM::array_net* uhdm_array);
    void create_memory_from_array(const UHDM::array_var* uhdm_array);
    
    // Helper functions to reduce code duplication
    const UHDM::assignment* cast_to_assignment(const UHDM::any* stmt);
    RTLIL::SigSpec create_temp_wire(int width = 1);
    RTLIL::SigSpec create_eq_cell(const RTLIL::SigSpec& a, const RTLIL::SigSpec& b, const UHDM::any* src = nullptr);
    RTLIL::SigSpec create_and_cell(const RTLIL::SigSpec& a, const RTLIL::SigSpec& b, const UHDM::any* src = nullptr);
    RTLIL::SigSpec create_or_cell(const RTLIL::SigSpec& a, const RTLIL::SigSpec& b, const UHDM::any* src = nullptr);
    RTLIL::SigSpec create_not_cell(const RTLIL::SigSpec& a, const UHDM::any* src = nullptr);
    RTLIL::SigSpec create_mux_cell(const RTLIL::SigSpec& sel, const RTLIL::SigSpec& b, const RTLIL::SigSpec& a, int width = 0);
    bool is_vpi_type(const UHDM::any* obj, int vpi_type);
    void process_assignment_lhs_rhs(const UHDM::assignment* assign, RTLIL::SigSpec& lhs, RTLIL::SigSpec& rhs);
    
    // Parameterized module creation
    std::string create_parameterized_module(const std::string& base_name, RTLIL::Module* base_module);
};

// Specialized importers for different aspects
struct UhdmModuleImporter;
struct UhdmMemoryImporter;
struct UhdmFsmImporter;

YOSYS_NAMESPACE_END

#endif