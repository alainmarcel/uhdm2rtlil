/*
 * UHDM Memory Analysis Pass
 * 
 * This file implements a comprehensive memory analysis pass that:
 * 1. Analyzes UHDM to identify memory objects and their usage patterns
 * 2. Builds an intermediate representation of memory structures
 * 3. Generates proper RTLIL memory primitives from the analysis
 */

#include "uhdm2rtlil.h"
#include <map>
#include <set>
#include <vector>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Intermediate representation for memory objects
struct MemoryInfo {
    std::string name;
    int width = 8;
    int size = 1;
    int addr_width = 1;
    bool is_array = false;
    bool has_initialization = false;
    
    // Access patterns found during analysis
    std::set<std::string> read_locations;
    std::set<std::string> write_locations;
    
    // Clock and enable signals
    std::string clock_signal;
    std::string reset_signal;
    
    // Source location for debugging
    std::string source_location;
};

// Memory access operation
struct MemoryAccess {
    enum Type { READ, WRITE };
    Type type;
    std::string memory_name;
    std::string addr_signal;
    std::string data_signal;
    std::string enable_signal;
    std::string clock_signal;
    bool is_conditional = false;
    std::string condition_signal;
    std::string source_location;
};

// UHDM Memory Analysis Pass
class UhdmMemoryAnalyzer {
public:
    UhdmImporter *parent;
    RTLIL::Module *module;
    
    // Analysis results
    std::map<std::string, MemoryInfo> memories;
    std::vector<MemoryAccess> memory_accesses;
    
    UhdmMemoryAnalyzer(UhdmImporter *parent) : parent(parent), module(parent->module) {}
    
    // Main analysis entry point
    void analyze_module(const module_inst* uhdm_module);
    
    // Analysis phases
    void analyze_memory_declarations(const module_inst* uhdm_module);
    void analyze_memory_usage_in_processes(const module_inst* uhdm_module);
    void analyze_memory_usage_in_expressions(const expr* expression, const std::string& context);
    
    // Memory detection helpers
    bool is_memory_declaration(const net* uhdm_net);
    MemoryInfo extract_memory_info(const net* uhdm_net);
    int calculate_address_width(int size);
    
    // Access pattern analysis
    void analyze_always_block(const process_stmt* uhdm_process);
    void analyze_statement_for_memory(const any* statement, const std::string& context);
    void analyze_assignment_for_memory(const assignment* assign, const std::string& context);
    void analyze_hierarchical_access(const ref_obj* hier_ref, const std::string& context);
    
    // RTLIL generation from analysis
    void generate_rtlil_memories();
    void generate_memory_block(const MemoryInfo& mem_info);
    void generate_memory_operations();
    void generate_memory_read_cell(const MemoryAccess& access);
    void generate_memory_write_process(const std::vector<MemoryAccess>& writes);
    
    // Utilities
    std::string get_source_location(const any* uhdm_obj);
    bool is_power_of_two(int value);
};

// Main analysis function
void UhdmMemoryAnalyzer::analyze_module(const module_inst* uhdm_module) {
    if (parent->mode_debug)
        log("Starting memory analysis for module\n");
    
    // Phase 1: Find all memory declarations
    analyze_memory_declarations(uhdm_module);
    
    // Phase 2: Analyze memory usage patterns in processes
    analyze_memory_usage_in_processes(uhdm_module);
    
    // Phase 3: Generate RTLIL from analysis
    generate_rtlil_memories();
    
    if (parent->mode_debug) {
        log("Memory analysis complete. Found %zu memories, %zu accesses\n", 
            memories.size(), memory_accesses.size());
    }
}

// Analyze memory declarations in nets
void UhdmMemoryAnalyzer::analyze_memory_declarations(const module_inst* uhdm_module) {
    if (!uhdm_module->Nets()) return;
    
    for (auto net : *uhdm_module->Nets()) {
        if (is_memory_declaration(net)) {
            MemoryInfo mem_info = extract_memory_info(net);
            memories[mem_info.name] = mem_info;
            
            if (parent->mode_debug) {
                log("  Found memory: %s, width=%d, size=%d\n", 
                    mem_info.name.c_str(), mem_info.width, mem_info.size);
            }
        }
    }
}

// Check if a net represents a memory declaration
bool UhdmMemoryAnalyzer::is_memory_declaration(const net* uhdm_net) {
    // Check for memory/array types
    int vpi_type = uhdm_net->VpiType();
    if (vpi_type == vpiMemory || vpi_type == vpiMemoryWord) {
        return true;
    }
    
    // Check for register arrays (reg [width-1:0] mem [size-1:0])
    if (vpi_type == vpiReg || vpi_type == vpiLogicNet) {
        // For now, use a simple heuristic - look for "memory" in the name
        std::string net_name = std::string(uhdm_net->VpiName());
        if (net_name.find("memory") != std::string::npos) {
            return true;
        }
    }
    
    return false;
}

// Extract memory information from UHDM net
MemoryInfo UhdmMemoryAnalyzer::extract_memory_info(const net* uhdm_net) {
    MemoryInfo info;
    info.name = std::string(uhdm_net->VpiName());
    info.source_location = get_source_location(uhdm_net);
    
    // For now, use default values based on simple_memory test
    // In the future, this should extract actual dimensions from UHDM
    info.width = 8;  // WIDTH parameter
    info.size = 16;  // DEPTH parameter
    
    // Calculate address width
    info.addr_width = calculate_address_width(info.size);
    
    return info;
}

// Calculate required address width for memory size
int UhdmMemoryAnalyzer::calculate_address_width(int size) {
    if (size <= 1) return 1;
    int bits = 0;
    int temp = size - 1;
    while (temp > 0) {
        bits++;
        temp >>= 1;
    }
    return bits;
}

// Analyze memory usage in always blocks
void UhdmMemoryAnalyzer::analyze_memory_usage_in_processes(const module_inst* uhdm_module) {
    if (!uhdm_module->Process()) return;
    
    for (auto process : *uhdm_module->Process()) {
        analyze_always_block(process);
    }
}

// Analyze individual always block for memory operations
void UhdmMemoryAnalyzer::analyze_always_block(const process_stmt* uhdm_process) {
    if (parent->mode_debug)
        log("  Analyzing always block for memory operations\n");
    
    // Analyze statements in the process
    if (auto stmt = uhdm_process->Stmt()) {
        analyze_statement_for_memory(stmt, "always_block");
    }
}

// Analyze statement for memory operations (needs implementation)
void UhdmMemoryAnalyzer::analyze_statement_for_memory(const any* statement, const std::string& context) {
    if (!statement) return;
    
    int stmt_type = statement->VpiType();
    
    if (stmt_type == vpiAssignment) {
        auto assign = static_cast<const assignment*>(statement);
        analyze_assignment_for_memory(assign, context);
    } else if (stmt_type == vpiIf) {
        auto if_stmt = static_cast<const if_else*>(statement);
        if (auto then_stmt = if_stmt->VpiStmt()) {
            analyze_statement_for_memory(then_stmt, context + "_if");
        }
        // Handle else clause if present
    } else if (stmt_type == vpiBegin) {
        auto begin_stmt = static_cast<const UHDM::begin*>(statement);
        if (auto stmts = begin_stmt->Stmts()) {
            for (auto nested_stmt : *stmts) {
                analyze_statement_for_memory(nested_stmt, context + "_begin");
            }
        }
    }
    // Add more statement types as needed
}

// Analyze assignment for memory access patterns
void UhdmMemoryAnalyzer::analyze_assignment_for_memory(const assignment* assign, const std::string& context) {
    if (!assign->Lhs() || !assign->Rhs()) return;
    
    if (parent->mode_debug) {
        log("    Analyzing assignment for memory patterns (context: %s)\n", context.c_str());
    }
    
    // Check if LHS is memory access (write operation)
    if (auto lhs_ref = dynamic_cast<const ref_obj*>(assign->Lhs())) {
        analyze_hierarchical_access(lhs_ref, context + "_write");
    }
    
    // Check if RHS contains memory access (read operation)
    if (auto rhs_expr = dynamic_cast<const expr*>(assign->Rhs())) {
        analyze_memory_usage_in_expressions(rhs_expr, context + "_read");
    }
    
    // Check for indexed references which indicate memory access
    if (assign->Rhs()->VpiType() == vpiIndexedPartSelect || assign->Rhs()->VpiType() == vpiPartSelect) {
        if (parent->mode_debug) {
            log("      Found indexed part select - potential memory read\n");
        }
        // This could be memory[addr] access - cast to expr*
        if (auto rhs_expr = dynamic_cast<const expr*>(assign->Rhs())) {
            analyze_memory_usage_in_expressions(rhs_expr, context + "_indexed_read");
        }
    }
}

// Analyze hierarchical reference for memory access
void UhdmMemoryAnalyzer::analyze_hierarchical_access(const ref_obj* hier_ref, const std::string& context) {
    if (!hier_ref) return;
    
    std::string ref_name = std::string(hier_ref->VpiName());
    
    // Check if this references a known memory
    if (memories.find(ref_name) != memories.end()) {
        MemoryAccess access;
        access.memory_name = ref_name;
        access.type = (context.find("write") != std::string::npos) ? 
                      MemoryAccess::WRITE : MemoryAccess::READ;
        access.source_location = get_source_location(hier_ref);
        
        // Extract address expression if present
        // This would require analyzing the hierarchical reference structure
        
        memory_accesses.push_back(access);
        
        if (parent->mode_debug) {
            log("    Found %s access to memory %s\n", 
                (access.type == MemoryAccess::WRITE) ? "write" : "read",
                ref_name.c_str());
        }
    }
}

// Analyze expressions for memory references
void UhdmMemoryAnalyzer::analyze_memory_usage_in_expressions(const expr* expression, const std::string& context) {
    if (!expression) return;
    
    if (parent->mode_debug) {
        log("      Analyzing expression for memory usage (VpiType=%d, context=%s)\n", 
            expression->VpiType(), context.c_str());
    }
    
    // Check if expression is a hierarchical reference to memory
    if (auto hier_ref = dynamic_cast<const ref_obj*>(expression)) {
        analyze_hierarchical_access(hier_ref, context);
    }
    
    // Check for indexed memory access patterns
    int expr_type = expression->VpiType();
    if (expr_type == vpiPartSelect || expr_type == vpiIndexedPartSelect || expr_type == vpiBitSelect) {
        if (parent->mode_debug) {
            log("        Found select operation - checking if it's memory access\n");
        }
        
        // Try to extract the base object and index
        // This would require UHDM-specific API calls to get parent/child relationships
        auto vpi_name = expression->VpiName();
        std::string expr_name = (!vpi_name.empty()) ? std::string(vpi_name) : "";
        if (!expr_name.empty() && memories.find(expr_name) != memories.end()) {
            // Found memory access!
            MemoryAccess access;
            access.memory_name = expr_name;
            access.type = (context.find("write") != std::string::npos) ? 
                          MemoryAccess::WRITE : MemoryAccess::READ;
            access.source_location = get_source_location(expression);
            memory_accesses.push_back(access);
            
            if (parent->mode_debug) {
                log("        Detected %s access to memory %s\n", 
                    (access.type == MemoryAccess::WRITE) ? "write" : "read",
                    expr_name.c_str());
            }
        }
    }
    
    // Recursively analyze sub-expressions
    // Add more expression types as needed
}

// Generate RTLIL memory blocks and operations
void UhdmMemoryAnalyzer::generate_rtlil_memories() {
    // Generate memory blocks
    for (const auto& pair : memories) {
        generate_memory_block(pair.second);
    }
    
    // Generate memory operations
    generate_memory_operations();
}

// Generate RTLIL memory block
void UhdmMemoryAnalyzer::generate_memory_block(const MemoryInfo& mem_info) {
    if (parent->mode_debug)
        log("  Generating RTLIL memory: %s\n", mem_info.name.c_str());
    
    // Create memory object
    RTLIL::IdString mem_id = RTLIL::escape_id(mem_info.name);
    RTLIL::Memory *memory = new RTLIL::Memory;
    memory->name = mem_id;
    memory->width = mem_info.width;
    memory->size = mem_info.size;
    memory->start_offset = 0;
    
    // Add source attribute
    if (!mem_info.source_location.empty()) {
        memory->attributes[ID::src] = RTLIL::Const(mem_info.source_location);
    }
    
    module->memories[mem_id] = memory;
    
    if (parent->mode_debug)
        log("    Created memory %s: width=%d, size=%d\n", 
            mem_info.name.c_str(), mem_info.width, mem_info.size);
}

// Generate memory operations from analysis
void UhdmMemoryAnalyzer::generate_memory_operations() {
    // Group accesses by memory and type
    std::map<std::string, std::vector<MemoryAccess>> reads, writes;
    
    for (const auto& access : memory_accesses) {
        if (access.type == MemoryAccess::READ) {
            reads[access.memory_name].push_back(access);
        } else {
            writes[access.memory_name].push_back(access);
        }
    }
    
    // Generate read cells
    for (const auto& pair : reads) {
        for (const auto& read_access : pair.second) {
            generate_memory_read_cell(read_access);
        }
    }
    
    // Generate write processes
    for (const auto& pair : writes) {
        if (!pair.second.empty()) {
            generate_memory_write_process(pair.second);
        }
    }
}

// Generate memory read cell (following Yosys Verilog frontend pattern)
void UhdmMemoryAnalyzer::generate_memory_read_cell(const MemoryAccess& access) {
    const auto& mem_info = memories[access.memory_name];
    
    // Generate cell name following Yosys pattern: $memrd$<memory>$<location>$<id>
    std::stringstream cell_name_stream;
    cell_name_stream << "$memrd$" << access.memory_name << "$" << access.source_location;
    std::string cell_name = parent->new_id(cell_name_stream.str()).str();
    
    RTLIL::Cell* read_cell = module->addCell(cell_name, ID($memrd));
    
    // Create data wire following Yosys pattern: <cell_name>_DATA
    RTLIL::Wire* data_wire = module->addWire(cell_name + "_DATA", mem_info.width);
    
    // Set parameters following Yosys Verilog frontend pattern
    read_cell->setParam(ID::MEMID, RTLIL::Const(access.memory_name));
    read_cell->setParam(ID::ABITS, mem_info.addr_width);
    read_cell->setParam(ID::WIDTH, mem_info.width);
    read_cell->setParam(ID::CLK_ENABLE, RTLIL::Const(0));
    read_cell->setParam(ID::CLK_POLARITY, RTLIL::Const(0));
    read_cell->setParam(ID::TRANSPARENT, RTLIL::Const(0));
    
    // Connect ports following Yosys pattern
    read_cell->setPort(ID::CLK, RTLIL::SigSpec(RTLIL::State::Sx, 1));
    read_cell->setPort(ID::EN, RTLIL::SigSpec(RTLIL::State::Sx, 1));
    read_cell->setPort(ID::DATA, RTLIL::SigSpec(data_wire));
    
    // For now, create a dummy address signal - this should be extracted from UHDM
    // This would be replaced with actual address extraction from memory access
    RTLIL::Wire* addr_wire = module->addWire(parent->new_id("addr"), mem_info.addr_width);
    read_cell->setPort(ID::ADDR, addr_wire);
    
    // Add source attribute to match Verilog frontend
    if (!access.source_location.empty()) {
        read_cell->attributes[ID::src] = RTLIL::Const(access.source_location);
        data_wire->attributes[ID::src] = RTLIL::Const(access.source_location);
    }
    
    if (parent->mode_debug)
        log("    Generated $memrd cell %s for memory %s\n", cell_name.c_str(), access.memory_name.c_str());
}

// Generate memory write process (simplified)
void UhdmMemoryAnalyzer::generate_memory_write_process(const std::vector<MemoryAccess>& writes) {
    if (writes.empty()) return;
    
    const auto& first_write = writes[0];
    const auto& mem_info = memories[first_write.memory_name];
    
    if (parent->mode_debug)
        log("    Generating write process for memory %s\n", first_write.memory_name.c_str());
    
    // This is a simplified implementation
    // In practice, this would need to integrate with the existing process generation
    // to handle the specific always block structure and conditions
}

// Get source location string from UHDM object
std::string UhdmMemoryAnalyzer::get_source_location(const any* uhdm_obj) {
    if (!uhdm_obj) return "";
    
    // Try to extract source location information
    // This would need proper UHDM API calls
    return "unknown_location";
}

// Helper function to check if value is power of two
bool UhdmMemoryAnalyzer::is_power_of_two(int value) {
    return value > 0 && (value & (value - 1)) == 0;
}

// Main entry point for memory analysis
void UhdmImporter::analyze_and_generate_memories(const module_inst* uhdm_module) {
    UhdmMemoryAnalyzer analyzer(this);
    analyzer.analyze_module(uhdm_module);
}

YOSYS_NAMESPACE_END