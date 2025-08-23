/*
 * Clocking and timing analysis for UHDM to RTLIL translation
 * 
 * This file handles the extraction and analysis of clocking information
 * from SystemVerilog always blocks.
 */

#include "uhdm2rtlil.h"

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Constructor for UhdmClocking
UhdmClocking::UhdmClocking(UhdmImporter *importer, const any* proc_obj) {
    module = importer->module;
    
    // Extract clocking information from process statement
    if (auto proc = dynamic_cast<const process_stmt*>(proc_obj)) {
        log("    UhdmClocking: Analyzing process for clocking information\n");
        
        // Check if this process has any clocking characteristics
        // Look for clock/reset references in the statement structure
        if (auto stmt = proc->Stmt()) {
            analyze_statement_for_clocking(importer, stmt);
        }
        
        log("    UhdmClocking: Found clock=%s, reset=%s\n", 
            clock_sig == State::Sx ? "none" : "present",
            has_reset ? "present" : "none");
    }
}

// Analyze a statement recursively to find clocking signals
void UhdmClocking::analyze_statement_for_clocking(UhdmImporter *importer, const any* stmt) {
    if (!stmt) return;
    
    // Look for references to signals named "clk", "clock", "reset", "rst"
    // This is a heuristic-based approach since UHDM sensitivity lists are complex
    
    // Check if this is a reference to a potential clock/reset signal
    if (stmt->VpiType() == vpiRefObj) {
        if (auto ref = dynamic_cast<const ref_obj*>(stmt)) {
            std::string name = std::string(ref->VpiName());
            
            log("    UhdmClocking: Analyzing signal reference: %s\n", name.c_str());
            
            if (name.find("clk") != std::string::npos || name.find("clock") != std::string::npos) {
                clock_sig = importer->get_sig_bit(ref);
                log("    UhdmClocking: Found potential clock signal: %s\n", name.c_str());
            } else if (name.find("rst") != std::string::npos || name.find("reset") != std::string::npos) {
                has_reset = true;
                reset_sig = importer->get_sig_bit(ref);
                log("    UhdmClocking: Found potential reset signal: %s\n", name.c_str());
            }
        }
    }
    
    // Recursively analyze child statements
    // For if statements, analyze condition and branches
    if (stmt->VpiType() == vpiIf) {
        if (auto if_stmt = dynamic_cast<const if_else*>(stmt)) {
            if (auto condition = if_stmt->VpiCondition()) {
                analyze_statement_for_clocking(importer, condition);
            }
            if (auto then_stmt = if_stmt->VpiStmt()) {
                analyze_statement_for_clocking(importer, then_stmt);
            }
            if (auto else_stmt = if_stmt->VpiElseStmt()) {
                analyze_statement_for_clocking(importer, else_stmt);
            }
        }
    }
    
    // For operations, analyze operands
    if (stmt->VpiType() == vpiOperation) {
        if (auto op = dynamic_cast<const operation*>(stmt)) {
            if (auto operands = op->Operands()) {
                for (auto operand : *operands) {
                    analyze_statement_for_clocking(importer, operand);
                }
            }
        }
    }
    
    // For other statement types, we could add more specific analysis
    // but this heuristic should catch most clock/reset signals
}

// Analyze sensitivity list to extract clock and reset
void UhdmClocking::analyze_sensitivity_list(UhdmImporter *importer, 
                                           const VectorOfany* sensitivity) {
    for (auto sens : *sensitivity) {
        int sens_type = sens->VpiType();
        
        switch (sens_type) {
            case vpiPosedge: {
                // Positive edge - likely clock
                if (auto edge = dynamic_cast<const operation*>(sens)) {
                    if (auto operands = edge->Operands()) {
                        if (!operands->empty()) {
                            clock_sig = importer->get_sig_bit((*operands)[0]);
                            posedge_clk = true;
                        }
                    }
                }
                break;
            }
            case vpiNegedge: {
                // Negative edge - could be clock or reset
                if (auto edge = dynamic_cast<const operation*>(sens)) {
                    if (auto operands = edge->Operands()) {
                        if (!operands->empty()) {
                            RTLIL::SigBit sig = importer->get_sig_bit((*operands)[0]);
                        
                            // Heuristic: if we don't have a clock yet, this might be it
                            if (clock_sig == State::Sx) {
                                clock_sig = sig;
                                posedge_clk = false;
                            } else {
                                // This is likely a reset
                                reset_sig = sig;
                                negedge_reset = true;
                                has_reset = true;
                            }
                        }
                    }
                }
                break;
            }
            default:
                // Level sensitive - might be reset or enable
                if (auto ref = dynamic_cast<const ref_obj*>(sens)) {
                    RTLIL::SigBit sig = importer->get_sig_bit(ref);
                    
                    // If no reset found yet, assume this is reset
                    if (!has_reset) {
                        reset_sig = sig;
                        negedge_reset = false;  // Active high reset
                        has_reset = true;
                    }
                }
                break;
        }
    }
}

// Create a D flip-flop with this clocking
RTLIL::Cell* UhdmClocking::addDff(IdString name, SigSpec sig_d, SigSpec sig_q, Const init_value) {
    if (clock_sig == State::Sx) {
        log_error("Cannot create DFF without clock signal\n");
        return nullptr;
    }
    
    RTLIL::Cell* cell = module->addCell(name, ID($dff));
    cell->setPort(ID::CLK, clock_sig);
    cell->setPort(ID::D, sig_d);
    cell->setPort(ID::Q, sig_q);
    cell->setParam(ID::WIDTH, sig_d.size());
    cell->setParam(ID::CLK_POLARITY, posedge_clk);
    
    if (init_value.size() > 0) {
        cell->setParam(ID::INIT, init_value);
    }
    
    return cell;
}

// Create a D flip-flop with async reset
RTLIL::Cell* UhdmClocking::addAdff(IdString name, SigSpec sig_d, SigSpec sig_q, Const arst_value) {
    if (clock_sig == State::Sx) {
        log_error("Cannot create ADFF without clock signal\n");
        return nullptr;
    }
    
    if (!has_reset) {
        log_error("Cannot create ADFF without reset signal\n");
        return nullptr;
    }
    
    RTLIL::Cell* cell = module->addCell(name, ID($adff));
    cell->setPort(ID::CLK, clock_sig);
    cell->setPort(ID::ARST, reset_sig);
    cell->setPort(ID::D, sig_d);
    cell->setPort(ID::Q, sig_q);
    cell->setParam(ID::WIDTH, sig_d.size());
    cell->setParam(ID::CLK_POLARITY, posedge_clk);
    cell->setParam(ID::ARST_POLARITY, !negedge_reset);
    cell->setParam(ID::ARST_VALUE, arst_value);
    
    return cell;
}

// Get signal bit from UHDM object
RTLIL::SigBit UhdmImporter::get_sig_bit(const any* uhdm_obj) {
    if (net_map.count(uhdm_obj)) {
        return net_map[uhdm_obj];
    }
    
    // Try to create from expression
    RTLIL::SigSpec sig = import_expression(dynamic_cast<const expr*>(uhdm_obj));
    if (sig.size() > 0) {
        RTLIL::SigBit bit = sig[0];
        net_map[uhdm_obj] = bit;
        return bit;
    }
    
    return RTLIL::State::Sx;
}

// Get signal spec from UHDM object
RTLIL::SigSpec UhdmImporter::get_sig_spec(const any* uhdm_obj, int width) {
    // Return a simple wire for now
    return create_wire("sig", width);
    
    return RTLIL::SigSpec(RTLIL::State::Sx, width);
}

// Get wire from UHDM object
RTLIL::Wire* UhdmImporter::get_wire(const any* uhdm_obj, int width) {
    if (wire_map.count(uhdm_obj)) {
        return wire_map[uhdm_obj];
    }
    
    // Create new wire
    std::string name = get_name(uhdm_obj);
    if (name.empty()) {
        name = "unnamed_wire";
    }
    
    RTLIL::Wire* wire = create_wire(name, width);
    wire_map[uhdm_obj] = wire;
    return wire;
}

YOSYS_NAMESPACE_END