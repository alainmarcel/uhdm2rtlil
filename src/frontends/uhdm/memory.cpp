/*
 * Memory and array handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog memory constructs
 * including arrays, memories, and memory operations.
 */

#include "uhdm2rtlil.h"

YOSYS_NAMESPACE_BEGIN
PRIVATE_NAMESPACE_BEGIN

using namespace UHDM;

// Memory importer for handling complex memory structures
struct UhdmMemoryImporter {
    UhdmImporter *parent;
    RTLIL::Module *module;
    
    UhdmMemoryImporter(UhdmImporter *parent) : parent(parent), module(parent->module) {}
    
    // Import memory declarations
    void import_memory(const logic_net* uhdm_mem);
    void import_array(const array_net* uhdm_array);
    
    // Import memory operations
    void import_memory_read(const operation* uhdm_read);
    void import_memory_write(const operation* uhdm_write);
    
    // Helper functions
    bool is_memory_type(const any* uhdm_obj);
    int get_memory_width(const any* uhdm_obj);
    int get_memory_size(const any* uhdm_obj);
};

// Import memory declaration
void UhdmMemoryImporter::import_memory(const logic_net* uhdm_mem) {
    std::string mem_name = uhdm_mem->VpiName();
    
    if (parent->mode_debug)
        log("  Importing memory: %s\n", mem_name.c_str());
    
    // Get memory dimensions
    int width = get_memory_width(uhdm_mem);
    int size = get_memory_size(uhdm_mem);
    
    // Create memory cell
    RTLIL::Cell* mem_cell = module->addCell(parent->new_id(mem_name), ID($mem));
    mem_cell->setParam(ID::WIDTH, width);
    mem_cell->setParam(ID::SIZE, size);
    mem_cell->setParam(ID::OFFSET, 0);
    
    // Create memory interface wires
    RTLIL::Wire* rd_clk = module->addWire(parent->new_id(mem_name + "_rd_clk"));
    RTLIL::Wire* rd_en = module->addWire(parent->new_id(mem_name + "_rd_en"));
    RTLIL::Wire* rd_addr = module->addWire(parent->new_id(mem_name + "_rd_addr"), 
                                          get_required_addr_bits(size));
    RTLIL::Wire* rd_data = module->addWire(parent->new_id(mem_name + "_rd_data"), width);
    
    RTLIL::Wire* wr_clk = module->addWire(parent->new_id(mem_name + "_wr_clk"));
    RTLIL::Wire* wr_en = module->addWire(parent->new_id(mem_name + "_wr_en"));
    RTLIL::Wire* wr_addr = module->addWire(parent->new_id(mem_name + "_wr_addr"), 
                                          get_required_addr_bits(size));
    RTLIL::Wire* wr_data = module->addWire(parent->new_id(mem_name + "_wr_data"), width);
    
    // Connect memory ports
    mem_cell->setPort(ID::RD_CLK, rd_clk);
    mem_cell->setPort(ID::RD_EN, rd_en);
    mem_cell->setPort(ID::RD_ADDR, rd_addr);
    mem_cell->setPort(ID::RD_DATA, rd_data);
    
    mem_cell->setPort(ID::WR_CLK, wr_clk);
    mem_cell->setPort(ID::WR_EN, wr_en);
    mem_cell->setPort(ID::WR_ADDR, wr_addr);
    mem_cell->setPort(ID::WR_DATA, wr_data);
    
    // Set memory parameters
    mem_cell->setParam(ID::RD_PORTS, 1);
    mem_cell->setParam(ID::WR_PORTS, 1);
    mem_cell->setParam(ID::RD_CLK_ENABLE, 1);
    mem_cell->setParam(ID::RD_CLK_POLARITY, 1);
    mem_cell->setParam(ID::WR_CLK_ENABLE, 1);
    mem_cell->setParam(ID::WR_CLK_POLARITY, 1);
    mem_cell->setParam(ID::RD_TRANSPARENT, 0);
    
    // Store memory information for later use
    parent->name_map[mem_name] = rd_data;  // For read operations
}

// Import array declaration
void UhdmMemoryImporter::import_array(const array_net* uhdm_array) {
    std::string array_name = uhdm_array->VpiName();
    
    if (parent->mode_debug)
        log("  Importing array: %s\n", array_name.c_str());
    
    // For now, treat arrays similarly to memories
    // TODO: Implement proper array handling for different array types
    log_warning("Array handling not fully implemented yet\n");
}

// Import memory read operation
void UhdmMemoryImporter::import_memory_read(const operation* uhdm_read) {
    if (parent->mode_debug)
        log("    Importing memory read operation\n");
    
    // TODO: Implement memory read operation
    // This would involve connecting the address and enabling the read
    log_warning("Memory read operations not fully implemented yet\n");
}

// Import memory write operation
void UhdmMemoryImporter::import_memory_write(const operation* uhdm_write) {
    if (parent->mode_debug)
        log("    Importing memory write operation\n");
    
    // TODO: Implement memory write operation
    // This would involve connecting the address, data, and enabling the write
    log_warning("Memory write operations not fully implemented yet\n");
}

// Check if object is a memory type
bool UhdmMemoryImporter::is_memory_type(const any* uhdm_obj) {
    int obj_type = uhdm_obj->VpiType();
    return (obj_type == vpiMemory || obj_type == vpiMemoryWord || obj_type == vpiReg);
}

// Get memory width
int UhdmMemoryImporter::get_memory_width(const any* uhdm_obj) {
    // Default to 1 bit
    int width = 1;
    
    if (auto typed = dynamic_cast<const expr*>(uhdm_obj)) {
        if (typed->VpiSize() > 0) {
            width = typed->VpiSize();
        }
    }
    
    return width;
}

// Get memory size (number of words)
int UhdmMemoryImporter::get_memory_size(const any* uhdm_obj) {
    // Default to single word
    int size = 1;
    
    // TODO: Extract size from UHDM object
    // This would involve analyzing the array bounds
    
    return size;
}

// Calculate required address bits for memory size
int get_required_addr_bits(int size) {
    if (size <= 1) return 1;
    int bits = 0;
    int temp = size - 1;
    while (temp > 0) {
        bits++;
        temp >>= 1;
    }
    return bits;
}

// Main memory import function for UhdmImporter
void UhdmImporter::import_memory_objects(const Module* uhdm_module) {
    UhdmMemoryImporter mem_importer(this);
    
    // Import memory declarations
    if (uhdm_module->Nets()) {
        for (auto net : *uhdm_module->Nets()) {
            if (mem_importer.is_memory_type(net)) {
                if (auto logic_net = dynamic_cast<const logic_net*>(net)) {
                    mem_importer.import_memory(logic_net);
                } else if (auto array_net = dynamic_cast<const array_net*>(net)) {
                    mem_importer.import_array(array_net);
                }
            }
        }
    }
}

PRIVATE_NAMESPACE_END
YOSYS_NAMESPACE_END