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
#include <uhdm/sv_vpi_user.h>
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
#include <uhdm/task_call.h>
#include <uhdm/task.h>

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

// Function call context for tracking individual function invocations
struct FunctionCallContext {
    // Identification
    std::string function_name;
    std::string instance_id;  // Unique ID like func$file:line$idx
    
    // Variable tracking
    std::map<std::string, RTLIL::SigSpec> wire_mappings;    // Variable -> Wire
    std::map<std::string, RTLIL::Const> const_values;       // Variable -> Const value
    std::map<std::string, RTLIL::Const> const_wire_values; // Track constant values of wires
    std::vector<RTLIL::SigSpec> arguments;
    
    // Metadata
    int call_depth;
    int source_line;
    std::string source_file;
    const UHDM::func_call* call_site;
    const UHDM::function* func_def;
    
    // For connecting instances
    RTLIL::Wire* result_wire;
    std::vector<RTLIL::Wire*> output_wires;
};

// Call stack manager for recursive function handling
class FunctionCallStack {
private:
    std::vector<FunctionCallContext> stack;
    std::map<std::string, RTLIL::Process*> generated_processes;
    std::map<std::string, RTLIL::SigSpec> memoized_results;
    static constexpr int MAX_DEPTH = 100;
    
public:
    // Stack operations
    bool push(FunctionCallContext ctx) {
        if (stack.size() >= MAX_DEPTH) {
            return false;
        }
        stack.push_back(std::move(ctx));
        return true;
    }
    
    void pop() {
        if (!stack.empty()) {
            stack.pop_back();
        }
    }
    
    // Return pointer to current context (top of stack), nullptr if empty
    FunctionCallContext* current() {
        if (!stack.empty()) {
            return &stack.back();
        }
        return nullptr;
    }
    
    const FunctionCallContext* parent() const {
        if (stack.size() < 2) {
            return nullptr;
        }
        return &stack[stack.size() - 2];
    }
    
    // Query operations
    bool isRecursive(const std::string& func_name) const {
        for (const auto& ctx : stack) {
            if (ctx.function_name == func_name) {
                return true;
            }
        }
        return false;
    }
    
    int getCallDepth(const std::string& func_name) const {
        int depth = 0;
        for (const auto& ctx : stack) {
            if (ctx.function_name == func_name) {
                depth++;
            }
        }
        return depth;
    }
    
    std::string generateInstanceId(const std::string& func_name, const std::string& filename, int line, int idx) {
        return stringf("%s$func$%s:%d$%d", func_name.c_str(), filename.c_str(), line, idx);
    }
    
    // Memoization
    bool hasCachedResult(const std::string& key) const {
        return memoized_results.count(key) > 0;
    }
    
    RTLIL::SigSpec getCachedResult(const std::string& key) const {
        auto it = memoized_results.find(key);
        return it != memoized_results.end() ? it->second : RTLIL::SigSpec();
    }
    
    void cacheResult(const std::string& key, RTLIL::SigSpec result) {
        memoized_results[key] = result;
    }
    
    // Check if empty
    bool empty() const { return stack.empty(); }
    
    // Get stack size
    size_t size() const { return stack.size(); }
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

    // Track nets driven by module instance output ports
    // These should not have the \reg attribute even if declared as reg
    std::set<std::string> instance_output_driven_nets;
    
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

    // Current generate scope for naming (deprecated - use gen_scope_stack)
    std::string current_gen_scope;
    
    // Generate scope stack for hierarchical lookups
    std::vector<std::string> gen_scope_stack;
    
    // Get the current full generate scope path
    std::string get_current_gen_scope() const {
        if (gen_scope_stack.empty()) {
            return "";
        }
        std::string path;
        for (size_t i = 0; i < gen_scope_stack.size(); i++) {
            if (i > 0) path += ".";
            path += gen_scope_stack[i];
        }
        return path;
    }
    
    // Context width for expression evaluation (from LHS of continuous assignments)
    // Used to propagate LHS width into arithmetic operations per Verilog semantics
    int expression_context_width = 0;

    // Loop variable values for unrolling
    std::map<std::string, int> loop_values;
    
    // Track accumulator values across loop iterations
    // Maps variable name to the current accumulated value
    std::map<std::string, RTLIL::SigSpec> loop_accumulators;
    
    // Current condition for conditional memory writes
    RTLIL::SigSpec current_condition;
    
    // UHDM design for accessing module definitions
    UHDM::design* uhdm_design = nullptr;
    
    // Context for handling async reset (maps signal name to temp wire)
    std::map<std::string, RTLIL::Wire*> current_signal_temp_wires;

    // Track current signal values during combinational always block processing
    // Maps signal name to its current SigSpec value (for task/function inlining)
    std::map<std::string, RTLIL::SigSpec> current_comb_values;

    // Maps hierarchical wire name to short VpiName (e.g., "foo.y" → "y") for named begin block variables
    std::map<std::string, std::string> comb_value_aliases;

    // Current combinational process pointer (non-null during import_always_comb statement processing)
    RTLIL::Process* current_comb_process = nullptr;
    
    // Track sync assignment targets for proper if-else handling
    std::map<std::string, RTLIL::Wire*> sync_assignment_targets;
    
    // Track assert enable wires created during process import
    std::vector<RTLIL::Wire*> current_assert_enable_wires;
    
    // Track current process context for assertions
    bool in_always_ff_context = false;
    
    // Function call stack for recursive function support
    FunctionCallStack function_call_stack;
    
    // Instance counter for generating unique function instance IDs
    int function_instance_counter = 0;
    
    // Get current function context for constant propagation (top of stack)
    FunctionCallContext* getCurrentFunctionContext() { 
        return function_call_stack.current();
    }
    RTLIL::SigSpec current_ff_clock_sig;
    
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
    
    struct AssignedSignal {
        std::string name;
        const expr* lhs_expr;  // The full LHS expression (could be part select)
        int msb = -1;
        int lsb = -1;
        bool is_part_select = false;
    };

    // Track pending sync assignments to merge multiple updates to same signal
    std::map<RTLIL::SigSpec, RTLIL::SigSpec> pending_sync_assignments;
    
    // Current loop variable substitutions for unrolling
    std::map<std::string, int64_t> current_loop_substitutions;
    
    // Track if we're currently processing an initial block
    bool in_initial_block = false;

    // Counter for generating unique unnamed block names
    int unnamed_block_counter = 0;

    // Track initial block assignments per signal to handle duplicates from generate unrolling.
    // Maps signal name to {sync_rule, action_index, from_generate_scope}.
    struct InitAssignInfo {
        RTLIL::SyncRule* sync;
        int action_idx;
        bool from_generate_scope;
    };
    std::map<std::string, InitAssignInfo> initial_signal_assignments;
    
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
    
    // Helper function to find wire in hierarchical generate scopes
    RTLIL::Wire* find_wire_in_scope(const std::string& signal_name, const std::string& context_for_log = "");
    
    // Expression handling
    RTLIL::SigSpec import_expression(const UHDM::expr* uhdm_expr, const std::map<std::string, RTLIL::SigSpec>* input_mapping = nullptr);
    
    RTLIL::SigSpec import_constant(const UHDM::constant* uhdm_const);
    RTLIL::SigSpec import_operation(const UHDM::operation* uhdm_op, const UHDM::scope* inst = nullptr, const std::map<std::string, RTLIL::SigSpec>* input_mapping = nullptr);
    RTLIL::SigSpec import_ref_obj(const UHDM::ref_obj* uhdm_ref, const UHDM::scope* inst = nullptr, const std::map<std::string, RTLIL::SigSpec>* input_mapping = nullptr);
    
    // Helper for evaluating expressions with variable substitution (for loop unrolling)
    RTLIL::SigSpec evaluate_expression_with_vars(const UHDM::expr* expr, 
                                                 const std::map<std::string, uint64_t>& vars,
                                                 const std::string& loop_var_name,
                                                 int64_t loop_index);
    
    // Statement interpreter for initial blocks
    void interpret_statement(const UHDM::any* stmt, std::map<std::string, int64_t>& variables,
                            std::map<std::string, std::vector<int64_t>>& arrays,
                            bool& break_flag, bool& continue_flag);
    
    // Expression evaluator for interpreter
    int64_t evaluate_expression(const UHDM::any* expr, std::map<std::string, int64_t>& variables,
                               std::map<std::string, std::vector<int64_t>>& arrays);
    
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
    void import_initial_sync(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    void import_initial_comb(const UHDM::process_stmt* uhdm_process, RTLIL::Process* yosys_proc);
    
    // TARGETED FIX: Memory for-loop processing
    bool is_memory_array(const UHDM::net* uhdm_net);
    bool is_memory_array(const UHDM::array_net* uhdm_array);
    bool is_memory_array(const UHDM::array_var* uhdm_array);
    bool has_only_constant_array_accesses(const std::string& array_name);
    void process_reset_block_for_memory(const UHDM::any* reset_stmt, RTLIL::CaseRule* reset_case);
    
    // Statement import for different contexts
    void import_statement_sync(const UHDM::any* uhdm_stmt, RTLIL::SyncRule* sync, bool is_reset);
    void import_statement_comb(const UHDM::any* uhdm_stmt, RTLIL::Process* proc);
    void import_statement_comb(const UHDM::any* uhdm_stmt, RTLIL::CaseRule* case_rule);
    void import_begin_block_sync(const UHDM::scope* uhdm_begin, RTLIL::SyncRule* sync, bool is_reset);
    void import_begin_block_comb(const UHDM::scope* uhdm_begin, RTLIL::Process* proc);
    void import_assignment_sync(const UHDM::assignment* uhdm_assign, RTLIL::SyncRule* sync);
    void import_assignment_comb(const UHDM::assignment* uhdm_assign, RTLIL::Process* proc);
    void import_assignment_comb(const UHDM::assignment* uhdm_assign, RTLIL::CaseRule* case_rule);
    void import_if_stmt_sync(const UHDM::if_stmt* uhdm_if, RTLIL::SyncRule* sync, bool is_reset);
    void import_if_stmt_comb(const UHDM::if_stmt* uhdm_if, RTLIL::Process* proc);
    void import_case_stmt_sync(const UHDM::case_stmt* uhdm_case, RTLIL::SyncRule* sync, bool is_reset);
    void import_case_stmt_comb(const UHDM::case_stmt* uhdm_case, RTLIL::Process* proc);

    // Task inlining for combinational processes
    void import_task_call_comb(const UHDM::task_call* tc, RTLIL::Process* proc);
    void inline_task_body_comb(const UHDM::any* stmt, RTLIL::Process* proc,
                               std::map<std::string, RTLIL::SigSpec>& task_mapping,
                               const std::string& context, const std::string& block_prefix,
                               const UHDM::any* process_src);

    // Function inlining for combinational processes
    RTLIL::SigSpec import_func_call_comb(const UHDM::func_call* fc, RTLIL::Process* proc);
    void inline_func_body_comb(const UHDM::any* stmt, RTLIL::Process* proc,
                               std::map<std::string, RTLIL::SigSpec>& func_mapping,
                               const std::string& func_name,
                               const std::string& context, const std::string& block_prefix,
                               const UHDM::any* process_src);

    // Assertion handling
    void import_immediate_assert(const UHDM::immediate_assert* assert_stmt, RTLIL::Wire*& enable_wire);
    
    // Additional expression types
    RTLIL::SigSpec import_part_select(const UHDM::part_select* uhdm_part, const UHDM::scope* inst = nullptr, const std::map<std::string, RTLIL::SigSpec>* input_mapping = nullptr);
    RTLIL::SigSpec import_bit_select(const UHDM::bit_select* uhdm_bit, const UHDM::scope* inst = nullptr, const std::map<std::string, RTLIL::SigSpec>* input_mapping = nullptr);
    RTLIL::SigSpec import_indexed_part_select(const UHDM::indexed_part_select* uhdm_indexed, const UHDM::scope* inst = nullptr, const std::map<std::string, RTLIL::SigSpec>* input_mapping = nullptr);
    RTLIL::SigSpec import_concat(const UHDM::operation* uhdm_concat, const UHDM::scope* inst = nullptr);
    RTLIL::SigSpec import_hier_path(const UHDM::hier_path* uhdm_hier, const UHDM::scope* inst = nullptr, const std::map<std::string, RTLIL::SigSpec>* input_mapping = nullptr);
    
    // Side-effect helpers for assignment expressions and inc/dec
    void emit_comb_assign(RTLIL::SigSpec lhs, RTLIL::SigSpec rhs, RTLIL::Process* proc);
    RTLIL::SigSpec map_to_temp_wire(RTLIL::SigSpec sig);

    // Utility functions
    RTLIL::IdString new_id(const std::string& name);
    std::string get_name(const UHDM::any* uhdm_obj);
    int get_width(const UHDM::any* uhdm_obj, const UHDM::scope* inst = nullptr);
    void import_attributes(dict<RTLIL::IdString, RTLIL::Const> &attributes, const UHDM::any* uhdm_obj);
    void import_memory_objects(const UHDM::module_inst* uhdm_module);
    void add_src_attribute(dict<RTLIL::IdString, RTLIL::Const>& attributes, const UHDM::any* uhdm_obj);
    std::string get_src_attribute(const UHDM::any* uhdm_obj);
    RTLIL::IdString get_unique_cell_name(const std::string& base_name);
    UHDM::VectorOfany *begin_block_stmts(const any *stmt);
    void extract_assigned_signals(const any* stmt, std::vector<AssignedSignal>& signals);
    void extract_assigned_signal_names(const any* stmt, std::set<std::string>& signal_names); 
    bool contains_complex_constructs(const any* stmt);
    bool is_memory_write(const assignment* assign, RTLIL::Module* module);
    void scan_for_memory_writes(const any* stmt, std::set<std::string>& memory_names, RTLIL::Module* module);
    const assignment* find_assignment_for_lhs(const any* stmt, const expr* lhs_expr);

    // Helper to extract RTLIL::Const from UHDM Value string
    static RTLIL::Const extract_const_from_value(const std::string& value_str);
    RTLIL::SigSpec extract_function_return_value(const UHDM::any* stmt, const std::string& func_name, int width);
    
    // Process function body and generate process blocks
    void scan_for_return_variables(const UHDM::any* stmt, const std::string& func_name,
                                   std::set<std::string>& return_vars, const UHDM::function* func_def = nullptr);
    void scan_for_direct_return_assignment(const UHDM::any* stmt, const std::string& func_name, bool& found);
    void process_stmt_to_case(const UHDM::any* stmt, RTLIL::CaseRule* case_rule,
                              RTLIL::Wire* result_wire,
                              std::map<std::string, RTLIL::SigSpec>& input_mapping,
                              const std::string& func_name,
                              int& temp_counter,
                              const std::string& func_call_context,
                              const std::map<std::string, int>& local_var_widths = {});
    
    RTLIL::Process* generate_function_process(const UHDM::function* func_def, const std::string& func_name,
                                              const std::vector<RTLIL::SigSpec>& args, RTLIL::Wire* result_wire, const UHDM::func_call* fc);
    
    // New context-aware function processing
    RTLIL::SigSpec process_function_with_context(const UHDM::function* func_def,
                                                 const std::vector<RTLIL::SigSpec>& args,
                                                 const UHDM::func_call* call_site,
                                                 FunctionCallContext* parent_ctx = nullptr);
    
    // Helper to create unique instance IDs for function calls
    std::string create_function_instance_id(const std::string& func_name,
                                            const UHDM::func_call* call_site);
    
    // Helper to handle recursive function calls with context
    RTLIL::SigSpec handle_recursive_call(FunctionCallContext& ctx,
                                         FunctionCallContext* parent_ctx);
    
    // Generate process for a specific function context
    RTLIL::Process* generate_process_for_context(const FunctionCallContext& ctx);
    
    // Evaluate function call at compile time (for initial blocks)
    RTLIL::Const evaluate_function_call(const UHDM::function* func_def, 
                                        const std::vector<RTLIL::Const>& const_args,
                                        std::map<std::string, RTLIL::Const>& output_params);
    
    // Helper to evaluate statements during compile-time function evaluation
    RTLIL::Const evaluate_function_stmt(const UHDM::any* stmt,
                                        std::map<std::string, RTLIL::Const>& local_vars,
                                        const std::string& func_name);
    
    // Helper to evaluate a single operand in compile-time context
    RTLIL::Const evaluate_single_operand(const UHDM::any* operand,
                                         const std::map<std::string, RTLIL::Const>& local_vars);

    // Helper to evaluate operations with constant values
    RTLIL::Const evaluate_operation_const(const UHDM::operation* op,
                                          const std::map<std::string, RTLIL::Const>& local_vars);
    
    // Helper to handle recursive function calls
    RTLIL::Const evaluate_recursive_function_call(const UHDM::func_call* fc,
                                                  const std::map<std::string, RTLIL::Const>& parent_vars);
    
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
    std::string generate_cell_name(const UHDM::any* uhdm_obj, const std::string& cell_type);
    int incr_autoidx() { return autoidx++; }
    // Parameterized module creation
    std::string create_parameterized_module(const std::string& base_name, RTLIL::Module* base_module);
};

// Specialized importers for different aspects
struct UhdmModuleImporter;
struct UhdmMemoryImporter;
struct UhdmFsmImporter;

YOSYS_NAMESPACE_END

#endif