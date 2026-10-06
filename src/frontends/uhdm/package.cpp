/*
 * Package-specific UHDM to RTLIL translation
 * 
 * This file handles the translation of SystemVerilog packages including
 * parameters, typespecs, and other package contents.
 */

#include <functional>
#include "uhdm2rtlil.h"
#include <uhdm/vpi_visitor.h>
#include <uhdm/struct_typespec.h>
#include <uhdm/uhdm_types.h>
#include <uhdm/param_assign.h>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Import a SystemVerilog package
void UhdmImporter::import_package(const package* uhdm_package) {
    if (!uhdm_package) return;
    
    std::string package_name = std::string(uhdm_package->VpiDefName());
    
    // Remove work@ prefix if present
    if (package_name.find("work@") == 0) {
        package_name = package_name.substr(5);
    }
    
    log("UHDM: Importing package: %s\n", package_name.c_str());
    
    // Store package for later reference
    package_map[package_name] = uhdm_package;
    
    // Import package parameters
    if (uhdm_package->Parameters()) {
        log("UHDM: Found %d parameters in package %s\n", 
            (int)uhdm_package->Parameters()->size(), package_name.c_str());
        
        for (const any* param : *uhdm_package->Parameters()) {
            if (auto param_obj = dynamic_cast<const parameter*>(param)) {
                std::string param_name = std::string(param_obj->VpiName());
                std::string full_name = package_name + "::" + param_name;

                log("UHDM: Importing package parameter: %s\n", full_name.c_str());

                // Outer element count of an array/table parameter (for a later
                // `pkg::TABLE[idx]` element-select to derive its element width).
                // The OUTER packed/unpacked range count of the parameter's
                // typespec — e.g. `logic [15:0][3:0]` -> 16 (PRESENT_SBOX4).
                auto record_elem_count = [&]() {
                    if (!param_obj->Typespec()) return;
                    auto ats = param_obj->Typespec()->Actual_typespec();
                    if (!ats) return;
                    UHDM::VectorOfrange* rngs = nullptr;
                    if (auto lt = dynamic_cast<const UHDM::logic_typespec*>(ats))
                        rngs = lt->Ranges();
                    else if (auto at = dynamic_cast<const UHDM::array_typespec*>(ats))
                        rngs = at->Ranges();
                    else if (auto pt =
                                 dynamic_cast<const UHDM::packed_array_typespec*>(ats))
                        rngs = pt->Ranges();
                    if (!rngs || rngs->empty()) return;
                    auto r0 = (*rngs)[0];
                    RTLIL::SigSpec l = import_expression(r0->Left_expr());
                    RTLIL::SigSpec r = import_expression(r0->Right_expr());
                    if (l.is_fully_const() && r.is_fully_const()) {
                        int n = std::abs(l.as_const().as_int() -
                                         r.as_const().as_int()) + 1;
                        if (n > 1) package_parameter_elem_count[full_name] = n;
                    }
                };

                // Get parameter value
                if (auto expr = param_obj->Expr()) {
                    // Temporarily set module to nullptr since we're in package context
                    RTLIL::Module* saved_module = module;
                    module = nullptr;
                    
                    RTLIL::SigSpec value_spec = import_expression(expr);
                    
                    module = saved_module;
                    
                    if (value_spec.is_fully_const()) {
                        RTLIL::Const param_value = value_spec.as_const();
                        package_parameter_map[full_name] = param_value;
                        log("UHDM: Package parameter %s = %s\n", 
                            full_name.c_str(), param_value.as_string().c_str());
                    } else {
                        log_warning("UHDM: Package parameter %s has non-constant value\n", 
                                   full_name.c_str());
                    }
                } else if (!param_obj->VpiValue().empty()) {
                    // Fallback: use VpiValue() directly (elaborated params may have resolved value here)
                    std::string val_str = std::string(param_obj->VpiValue());
                    // Get width from typespec if available, else default 32
                    int width = 32;
                    if (param_obj->Typespec()) {
                        if (auto ts = param_obj->Typespec()->Actual_typespec()) {
                            int ts_width = get_width_from_typespec(ts);
                            if (ts_width > 0) width = ts_width;
                        }
                    }
                    // Use the arbitrary-width parser — `parse_vpi_value_to_int`
                    // truncates to `int` and overflows std::stoul for wide
                    // constants (e.g. a 160-bit `logic [159:0]` package
                    // parameter — ParameterSizeOfInstance crashed here).
                    RTLIL::Const param_value = extract_const_from_value(val_str);
                    if (param_value.size() != width)
                        param_value = param_value.extract(0, width, RTLIL::State::S0);
                    package_parameter_map[full_name] = param_value;
                    log("UHDM: Package parameter %s = %s (from VpiValue)\n",
                        full_name.c_str(), param_value.as_string().c_str());
                } else if (const UHDM::param_assign* pa = [&]() -> const UHDM::param_assign* {
                               // The value can live in the package's Param_assigns
                               // list rather than Expr()/VpiValue — e.g. a
                               // struct/union assignment-pattern initializer
                               // `'{default: 1}` (UnionParameter).
                               if (uhdm_package->Param_assigns())
                                   for (auto p : *uhdm_package->Param_assigns())
                                       if (p->Lhs() &&
                                           std::string(p->Lhs()->VpiName()) == param_name)
                                           return p;
                               return nullptr;
                           }()) {
                    if (pa->Rhs()) {
                        if (auto re = dynamic_cast<const UHDM::expr*>(pa->Rhs())) {
                            RTLIL::Module* saved_module = module;
                            module = nullptr;
                            RTLIL::SigSpec value_spec = import_expression(re);
                            module = saved_module;
                            if (value_spec.is_fully_const()) {
                                int width = 32;
                                if (param_obj->Typespec())
                                    if (auto ts = param_obj->Typespec()->Actual_typespec()) {
                                        int tw = get_width_from_typespec(ts);
                                        if (tw > 0) width = tw;
                                    }
                                RTLIL::Const param_value = value_spec.as_const();
                                if (param_value.size() != width)
                                    param_value = param_value.extract(0, width, RTLIL::State::S0);
                                package_parameter_map[full_name] = param_value;
                                log("UHDM: Package parameter %s = %s (from param_assign)\n",
                                    full_name.c_str(), param_value.as_string().c_str());
                            } else {
                                log_warning("UHDM: Package parameter %s param_assign Rhs not constant\n",
                                            full_name.c_str());
                            }
                        }
                    }
                } else {
                    log_warning("UHDM: Package parameter %s has no expression\n",
                               full_name.c_str());
                }
                if (package_parameter_map.count(full_name)) record_elem_count();
            }
        }
    }

    // Import package typespecs
    if (uhdm_package->Typespecs()) {
        log("UHDM: Found %d typespecs in package %s\n", 
            (int)uhdm_package->Typespecs()->size(), package_name.c_str());
        
        for (const typespec* ts : *uhdm_package->Typespecs()) {
            std::string type_name = std::string(ts->VpiName());
            std::string full_name = package_name + "::" + type_name;
            
            log("UHDM: Importing package typespec: %s (UhdmType=%s)\n", 
                full_name.c_str(), UhdmName(ts->UhdmType()).c_str());
            
            // Store typespec for later reference
            package_typespec_map[full_name] = ts;
            
            // Also store without package prefix for import * cases
            package_typespec_map[type_name] = ts;
        }
    }
    
    // Import package variables (if any)
    if (uhdm_package->Variables()) {
        log("UHDM: Found %d variables in package %s\n", 
            (int)uhdm_package->Variables()->size(), package_name.c_str());
        
        // Note: Package variables are not commonly used in synthesizable code
        // but we log them for completeness
        for (const variables* var : *uhdm_package->Variables()) {
            std::string var_name = std::string(var->VpiName());
            log("UHDM: Package variable: %s (not imported - synthesis limitation)\n", 
                var_name.c_str());
        }
    }
    
    log("UHDM: Finished importing package %s\n", package_name.c_str());
}

// Compilation-unit ($unit) parameters: the declarations an `include` file puts
// outside any package or module (scr1's src/includes/*.svh -- `parameter bit
// [31:SCR1_CSR_MTVEC_BASE_ZERO_BITS] SCR1_CSR_MTVEC_BASE_RST_VAL = ...`).
// Surelog hangs them off the DESIGN, not off a package, and a reference to one
// is a bare ref_obj with no vpiActual, so every lookup in import_ref_obj
// failed and the name became a fabricated 1-bit wire.  In scr1_pipe_csr's
// `assign csr_mtvec_base = {csr_mtvec_base_reg, RST_VAL[ZERO_BITS +: RO_BITS]}`
// that turned a 22-bit slice into one X bit, and read_uhdm SEGFAULTED on every
// module above it (scr1_pipe_top, scr1_core_top, scr1_top_axi, scr1_top_ahb) --
// which is how the new SCR1 sweep found it.
//
// The value is usually not on the parameter itself: Surelog leaves
// `(SCR1_XLEN-(ZERO_BITS+WR_BITS))` unfolded and puts it in the DESIGN's
// Param_assigns list, where it refers to other $unit parameters.  So resolve
// to a fixed point: each pass imports the RHS of what is still unresolved,
// and because import_ref_obj consults this same map, a parameter resolved in
// one pass lets the next pass fold the ones that use it.
//
// $unit is the OUTERMOST scope, so an entry a package already defined is never
// overwritten, and every caller consults the map only after its local lookups
// fail.
void UhdmImporter::import_unit_parameters(const UHDM::design* uhdm_design) {
    if (!uhdm_design) return;

    // name -> the parameter object (for its typespec width), and the RHS the
    // design's param_assign list gives it.
    std::map<std::string, const parameter*> params;
    // `ifdef` branches can leave SEVERAL design-level param_assigns for one
    // name (scr1_tdu.svh declares SCR1_TDU_ALLTRIG_NUM twice); keep them all
    // and take the first that folds, instead of whichever came last.
    std::map<std::string, std::vector<const UHDM::any*>> rhs_of;
    if (uhdm_design->Parameters())
        for (auto p : *uhdm_design->Parameters())
            if (auto po = dynamic_cast<const parameter*>(p)) {
                std::string n = std::string(po->VpiName());
                if (!n.empty() && !package_parameter_map.count(n)) params[n] = po;
            }
    if (uhdm_design->Param_assigns())
        for (auto pa : *uhdm_design->Param_assigns()) {
            if (!pa->Lhs() || !pa->Rhs()) continue;
            std::string n = std::string(pa->Lhs()->VpiName());
            if (n.empty() || package_parameter_map.count(n)) continue;
            rhs_of[n].push_back(pa->Rhs());
            if (!params.count(n))
                if (auto po = dynamic_cast<const parameter*>(pa->Lhs())) params[n] = po;
        }
    if (params.empty()) return;

    // A $unit parameter can be declared over a non-zero-based range
    // (`parameter bit [31:6] RST_VAL`): record the declared LSB so a later
    // `RST_VAL[6 +: 22]` can turn the source's bit NUMBER into an offset into
    // the constant.  Without it the slice reads 22 bits starting at 6 of a
    // 26-bit value and comes back all zero.
    auto record_lsb = [&](const std::string& n, const parameter* po) {
        if (!po->Typespec()) return;
        auto ats = po->Typespec()->Actual_typespec();
        if (!ats) return;
        UHDM::VectorOfrange* rngs = nullptr;
        if (auto lt = dynamic_cast<const UHDM::logic_typespec*>(ats)) rngs = lt->Ranges();
        else if (auto bt = dynamic_cast<const UHDM::bit_typespec*>(ats)) rngs = bt->Ranges();
        else if (auto pt = dynamic_cast<const UHDM::packed_array_typespec*>(ats)) rngs = pt->Ranges();
        if (!rngs || rngs->empty()) return;
        auto r0 = (*rngs)[0];
        if (!r0->Left_expr() || !r0->Right_expr()) return;
        RTLIL::Module* saved = module;
        module = design->addModule(NEW_ID);
        bool saved_fcf = force_const_fold;
        force_const_fold = true;
        RTLIL::SigSpec l = import_expression(r0->Left_expr());
        RTLIL::SigSpec r = import_expression(r0->Right_expr());
        force_const_fold = saved_fcf;
        discard_eval_module(module);
        module = saved;
        if (!l.is_fully_const() || !r.is_fully_const()) return;
        int lo = std::min(l.as_const().as_int(), r.as_const().as_int());
        if (lo != 0) package_parameter_lsb[n] = lo;
    };

    // A reference that resolves to nothing folds to a CONSTANT 0 here (the
    // isolated-fold context has no module, so import_ref_obj cannot even
    // fabricate a wire), and a wrong 0 is worse than no value at all: it made
    // `SCR1_TDU_MTRIG_NUM = SCR1_TDU_TRIG_NUM` read 0 because std::map walks
    // M before T, and $clog2(0+1) = 0 then turned a cast into a zero-width
    // constant.  So a parameter whose RHS still mentions an unresolved $unit
    // parameter is deferred to a later pass, and one that never resolves is
    // left out of the map entirely.
    std::set<std::string> pending;
    for (auto& [n, po] : params) pending.insert(n);
    std::function<bool(const UHDM::any*, int)> waits_for_pending =
        [&](const UHDM::any* e, int depth) -> bool {
        if (!e || depth > 24) return false;
        switch (e->UhdmType()) {
            case uhdmref_obj: {
                std::string rn = std::string(e->VpiName());
                return pending.count(rn) > 0;
            }
            case uhdmoperation: {
                auto op = any_cast<const UHDM::operation*>(e);
                if (op->Operands())
                    for (auto o : *op->Operands())
                        if (waits_for_pending(o, depth + 1)) return true;
                return false;
            }
            case uhdmsys_func_call: {
                auto sf = any_cast<const UHDM::sys_func_call*>(e);
                if (sf->Tf_call_args())
                    for (auto a : *sf->Tf_call_args())
                        if (waits_for_pending(a, depth + 1)) return true;
                return false;
            }
            case uhdmpart_select: {
                auto ps = any_cast<const UHDM::part_select*>(e);
                if (pending.count(std::string(ps->VpiName()))) return true;
                return waits_for_pending(ps->Left_range(), depth + 1) ||
                       waits_for_pending(ps->Right_range(), depth + 1);
            }
            case uhdmindexed_part_select: {
                auto ip = any_cast<const UHDM::indexed_part_select*>(e);
                if (pending.count(std::string(ip->VpiName()))) return true;
                return waits_for_pending(ip->Base_expr(), depth + 1) ||
                       waits_for_pending(ip->Width_expr(), depth + 1);
            }
            case uhdmbit_select: {
                auto bs = any_cast<const UHDM::bit_select*>(e);
                if (pending.count(std::string(bs->VpiName()))) return true;
                return waits_for_pending(bs->VpiIndex(), depth + 1);
            }
            default:
                return false;
        }
    };

    size_t resolved_before;
    do {
        resolved_before = package_parameter_map.size();
        for (auto it = params.begin(); it != params.end();) {
            const std::string& n = it->first;
            const parameter* po = it->second;
            int width = 0;
            if (po->Typespec())
                if (auto ts = po->Typespec()->Actual_typespec())
                    width = get_width_from_typespec(ts);
            RTLIL::Const value;
            bool have = false;
            // The parameter's own folded value first, then the design's
            // param_assign RHS (an expression over other $unit parameters).
            if (!po->VpiValue().empty()) {
                value = extract_const_from_value(std::string(po->VpiValue()));
                have = true;
            }
            if (!have) {
                std::vector<const UHDM::any*> cands;
                if (po->Expr()) cands.push_back(po->Expr());
                if (rhs_of.count(n))
                    for (auto r : rhs_of.at(n)) cands.push_back(r);
                bool waiting = false;
                for (auto e : cands) {
                    if (waits_for_pending(e, 0)) { waiting = true; continue; }
                    // Fold in a THROWAWAY module, not with `module = nullptr`:
                    // import_operation refuses to emit anything without a
                    // module and returns empty before it even tries to fold,
                    // so `SCR1_TDU_ALLTRIG_NUM = SCR1_TDU_MTRIG_NUM + 1'b1`
                    // never resolved while the bare `MTRIG_NUM = TRIG_NUM`
                    // did.  discard_eval_module() drops the module AND the
                    // name_map entries pointing into it (see
                    // "Throwaway modules" in CLAUDE.md).
                    RTLIL::Module* saved = module;
                    module = design->addModule(NEW_ID);
                    // Without force_const_fold an all-constant operation emits
                    // a cell and returns a WIRE instead of folding (see
                    // "Constant Folding in Generate Scopes" in CLAUDE.md), so
                    // `MTRIG_NUM + 1'b1` never produced a value.
                    bool saved_fcf = force_const_fold;
                    force_const_fold = true;
                    RTLIL::SigSpec v = import_expression(dynamic_cast<const UHDM::expr*>(e));
                    force_const_fold = saved_fcf;
                    discard_eval_module(module);
                    module = saved;
                    // An EMPTY SigSpec is trivially "fully const" and would
                    // zero-extend to a wrong 0 (that is how
                    // SCR1_TDU_MTRIG_NUM became 0 and $clog2 collapsed a size
                    // cast to zero width); only a real value counts.
                    if (v.is_fully_const() && v.size() > 0) {
                        value = v.as_const(); have = true; break;
                    }
                }
                if (!have && waiting) { ++it; continue; }
            }
            if (!have) { ++it; continue; }
            if (width > 0 && value.size() != width)
                value = value.extract(0, width, RTLIL::State::S0);
            package_parameter_map[n] = value;
            record_lsb(n, po);
            pending.erase(n);
            log("UHDM: $unit parameter %s = %s\n", n.c_str(), value.as_string().c_str());
            it = params.erase(it);
        }
    } while (package_parameter_map.size() != resolved_before && !params.empty());

    if (mode_debug)
        for (auto& [n, po] : params)
            log("    $unit parameter '%s' left unresolved (no foldable value)\n", n.c_str());
}

YOSYS_NAMESPACE_END
