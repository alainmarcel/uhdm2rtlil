/*
 * Primitive Gate UHDM to RTLIL translation
 * 
 * This file handles the translation of Verilog primitive gates
 * (and, or, not, nand, nor, xor, xnor, buf, bufif0, bufif1, notif0, notif1)
 * from UHDM to Yosys RTLIL format.
 */

#include "uhdm2rtlil.h"
#include <uhdm/gate.h>
#include <uhdm/gate_array.h>
#include <uhdm/prim_term.h>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Import primitive gates from a module
// Surelog builds a module DEFINITION's primitives from the parse tree with
// CompileHelper::compileGateInstantiation, which assumes every gate has a
// Name_of_instance.  An UNNAMED gate (`and (y, a, b);`, `buf (O, PAD);` --
// legal, LRM 28.3.4) has none, so the walk starts at its SECOND terminal and
// the definition holds a gate missing its output (and other unnamed gates
// dropped altogether).  NetlistElaboration checks the node type and builds
// the ELABORATED instance's gates correctly.  A top module is imported from
// its elaborated instance and never saw this; every CHILD module with an
// unnamed gate stopped the read with "Gate has insufficient terminals"
// (pulpissimo hyper_macro via tech_cells_generic pad_functional_pd).
//
// So for a DEFINITION import take the primitives from an elaborated instance
// of it -- same guard as the net-declaration-initialiser recovery in
// import_module: a module that already IS an elaborated instance keeps its
// own (the first instance of the definition may be a sibling $paramod).
//
// A definition NOTHING instantiates (a cell library file in the source list:
// openpiton's u1.beh.v `bw_u1_ckbuf_1p5x` is `buf (clk, rclk);`) has no
// elaborated copy to take from.  Its unnamed gates cannot be recovered, and
// the module is dead -- `hierarchy -top` removes it -- so import_gate skips
// them with a warning instead of stopping the whole read
// (prims_from_unelab_def_).
const module_inst* UhdmImporter::primitives_source(const module_inst* uhdm_module) {
    prims_from_unelab_def_ = false;
    if (!uhdm_module) return nullptr;
    build_elab_index();
    auto sit = elab_insts_by_def_.find(std::string(uhdm_module->VpiDefName()));
    if (sit == elab_insts_by_def_.end()) {
        prims_from_unelab_def_ = true;
        return uhdm_module;
    }
    for (auto m : sit->second)
        if (m == uhdm_module) return uhdm_module;
    const module_inst* elab = find_elab_instance(uhdm_module);
    if (elab && (elab->Primitives() || elab->Primitive_arrays())) {
        if (mode_debug)
            log("UHDM: taking primitives of definition %s from elaborated instance %s\n",
                std::string(uhdm_module->VpiDefName()).c_str(),
                std::string(elab->VpiFullName()).c_str());
        return elab;
    }
    return uhdm_module;
}

void UhdmImporter::import_primitives(const module_inst* uhdm_module) {
    uhdm_module = primitives_source(uhdm_module);
    if (!uhdm_module) return;
    
    // Import primitive gates from module
    if (uhdm_module->Primitives()) {
        uhdm_trace("UHDM: Found %d primitive gates\n", (int)uhdm_module->Primitives()->size());
        pending_pulls_.clear();
        for (auto prim : *uhdm_module->Primitives()) {
            if (auto gate = dynamic_cast<const UHDM::gate*>(prim)) {
                std::string instance_name(gate->VpiName());
                import_gate(gate, instance_name);
            } else if (auto u = dynamic_cast<const UHDM::udp*>(prim)) {
                import_udp(u);
            }
        }
        resolve_pulls();
    }
}

// `pullup p(bus)` next to `bufif1 g1(bus, a, en_a); bufif1 g2(bus, b, en_b);`
// (IEEE 1800-2023 28.10): the pull is a weak driver, so the net is the
// enabled buffer's value, and the pull value only when no buffer is
// enabled -- bus = en_a ? a : en_b ? b : 1.  Driving the pull as a second
// strong driver (what read_slang does) makes `en_a & !a` read 1.  Each
// pulled bit's $_TBUF_ drivers are folded into that mux chain; a pulled bit
// no three-state gate drives takes the pull value.
void UhdmImporter::resolve_pulls() {
    if (pending_pulls_.empty()) return;
    SigMap sigmap(module);
    dict<RTLIL::SigBit, std::vector<RTLIL::Cell*>> tbufs;
    for (auto cell : module->cells())
        if (cell->type == ID($_TBUF_))
            tbufs[sigmap(cell->getPort(ID::Y).as_bit())].push_back(cell);
    for (auto& [net, v] : pending_pulls_) {
        for (int b = 0; b < net.size(); b++) {
            RTLIL::SigBit bit = sigmap(net[b]);
            auto it = tbufs.find(bit);
            if (it == tbufs.end() || it->second.empty()) {
                module->connect(net[b], RTLIL::SigBit(v));
                continue;
            }
            RTLIL::SigBit val(v);
            for (auto cell : it->second) {
                RTLIL::SigBit a = cell->getPort(ID::A).as_bit();
                RTLIL::SigBit e = cell->getPort(ID::E).as_bit();
                RTLIL::SigBit y = module->addWire(NEW_ID);
                module->addMuxGate(NEW_ID, val, a, e, y);
                val = y;
                module->remove(cell);
            }
            it->second.clear();
            module->connect(net[b], val);
        }
    }
    pending_pulls_.clear();
}

// Import primitive gate arrays from a module
void UhdmImporter::import_primitive_arrays(const module_inst* uhdm_module) {
    uhdm_module = primitives_source(uhdm_module);
    if (!uhdm_module) return;
    
    // Check for Primitive_arrays() which should contain gate arrays
    if (uhdm_module->Primitive_arrays()) {
        uhdm_trace("UHDM: Found %d primitive arrays\n", (int)uhdm_module->Primitive_arrays()->size());
        for (auto prim_array : *uhdm_module->Primitive_arrays()) {
            if (auto gate_array = dynamic_cast<const UHDM::gate_array*>(prim_array)) {
                import_gate_array(gate_array);
            }
        }
    }
}

// Import a single gate
void UhdmImporter::import_gate(const gate* uhdm_gate, const std::string& instance_name) {
    if (!uhdm_gate) return;
    
    // Get gate type
    int prim_type = uhdm_gate->VpiPrimType();
    std::string gate_type_str;
    RTLIL::IdString cell_type;

    // Three-state gates and pull primitives (IEEE 1800-2023 28.6, 28.10):
    // `bufif1 g(out, in, en)`, `notif0 g(out, in, en)`, `pullup p(net)`.
    // They were dropped ("Unsupported primitive type"), so a shared bus read
    // whatever else drove it and a pulled-up net read 0.  Lowered the way
    // read_slang lowers them, so both frontends describe the same netlist:
    // a $_TBUF_ per bit (E = enable, inverted for the -if0 forms; data
    // inverted for notif).  A pull is weak and is resolved separately.
    if (prim_type == vpiBufif0Prim || prim_type == vpiBufif1Prim ||
        prim_type == vpiNotif0Prim || prim_type == vpiNotif1Prim ||
        prim_type == vpiPullupPrim || prim_type == vpiPulldownPrim) {
        if (!uhdm_gate->Prim_terms() || uhdm_gate->Prim_terms()->empty()) return;
        std::vector<RTLIL::SigSpec> t;
        for (auto term : *uhdm_gate->Prim_terms())
            t.push_back(term->Expr() ? import_expression(term->Expr()) : RTLIL::SigSpec());
        std::string base = instance_name.empty() ? std::string(uhdm_gate->VpiName()) : instance_name;
        if (prim_type == vpiPullupPrim || prim_type == vpiPulldownPrim) {
            // A pull is WEAK: it decides the net only while no three-state
            // driver is enabled.  Recorded here and resolved once every gate
            // of the module exists (resolve_pulls).
            RTLIL::State v = prim_type == vpiPullupPrim ? RTLIL::State::S1 : RTLIL::State::S0;
            for (auto& net : t)
                if (!net.empty()) pending_pulls_.push_back({net, v});
            return;
        }
        if (t.size() != 3 || t[0].empty() || t[1].empty() || t[2].empty()) {
            log_warning("UHDM: three-state gate '%s' needs (out, in, enable)\n", base.c_str());
            return;
        }
        RTLIL::SigSpec out = t[0], in = t[1], en = t[2];
        if (in.size() < out.size()) in.extend_u0(out.size(), false);
        if (en.size() > 1) en = module->ReduceBool(NEW_ID, en);
        if (prim_type == vpiBufif0Prim || prim_type == vpiNotif0Prim) en = module->Not(NEW_ID, en);
        if (prim_type == vpiNotif0Prim || prim_type == vpiNotif1Prim) in = module->Not(NEW_ID, in.extract(0, out.size()));
        for (int b = 0; b < out.size(); b++) {
            RTLIL::Cell* c = module->addCell(
                (b == 0 && !base.empty()) ? module->uniquify(RTLIL::escape_id(base)) : NEW_ID, ID($_TBUF_));
            c->setPort(ID::A, in[b]);
            c->setPort(ID::E, en);
            c->setPort(ID::Y, out[b]);
        }
        return;
    }
    
    // Map UHDM primitive types to Yosys cell types
    switch (prim_type) {
        case vpiAndPrim:
            gate_type_str = "AND";
            cell_type = ID($_AND_);
            break;
        case vpiNandPrim:
            gate_type_str = "NAND";
            cell_type = ID($_NAND_);
            break;
        case vpiOrPrim:
            gate_type_str = "OR";
            cell_type = ID($_OR_);
            break;
        case vpiNorPrim:
            gate_type_str = "NOR";
            cell_type = ID($_NOR_);
            break;
        case vpiXorPrim:
            gate_type_str = "XOR";
            cell_type = ID($_XOR_);
            break;
        case vpiXnorPrim:
            gate_type_str = "XNOR";
            cell_type = ID($_XNOR_);
            break;
        case vpiNotPrim:
            gate_type_str = "NOT";
            cell_type = ID($_NOT_);
            break;
        case vpiBufPrim:
            gate_type_str = "BUF";
            cell_type = ID($_BUF_);
            break;
        default:
            log_warning("UHDM: Unsupported primitive type %d\n", prim_type);
            return;
    }
    
    // Get instance name (use provided name or gate's VpiName)
    std::string inst_name = instance_name.empty() ? std::string(uhdm_gate->VpiName()) : instance_name;
    if (inst_name.empty()) {
        inst_name = gate_type_str + "_gate";
    }
    
    uhdm_trace("UHDM: Importing %s gate '%s'\n", gate_type_str.c_str(), inst_name.c_str());
    
    // Get terminals (ports)
    if (!uhdm_gate->Prim_terms()) {
        log_error("UHDM: Gate has no terminals\n");
        return;
    }
    
    // Primitive gates can have multiple outputs and/or inputs
    // For buf/not: multiple outputs, 1 input
    // For xor/xnor: 1 output, multiple inputs
    // For other gates: 1 output, 2 inputs
    if (prims_from_unelab_def_ && std::string(uhdm_gate->VpiName()).empty()) {
        log_warning("UHDM: skipping unnamed %s gate in module '%s', which nothing "
                    "instantiates (Surelog's definition view of an unnamed gate is "
                    "incomplete)\n", gate_type_str.c_str(),
                    module ? log_id(module->name) : "?");
        return;
    }
    auto terms = *uhdm_gate->Prim_terms();
    if (terms.size() < 2) {
        log_error("UHDM: Gate has insufficient terminals (%d)\n", (int)terms.size());
        return;
    }
    
    // Separate outputs and inputs based on terminal direction
    std::vector<RTLIL::SigSpec> outputs;
    std::vector<RTLIL::SigSpec> inputs;
    
    for (auto term : terms) {
        // First check VpiDirection
        int direction = term->VpiDirection();
        if (direction == vpiOutput) {
            // Explicitly marked as output
            if (auto expr = term->Expr()) {
                outputs.push_back(import_expression(expr));
            }
        } else if (direction == vpiInput) {
            // Explicitly marked as input
            if (auto expr = term->Expr()) {
                inputs.push_back(import_expression(expr));
            }
        } else {
            // No explicit direction - use position
            // For buf/not: first terminals are outputs, last is input
            // Check TermIndex to determine position
            int term_index = term->VpiTermIndex();
            if (term_index >= 0) {
                // TermIndex available - use it
                // Last terminal is input for buf/not
                if ((prim_type == vpiBufPrim || prim_type == vpiNotPrim) && 
                    term_index == (int)terms.size() - 1) {
                    if (auto expr = term->Expr()) {
                        inputs.push_back(import_expression(expr));
                    }
                } else if (prim_type == vpiBufPrim || prim_type == vpiNotPrim) {
                    // Earlier terminals are outputs for buf/not
                    if (auto expr = term->Expr()) {
                        outputs.push_back(import_expression(expr));
                    }
                } else {
                    // For other gates, first is output, rest are inputs
                    if (outputs.empty()) {
                        if (auto expr = term->Expr()) {
                            outputs.push_back(import_expression(expr));
                        }
                    } else {
                        if (auto expr = term->Expr()) {
                            inputs.push_back(import_expression(expr));
                        }
                    }
                }
            } else {
                // No TermIndex - use order
                if ((prim_type == vpiBufPrim || prim_type == vpiNotPrim)) {
                    // For buf/not: all but last are outputs
                    if (term == terms.back()) {
                        if (auto expr = term->Expr()) {
                            inputs.push_back(import_expression(expr));
                        }
                    } else {
                        if (auto expr = term->Expr()) {
                            outputs.push_back(import_expression(expr));
                        }
                    }
                } else {
                    // For other gates, first is output
                    if (outputs.empty()) {
                        if (auto expr = term->Expr()) {
                            outputs.push_back(import_expression(expr));
                        }
                    } else {
                        if (auto expr = term->Expr()) {
                            inputs.push_back(import_expression(expr));
                        }
                    }
                }
            }
        }
    }
    
    uhdm_trace("UHDM: Gate '%s' has %d outputs and %d inputs\n", 
        inst_name.c_str(), (int)outputs.size(), (int)inputs.size());
    
    // Import gate attributes helper
    auto import_gate_attributes = [&](RTLIL::Cell* cell, const UHDM::gate* gate_obj) {
        if (gate_obj && gate_obj->Attributes()) {
            for (auto attr : *gate_obj->Attributes()) {
                std::string attr_name = std::string(attr->VpiName());
                if (attr_name.empty()) continue;
                cell->attributes[RTLIL::escape_id(attr_name)] = import_attribute_value(attr);
            }
        }
    };

    // For primitives with multiple outputs (buf, not), create separate cells
    if (outputs.size() > 1) {
        // Create a cell for each output
        for (size_t i = 0; i < outputs.size(); i++) {
            std::string cell_name = (outputs.size() > 1) ? 
                inst_name + "_" + std::to_string(i) : inst_name;
            RTLIL::Cell* cell = module->addCell(get_unique_cell_name(cell_name), cell_type);
            add_src_attribute(cell->attributes, uhdm_gate);
            import_gate_attributes(cell, uhdm_gate);
            
            // Connect this output
            cell->setPort(ID::Y, outputs[i]);
            
            // Connect input(s)
            if (prim_type == vpiNotPrim || prim_type == vpiBufPrim) {
                // Single input gates
                if (inputs.size() >= 1) {
                    cell->setPort(ID::A, inputs[0]);
                }
            } else {
                // Should not happen for gates with multiple outputs
                log_error("UHDM: Unexpected multiple outputs for gate type %d\n", prim_type);
            }
        }
    } else if (outputs.size() == 1) {
        // Single output - standard case
        RTLIL::Cell* cell = module->addCell(get_unique_cell_name(inst_name), cell_type);
        add_src_attribute(cell->attributes, uhdm_gate);
        import_gate_attributes(cell, uhdm_gate);
        
        // Connect output
        cell->setPort(ID::Y, outputs[0]);
        
        // Connect inputs based on gate type
        if (prim_type == vpiNotPrim || prim_type == vpiBufPrim) {
            // Single input gates
            if (inputs.size() >= 1) {
                cell->setPort(ID::A, inputs[0]);
            }
        } else if (prim_type == vpiXorPrim || prim_type == vpiXnorPrim) {
            // XOR/XNOR can have multiple inputs - need to create tree
            if (inputs.size() == 2) {
                cell->setPort(ID::A, inputs[0]);
                cell->setPort(ID::B, inputs[1]);
            } else if (inputs.size() > 2) {
                // A multi-input XOR/XNOR is an XOR-reduction of all inputs;
                // XNOR adds ONE final inversion.  Build a chain of 2-input
                // $_XOR_ gates, then invert once for XNOR.
                // NOTE: a chain of 2-input $_XNOR_ is WRONG — the per-stage
                // inversions cancel for odd input counts and yield XOR
                // (verilog_primitives: xnor(out,in1,in2,in3) came out as
                // in1^in2^in3 instead of ~(in1^in2^in3)).
                RTLIL::SigSpec result = inputs[0];
                for (size_t i = 1; i < inputs.size(); i++) {
                    RTLIL::Wire* temp_wire = module->addWire(NEW_ID);
                    RTLIL::Cell* tree_cell = module->addCell(NEW_ID, ID($_XOR_));
                    tree_cell->setPort(ID::A, result);
                    tree_cell->setPort(ID::B, inputs[i]);
                    tree_cell->setPort(ID::Y, temp_wire);
                    result = RTLIL::SigSpec(temp_wire);
                }
                if (prim_type == vpiXnorPrim) {
                    RTLIL::Cell* not_cell = module->addCell(NEW_ID, ID($_NOT_));
                    not_cell->setPort(ID::A, result);
                    not_cell->setPort(ID::Y, outputs[0]);
                } else {
                    module->connect(outputs[0], result);
                }
                // Don't need the original cell
                module->remove(cell);
                uhdm_trace("UHDM: Created %d-input %s as XOR-reduce%s\n",
                    (int)inputs.size(), gate_type_str.c_str(),
                    prim_type == vpiXnorPrim ? " + NOT" : "");
                return;
            }
        } else {
            // AND / OR / NAND / NOR.  These can ALSO have >2 inputs
            // (`or U (carry, a, b, c)`); a fixed 2-input cell silently
            // DROPPED the extra inputs (full_adder_gates: carry = a|b
            // instead of a|b|c).  For >2, reduce all inputs with a chain
            // of the 2-input base op ($_AND_ for AND/NAND, $_OR_ for
            // OR/NOR); NAND/NOR add ONE final inversion.
            if (inputs.size() == 2) {
                cell->setPort(ID::A, inputs[0]);
                cell->setPort(ID::B, inputs[1]);
            } else if (inputs.size() > 2) {
                RTLIL::IdString base =
                    (prim_type == vpiAndPrim || prim_type == vpiNandPrim)
                        ? ID($_AND_) : ID($_OR_);
                bool invert = (prim_type == vpiNandPrim || prim_type == vpiNorPrim);
                RTLIL::SigSpec result = inputs[0];
                for (size_t i = 1; i < inputs.size(); i++) {
                    RTLIL::Wire* temp_wire = module->addWire(NEW_ID);
                    RTLIL::Cell* tree_cell = module->addCell(NEW_ID, base);
                    tree_cell->setPort(ID::A, result);
                    tree_cell->setPort(ID::B, inputs[i]);
                    tree_cell->setPort(ID::Y, temp_wire);
                    result = RTLIL::SigSpec(temp_wire);
                }
                if (invert) {
                    RTLIL::Cell* not_cell = module->addCell(NEW_ID, ID($_NOT_));
                    not_cell->setPort(ID::A, result);
                    not_cell->setPort(ID::Y, outputs[0]);
                } else {
                    module->connect(outputs[0], result);
                }
                module->remove(cell);
                uhdm_trace("UHDM: Created %d-input %s as reduce%s\n",
                    (int)inputs.size(), gate_type_str.c_str(),
                    invert ? " + NOT" : "");
                return;
            } else if (inputs.size() == 1) {
                // Degenerate 1-input and/or behaves like a buffer of A.
                cell->setPort(ID::A, inputs[0]);
                cell->setPort(ID::B, inputs[0]);
            }
        }
    } else {
        log_error("UHDM: Gate has no outputs\n");
        return;
    }
    
    uhdm_trace("UHDM: Successfully imported %s gate\n", gate_type_str.c_str());
}

// Import a gate array
void UhdmImporter::import_gate_array(const gate_array* uhdm_gate_array) {
    if (!uhdm_gate_array) return;
    
    std::string array_name = std::string(uhdm_gate_array->VpiName());
    uhdm_trace("UHDM: Importing gate array '%s'\n", array_name.c_str());
    
    // Get array bounds from Ranges()
    int array_left = 0;
    int array_right = 0;
    int array_size = 0;
    
    if (uhdm_gate_array->Ranges() && !uhdm_gate_array->Ranges()->empty()) {
        auto range = (*uhdm_gate_array->Ranges())[0];
        if (range->Left_expr() && range->Right_expr()) {
            // Get the left and right bounds
            if (auto left_const = dynamic_cast<const constant*>(range->Left_expr())) {
                // Import the constant to get its value
                RTLIL::SigSpec left_spec = import_constant(left_const);
                if (left_spec.is_fully_const()) {
                    array_left = left_spec.as_const().as_int();
                }
            }
            if (auto right_const = dynamic_cast<const constant*>(range->Right_expr())) {
                // Import the constant to get its value
                RTLIL::SigSpec right_spec = import_constant(right_const);
                if (right_spec.is_fully_const()) {
                    array_right = right_spec.as_const().as_int();
                }
            }
            // Calculate size
            array_size = std::abs(array_left - array_right) + 1;
        }
    } else {
        // Use VpiSize if available
        array_size = uhdm_gate_array->VpiSize();
        if (array_size == 0) {
            log_error("UHDM: Gate array has no size information\n");
            return;
        }
    }
    
    uhdm_trace("UHDM: Gate array has %d elements (range [%d:%d])\n", array_size, array_left, array_right);
    
    // Get the primitive template
    if (!uhdm_gate_array->Primitives() || uhdm_gate_array->Primitives()->empty()) {
        log_error("UHDM: Gate array has no primitive template\n");
        return;
    }
    
    // The first primitive is the template for the array
    auto prim_template = (*uhdm_gate_array->Primitives())[0];
    auto gate_template = dynamic_cast<const gate*>(prim_template);
    if (!gate_template) {
        log_error("UHDM: Primitive is not a gate\n");
        return;
    }
    
    // Import each gate in the array
    // Determine if array is ascending or descending
    bool descending = (array_left > array_right);
    
    for (int i = 0; i < array_size; i++) {
        int array_index;
        int bit_index;
        
        if (descending) {
            // For [3:0], array_index goes 3,2,1,0 and bit_index matches
            array_index = array_left - i;
            bit_index = array_index;
        } else {
            // For [0:3], array_index goes 0,1,2,3 and bit_index matches
            array_index = array_left + i;
            bit_index = array_index;
        }
        
        // Generate instance name with array index
        std::string inst_name = array_name + "[" + std::to_string(array_index) + "]";
        
        // For each array element, we need to create a gate with bit-selected connections
        import_gate_array_element(gate_template, inst_name, bit_index);
    }
}

// Import a single element of a gate array
void UhdmImporter::import_gate_array_element(const gate* gate_template, const std::string& instance_name, int bit_index) {
    if (!gate_template) return;
    
    // Get gate type
    int prim_type = gate_template->VpiPrimType();
    std::string gate_type_str;
    RTLIL::IdString cell_type;
    
    // Map UHDM primitive types to Yosys cell types
    switch (prim_type) {
        case vpiAndPrim:
            gate_type_str = "AND";
            cell_type = ID($_AND_);
            break;
        case vpiNandPrim:
            gate_type_str = "NAND";
            cell_type = ID($_NAND_);
            break;
        case vpiOrPrim:
            gate_type_str = "OR";
            cell_type = ID($_OR_);
            break;
        case vpiNorPrim:
            gate_type_str = "NOR";
            cell_type = ID($_NOR_);
            break;
        case vpiXorPrim:
            gate_type_str = "XOR";
            cell_type = ID($_XOR_);
            break;
        case vpiXnorPrim:
            gate_type_str = "XNOR";
            cell_type = ID($_XNOR_);
            break;
        case vpiNotPrim:
            gate_type_str = "NOT";
            cell_type = ID($_NOT_);
            break;
        case vpiBufPrim:
            gate_type_str = "BUF";
            cell_type = ID($_BUF_);
            break;
        default:
            log_warning("UHDM: Unsupported primitive type %d\n", prim_type);
            return;
    }
    
    uhdm_trace("UHDM: Creating %s gate '%s' (bit %d)\n", gate_type_str.c_str(), instance_name.c_str(), bit_index);
    
    // Get terminals (ports)
    if (!gate_template->Prim_terms()) {
        log_error("UHDM: Gate has no terminals\n");
        return;
    }
    
    // Create the cell
    RTLIL::Cell* cell = module->addCell(get_unique_cell_name(instance_name), cell_type);
    add_src_attribute(cell->attributes, gate_template);
    
    // Import user attributes
    if (gate_template->Attributes()) {
        for (auto attr : *gate_template->Attributes()) {
            std::string attr_name = std::string(attr->VpiName());
            if (attr_name.empty()) continue;
            cell->attributes[RTLIL::escape_id(attr_name)] = import_attribute_value(attr);
        }
    }
    
    // Process terminals - first is output, rest are inputs
    auto terms = *gate_template->Prim_terms();
    if (terms.size() < 2) {
        log_error("UHDM: Gate has insufficient terminals (%d)\n", (int)terms.size());
        return;
    }
    
    // Get output signal (first terminal) with bit selection
    RTLIL::SigSpec output_sig;
    if (auto out_expr = terms[0]->Expr()) {
        RTLIL::SigSpec full_sig = import_expression(out_expr);
        // Select the specific bit for this array element
        if (full_sig.size() > 1 && bit_index < full_sig.size()) {
            output_sig = full_sig[bit_index];
        } else {
            output_sig = full_sig;
        }
    } else {
        log_error("UHDM: Gate output terminal has no expression\n");
        return;
    }
    
    // Connect output
    cell->setPort(ID::Y, output_sig);
    
    // Handle different gate types
    if (prim_type == vpiNotPrim || prim_type == vpiBufPrim) {
        // Single input gates
        if (terms.size() < 2) {
            log_error("UHDM: Single-input gate has no input terminal\n");
            return;
        }
        
        RTLIL::SigSpec input_sig;
        if (auto in_expr = terms[1]->Expr()) {
            RTLIL::SigSpec full_sig = import_expression(in_expr);
            // Select the specific bit for this array element
            if (full_sig.size() > 1 && bit_index < full_sig.size()) {
                input_sig = full_sig[bit_index];
            } else {
                input_sig = full_sig;
            }
        } else {
            log_error("UHDM: Gate input terminal has no expression\n");
            return;
        }
        
        cell->setPort(ID::A, input_sig);
    } else {
        // Two input gates
        if (terms.size() < 3) {
            log_error("UHDM: Two-input gate has insufficient inputs\n");
            return;
        }
        
        RTLIL::SigSpec input_a, input_b;
        if (auto in_expr = terms[1]->Expr()) {
            RTLIL::SigSpec full_sig = import_expression(in_expr);
            // Select the specific bit for this array element
            if (full_sig.size() > 1 && bit_index < full_sig.size()) {
                input_a = full_sig[bit_index];
            } else {
                input_a = full_sig;
            }
        } else {
            log_error("UHDM: Gate input A terminal has no expression\n");
            return;
        }
        
        if (auto in_expr = terms[2]->Expr()) {
            RTLIL::SigSpec full_sig = import_expression(in_expr);
            // Select the specific bit for this array element
            if (full_sig.size() > 1 && bit_index < full_sig.size()) {
                input_b = full_sig[bit_index];
            } else {
                input_b = full_sig;
            }
        } else {
            log_error("UHDM: Gate input B terminal has no expression\n");
            return;
        }
        
        cell->setPort(ID::A, input_a);
        cell->setPort(ID::B, input_b);
    }
    
    uhdm_trace("UHDM: Successfully created %s gate element\n", gate_type_str.c_str());
}


// A user-defined primitive instance (IEEE 1800-2023 29).  UDP instances were
// skipped entirely -- the module was left with no cells for them -- because
// only `gate` primitives were imported.
//
// The table is the definition: each table_entry is a row "in... [: state] :
// out" (Surelog drops the parentheses of an edge, `(01)` arrives as `01`).
//  - Combinational (29.3): out = OR over the rows whose output is 1 of the
//    AND of their input conditions (0, 1, ?/b don't-care).  Rows with an x
//    input never match a 2-state value; a combination no row covers is x by
//    the LRM and synthesises to 0.
//  - Edge-sensitive sequential (29.6): every row with a 0/1 output carries
//    an edge on ONE column, the clock; q is a $dff on that edge whose D is
//    the same sum of products over the other inputs and the current state.
//    Rows with output `-` (hold) need nothing.  A LEVEL-sensitive row with a
//    0/1 output (a latch, or an asynchronous set / reset) is not lowered: a
//    warning is printed and the instance is skipped rather than synthesised
//    wrongly.
void UhdmImporter::import_udp(const UHDM::udp* inst) {
    const UHDM::udp_defn* def = inst->Udp_defn();
    std::string dname = std::string(inst->VpiDefName());
    if (!def && uhdm_design && uhdm_design->AllUdps())
        for (auto d : *uhdm_design->AllUdps()) {
            std::string n = std::string(d->VpiDefName());
            if (n == dname || n == "work@" + dname) { def = d; break; }
        }
    if (!def || !def->Table_entrys() || !inst->Prim_terms()) {
        log_warning("UHDM: UDP instance '%s' of '%s' has no table; skipped\n",
                    std::string(inst->VpiName()).c_str(), dname.c_str());
        return;
    }
    std::vector<RTLIL::SigBit> terms;
    for (auto t : *inst->Prim_terms()) {
        RTLIL::SigSpec v = t->Expr() ? import_expression(t->Expr()) : RTLIL::SigSpec();
        if (v.size() < 1) { log_warning("UHDM: UDP '%s' terminal unresolved\n", dname.c_str()); return; }
        terms.push_back(v[0]);
    }
    if (terms.size() < 2) return;
    RTLIL::SigBit out = terms[0];
    std::vector<RTLIL::SigBit> ins(terms.begin() + 1, terms.end());
    const size_t nin = ins.size();

    struct Row { std::vector<std::string> in; std::string state, out; };
    std::vector<Row> rows;
    bool sequential = false;
    for (auto te : *def->Table_entrys()) {
        std::string v = std::string(te->VpiValue());
        if (v.rfind("STRING:", 0) == 0) v = v.substr(7);
        std::vector<std::string> fields;
        {
            size_t st = 0, c;
            while ((c = v.find(':', st)) != std::string::npos) { fields.push_back(v.substr(st, c - st)); st = c + 1; }
            fields.push_back(v.substr(st));
        }
        auto toks = [](const std::string& f) {
            std::vector<std::string> r; std::string cur;
            for (char ch : f) {
                if (ch == ' ' || ch == '\t' || ch == '(' || ch == ')') { if (!cur.empty()) { r.push_back(cur); cur.clear(); } }
                else cur += ch;
            }
            if (!cur.empty()) r.push_back(cur);
            return r;
        };
        Row r;
        r.in = toks(fields[0]);
        if (r.in.size() != nin) {            // `0 0 1` written without spaces
            std::vector<std::string> chars;
            for (auto& t : r.in) for (char ch : t) chars.push_back(std::string(1, ch));
            r.in = chars;
        }
        if (fields.size() == 3) { sequential = true; auto st = toks(fields[1]); r.state = st.empty() ? "?" : st[0]; }
        auto o = toks(fields.back());
        r.out = o.empty() ? "" : o[0];
        if (r.in.size() != nin || r.out.empty()) {
            log_warning("UHDM: UDP '%s': cannot read table row '%s'; instance skipped\n", dname.c_str(), v.c_str());
            return;
        }
        rows.push_back(r);
    }

    // Whether a level symbol can match; the condition bit (1 = always).
    auto level_cond = [&](const std::string& sym, RTLIL::SigBit b, bool& never) -> RTLIL::SigBit {
        char ch = std::tolower(sym[0]);
        if (ch == '0') return module->NotGate(NEW_ID, b);
        if (ch == '1') return b;
        if (ch == '?' || ch == 'b') return RTLIL::State::S1;
        never = true;                       // x: never a 2-state value
        return RTLIL::State::S0;
    };
    auto is_edge = [](const std::string& sym) {
        if (sym.size() == 2) return true;
        char ch = std::tolower(sym[0]);
        return ch == 'r' || ch == 'f' || ch == 'p' || ch == 'n' || ch == '*';
    };
    auto rising = [](const std::string& sym) {
        std::string l; for (char c : sym) l += std::tolower(c);
        return l == "01" || l == "r" || l == "p" || l == "0x" || l == "x1" || l == "?1";
    };
    auto falling = [](const std::string& sym) {
        std::string l; for (char c : sym) l += std::tolower(c);
        return l == "10" || l == "f" || l == "n" || l == "1x" || l == "x0" || l == "?0";
    };

    // Sum of products over `pick` rows, skipping column `skip`; `state`
    // (when valid) is matched against the rows' current-state column.
    auto sop = [&](const std::vector<const Row*>& pick, int skip, RTLIL::SigBit state) -> RTLIL::SigBit {
        RTLIL::SigBit acc = RTLIL::State::S0;
        for (auto r : pick) {
            if (r->out != "1") continue;
            bool never = false;
            RTLIL::SigBit term = RTLIL::State::S1;
            for (size_t k = 0; k < nin && !never; k++) {
                if ((int)k == skip) continue;
                RTLIL::SigBit c = level_cond(r->in[k], ins[k], never);
                if (c != RTLIL::State::S1) term = module->AndGate(NEW_ID, term, c);
            }
            if (!never && !r->state.empty() && state.wire) {
                RTLIL::SigBit c = level_cond(r->state, state, never);
                if (c != RTLIL::State::S1) term = module->AndGate(NEW_ID, term, c);
            }
            if (never) continue;
            acc = acc == RTLIL::State::S0 ? term : module->OrGate(NEW_ID, acc, term);
        }
        return acc;
    };

    std::string iname = std::string(inst->VpiName());
    if (!sequential) {
        std::vector<const Row*> all;
        for (auto& r : rows) all.push_back(&r);
        RTLIL::SigBit y = sop(all, -1, RTLIL::SigBit());
        module->connect(out, y);
        uhdm_trace("UHDM: combinational UDP %s (%s): %d rows\n", iname.c_str(), dname.c_str(), (int)rows.size());
        return;
    }
    int clk_col = -1;
    bool pos = true;
    std::vector<const Row*> edge_rows;
    for (auto& r : rows) {
        int ec = -1;
        for (size_t k = 0; k < nin; k++) if (is_edge(r.in[k])) { ec = (int)k; break; }
        if (r.out == "-") continue;
        if (ec < 0) {
            log_warning("UHDM: UDP '%s' has a level-sensitive row with output %s (a latch or an "
                        "asynchronous set/reset), which is not supported; instance '%s' skipped\n",
                        dname.c_str(), r.out.c_str(), iname.c_str());
            return;
        }
        bool rp = rising(r.in[ec]), fp = falling(r.in[ec]);
        if (clk_col < 0) { clk_col = ec; pos = rp; }
        if (ec != clk_col || (!rp && !fp) || rp != pos) {
            log_warning("UHDM: UDP '%s' changes state on more than one edge; instance '%s' skipped\n",
                        dname.c_str(), iname.c_str());
            return;
        }
        edge_rows.push_back(&r);
    }
    if (clk_col < 0) { log_warning("UHDM: UDP '%s' never changes state\n", dname.c_str()); return; }
    RTLIL::Wire* q = module->addWire(NEW_ID);
    RTLIL::SigBit d = sop(edge_rows, clk_col, RTLIL::SigBit(q));
    module->addDff(NEW_ID, ins[clk_col], d, RTLIL::SigBit(q), pos);
    module->connect(out, RTLIL::SigBit(q));
    uhdm_trace("UHDM: sequential UDP %s (%s): %s-edge on input %d\n", iname.c_str(), dname.c_str(),
               pos ? "pos" : "neg", clk_col);
}

YOSYS_NAMESPACE_END
