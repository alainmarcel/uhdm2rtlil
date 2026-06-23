/*
 *  yosys -- Yosys Open SYnthesis Suite
 *
 *  Copyright (C) 2024 The Yosys Authors
 *
 *  Permission to use, copy, modify, and/or distribute this software for any
 *  purpose with or without fee is hereby granted, provided that the above
 *  copyright notice and this permission notice appear in all copies.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 *  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 *  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 *  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 *  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 *  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 *  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

/*
 * Process and statement handling for UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog processes
 * (always blocks) and statements.
 */

#include "uhdm2rtlil.h"
#include <algorithm>
#include <functional>
#include <set>


YOSYS_NAMESPACE_BEGIN

// ============================================================================
// Helper functions to reduce code duplication
// ============================================================================

// Helper to safely cast to assignment
const UHDM::assignment* UhdmImporter::cast_to_assignment(const UHDM::any* stmt) {
    if (!stmt || stmt->VpiType() != vpiAssignment) return nullptr;
    return any_cast<const assignment*>(stmt);
}

// Helper to check VPI type
bool UhdmImporter::is_vpi_type(const UHDM::any* obj, int vpi_type) {
    return obj && obj->VpiType() == vpi_type;
}

// Create a temporary wire
RTLIL::SigSpec UhdmImporter::create_temp_wire(int width) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, width);
    return wire;
}

// Create equality comparison cell
RTLIL::SigSpec UhdmImporter::create_eq_cell(const RTLIL::SigSpec& a, const RTLIL::SigSpec& b, const UHDM::any* src) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, 1);
    if (src) add_src_attribute(wire->attributes, src);
    RTLIL::SigSpec result = wire;
    RTLIL::Cell* cell = module->addEq(NEW_ID, a, b, result);
    if (src) add_src_attribute(cell->attributes, src);
    return result;
}

// Create AND cell
RTLIL::SigSpec UhdmImporter::create_and_cell(const RTLIL::SigSpec& a, const RTLIL::SigSpec& b, const UHDM::any* src) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, 1);
    if (src) add_src_attribute(wire->attributes, src);
    RTLIL::SigSpec result = wire;
    RTLIL::Cell* cell = module->addAnd(NEW_ID, a, b, result);
    if (src) add_src_attribute(cell->attributes, src);
    return result;
}

// Create OR cell
RTLIL::SigSpec UhdmImporter::create_or_cell(const RTLIL::SigSpec& a, const RTLIL::SigSpec& b, const UHDM::any* src) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, 1);
    if (src) add_src_attribute(wire->attributes, src);
    RTLIL::SigSpec result = wire;
    RTLIL::Cell* cell = module->addOr(NEW_ID, a, b, result);
    if (src) add_src_attribute(cell->attributes, src);
    return result;
}

// Create NOT cell
RTLIL::SigSpec UhdmImporter::create_not_cell(const RTLIL::SigSpec& a, const UHDM::any* src) {
    RTLIL::Wire* wire = module->addWire(NEW_ID, 1);
    if (src) add_src_attribute(wire->attributes, src);
    RTLIL::SigSpec result = wire;
    RTLIL::Cell* cell = module->addNot(NEW_ID, a, result);
    if (src) add_src_attribute(cell->attributes, src);
    return result;
}

// Create MUX cell
RTLIL::SigSpec UhdmImporter::create_mux_cell(const RTLIL::SigSpec& sel, const RTLIL::SigSpec& b, const RTLIL::SigSpec& a, int width) {
    if (width == 0) width = std::max(a.size(), b.size());
    RTLIL::SigSpec result = create_temp_wire(width);
    module->addMux(NEW_ID, a, b, sel, result);
    return result;
}

UHDM::VectorOfany *UhdmImporter::begin_block_stmts(const any *stmt)
{
    UHDM::VectorOfany *stmts = nullptr;
    if (stmt->VpiType() == vpiBegin) {
        const UHDM::begin *begin_stmt = any_cast<const UHDM::begin *>(stmt);
        if (begin_stmt->Stmts() && !begin_stmt->Stmts()->empty()) {
            stmts = begin_stmt->Stmts();
        }
    } else {
        const UHDM::named_begin *begin_stmt = any_cast<const UHDM::named_begin *>(stmt);
        if (begin_stmt->Stmts() && !begin_stmt->Stmts()->empty()) {
            stmts = begin_stmt->Stmts();
        }
    }
    return stmts;
}

// Process assignment to get LHS and RHS
void UhdmImporter::process_assignment_lhs_rhs(const UHDM::assignment* assign, RTLIL::SigSpec& lhs, RTLIL::SigSpec& rhs) {
    if (!assign) return;
    
    auto lhs_expr = assign->Lhs();
    auto rhs_expr = assign->Rhs();
    
    if (lhs_expr) lhs = import_expression(any_cast<const expr*>(lhs_expr));
    if (rhs_expr) rhs = import_expression(any_cast<const expr*>(rhs_expr));
}


// Extract assigned signals from a single LHS expression. Handles ref_obj,
// net_bit, part_select, indexed_part_select, bit_select, hier_path, and
// concatenation operations (`{a, b[hi:lo], c[idx]} <= rhs`) by recursing on
// each concat operand. Caller pushes results into `signals`.
void UhdmImporter::extract_lhs_signals(const expr* lhs_expr, std::vector<AssignedSignal>& signals) {
    if (!lhs_expr) return;

    // Concat LHS: recurse on each operand so the temp-wire setup allocates
    // a `$0\<base>` for each base wire written through the concat.
    if (lhs_expr->VpiType() == vpiOperation) {
        auto op = any_cast<const operation*>(lhs_expr);
        if (op && op->VpiOpType() == vpiConcatOp) {
            if (auto operands = op->Operands()) {
                for (auto operand : *operands) {
                    if (auto op_expr = dynamic_cast<const expr*>(operand)) {
                        extract_lhs_signals(op_expr, signals);
                    }
                }
            }
            return;
        }
    }

    AssignedSignal sig;
    sig.lhs_expr = lhs_expr;

    if (lhs_expr->VpiType() == vpiRefObj) {
        auto ref = any_cast<const ref_obj*>(lhs_expr);
        sig.name = std::string(ref->VpiName());
        sig.is_part_select = false;
        signals.push_back(sig);
    } else if (lhs_expr->VpiType() == vpiNetBit) {
        auto net_bit = any_cast<const UHDM::net_bit*>(lhs_expr);
        sig.name = std::string(net_bit->VpiName());
        sig.is_part_select = false;
        signals.push_back(sig);
    } else if (lhs_expr->VpiType() == vpiIndexedPartSelect) {
        auto indexed_part_sel = any_cast<const indexed_part_select*>(lhs_expr);
        sig.is_part_select = true;
        if (!indexed_part_sel->VpiName().empty())
            sig.name = std::string(indexed_part_sel->VpiName());
        signals.push_back(sig);
    } else if (lhs_expr->VpiType() == vpiPartSelect) {
        auto part_sel = any_cast<const part_select*>(lhs_expr);
        sig.is_part_select = true;
        if (auto parent = part_sel->VpiParent()) {
            if (parent->VpiType() == vpiRefObj) {
                auto ref = any_cast<const ref_obj*>(parent);
                sig.name = std::string(ref->VpiName());
            } else if (!parent->VpiName().empty()) {
                sig.name = std::string(parent->VpiName());
            }
        }
        if (sig.name.empty() && !part_sel->VpiDefName().empty())
            sig.name = std::string(part_sel->VpiDefName());
        if (sig.name.empty() && !part_sel->VpiName().empty())
            sig.name = std::string(part_sel->VpiName());
        signals.push_back(sig);
    } else if (lhs_expr->VpiType() == vpiBitSelect) {
        auto bit_sel = any_cast<const bit_select*>(lhs_expr);
        sig.is_part_select = true;
        if (!bit_sel->VpiName().empty()) {
            sig.name = std::string(bit_sel->VpiName());
        } else if (auto parent = bit_sel->VpiParent()) {
            if (parent->VpiType() == vpiRefObj) {
                auto ref = any_cast<const ref_obj*>(parent);
                sig.name = std::string(ref->VpiName());
            } else if (!parent->VpiName().empty()) {
                sig.name = std::string(parent->VpiName());
            }
        }
        if (!sig.name.empty()) {
            auto idx = bit_sel->VpiIndex();
            bool is_const_idx = idx && idx->VpiType() == vpiConstant;
            if (!is_const_idx) {
                RTLIL::IdString mem_id = RTLIL::escape_id(sig.name);
                if (!module->memories.count(mem_id) &&
                    module->wire(RTLIL::escape_id(sig.name + "[0]"))) {
                    return;
                }
            }
        }
        signals.push_back(sig);
    } else if (lhs_expr->VpiType() == vpiVarSelect) {
        // `dout_array[0][1]` inside a concat LHS — a bit of an array element.
        // For a comb-only array (expanded to per-element wires) with a constant
        // element index, target the element wire `<base>[idx]` so the write
        // reaches its `$0\` temp; otherwise fall back to the base name
        // (mem2reg_test6: `{dout_array[0][1], dout_array[0][0]} = ...`).
        auto vs = any_cast<const var_select*>(lhs_expr);
        sig.is_part_select = true;
        std::string base = std::string(vs->VpiName());
        if (vs->Exprs() && !vs->Exprs()->empty()) {
            auto e0 = (*vs->Exprs())[0];
            if (e0 && e0->VpiType() == vpiConstant) {
                RTLIL::SigSpec idx = import_constant(any_cast<const constant*>(e0));
                if (idx.is_fully_const()) {
                    std::string elem = base + "[" + std::to_string(idx.as_const().as_int()) + "]";
                    if (module->wire(RTLIL::escape_id(elem))) sig.name = elem;
                }
            }
        }
        if (sig.name.empty()) sig.name = base;
        signals.push_back(sig);
    } else if (lhs_expr->VpiType() == vpiHierPath) {
        auto hp = any_cast<const hier_path*>(lhs_expr);
        sig.is_part_select = false;
        std::string full_name = std::string(hp->VpiName());
        std::string base;
        size_t dot_pos = full_name.find('.');
        if (dot_pos != std::string::npos)
            base = full_name.substr(0, dot_pos);
        else
            base = full_name;
        RTLIL::Wire* base_w = base.empty() ? nullptr :
            module->wire(RTLIL::escape_id(base));
        bool base_is_wire = base_w != nullptr &&
            !base_w->attributes.count(RTLIL::escape_id("is_interface"));
        bool full_is_wire = !full_name.empty() &&
            module->wire(RTLIL::escape_id(full_name)) != nullptr;
        if (full_is_wire && !base_is_wire)
            sig.name = full_name;
        else
            sig.name = base;
        signals.push_back(sig);
    }
}

void UhdmImporter::collect_for_loop_var_names(const any* stmt, std::set<std::string>& names) {
    if (!stmt) return;
    switch (stmt->VpiType()) {
        case vpiFor: {
            auto for_loop = any_cast<const for_stmt*>(stmt);
            if (for_loop->VpiForInitStmts())
                for (auto s : *for_loop->VpiForInitStmts())
                    if (s->VpiType() == vpiAssignment)
                        if (auto ia = any_cast<const assignment*>(s))
                            if (ia->Lhs() && !ia->Lhs()->VpiName().empty())
                                names.insert(std::string(ia->Lhs()->VpiName()));
            collect_for_loop_var_names(for_loop->VpiStmt(), names);
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            if (auto stmts = begin_block_stmts(stmt))
                for (auto s : *stmts) collect_for_loop_var_names(s, names);
            break;
        }
        case vpiIf: {
            auto if_st = any_cast<const if_stmt*>(stmt);
            collect_for_loop_var_names(if_st->VpiStmt(), names);
            break;
        }
        case vpiIfElse: {
            auto ie = any_cast<const if_else*>(stmt);
            collect_for_loop_var_names(ie->VpiStmt(), names);
            collect_for_loop_var_names(ie->VpiElseStmt(), names);
            break;
        }
        case vpiCase: {
            auto cs = any_cast<const case_stmt*>(stmt);
            if (cs->Case_items())
                for (auto item : *cs->Case_items())
                    collect_for_loop_var_names(item->Stmt(), names);
            break;
        }
        default: break;
    }
}

void UhdmImporter::extract_assigned_signals(const any* stmt, std::vector<AssignedSignal>& signals) {
    if (!stmt) return;

    switch (stmt->VpiType()) {
        case vpiAssignment:
        case vpiAssignStmt: {
            // `assignment` (x = y) and `assign_stmt` (`assign x = y` in a
            // task/func body — TaskOutputArgument) are distinct UHDM classes
            // both reached by vpiAssignStmt; cast generically (the old single
            // cast to `assignment` returned null for assign_stmt -> crash when
            // the task-body recursion below dereferenced it).
            const UHDM::expr* a_lhs = nullptr;
            if (auto assign = any_cast<const assignment*>(stmt))
                a_lhs = assign->Lhs();
            else if (auto as = any_cast<const UHDM::assign_stmt*>(stmt))
                a_lhs = as->Lhs();
            if (auto lhs = a_lhs) {
                if (auto lhs_expr = dynamic_cast<const expr*>(lhs)) {
                    AssignedSignal sig;
                    sig.lhs_expr = lhs_expr;

                    log("extract_assigned_signals: LHS type is %d\n", lhs_expr->VpiType());
                    if (lhs_expr->VpiType() == vpiOperation) {
                        // Concat LHS — delegate to extract_lhs_signals which
                        // recurses on each operand (`{a, b[hi:lo]} <= rhs`).
                        extract_lhs_signals(lhs_expr, signals);
                    } else if (lhs_expr->VpiType() == vpiRefObj) {
                        auto ref = any_cast<const ref_obj*>(lhs_expr);
                        sig.name = std::string(ref->VpiName());
                        sig.is_part_select = false;
                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to '%s' (ref_obj)\n", ref->VpiName().data());
                    } else if (lhs_expr->VpiType() == vpiNetBit) {
                        auto net_bit = any_cast<const UHDM::net_bit*>(lhs_expr);
                        sig.name = std::string(net_bit->VpiName());
                        sig.is_part_select = false;
                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to '%s' (net_bit)\n", net_bit->VpiName().data());
                    } else if (lhs_expr->VpiType() == vpiIndexedPartSelect) {
                        // Handle indexed part selects like result[i*8 +: 8]
                        auto indexed_part_sel = any_cast<const indexed_part_select*>(lhs_expr);
                        sig.is_part_select = true;
                        
                        // Get the signal name
                        if (!indexed_part_sel->VpiName().empty()) {
                            sig.name = std::string(indexed_part_sel->VpiName());
                        }
                        
                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to indexed part select of '%s'\n", sig.name.c_str());
                    } else if (lhs_expr->VpiType() == vpiPartSelect) {
                        // Handle part selects like result[7:0]
                        auto part_sel = any_cast<const part_select*>(lhs_expr);
                        sig.is_part_select = true;

                        if (auto parent = part_sel->VpiParent()) {
                            if (parent->VpiType() == vpiRefObj) {
                                auto ref = any_cast<const ref_obj*>(parent);
                                sig.name = std::string(ref->VpiName());
                            } else if (!parent->VpiName().empty()) {
                                sig.name = std::string(parent->VpiName());
                            }
                        }
                        // Fallback: get name directly from part_select if parent didn't provide it
                        if (sig.name.empty() && !part_sel->VpiDefName().empty()) {
                            sig.name = std::string(part_sel->VpiDefName());
                        }
                        if (sig.name.empty() && !part_sel->VpiName().empty()) {
                            sig.name = std::string(part_sel->VpiName());
                        }

                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to part select of '%s'\n", sig.name.c_str());
                    } else if (lhs_expr->VpiType() == vpiBitSelect) {
                        // Handle bit selects like result[0] or memory[addr]
                        auto bit_sel = any_cast<const bit_select*>(lhs_expr);
                        sig.is_part_select = true;

                        // First try to get name from bit_select itself
                        if (!bit_sel->VpiName().empty()) {
                            sig.name = std::string(bit_sel->VpiName());
                        } else if (auto parent = bit_sel->VpiParent()) {
                            // Fall back to parent if bit_select doesn't have a name
                            if (parent->VpiType() == vpiRefObj) {
                                auto ref = any_cast<const ref_obj*>(parent);
                                sig.name = std::string(ref->VpiName());
                            } else if (!parent->VpiName().empty()) {
                                sig.name = std::string(parent->VpiName());
                            }
                        }

                        // Dynamic write to an expanded array (individual element wires exist,
                        // not a $memory object) with a non-constant index is handled specially
                        // in import_assignment_comb using per-element mux logic.
                        // Skip it here so we don't create a temp wire for the whole array.
                        if (!sig.name.empty()) {
                            auto idx = bit_sel->VpiIndex();
                            bool is_const_idx = idx && idx->VpiType() == vpiConstant;
                            if (!is_const_idx) {
                                RTLIL::IdString mem_id = RTLIL::escape_id(sig.name);
                                if (!module->memories.count(mem_id) &&
                                    module->wire(RTLIL::escape_id(sig.name + "[0]"))) {
                                    log("extract_assigned_signals: Skipping dynamic write to expanded array '%s'\n",
                                        sig.name.c_str());
                                    break;
                                }
                            }
                        }

                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to bit select of '%s'\n", sig.name.c_str());
                    } else if (lhs_expr->VpiType() == vpiHierPath) {
                        // Two distinct shapes share this VPI type:
                        //   1. Struct-field write — `internal_bus.field`
                        //      where `internal_bus` is a wire of struct
                        //      type.  Report the BASE wire so the
                        //      always_ff/comb temp-wire setup creates a
                        //      single `$0\<base>` covering all fields;
                        //      the partial bit-slice gets remapped to a
                        //      slice of that temp wire later (see
                        //      import_assignment_comb).
                        //   2. Interface-port signal write —
                        //      `bus.rdt` where `bus` is a `.sub` modport
                        //      port.  `\bus` itself is NOT a wire;
                        //      `import_port` created `\bus.rdt` as a
                        //      module-local per-signal wire.  Report the
                        //      *full* hier_path so the temp-wire setup
                        //      allocates `$0\bus.rdt` and the sync rule
                        //      updates that wire (jeras/UHDM-tests/
                        //      tcb_gpio.sv).
                        // Distinguish by checking whether the base wire
                        // exists; if not, prefer the full path.
                        auto hp = any_cast<const hier_path*>(lhs_expr);
                        sig.is_part_select = false;
                        std::string full_name = std::string(hp->VpiName());
                        std::string base;
                        size_t dot_pos = full_name.find('.');
                        if (dot_pos != std::string::npos)
                            base = full_name.substr(0, dot_pos);
                        else
                            base = full_name;

                        // Interface ports have a 1-bit `\<port>`
                        // placeholder wire (set in `import_port` with
                        // the `is_interface` attribute) — that is NOT
                        // the real signal storage.  Skip it when
                        // deciding whether the base is a usable wire.
                        RTLIL::Wire* base_w = base.empty() ? nullptr :
                            module->wire(RTLIL::escape_id(base));
                        bool base_is_wire = base_w != nullptr &&
                            !base_w->attributes.count(
                                RTLIL::escape_id("is_interface"));
                        bool full_is_wire = !full_name.empty() &&
                            module->wire(RTLIL::escape_id(full_name)) != nullptr;
                        if (full_is_wire && !base_is_wire)
                            sig.name = full_name;
                        else
                            sig.name = base;

                        signals.push_back(sig);
                        log("extract_assigned_signals: Found assignment to hier_path of '%s' (using '%s')\n",
                            full_name.c_str(), sig.name.c_str());
                    }
                }
            }
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            UHDM::VectorOfany* stmts = begin_block_stmts(stmt);
            if (stmts) { 
                for (auto s : *stmts) {
                    extract_assigned_signals(s, signals);
                }
            }
            break;
        }
        case vpiCase: {
            auto case_st = any_cast<const UHDM::case_stmt*>(stmt);
            if (auto items = case_st->Case_items()) {
                for (auto item : *items) {
                    if (auto s = item->Stmt()) {
                        extract_assigned_signals(s, signals);
                    }
                }
            }
            break;
        }
        case vpiIf: {
            auto if_st = any_cast<const UHDM::if_stmt*>(stmt);
            if (auto then_stmt = if_st->VpiStmt()) {
                extract_assigned_signals(then_stmt, signals);
            }
            break;
        }
        case vpiIfElse: {
            auto if_else = any_cast<const UHDM::if_else*>(stmt);
            if (auto then_stmt = if_else->VpiStmt()) {
                extract_assigned_signals(then_stmt, signals);
            }
            if (auto else_stmt = if_else->VpiElseStmt()) {
                extract_assigned_signals(else_stmt, signals);
            }
            break;
        }
        case vpiTaskCall: {
            // For task calls, we only extract:
            // 1. Output parameter targets (caller's arguments for output params)
            // 2. Module signals directly assigned by the task body
            // We do NOT extract task-internal variables (they are handled by task inlining)
            auto tc = any_cast<const UHDM::task_call*>(stmt);
            if (tc && tc->Task()) {
                auto task_def = tc->Task();
                auto io_decls = task_def->Io_decls();
                auto args = tc->Tf_call_args();

                // Collect task-local variable names to filter them out
                std::set<std::string> task_local_names;
                if (io_decls) {
                    for (auto io_any : *io_decls) {
                        auto io = any_cast<const UHDM::io_decl*>(io_any);
                        if (io) task_local_names.insert(std::string(io->VpiName()));
                    }
                }
                if (task_def->Variables()) {
                    for (auto var : *task_def->Variables()) {
                        task_local_names.insert(std::string(var->VpiName()));
                    }
                }

                // Extract output parameter targets from the call site
                if (io_decls && args) {
                    size_t n = std::min(io_decls->size(), args->size());
                    for (size_t i = 0; i < n; i++) {
                        auto io = any_cast<const UHDM::io_decl*>((*io_decls)[i]);
                        if (io && io->VpiDirection() == vpiOutput) {
                            auto arg = (*args)[i];
                            if (auto arg_expr = dynamic_cast<const UHDM::expr*>(arg)) {
                                AssignedSignal sig;
                                sig.lhs_expr = arg_expr;
                                sig.is_part_select = false;
                                if (arg_expr->VpiType() == vpiRefObj) {
                                    auto ref = any_cast<const UHDM::ref_obj*>(arg_expr);
                                    sig.name = std::string(ref->VpiName());
                                    signals.push_back(sig);
                                }
                            }
                        }
                    }
                }

                // Extract module signals assigned inside the task body
                // Only include signals that exist as module wires (skip task-internal variables)
                std::vector<AssignedSignal> task_body_signals;
                if (auto task_stmt = task_def->Stmt()) {
                    extract_assigned_signals(task_stmt, task_body_signals);
                }
                for (auto& sig : task_body_signals) {
                    if (!task_local_names.count(sig.name) && name_map.count(sig.name)) {
                        signals.push_back(sig);
                    }
                }
            }
            break;
        }
        case vpiFor: {
            // Extract signals assigned inside for loop body.
            // We cannot evaluate the (dynamic) loop index at this stage, so treat
            // any part-select assignment (e.g. q[k]) as a full-wire assignment by
            // returning is_part_select=false and lhs_expr=nullptr.  The caller will
            // create a full-width temp wire for the signal.
            const for_stmt* for_loop = any_cast<const for_stmt*>(stmt);
            // Helper: dedup-add an AssignedSignal to `signals` (by name).
            auto dedup_add = [&](AssignedSignal sig) {
                if (sig.is_part_select) {
                    sig.is_part_select = false;
                    sig.lhs_expr = nullptr;
                }
                for (const auto& existing : signals)
                    if (existing.name == sig.name) return;
                signals.push_back(sig);
            };
            // A LOCALLY-declared loop var (`for (int i = ...)`) is
            // loop_values-only and must NOT become a module wire — otherwise it
            // leaks as `assign i = 1'hx` (MultipleAssignments).  Detect it (init
            // LHS is a variable-declaration node, not a ref_obj/ref_var) so the
            // init/inc scan below can skip it.
            std::string local_loopvar;
            if (for_loop->VpiForInitStmts() && !for_loop->VpiForInitStmts()->empty()) {
                auto s0 = (*for_loop->VpiForInitStmts())[0];
                if (s0->VpiType() == vpiAssignment) {
                    auto ia0 = any_cast<const assignment*>(s0);
                    if (ia0->Lhs()) {
                        int lt = ia0->Lhs()->VpiType();
                        if (lt != vpiRefObj && lt != vpiRefVar &&
                            !ia0->Lhs()->VpiName().empty())
                            local_loopvar = std::string(ia0->Lhs()->VpiName());
                    }
                }
            }
            // Also scan the init and increment statements — for a
            // module-scope `integer k` used as the loop var
            // (`for (k=0; k<N; k=k+1)`), `k` is written by the init
            // `k=0` and the increment `k=k+1`.  Without this scan, no
            // `$0\k` temp wire is created and the post-loop value of
            // `k` (substituted into expressions like `y = k - ...`)
            // never gets driven onto the actual wire — yosys/tests/
            // simple/forloops.v depends on this.  (Skipped for a
            // locally-declared loop var per `local_loopvar` above.)
            if (for_loop->VpiForInitStmts() && local_loopvar.empty()) {
                for (auto s : *for_loop->VpiForInitStmts()) {
                    std::vector<AssignedSignal> init_signals;
                    extract_assigned_signals(s, init_signals);
                    for (auto& sig : init_signals) dedup_add(sig);
                }
            }
            if (for_loop->VpiForIncStmts() && local_loopvar.empty()) {
                for (auto s : *for_loop->VpiForIncStmts()) {
                    std::vector<AssignedSignal> inc_signals;
                    extract_assigned_signals(s, inc_signals);
                    for (auto& sig : inc_signals) dedup_add(sig);
                }
            }
            if (auto body = for_loop->VpiStmt()) {
                std::vector<AssignedSignal> body_signals;
                extract_assigned_signals(body, body_signals);
                for (auto& sig : body_signals) dedup_add(sig);
            }
            break;
        }
    }
}


// Extract signal names from a UHDM process statement
bool UhdmImporter::extract_signal_names_from_process(const UHDM::any* stmt, 
                                                   std::string& output_signal, std::string& input_signal,
                                                   std::string& clock_signal, std::string& reset_signal,
                                                   std::vector<int>& slice_offsets, std::vector<int>& slice_widths) {
    
    log("UHDM: Extracting signal names from process statement\n");
    
    // Handle event_control wrapper (for always_ff @(...))
    if (stmt->VpiType() == vpiEventControl) {
        const UHDM::event_control* event_ctrl = any_cast<const UHDM::event_control*>(stmt);
        if (auto controlled_stmt = event_ctrl->Stmt()) {
            // Extract the actual statement from event control
            stmt = controlled_stmt;
            log("UHDM: Unwrapped event_control, found inner statement type: %s (vpiType=%d)\n", 
                UhdmName(stmt->UhdmType()).c_str(), stmt->VpiType());
        }
    }
    
    // Handle begin block
    VectorOfany* stmts = begin_block_stmts(stmt);
    if (stmts) {
        // Get first statement from begin block
        stmt = stmts->at(0);
        log("UHDM: Unwrapped begin block, found inner statement type: %s (vpiType=%d)\n",
            UhdmName(stmt->UhdmType()).c_str(), stmt->VpiType());
    }
    
    // For simple_counter, we need to extract from the if statement structure
    if (stmt->VpiType() == vpiIf || stmt->VpiType() == vpiIfElse) {
        log("UHDM: Found if statement, VpiType=%d, UhdmType=%s\n", stmt->VpiType(), UhdmName(stmt->UhdmType()).c_str());
        
        // Check if this is an if_else or just if_stmt
        if (stmt->UhdmType() == uhdmif_else) {
            const UHDM::if_else* if_else_stmt = any_cast<const UHDM::if_else*>(stmt);
            
            // For simple always_ff patterns like: if (!rst_n) count <= 0; else count <= count + 1;
            // We look for assignments in the then/else branches
            
            // Check then statement for reset assignment
            if (auto then_stmt = if_else_stmt->VpiStmt()) {
                log("UHDM: Then statement type: %s (vpiType=%d)\n", UhdmName(then_stmt->UhdmType()).c_str(), then_stmt->VpiType());
                // Handle begin blocks
                if (then_stmt->VpiType() == vpiBegin || then_stmt->VpiType() == vpiNamedBegin) {
                    VectorOfany* stmts = begin_block_stmts(then_stmt);
                    if (stmts) {
                        // Look for assignment inside begin block
                        for (auto stmt : *stmts) {
                            if (stmt->VpiType() == vpiAssignment) {
                                then_stmt = stmt;
                                break;
                            }
                        }
                    }
                }
                
                if (then_stmt->VpiType() == vpiAssignment) {
                    const UHDM::assignment* assign = any_cast<const UHDM::assignment*>(then_stmt);
                    if (auto lhs = assign->Lhs()) {
                        if (lhs->VpiType() == vpiRefObj) {
                            const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(lhs);
                            output_signal = std::string(ref->VpiName());
                            log("UHDM: Found output signal from reset assignment: %s\n", output_signal.c_str());
                        } else if (lhs->VpiType() == vpiIndexedPartSelect) {
                            // For indexed part selects like result[i*8 +: 8], we need to extract the base signal
                            const UHDM::indexed_part_select* ips = any_cast<const UHDM::indexed_part_select*>(lhs);
                            // Try to get the base signal name
                            if (!ips->VpiDefName().empty()) {
                                output_signal = std::string(ips->VpiDefName());
                            } else if (!ips->VpiName().empty()) {
                                output_signal = std::string(ips->VpiName());
                            } else if (auto parent = ips->VpiParent()) {
                                if (!parent->VpiDefName().empty()) {
                                    output_signal = std::string(parent->VpiDefName());
                                } else if (!parent->VpiName().empty()) {
                                    output_signal = std::string(parent->VpiName());
                                }
                            }
                            log("UHDM: Found output signal from indexed part select: %s\n", output_signal.c_str());
                            
                            // Extract slice information from indexed part select
                            if (ips->Base_expr()) {
                                RTLIL::SigSpec base_expr = import_expression(ips->Base_expr());
                                if (base_expr.is_fully_const()) {
                                    int offset = base_expr.as_const().as_int();
                                    slice_offsets.push_back(offset);
                                    log("UHDM: Indexed part select offset: %d\n", offset);
                                }
                            }
                            if (ips->Width_expr()) {
                                RTLIL::SigSpec width_expr = import_expression(ips->Width_expr());
                                if (width_expr.is_fully_const()) {
                                    int width = width_expr.as_const().as_int();
                                    slice_widths.push_back(width);
                                    log("UHDM: Indexed part select width: %d\n", width);
                                }
                            }
                        }
                    }
                }
            }
            
            // Check else statement for normal assignment  
            if (auto else_stmt = if_else_stmt->VpiElseStmt()) {
                log("UHDM: Found else statement, type: %s (vpiType=%d)\n", 
                    UhdmName(else_stmt->UhdmType()).c_str(), else_stmt->VpiType());
                // Handle begin blocks
                if (else_stmt->VpiType() == vpiBegin || else_stmt->VpiType() == vpiNamedBegin) {
                    VectorOfany* stmts = begin_block_stmts(stmt);
                    if (stmts) {
                        // Look for assignment inside begin block
                        for (auto stmt : *stmts) {
                            if (stmt->VpiType() == vpiAssignment) {
                                else_stmt = stmt;
                                break;
                            }
                        }
                    }
                }
                
                if (else_stmt->VpiType() == vpiAssignment) {
                    const UHDM::assignment* assign = any_cast<const UHDM::assignment*>(else_stmt);
                    log("UHDM: Processing else assignment\n");
                    if (auto rhs = assign->Rhs()) {
                        log("UHDM: RHS type: %s (vpiType=%d)\n", UhdmName(rhs->UhdmType()).c_str(), rhs->VpiType());
                        // For simple ref like "unit_result"
                        if (rhs->VpiType() == vpiRefObj) {
                            const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(rhs);
                            input_signal = std::string(ref->VpiName());
                            log("UHDM: Found input signal from else assignment: %s\n", input_signal.c_str());
                        }
                        // For expressions like "count + 1", we want to extract "count" as input
                        else if (rhs->VpiType() == vpiOperation) {
                            const UHDM::operation* op = any_cast<const UHDM::operation*>(rhs);
                            if (auto operands = op->Operands()) {
                                for (auto operand : *operands) {
                                    if (operand->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(operand);
                                        input_signal = std::string(ref->VpiName());
                                        log("UHDM: Found input signal from operation: %s\n", input_signal.c_str());
                                        break;
                                    }
                                }
                            }
                        }
                    }
                } else if (else_stmt->VpiType() == vpiIfElse || else_stmt->VpiType() == vpiIf) {
                    // Handle else-if case
                    const UHDM::any* else_if_stmt = else_stmt;
                    if (else_if_stmt->UhdmType() == uhdmif_else) {
                        const UHDM::if_else* nested_if_else = any_cast<const UHDM::if_else*>(else_if_stmt);
                        // Check the then statement of the else-if
                        if (auto then_stmt = nested_if_else->VpiStmt()) {
                            if (then_stmt->VpiType() == vpiAssignment) {
                                const UHDM::assignment* assign = any_cast<const UHDM::assignment*>(then_stmt);
                                if (auto lhs = assign->Lhs()) {
                                    if (lhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(lhs);
                                        // Only update output_signal if it's empty (priority to first-level assignment)
                                        if (output_signal.empty()) {
                                            output_signal = std::string(ref->VpiName());
                                            log("UHDM: Found output signal from else-if assignment: %s\n", output_signal.c_str());
                                        }
                                    }
                                }
                                if (auto rhs = assign->Rhs()) {
                                    if (rhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(rhs);
                                        input_signal = std::string(ref->VpiName());
                                        log("UHDM: Found input signal from else-if assignment: %s\n", input_signal.c_str());
                                    }
                                }
                            }
                        }
                    } else if (else_if_stmt->VpiType() == vpiIf) {
                        const UHDM::if_stmt* nested_if = any_cast<const UHDM::if_stmt*>(else_if_stmt);
                        // Check the then statement of the else-if
                        if (auto then_stmt = nested_if->VpiStmt()) {
                            if (then_stmt->VpiType() == vpiAssignment) {
                                const UHDM::assignment* assign = any_cast<const UHDM::assignment*>(then_stmt);
                                if (auto lhs = assign->Lhs()) {
                                    if (lhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(lhs);
                                        // Only update output_signal if it's empty (priority to first-level assignment)
                                        if (output_signal.empty()) {
                                            output_signal = std::string(ref->VpiName());
                                            log("UHDM: Found output signal from else-if assignment: %s\n", output_signal.c_str());
                                        }
                                    }
                                }
                                if (auto rhs = assign->Rhs()) {
                                    if (rhs->VpiType() == vpiRefObj) {
                                        const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(rhs);
                                        input_signal = std::string(ref->VpiName());
                                        log("UHDM: Found input signal from else-if assignment: %s\n", input_signal.c_str());
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Extract reset signal from condition (!rst_n)
            if (auto condition = if_else_stmt->VpiCondition()) {
                if (condition->VpiType() == vpiOperation) {
                    const UHDM::operation* op = any_cast<const UHDM::operation*>(condition);
                    if (auto operands = op->Operands()) {
                        for (auto operand : *operands) {
                            if (operand->VpiType() == vpiRefObj) {
                                const UHDM::ref_obj* ref = any_cast<const UHDM::ref_obj*>(operand);
                                reset_signal = std::string(ref->VpiName());
                                log("UHDM: Found reset signal from condition: %s\n", reset_signal.c_str());
                                break;
                            }
                        }
                    }
                }
            }
        } else {
            // Handle simple if_stmt without else
            log("UHDM: Processing simple if_stmt (no else clause)\n");
        }
    }
    
    // For clock signal, we need to look at the sensitivity list (this is tricky in UHDM)
    // For now, use a common default
    clock_signal = "clk";  
    
    // For simple_counter, count is both input and output, so allow this case
    if (!output_signal.empty() && input_signal.empty()) {
        input_signal = output_signal;  // count is both input and output
    }
    
    // Return true if we found at least an output signal
    bool success = !output_signal.empty();
    log("UHDM: Signal extraction %s: output=%s, input=%s, clock=%s, reset=%s\n",
        success ? "succeeded" : "failed",
        output_signal.c_str(), input_signal.c_str(), 
        clock_signal.c_str(), reset_signal.c_str());
    
    return success;
}

// Check if a statement contains complex constructs (for loops, memory writes, etc.)
bool UhdmImporter::contains_complex_constructs(const any* stmt) {
    if (!stmt) return false;
    
    int stmt_type = stmt->VpiType();
    
    // Check for complex statement types
    if (stmt_type == vpiFor || stmt_type == vpiForever || stmt_type == vpiWhile) {
        return true;
    }

    // A write to a dynamic indexed part-select (`mem[idx +: W] <= data` with a
    // non-constant `idx`) needs the read-modify-write handling in
    // import_statement_sync; the simple-if optimisation imports the LHS as a
    // read and silently drops the write (memlib_wide_sdp's flat `reg [79:0]`).
    // Treat it as complex so this block falls through to the general path.
    if (stmt_type == vpiAssignment || stmt_type == vpiAssignStmt) {
        const assignment* a = any_cast<const assignment*>(stmt);
        if (a && a->Lhs() && a->Lhs()->VpiType() == vpiIndexedPartSelect) {
            auto ips = any_cast<const indexed_part_select*>(a->Lhs());
            if (ips && ips->Base_expr() &&
                ips->Base_expr()->VpiType() != vpiConstant)
                return true;
        }
    }

    // Note: Memory writes (bit select assignments) are now allowed in simple if patterns
    // They will be handled specially during switch statement generation
    
    // Check for begin blocks (both regular and named)
    if (stmt_type == vpiBegin || stmt_type == vpiNamedBegin) {
        VectorOfany* stmts = begin_block_stmts(stmt);
        if (stmts) {
            for (auto sub_stmt : *stmts) {
                if (sub_stmt && contains_complex_constructs(sub_stmt)) {
                    return true;
                }
            }
        }
    } else if (stmt_type == vpiIf) {
        // Check for nested if statements
        const UHDM::if_stmt* if_stmt = any_cast<const UHDM::if_stmt*>(stmt);
        if (if_stmt) {
            if (if_stmt->VpiStmt() && contains_complex_constructs(if_stmt->VpiStmt())) {
                return true;
            }
        }
    } else if (stmt_type == vpiIfElse) {
        // Check for nested if statements
        const if_else* if_stmt = any_cast<const if_else*>(stmt);
        if (if_stmt) {
            if (if_stmt->VpiStmt() && contains_complex_constructs(if_stmt->VpiStmt())) {
                return true;
            }
            if (if_stmt->VpiElseStmt() && contains_complex_constructs(if_stmt->VpiElseStmt())) {
                return true;
            }
        }
    }
    
    return false;
}

// Extract just the signal names from assignments
void UhdmImporter::extract_assigned_signal_names(const any* stmt, std::set<std::string>& signal_names) {
    std::vector<AssignedSignal> signals;
    extract_assigned_signals(stmt, signals);
    for (const auto& sig : signals) {
        if (!sig.name.empty()) {
            signal_names.insert(sig.name);
        }
    }
}

// Collect base names of signals written via BLOCKING (`=`) assignments
// only.  Used by emit_full_case_default in always_ff context: genrtlil
// emits `\sig = X` in a full_case default ONLY for blocking-assigned
// combinational temps (e.g. picorv32's set_mem_do_*/current_pc/
// next_irq_pending), while non-blocking (`<=`) FF signals must HOLD
// (an X on a FF's D collapses its whole cone to X — see commit ee63b3e4).
void UhdmImporter::collect_blocking_assigned_names(const any* stmt, std::set<std::string>& signal_names) {
    if (!stmt) return;
    switch (stmt->VpiType()) {
        case vpiAssignment:
        case vpiAssignStmt: {
            const assignment* assign = any_cast<const assignment*>(stmt);
            if (assign->VpiBlocking()) {
                std::vector<AssignedSignal> sigs;
                extract_assigned_signals(stmt, sigs);
                for (const auto& s : sigs)
                    if (!s.name.empty()) signal_names.insert(s.name);
            }
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            if (VectorOfany* stmts = begin_block_stmts(stmt))
                for (auto s : *stmts) collect_blocking_assigned_names(s, signal_names);
            break;
        }
        case vpiIf: {
            const UHDM::if_stmt* i = any_cast<const UHDM::if_stmt*>(stmt);
            collect_blocking_assigned_names(i->VpiStmt(), signal_names);
            break;
        }
        case vpiIfElse: {
            const if_else* i = any_cast<const if_else*>(stmt);
            collect_blocking_assigned_names(i->VpiStmt(), signal_names);
            collect_blocking_assigned_names(i->VpiElseStmt(), signal_names);
            break;
        }
        case vpiCase: {
            const case_stmt* c = any_cast<const case_stmt*>(stmt);
            if (c->Case_items())
                for (auto it : *c->Case_items())
                    collect_blocking_assigned_names(it->Stmt(), signal_names);
            break;
        }
        case vpiFor: {
            const for_stmt* f = any_cast<const for_stmt*>(stmt);
            collect_blocking_assigned_names(f->VpiStmt(), signal_names);
            break;
        }
        case vpiRepeat: {
            const UHDM::repeat* r = any_cast<const UHDM::repeat*>(stmt);
            collect_blocking_assigned_names(r->VpiStmt(), signal_names);
            break;
        }
    }
}

// Helper function to check if an assignment is a memory write
bool UhdmImporter::parse_mem_partial_select(const UHDM::var_select* vs,
                                            const UHDM::expr*& addr_expr, int& lo, int& hi) {
    addr_expr = nullptr;
    const UHDM::any* sel = nullptr;
    const UHDM::expr* second = nullptr;
    if (!vs->Exprs()) return false;
    // Exprs() = [address, selector].  The selector is a part_select or
    // indexed_part_select; the other entry is the word address.  A plain
    // second index (`mem[addr][bit]`) is a single-bit select.
    for (auto e : *vs->Exprs()) {
        int t = e->VpiType();
        if (t == vpiPartSelect || t == vpiIndexedPartSelect)
            sel = e;
        else if (!addr_expr)
            addr_expr = e;
        else if (!second)
            second = e;
    }
    if (!addr_expr) return false;
    if (!sel) {
        // No range selector: `mem[addr][bit]` — a constant-evaluable single bit.
        if (!second) return false;
        RTLIL::SigSpec b = import_expression(second);
        if (!b.is_fully_const()) return false;
        lo = hi = b.as_int();
        return true;
    }
    if (sel->VpiType() == vpiPartSelect) {
        auto ps = any_cast<const part_select*>(sel);
        RTLIL::SigSpec l = import_expression(ps->Left_range());
        RTLIL::SigSpec r = import_expression(ps->Right_range());
        if (!l.is_fully_const() || !r.is_fully_const()) return false;
        lo = std::min(l.as_int(), r.as_int());
        hi = std::max(l.as_int(), r.as_int());
        return true;
    }
    // indexed_part_select: `[base +: width]` (type 1) or `[base -: width]` (2)
    auto ips = any_cast<const indexed_part_select*>(sel);
    RTLIL::SigSpec base = import_expression(ips->Base_expr());
    RTLIL::SigSpec width = import_expression(ips->Width_expr());
    if (!base.is_fully_const() || !width.is_fully_const()) return false;
    int b = base.as_int(), w = width.as_int();
    if (ips->VpiIndexedPartSelectType() == 2) {   // -:
        hi = b; lo = b - w + 1;
    } else {                                       // +:
        lo = b; hi = b + w - 1;
    }
    return true;
}

bool UhdmImporter::is_memory_write(const assignment* assign, RTLIL::Module* module) {
    if (!assign || !module) return false;
    
    if (auto lhs = assign->Lhs()) {
        if (lhs->VpiType() == vpiBitSelect) {
            const bit_select* bit_sel = any_cast<const bit_select*>(lhs);
            std::string signal_name = std::string(bit_sel->VpiName());
            RTLIL::IdString mem_id = RTLIL::escape_id(signal_name);
            return module->memories.count(mem_id) > 0;
        }
        // Partial (byte-enable) memory write: `mem[addr][hi:lo] <= data`.
        // UHDM represents the LHS as a var_select whose VpiName is the memory.
        if (lhs->VpiType() == vpiVarSelect) {
            const var_select* vs = any_cast<const var_select*>(lhs);
            RTLIL::IdString mem_id = RTLIL::escape_id(std::string(vs->VpiName()));
            return module->memories.count(mem_id) > 0;
        }
    }
    return false;
}

// Helper function to scan a statement tree for memory writes
// Collect, in source order, the LHS bit_select node of every memory-write
// statement, grouped by memory name.  Recurses through the same control-flow
// constructs as scan_for_memory_writes so the order matches body import.
void UhdmImporter::collect_memory_write_lhs(const any* stmt,
        std::map<std::string, std::vector<const any*>>& out, RTLIL::Module* module) {
    if (!stmt || !module) return;
    switch (stmt->VpiType()) {
        case vpiAssignment:
        case vpiAssignStmt: {
            const assignment* assign = any_cast<const assignment*>(stmt);
            if (is_memory_write(assign, module)) {
                if (auto lhs = assign->Lhs()) {
                    if (lhs->VpiType() == vpiBitSelect) {
                        const bit_select* bit_sel = any_cast<const bit_select*>(lhs);
                        out[std::string(bit_sel->VpiName())].push_back(lhs);
                    } else if (lhs->VpiType() == vpiVarSelect) {
                        const var_select* vs = any_cast<const var_select*>(lhs);
                        out[std::string(vs->VpiName())].push_back(lhs);
                    }
                }
            }
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            if (VectorOfany* stmts = begin_block_stmts(stmt))
                for (auto s : *stmts)
                    collect_memory_write_lhs(s, out, module);
            break;
        }
        case vpiIf: {
            const UHDM::if_stmt* s = any_cast<const UHDM::if_stmt*>(stmt);
            if (auto t = s->VpiStmt()) collect_memory_write_lhs(t, out, module);
            break;
        }
        case vpiIfElse: {
            const if_else* s = any_cast<const if_else*>(stmt);
            if (auto t = s->VpiStmt()) collect_memory_write_lhs(t, out, module);
            if (auto e = s->VpiElseStmt()) collect_memory_write_lhs(e, out, module);
            break;
        }
        case vpiCase: {
            const case_stmt* cs = any_cast<const case_stmt*>(stmt);
            if (cs->Case_items())
                for (auto ci : *cs->Case_items())
                    if (auto s = ci->Stmt()) collect_memory_write_lhs(s, out, module);
            break;
        }
        case vpiFor: {
            const for_stmt* f = any_cast<const for_stmt*>(stmt);
            if (auto b = f->VpiStmt()) collect_memory_write_lhs(b, out, module);
            break;
        }
        case vpiRepeat: {
            const UHDM::repeat* r = any_cast<const UHDM::repeat*>(stmt);
            if (auto b = r->VpiStmt()) collect_memory_write_lhs(b, out, module);
            break;
        }
        default:
            break;
    }
}

void UhdmImporter::scan_for_memory_writes(const any* stmt, std::set<std::string>& memory_names, RTLIL::Module* module) {
    if (!stmt || !module) return;

    switch (stmt->VpiType()) {
        case vpiAssignment:
        case vpiAssignStmt: {
            const assignment* assign = any_cast<const assignment*>(stmt);
            if (is_memory_write(assign, module)) {
                if (auto lhs = assign->Lhs()) {
                    if (lhs->VpiType() == vpiBitSelect) {
                        const bit_select* bit_sel = any_cast<const bit_select*>(lhs);
                        std::string signal_name = std::string(bit_sel->VpiName());
                        memory_names.insert(signal_name);
                    } else if (lhs->VpiType() == vpiVarSelect) {
                        const var_select* vs = any_cast<const var_select*>(lhs);
                        memory_names.insert(std::string(vs->VpiName()));
                    }
                }
            }
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            VectorOfany* stmts = begin_block_stmts(stmt);
            if (stmts) {
                for (auto sub_stmt : *stmts) {
                    scan_for_memory_writes(sub_stmt, memory_names, module);
                }
            }
            break;
        }
        case vpiIf: {
            const UHDM::if_stmt* if_stmt = any_cast<const UHDM::if_stmt*>(stmt);
            if (auto then_stmt = if_stmt->VpiStmt()) {
                scan_for_memory_writes(then_stmt, memory_names, module);
            }
            break;
        }
        case vpiIfElse: {
            const if_else* if_else_stmt = any_cast<const if_else*>(stmt);
            if (auto then_stmt = if_else_stmt->VpiStmt()) {
                scan_for_memory_writes(then_stmt, memory_names, module);
            }
            if (auto else_stmt = if_else_stmt->VpiElseStmt()) {
                scan_for_memory_writes(else_stmt, memory_names, module);
            }
            break;
        }
        case vpiCase: {
            const case_stmt* case_stmt_obj = any_cast<const case_stmt*>(stmt);
            if (case_stmt_obj->Case_items()) {
                for (auto case_item : *case_stmt_obj->Case_items()) {
                    if (auto case_item_stmt = case_item->Stmt()) {
                        scan_for_memory_writes(case_item_stmt, memory_names, module);
                    }
                }
            }
            break;
        }
        case vpiFor: {
            const for_stmt* for_loop = any_cast<const for_stmt*>(stmt);
            if (auto body = for_loop->VpiStmt()) {
                scan_for_memory_writes(body, memory_names, module);
            }
            break;
        }
        case vpiRepeat: {
            const UHDM::repeat* repeat_s = any_cast<const UHDM::repeat*>(stmt);
            if (auto body = repeat_s->VpiStmt()) {
                scan_for_memory_writes(body, memory_names, module);
            }
            break;
        }
    }
}

// Collect the base names of `(* mem2reg *)`-expanded arrays written with a
// DYNAMIC (non-constant) index anywhere in the statement tree.  Such an array
// is flattened to per-element wires \base[0..N-1] (no $memory object), so a
// write `base[idx] <= ...` with a variable idx is the marker.  Used by the
// async-reset always_ff path to register every element as its own FF.
void UhdmImporter::collect_dynamic_expanded_array_writes(
        const any* stmt, std::set<std::string>& names, RTLIL::Module* module) {
    if (!stmt || !module) return;
    auto record = [&](const std::string& base, const any* idx) {
        if (base.empty()) return;
        bool const_idx = idx && idx->VpiType() == vpiConstant;
        if (const_idx) return;
        // Expanded array, not a real $memory: element wire \base[0] exists.
        if (!module->memories.count(RTLIL::escape_id(base)) &&
            module->wire(RTLIL::escape_id(base + "[0]")))
            names.insert(base);
    };
    switch (stmt->VpiType()) {
        case vpiAssignment:
        case vpiAssignStmt: {
            const assignment* assign = any_cast<const assignment*>(stmt);
            if (auto lhs = assign->Lhs()) {
                if (lhs->VpiType() == vpiBitSelect) {
                    const bit_select* bs = any_cast<const bit_select*>(lhs);
                    record(std::string(bs->VpiName()), bs->VpiIndex());
                }
            }
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            if (VectorOfany* stmts = begin_block_stmts(stmt))
                for (auto s : *stmts) collect_dynamic_expanded_array_writes(s, names, module);
            break;
        }
        case vpiIf: {
            const UHDM::if_stmt* s = any_cast<const UHDM::if_stmt*>(stmt);
            if (s->VpiStmt()) collect_dynamic_expanded_array_writes(s->VpiStmt(), names, module);
            break;
        }
        case vpiIfElse: {
            const if_else* s = any_cast<const if_else*>(stmt);
            if (s->VpiStmt()) collect_dynamic_expanded_array_writes(s->VpiStmt(), names, module);
            if (s->VpiElseStmt()) collect_dynamic_expanded_array_writes(s->VpiElseStmt(), names, module);
            break;
        }
        case vpiCase: {
            const case_stmt* cs = any_cast<const case_stmt*>(stmt);
            if (cs->Case_items())
                for (auto ci : *cs->Case_items())
                    if (ci->Stmt()) collect_dynamic_expanded_array_writes(ci->Stmt(), names, module);
            break;
        }
        case vpiFor: {
            const for_stmt* f = any_cast<const for_stmt*>(stmt);
            if (f->VpiStmt()) collect_dynamic_expanded_array_writes(f->VpiStmt(), names, module);
            break;
        }
        case vpiRepeat: {
            const UHDM::repeat* r = any_cast<const UHDM::repeat*>(stmt);
            if (r->VpiStmt()) collect_dynamic_expanded_array_writes(r->VpiStmt(), names, module);
            break;
        }
    }
}

// Helper: return true if the statement tree contains a for loop (at any depth).
bool UhdmImporter::has_for_loop(const any* stmt) {
    if (!stmt) return false;
    int type = stmt->VpiType();
    if (type == vpiFor) return true;
    if (type == vpiBegin || type == vpiNamedBegin) {
        VectorOfany* stmts = begin_block_stmts(stmt);
        if (stmts) for (auto s : *stmts) if (has_for_loop(s)) return true;
    }
    if (type == vpiIf) {
        const UHDM::if_stmt* if_s = any_cast<const UHDM::if_stmt*>(stmt);
        if (if_s->VpiStmt() && has_for_loop(if_s->VpiStmt())) return true;
    }
    if (type == vpiIfElse) {
        const if_else* if_e = any_cast<const if_else*>(stmt);
        if (if_e->VpiStmt() && has_for_loop(if_e->VpiStmt())) return true;
        if (if_e->VpiElseStmt() && has_for_loop(if_e->VpiElseStmt())) return true;
    }
    return false;
}

// Helper: return true if the always_ff body requires the old import_statement_sync path.
// The comb path handles for loops at the top level of a Process (via the vpiFor case in
// import_statement_comb(Process*)), but fails in two situations:
//  1. vpiRepeat loops (not handled at all in import_statement_comb)
//  2. vpiFor loops nested inside a conditional (CaseRule* version lacks vpiFor)
// In either case, fall back to import_statement_sync which handles these via
// import_statement_with_loop_vars / the vpiRepeat handler.
bool UhdmImporter::needs_sync_path(const any* stmt, bool inside_conditional) {
    if (!stmt) return false;
    int type = stmt->VpiType();

    // vpiRepeat is not handled by import_statement_comb at all.
    if (type == vpiRepeat) return true;

    // Dynamic indexed-part-select on the LHS of a non-blocking assignment
    // (e.g. `dout[ctrl*sel +: 16] <= din`) requires a read-modify-write
    // pattern over the *full* base wire — `import_statement_comb` would
    // otherwise treat the slice wire returned by import_indexed_part_select
    // as an FF target, leaving the real base wire undriven.  The sync path
    // (import_assignment_sync) has the proper handler for this.
    if (type == vpiAssignment) {
        auto a = any_cast<const assignment*>(stmt);
        if (a && a->Lhs() && a->Lhs()->VpiType() == vpiIndexedPartSelect) {
            auto ips = any_cast<const indexed_part_select*>(a->Lhs());
            if (ips && ips->Base_expr() &&
                ips->Base_expr()->VpiType() != vpiConstant)
                return true;
        }
    }

    // A for loop inside a conditional (CaseRule* context) is not handled.
    if (type == vpiFor && inside_conditional) return true;

    // For a for loop at the top level, just recurse into its body with the
    // inside_conditional flag unchanged (still false at the process level).
    if (type == vpiFor) {
        const for_stmt* fs = any_cast<const for_stmt*>(stmt);
        if (fs->VpiStmt()) return needs_sync_path(fs->VpiStmt(), false);
        return false;
    }

    // Conditionals flip the flag for their bodies.
    if (type == vpiIf) {
        const UHDM::if_stmt* if_s = any_cast<const UHDM::if_stmt*>(stmt);
        if (if_s->VpiStmt() && needs_sync_path(if_s->VpiStmt(), true)) return true;
        return false;
    }
    if (type == vpiIfElse) {
        const if_else* if_e = any_cast<const if_else*>(stmt);
        if (if_e->VpiStmt() && needs_sync_path(if_e->VpiStmt(), true)) return true;
        if (if_e->VpiElseStmt() && needs_sync_path(if_e->VpiElseStmt(), true)) return true;
        return false;
    }
    if (type == vpiCase) {
        const case_stmt* cs = any_cast<const case_stmt*>(stmt);
        if (cs->Case_items()) {
            for (auto ci : *cs->Case_items()) {
                if (ci->Stmt() && needs_sync_path(ci->Stmt(), true)) return true;
            }
        }
        return false;
    }
    if (type == vpiBegin || type == vpiNamedBegin) {
        VectorOfany* stmts = begin_block_stmts(stmt);
        if (stmts) {
            for (auto s : *stmts) {
                if (needs_sync_path(s, inside_conditional)) return true;
            }
        }
    }
    return false;
}

// Find assignment statement for a given LHS expression
const assignment* UhdmImporter::find_assignment_for_lhs(const any* stmt, const expr* lhs_expr) {
    if (!stmt || !lhs_expr) return nullptr;
    
    switch (stmt->VpiType()) {
        case vpiAssignment:
        case vpiAssignStmt: {
            auto assign = any_cast<const assignment*>(stmt);
            if (assign->Lhs() == lhs_expr) {
                return assign;
            }
            break;
        }
        case vpiBegin:
        case vpiNamedBegin: {
            VectorOfany* stmts = begin_block_stmts(stmt);
            if (stmts) {
                for (auto s : *stmts) {
                    if (auto result = find_assignment_for_lhs(s, lhs_expr)) {
                        return result;
                    }
                }
            }
            break;
        }
        case vpiIfElse:
        case vpiIf: {
            auto if_st = any_cast<const UHDM::if_stmt*>(stmt);
            if (auto result = find_assignment_for_lhs(if_st->VpiStmt(), lhs_expr)) {
                return result;
            }
            if (stmt->VpiType() == vpiIfElse) {
                auto if_else_st = any_cast<const UHDM::if_else*>(stmt);
                if (if_else_st->VpiElseStmt()) {
                    if (auto result = find_assignment_for_lhs(if_else_st->VpiElseStmt(), lhs_expr)) {
                        return result;
                    }
                }
            }
            break;
        }
    }
    
    return nullptr;
}


// Check if an array is accessed only with constant indices
bool UhdmImporter::has_only_constant_array_accesses(const std::string& array_name) {
    if (!module) return false;
    
    // We need to scan all processes in the module to check array accesses
    auto uhdm_module = current_instance;
    if (!uhdm_module || !uhdm_module->Process()) {
        return true;  // If no processes, assume constant access (will be unrolled)
    }
    
    // Always log this for debugging array issues
    log("UHDM: Checking array accesses for '%s' in %d processes\n", 
        array_name.c_str(), (int)uhdm_module->Process()->size());
    log("      Current instance: %p, Module: %p\n", current_instance, module);
    
    // Capture the module for lambda access
    auto rtlil_module = module;
    
    // Helper lambda to check if an expression is a constant
    std::function<bool(const UHDM::expr*)> is_constant_expr = [&, rtlil_module](const UHDM::expr* expr) -> bool {
        if (!expr) return true;
        
        switch (expr->VpiType()) {
            case vpiConstant:  // vpiIntConst has the same value
            case vpiRealConst:
            case vpiStringConst:
            case vpiBinaryConst:
            case vpiOctConst:
            case vpiDecConst:
            case vpiHexConst:
                return true;
            
            case vpiRefObj: {
                // Check if it's a parameter reference
                auto ref = any_cast<const ref_obj*>(expr);
                if (ref) {
                    std::string ref_name = std::string(ref->VpiName());
                    // Check if it's a parameter
                    if (rtlil_module->parameter_default_values.count(RTLIL::escape_id(ref_name))) {
                        return true;  // Parameters are constant
                    }
                }
                return false;
            }
            
            case vpiOperation: {
                // Check if all operands are constant
                auto op = any_cast<const operation*>(expr);
                if (op && op->Operands()) {
                    for (auto operand : *op->Operands()) {
                        if (!is_constant_expr(any_cast<const UHDM::expr*>(operand))) {
                            return false;
                        }
                    }
                    return true;
                }
                return false;
            }
            
            default:
                return false;
        }
    };
    
    // Helper lambda to check array accesses in an expression
    std::function<bool(const UHDM::any*, int)> check_array_access = [&](const UHDM::any* stmt, int cur_depth) -> bool {
        if (!stmt) return true;
        
        // Debug: log statement type
        if (cur_depth <= 5) {  // Only log first few levels to avoid spam
            log("      [Depth %d] Checking statement type: %d\n", cur_depth, stmt->VpiType());
        }
        
        switch (stmt->VpiType()) {
            case vpiBitSelect: {
                auto bit_sel = any_cast<const bit_select*>(stmt);
                if (bit_sel && bit_sel->VpiParent()) {
                    // Check if this is accessing our array
                    std::string parent_name = std::string(bit_sel->VpiName());
                    
                    // Debug log to see all bit selects
                    log("      Found bit_select with name='%s'\n", parent_name.c_str());
                    
                    // Sometimes the parent is the array reference
                    if (bit_sel->VpiParent()->VpiType() == vpiRefObj) {
                        auto ref = any_cast<const ref_obj*>(bit_sel->VpiParent());
                        if (ref) {
                            parent_name = std::string(ref->VpiName());
                        }
                    }
                    
                    if (mode_debug) {
                        log("      Checking bit_select: parent_name='%s', array_name='%s'\n", 
                            parent_name.c_str(), array_name.c_str());
                    }
                    
                    if (parent_name == array_name) {
                        // This is an access to our array - check if index is constant
                        if (mode_debug) {
                            log("      Found access to array %s\n", array_name.c_str());
                        }
                        if (!is_constant_expr(bit_sel->VpiIndex())) {
                            if (mode_debug) {
                                log("      Array %s has non-constant index access!\n", array_name.c_str());
                            }
                            return false;  // Non-constant access found
                        } else {
                            if (mode_debug) {
                                log("      Array %s access with constant index\n", array_name.c_str());
                            }
                        }
                    }
                }
                // Don't recursively check parent - we'll visit it through normal traversal
                break;
            }
            
            case vpiAssignment: {
                auto assign = any_cast<const assignment*>(stmt);
                if (assign) {
                    // Check both LHS and RHS for array accesses
                    // These might be bit_selects
                    if (assign->Lhs()) {
                        log("        Assignment LHS type: %d\n", assign->Lhs()->VpiType());
                        if (!check_array_access(assign->Lhs(), cur_depth + 1)) return false;
                    }
                    if (assign->Rhs()) {
                        log("        Assignment RHS type: %d\n", assign->Rhs()->VpiType());
                        if (!check_array_access(assign->Rhs(), cur_depth + 1)) return false;
                    }
                }
                break;
            }
            
            case vpiBegin:
            case vpiNamedBegin: {
                VectorOfany* stmts = begin_block_stmts(stmt);
                if (stmts) {
                    log("        Begin block has %d statements\n", (int)stmts->size());
                    for (auto sub_stmt : *stmts) {
                        log("        Begin sub-statement type: %d\n", sub_stmt->VpiType());
                        if (!check_array_access(sub_stmt, cur_depth + 1)) return false;
                    }
                } else {
                    log("        Begin block has no statements\n");
                }
                break;
            }

            case vpiIfElse: {
                auto if_stmt = any_cast<const UHDM::if_else*>(stmt);
                if (if_stmt) {
                    if (!check_array_access(if_stmt->VpiCondition(), cur_depth + 1)) return false;
                    if (if_stmt->VpiStmt()) {
                        log("        IfElse statement body type: %d\n", if_stmt->VpiStmt()->VpiType());
                        if (!check_array_access(if_stmt->VpiStmt(), cur_depth + 1)) return false;
                    }
                    if (!check_array_access(if_stmt->VpiElseStmt(), cur_depth + 1)) return false;
                }
                break;
            }
            
            case vpiIf: {
                auto if_stmt = any_cast<const UHDM::if_stmt*>(stmt);
                if (if_stmt) {
                    log("        Found if statement\n");
                    if (!check_array_access(if_stmt->VpiCondition(), cur_depth + 1)) return false;
                    if (if_stmt->VpiStmt()) {
                        log("        If statement body type: %d\n", if_stmt->VpiStmt()->VpiType());
                        if (!check_array_access(if_stmt->VpiStmt(), cur_depth + 1)) return false;
                    } else {
                        log("        If statement has no body\n");
                    }
                }
                break;
            }
            
            case vpiCase: {
                auto case_stmt = any_cast<const UHDM::case_stmt*>(stmt);
                if (case_stmt) {
                    if (!check_array_access(case_stmt->VpiCondition(), cur_depth + 1)) return false;
                    if (case_stmt->Case_items()) {
                        for (auto item : *case_stmt->Case_items()) {
                            if (!check_array_access(item, cur_depth + 1)) return false;
                        }
                    }
                }
                break;
            }
            
            case vpiCaseItem: {
                auto case_item = any_cast<const UHDM::case_item*>(stmt);
                if (case_item) {
                    if (!check_array_access(case_item->Stmt(), cur_depth + 1)) return false;
                }
                break;
            }
            
            case vpiFor: {
                auto for_s = any_cast<const UHDM::for_stmt*>(stmt);
                if (for_s) {
                    if (!check_array_access(for_s->VpiStmt(), cur_depth + 1)) return false;
                }
                break;
            }
            
            case vpiEventControl: {
                auto event_ctrl = any_cast<const event_control*>(stmt);
                if (event_ctrl) {
                    if (!check_array_access(event_ctrl->Stmt(), cur_depth + 1)) return false;
                }
                break;
            }
            
            case vpiOperation: {
                auto op = any_cast<const operation*>(stmt);
                if (op && op->Operands()) {
                    for (auto operand : *op->Operands()) {
                        if (!check_array_access(any_cast<const UHDM::expr*>(operand), cur_depth + 1)) return false;
                    }
                }
                break;
            }
            
            case vpiRefObj: {
                // Check if this reference involves array access
                auto ref = any_cast<const ref_obj*>(stmt);
                if (ref) {
                    // Check if it has a bit select child
                    if (ref->VpiType() == vpiBitSelect) {
                        if (!check_array_access(ref, cur_depth + 1)) return false;
                    }
                }
                break;
            }
        }
        
        return true;  // No non-constant access found
    };
    
    // Check all processes in the module
    int process_count = 0;
    for (auto proc : *uhdm_module->Process()) {
        log("      Process type: %d (vpiAlways=%d, vpiAlwaysComb=%d, vpiAlwaysFF=%d)\n",
            proc->VpiType(), vpiAlways, vpiAlwaysComb, vpiAlwaysFF);
        if (proc->VpiType() == vpiAlways || proc->VpiType() == vpiAlwaysComb || 
            proc->VpiType() == vpiAlwaysFF || proc->VpiType() == vpiInitial) {
            auto always_proc = any_cast<const process_stmt*>(proc);
            if (always_proc && always_proc->Stmt()) {
                process_count++;
                log("    Checking process %d for array accesses\n", process_count);
                if (!check_array_access(always_proc->Stmt(), 1)) {
                    if (mode_debug) {
                        log("    Found non-constant access in process %d\n", process_count);
                    }
                    return false;  // Found non-constant access
                }
            }
        }
    }
    
    if (mode_debug) {
        log("    Array %s has only constant index accesses\n", array_name.c_str());
    }
    
    return true;  // All accesses are constant
}

// TARGETED FIX: Check if a single net is a memory array (has both packed and unpacked dimensions)
bool UhdmImporter::is_memory_array(const UHDM::net* uhdm_net) {
    if (!uhdm_net) return false;
    
    // Skip if no typespec
    if (!uhdm_net->Typespec()) return false;
    
    auto ref_typespec = uhdm_net->Typespec();
    const UHDM::typespec* typespec = nullptr;
    
    if (ref_typespec && ref_typespec->Actual_typespec()) {
        typespec = ref_typespec->Actual_typespec();
    } else {
        return false;
    }

    // Unpacked array via array_typespec (typedef'd unpacked array, e.g.
    // `typedef logic [3:0] ram16x4_t[0:15]; ram16x4_t mem;`): the net carries
    // its unpacked dimension(s) in the array_typespec and its packed width in
    // the element typespec -> infer a memory.
    if (typespec->UhdmType() == uhdmarray_typespec) {
        if (mode_debug) {
            log("    Detected memory array: %s (logic_net with array_typespec)\n",
                std::string(uhdm_net->VpiName()).c_str());
        }
        return true;
    }

    // Check if typespec has both packed and unpacked dimensions
    if (typespec->UhdmType() == uhdmlogic_typespec) {
        auto logic_typespec = any_cast<const UHDM::logic_typespec*>(typespec);
        
        // Check for packed dimensions
        bool has_packed = logic_typespec->Ranges() && !logic_typespec->Ranges()->empty();
        
        // Check for unpacked dimensions on the net itself
        // Note: regular nets don't have unpacked dimensions - only array_nets do
        // So this case would be rare, but check if net has array indicators
        bool has_unpacked = false;
        
        if (has_packed && has_unpacked) {
            if (mode_debug) {
                log("    Detected memory array: %s (logic_net with both packed and unpacked dimensions)\n", 
                    std::string(uhdm_net->VpiName()).c_str());
            }
            return true;
        }
    }
    
    return false;
}

// TARGETED FIX: Check if an array_net is a memory array
bool UhdmImporter::is_memory_array(const UHDM::array_net* uhdm_array) {
    if (!uhdm_array) return false;
    
    // Array_net inherently has unpacked dimensions
    // Check if the underlying net has packed dimensions (bit width > 1)
    if (uhdm_array->Nets() && !uhdm_array->Nets()->empty()) {
        auto underlying_net = (*uhdm_array->Nets())[0];
        
        // Get the typespec to check for packed dimensions
        if (underlying_net->Typespec()) {
            auto ref_typespec = underlying_net->Typespec();
            const UHDM::typespec* typespec = nullptr;
            
            if (ref_typespec && ref_typespec->Actual_typespec()) {
                typespec = ref_typespec->Actual_typespec();
            } else {
                return false;
            }
            
            // Check for logic_typespec with ranges (packed dimensions)
            if (typespec->UhdmType() == uhdmlogic_typespec) {
                auto logic_typespec = any_cast<const UHDM::logic_typespec*>(typespec);
                if (logic_typespec->Ranges() && !logic_typespec->Ranges()->empty()) {
                    // This net has both packed (from typespec) and unpacked (from array_net) dimensions
                    if (mode_debug) {
                        log("    Detected memory array: %s (array_net with packed dimensions)\n", 
                            std::string(uhdm_array->VpiName()).c_str());
                    }
                    return true;
                }
            }
        }
    }
    
    return false;
}

// TARGETED FIX: Check if an array_var is a memory array
bool UhdmImporter::is_memory_array(const UHDM::array_var* uhdm_array) {
    if (!uhdm_array) return false;
    
    // Array_var inherently has unpacked dimensions
    // Check if the underlying var has packed dimensions (bit width > 1)
    // The underlying logic_var is accessed through Reg()
    const UHDM::VectorOfvariables * underlying_var = uhdm_array->Variables();
    
    if (underlying_var && !underlying_var->empty()) {
        
        // Get the typespec to check for packed dimensions
        if (underlying_var->at(0)->Typespec()) {
            auto ref_typespec = underlying_var->at(0)->Typespec();
            const UHDM::typespec* typespec = nullptr;
            
            if (ref_typespec && ref_typespec->Actual_typespec()) {
                typespec = ref_typespec->Actual_typespec();
            }
            
            // Check for logic_typespec with ranges (packed dimensions)
            if (typespec && typespec->UhdmType() == uhdmlogic_typespec) {
                auto logic_typespec = any_cast<const UHDM::logic_typespec*>(typespec);
                if (logic_typespec->Ranges() && !logic_typespec->Ranges()->empty()) {
                    // This var has both packed (from typespec) and unpacked (from array_var) dimensions
                    if (mode_debug) {
                        log("    Detected memory array: %s (array_var with packed dimensions)\n",
                            std::string(uhdm_array->VpiName()).c_str());
                    }
                    return true;
                }
            }
        }
    }

    // Typedef'd unpacked array (`typedef logic [3:0] ram16x4_t[0:15]; ram16x4_t mem;`):
    // the array_var has no underlying Variables(); its unpacked range and packed
    // element type both live on the array_typespec.  Treat as a memory when the
    // element typespec carries a packed dimension.
    if (uhdm_array->Typespec() && uhdm_array->Typespec()->Actual_typespec() &&
        uhdm_array->Typespec()->Actual_typespec()->UhdmType() == uhdmarray_typespec) {
        auto ats = any_cast<const UHDM::array_typespec*>(uhdm_array->Typespec()->Actual_typespec());
        if (ats->Elem_typespec() && ats->Elem_typespec()->Actual_typespec()) {
            auto elem = ats->Elem_typespec()->Actual_typespec();
            if (elem->UhdmType() == uhdmlogic_typespec) {
                auto lt = any_cast<const UHDM::logic_typespec*>(elem);
                if (lt->Ranges() && !lt->Ranges()->empty()) {
                    if (mode_debug) {
                        log("    Detected memory array: %s (array_var with array_typespec)\n",
                            std::string(uhdm_array->VpiName()).c_str());
                    }
                    return true;
                }
            }
        }
    }

    return false;
}


// Helper function to evaluate expressions with variable substitution
RTLIL::SigSpec UhdmImporter::evaluate_expression_with_vars(const expr* expr, 
                                                           const std::map<std::string, uint64_t>& vars,
                                                           const std::string& loop_var_name,
                                                           int64_t loop_index) {
    if (!expr) return RTLIL::SigSpec();
    
    switch (expr->VpiType()) {
        case vpiConstant:
            return import_constant(any_cast<const constant*>(expr));
            
        case vpiRefVar:
        case vpiRefObj: {
            std::string var_name;
            if (expr->VpiType() == vpiRefVar) {
                var_name = any_cast<const ref_var*>(expr)->VpiName();
            } else {
                var_name = any_cast<const ref_obj*>(expr)->VpiName();
            }
            
            // Check if this is the loop variable
            if (var_name == loop_var_name) {
                return RTLIL::SigSpec(RTLIL::Const(loop_index, 32));
            }
            
            // Check if this is a tracked variable
            auto it = vars.find(var_name);
            if (it != vars.end()) {
                return RTLIL::SigSpec(RTLIL::Const(it->second, 32));
            }
            
            // Otherwise try normal import
            return import_expression(expr);
        }
        
        case vpiOperation: {
            const operation* op = any_cast<const operation*>(expr);
            int op_type = op->VpiOpType();
            
            if (!op->Operands() || op->Operands()->empty()) {
                return RTLIL::SigSpec();
            }
            
            // Evaluate operands
            std::vector<RTLIL::SigSpec> operands;
            for (auto operand : *op->Operands()) {
                operands.push_back(evaluate_expression_with_vars(any_cast<const UHDM::expr*>(operand), vars, loop_var_name, loop_index));
            }
            
            // Perform operation if all operands are constant.  An EMPTY operand
            // (an unhandled sub-expression that returned no SigSpec) must count
            // as non-const — otherwise `as_int()` reads it as 0 and silently
            // corrupts the result (e.g. `PRIME*(i*2+1)` with `i*2+1` unhandled
            // became `PRIME*0`).
            bool all_const = true;
            for (const auto& operand : operands) {
                if (operand.empty() || !operand.is_fully_const()) {
                    all_const = false;
                    break;
                }
            }

            if (!all_const) {
                return RTLIL::SigSpec();
            }

            // For `*`, `+`, `-` the SV self-determined result width is the max
            // of the operand widths (LRM §11.6.1).  Truncate to that so a value
            // assigned to a wider word zero-extends — matching how
            // import_expression computes the same expression elsewhere (e.g. the
            // `expect_val` wire in arch/*/meminit.v).  Without it the ROM word
            // (full product) and the comparison value (truncated) disagree.
            auto arith_width = [&]() -> int {
                int w = 0;
                for (const auto& o : operands) w = std::max(w, o.size());
                return w > 0 ? w : 32;
            };

            // Evaluate constant operations
            switch (op_type) {
                // TODO: support all op types
                case vpiMultOp:
                    if (operands.size() == 2) {
                        uint64_t a = (uint32_t)operands[0].as_const().as_int();
                        uint64_t b = (uint32_t)operands[1].as_const().as_int();
                        return RTLIL::SigSpec(RTLIL::Const((a * b) & 0xFFFFFFFFFFFFFFFFull,
                                                           arith_width()));
                    }
                    break;

                case vpiAddOp:
                    if (operands.size() == 2)
                        return RTLIL::SigSpec(RTLIL::Const(
                            (uint64_t)(uint32_t)operands[0].as_const().as_int() +
                            (uint64_t)(uint32_t)operands[1].as_const().as_int(),
                            arith_width()));
                    break;

                case vpiSubOp:
                    if (operands.size() == 2)
                        return RTLIL::SigSpec(RTLIL::Const(
                            (uint64_t)(uint32_t)operands[0].as_const().as_int() -
                            (uint64_t)(uint32_t)operands[1].as_const().as_int(),
                            arith_width()));
                    break;
                    
                case vpiBitXorOp: // 30
                    if (operands.size() == 2) {
                        uint32_t a = operands[0].as_const().as_int() & 0xFFFFFFFF;
                        uint32_t b = operands[1].as_const().as_int() & 0xFFFFFFFF;
                        return RTLIL::SigSpec(RTLIL::Const(a ^ b, 32));
                    }
                    break;
                    
                case vpiLShiftOp:
                    if (operands.size() == 2) {
                        uint32_t a = operands[0].as_const().as_int() & 0xFFFFFFFF;
                        uint32_t b = operands[1].as_const().as_int() & 0xFFFFFFFF;
                        return RTLIL::SigSpec(RTLIL::Const(a << b, 32));
                    }
                    break;
                    
                case vpiRShiftOp:
                    if (operands.size() == 2) {
                        uint32_t a = operands[0].as_const().as_int() & 0xFFFFFFFF;
                        uint32_t b = operands[1].as_const().as_int() & 0xFFFFFFFF;
                        return RTLIL::SigSpec(RTLIL::Const(a >> b, 32));
                    }
                    break;
            }
            break;
        }
        
        default:
            // Fall back to regular import
            return import_expression(expr);
    }
    
    return RTLIL::SigSpec();
}

YOSYS_NAMESPACE_END