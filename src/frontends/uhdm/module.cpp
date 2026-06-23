/*
 * Module-specific UHDM to RTLIL translation
 * 
 * This file handles the translation of module-level constructs including
 * ports, nets, and module instantiations.
 */

#include "uhdm2rtlil.h"
#include <uhdm/vpi_visitor.h>
#include <uhdm/packed_array_var.h>
#include <uhdm/gen_scope.h>
#include <cctype>
#include <functional>
#include <uhdm/gen_scope_array.h>
#include <uhdm/uhdm_types.h>
#include <uhdm/union_typespec.h>
#include <uhdm/packed_array_typespec.h>
#include <uhdm/ExprEval.h>
#include <uhdm/func_call.h>
#include <uhdm/function.h>
#include <uhdm/parameter.h>
#include <uhdm/variables.h>
#include <uhdm/logic_typespec.h>
#include <uhdm/integer_typespec.h>
#include <uhdm/int_typespec.h>
#include <uhdm/short_int_typespec.h>
#include <uhdm/long_int_typespec.h>
#include <uhdm/byte_typespec.h>
#include <uhdm/bit_typespec.h>
#include <uhdm/struct_typespec.h>
YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

// Import a module port
void UhdmImporter::import_port(const port* uhdm_port, int positional_idx) {
    std::string portname = std::string(uhdm_port->VpiName());
    int direction = uhdm_port->VpiDirection();

    // Handle empty port names — blackbox modules instantiated with
    // positional args (e.g. `unknown u(~i, w);` in
    // yosys/tests/various/abc9.v) have ports with no VpiName.  Use
    // `$<index>` (Verilog frontend's positional-port convention) so
    // each unnamed port gets a unique wire name and the cell-side
    // connection lookup matches.
    if (portname.empty()) {
        if (positional_idx > 0) {
            portname = "$" + std::to_string(positional_idx);
        } else {
            log_warning("UHDM: Port has empty name, using default name 'unnamed_port'\n");
            portname = "unnamed_port";
        }
    }
    
    if (mode_debug)
        log("  Importing port: %s (dir=%d)\n", portname.c_str(), direction);
    
    // Get port width
    int width = get_width(uhdm_port, current_instance);
    
    // Check if this is an interface port
    if (width == -1) {
        log("UHDM: Port '%s' is an interface type, creating placeholder\n", portname.c_str());
        // For interface ports, create a special wire that won't be used for connections
        // but serves as a placeholder for the port list
        RTLIL::Wire* w = module->addWire(RTLIL::escape_id(portname), 1);
        
        // Add interface-specific attributes
        w->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
        
        // Get the interface type information from the port's typespec
        if (uhdm_port->Typespec()) {
            const UHDM::ref_typespec* ref_typespec = uhdm_port->Typespec();
            const UHDM::typespec* typespec = nullptr;
            
            // Get actual typespec from ref_typespec
            if (ref_typespec && ref_typespec->Actual_typespec()) {
                typespec = ref_typespec->Actual_typespec();
            }
            
            // Get interface type name
            if (typespec && typespec->UhdmType() == uhdminterface_typespec) {
                const UHDM::interface_typespec* iface_ts = any_cast<const UHDM::interface_typespec*>(typespec);
                std::string interface_type;
                std::string modport_name;
                
                // Check if this is a modport (has vpiIsModPort)
                if (iface_ts->VpiIsModPort()) {
                    // This is a modport, so get the modport name
                    modport_name = std::string(iface_ts->VpiName());
                    
                    // The parent should be the actual interface typespec
                    if (iface_ts->VpiParent() && iface_ts->VpiParent()->UhdmType() == uhdminterface_typespec) {
                        const UHDM::interface_typespec* parent_iface_ts = 
                            any_cast<const UHDM::interface_typespec*>(iface_ts->VpiParent());
                        interface_type = std::string(parent_iface_ts->VpiName());
                    } 
                } else {
                    // This is the interface itself
                    interface_type = std::string(iface_ts->VpiName());
                }

                if (interface_type.empty())
                {
                    const UHDM::any *lowconn = uhdm_port->Low_conn();
                    if (lowconn && lowconn->UhdmType() == uhdmref_obj)
                    {
                        const ref_obj *ref = (const ref_obj *)lowconn;
                        const any *actual = ref->Actual_group();
                        if (actual && actual->UhdmType() == uhdmmodport)
                        {
                            modport *mod = (modport *)actual;
                            const any *inst = mod->VpiParent();
                            interface_type = std::string(inst->VpiDefName());
                        }
                    }
                }

                // If we still don't have interface type, try other sources
                if (interface_type.empty()) {
                    if (ref_typespec && !ref_typespec->VpiDefName().empty()) {
                        interface_type = std::string(ref_typespec->VpiDefName());
                    } else if (!iface_ts->VpiDefName().empty()) {
                        interface_type = std::string(iface_ts->VpiDefName());
                    }
                }
                
                if (!interface_type.empty()) {
                    // Remove work@ prefix if present
                    if (interface_type.find("work@") == 0) {
                        interface_type = interface_type.substr(5);
                    }
                    
                    // Check if we need to use a parameterized interface name
                    std::string final_interface_type = interface_type;
                    
                    // Try to determine the WIDTH parameter from the context
                    // First check if the parent module has a WIDTH parameter
                    if (module->parameter_default_values.count(RTLIL::escape_id("WIDTH"))) {
                        // Build the parameterized interface name
                        std::string param_interface_name = RTLIL::escape_id("$paramod") + RTLIL::escape_id(interface_type);
                        param_interface_name +=  RTLIL::escape_id("WIDTH=");
                        RTLIL::Const width_val = module->parameter_default_values.at(RTLIL::escape_id("WIDTH"));
                        //if (width_val.flags & RTLIL::CONST_FLAG_SIGNED) {
                            param_interface_name += "s";
                        //}
                        param_interface_name += std::to_string(width_val.size()) + "'";
                        // Add binary representation
                        for (int i = width_val.size() - 1; i >= 0; i--) {
                            param_interface_name += (width_val[i] == RTLIL::State::S1) ? "1" : "0";
                        }
                        
                        // Check if this parameterized interface module exists
                        //if (design->module(RTLIL::escape_id(param_interface_name))) {
                            final_interface_type = param_interface_name;
                            log("UHDM: Using parameterized interface name: %s\n", final_interface_type.c_str());
                        //}
                    }
                    
                    w->attributes[RTLIL::escape_id("interface_type")] = RTLIL::Const( final_interface_type);
                }
                
                // Set modport name
                if (!modport_name.empty()) {
                    w->attributes[RTLIL::escape_id("interface_modport")] = RTLIL::Const(modport_name);
                }

                // Create the per-signal wires inside this module (e.g.
                // `\bus.in`, `\bus.out`) for an interface modport port.
                // Without these, hier_path references inside the body
                // (`assign bus.out = bus.in;`) can't resolve, and the
                // later interface-port-expansion pass has nothing to
                // promote to ports.  Source the signals from the
                // modport's IODecls when possible (so direction matches
                // the modport view); fall back to the parent interface's
                // nets.
                const UHDM::modport* mp = nullptr;
                const UHDM::interface_inst* iface_inst = nullptr;
                if (auto lowconn = uhdm_port->Low_conn()) {
                    if (lowconn->UhdmType() == uhdmref_obj) {
                        auto ref = any_cast<const ref_obj*>(lowconn);
                        if (auto actual = ref->Actual_group()) {
                            if (actual->UhdmType() == uhdmmodport)
                                mp = any_cast<const UHDM::modport*>(actual);
                            else if (actual->UhdmType() == uhdminterface_inst)
                                iface_inst = any_cast<const UHDM::interface_inst*>(actual);
                        }
                    }
                }
                if (mp && mp->VpiParent() &&
                    mp->VpiParent()->UhdmType() == uhdminterface_inst)
                    iface_inst = any_cast<const UHDM::interface_inst*>(mp->VpiParent());

                // AllModules has the unelaborated interface_inst (default
                // parameter values).  Swap in the elaborated form's port
                // iface_inst so per-signal widths reflect the parent's
                // `#(.W(N))` override.  Without this, a `bus` port whose
                // declared field is `logic [W-1:0] data` always materialises
                // as the default `W` width, even when the parent
                // instantiated the interface with a wider `W`.
                if (uhdm_design && uhdm_design->TopModules() && current_instance) {
                    std::string def = std::string(current_instance->VpiDefName());
                    std::function<const UHDM::module_inst*(const UHDM::module_inst*)> find =
                        [&](const UHDM::module_inst* m) -> const UHDM::module_inst* {
                        if (!m) return nullptr;
                        if (std::string(m->VpiDefName()) == def &&
                            m != current_instance && m->Ports())
                            return m;
                        if (m->Modules())
                            for (auto c : *m->Modules())
                                if (auto r = find(c)) return r;
                        return nullptr;
                    };
                    // Extract the parent-side interface_inst from a module
                    // instance's port High_conn (carries the overridden
                    // parameter).  Low_conn is the submodule's local view (no
                    // override), so it's not used.  Only `iface_inst` is swapped
                    // (parameter resolution / per-signal widths); `mp` (port
                    // direction) intentionally keeps the submodule's own modport.
                    auto eii_from = [&](const UHDM::module_inst* mi)
                            -> const UHDM::interface_inst* {
                        if (!mi || !mi->Ports()) return nullptr;
                        for (auto ep : *mi->Ports()) {
                            if (std::string(ep->VpiName()) != portname) continue;
                            auto hc = ep->High_conn();
                            if (hc && hc->UhdmType() == uhdmref_obj) {
                                auto r2 = any_cast<const ref_obj*>(hc);
                                if (auto ag = r2->Actual_group()) {
                                    if (ag->UhdmType() == uhdminterface_inst)
                                        return any_cast<const UHDM::interface_inst*>(ag);
                                    if (ag->UhdmType() == uhdmmodport) {
                                        auto emp = any_cast<const UHDM::modport*>(ag);
                                        if (emp && emp->VpiParent() &&
                                            emp->VpiParent()->UhdmType() == uhdminterface_inst)
                                            return any_cast<const UHDM::interface_inst*>(emp->VpiParent());
                                    }
                                }
                            }
                            break;
                        }
                        return nullptr;
                    };
                    // Prefer current_instance's OWN elaborated port — it carries
                    // THIS instance's parameter override (e.g. inst3 with
                    // WIDTH=16).  Matching another same-def instance by name
                    // (find) returns the first one (inst1, WIDTH=8) and gets the
                    // wrong width; only use it when current_instance isn't
                    // elaborated (the AllModules definition pass).
                    const UHDM::interface_inst* eii = eii_from(current_instance);
                    if (!eii) {
                        const UHDM::module_inst* elab = nullptr;
                        for (auto t : *uhdm_design->TopModules())
                            if (auto r = find(t)) { elab = r; break; }
                        eii = eii_from(elab);
                    }
                    if (eii) iface_inst = eii;
                }

                // When the interface signal's typespec refers to an
                // interface parameter (e.g. `logic [DATA_WIDTH-1:0]`
                // where DATA_WIDTH is on `bus_if`), `get_width` needs
                // the interface_inst as its scope context so ExprEval
                // can resolve the parameter.  Pass `iface_inst` rather
                // than `current_instance` (the module being imported).
                auto compute_signal_width = [&](const UHDM::any* obj) -> int {
                    const UHDM::scope* ctx = iface_inst
                        ? static_cast<const UHDM::scope*>(iface_inst)
                        : static_cast<const UHDM::scope*>(current_instance);
                    int sw = get_width(const_cast<UHDM::any*>(obj), ctx);
                    return (sw > 0) ? sw : 1;
                };

                if (mp && mp->Io_decls() && iface_inst) {
                    for (auto io : *mp->Io_decls()) {
                        std::string sig_name = std::string(io->VpiName());
                        if (sig_name.empty()) continue;
                        std::string full_name = portname + "." + sig_name;
                        if (name_map.count(full_name)) continue;
                        // Find the matching net/variable in the interface
                        // so we can sample its real width and source loc.
                        const UHDM::any* width_obj = nullptr;
                        if (iface_inst->Nets()) {
                            for (auto n : *iface_inst->Nets()) {
                                if (std::string(n->VpiName()) == sig_name) {
                                    width_obj = n; break;
                                }
                            }
                        }
                        if (!width_obj && iface_inst->Variables()) {
                            for (auto v : *iface_inst->Variables()) {
                                if (std::string(v->VpiName()) == sig_name) {
                                    width_obj = v; break;
                                }
                            }
                        }
                        int sig_w = width_obj ? compute_signal_width(width_obj) : 1;
                        RTLIL::Wire* sw = module->addWire(
                            RTLIL::escape_id(full_name), sig_w);
                        if (width_obj) add_src_attribute(sw->attributes, width_obj);
                        // Remember the modport's direction for this
                        // signal so `expand_interfaces` can promote
                        // it to an input/output (rather than blanket
                        // inout inherited from the interface port).
                        sw->attributes[RTLIL::escape_id("modport_direction")] =
                            RTLIL::Const(io->VpiDirection());
                        name_map[full_name] = sw;
                        if (mode_debug)
                            log("UHDM: Created modport signal wire '%s' (width=%d, dir=%d)\n",
                                full_name.c_str(), sig_w, io->VpiDirection());
                    }
                } else if (iface_inst) {
                    // No modport — full interface port; mirror every signal
                    // in the interface.
                    auto add_sig = [&](const UHDM::any* obj,
                                       const std::string& sig_name) {
                        std::string full_name = portname + "." + sig_name;
                        if (name_map.count(full_name)) return;
                        int sig_w = compute_signal_width(obj);
                        RTLIL::Wire* sw = module->addWire(
                            RTLIL::escape_id(full_name), sig_w);
                        add_src_attribute(sw->attributes, obj);
                        name_map[full_name] = sw;
                    };
                    if (iface_inst->Nets())
                        for (auto n : *iface_inst->Nets())
                            add_sig(n, std::string(n->VpiName()));
                    if (iface_inst->Variables())
                        for (auto v : *iface_inst->Variables())
                            add_sig(v, std::string(v->VpiName()));
                }
            }
        }

        // Add source attribute
        add_src_attribute(w->attributes, uhdm_port);

        // Set port direction
        if (direction == vpiInput)
            w->port_input = true;
        else if (direction == vpiOutput)
            w->port_output = true;
        else if (direction == vpiInout) {
            w->port_input = true;
            w->port_output = true;
        }

        w->port_id = module->ports.size() + 1;
        module->ports.push_back(w->name);

        // Store in maps
        wire_map[uhdm_port] = w;
        name_map[portname] = w;
        return;
    }
    
    // Check if this port has reversed bit ordering
    bool upto = false;
    int start_offset = 0;
    int left = -1, right = -1;
    
    // Try to get range information from the port's typespec
    if (uhdm_port->Typespec()) {
        auto ref_typespec = uhdm_port->Typespec();
        if (ref_typespec && ref_typespec->Actual_typespec()) {
            auto typespec = ref_typespec->Actual_typespec();
            if (typespec && typespec->UhdmType() == uhdmlogic_typespec) {
                auto logic_typespec = any_cast<const UHDM::logic_typespec*>(typespec);
                if (logic_typespec->Ranges() && !logic_typespec->Ranges()->empty()) {
                    // For packed multidimensional arrays (multiple ranges or Elem_typespec),
                    // the wire is flat - don't set upto/start_offset
                    bool is_packed_multidim = logic_typespec->Ranges()->size() > 1 ||
                                              logic_typespec->Elem_typespec() != nullptr;
                    if (!is_packed_multidim) {
                        auto range = (*logic_typespec->Ranges())[0];
                        if (range->Left_expr() && range->Right_expr()) {
                            RTLIL::SigSpec left_spec = import_expression(range->Left_expr());
                            RTLIL::SigSpec right_spec = import_expression(range->Right_expr());

                            if (left_spec.is_fully_const() && right_spec.is_fully_const()) {
                                left = left_spec.as_int();
                                right = right_spec.as_int();

                                // Check if range is reversed (e.g., [0:7] instead of [7:0])
                                if (left < right) {
                                    upto = true;
                                    start_offset = left;
                                    log("UHDM: Port '%s' has reversed bit ordering [%d:%d]\n", portname.c_str(), left, right);
                                } else {
                                    start_offset = right;
                                    log("UHDM: Port '%s' has normal bit ordering [%d:%d]\n", portname.c_str(), left, right);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Surelog's elaborated parameterized variant may strip the unpacked
    // dimension from the port's typespec (leaving just the element
    // `logic_typespec`).  Recover it by checking the module's
    // `Array_nets()` / `Variables()` for an `array_net`/`array_var` of
    // the same name and using its dimensions to size the port wire.
    int unpacked_count = 0;
    int unpacked_elem_w = 0;
    if (current_instance) {
        // Walk the module instance's Array_nets() (unpacked-array nets).
        auto module_scope =
            dynamic_cast<const UHDM::module_inst*>(current_instance);
        if (module_scope && module_scope->Array_nets()) {
            for (auto an : *module_scope->Array_nets()) {
                if (an->VpiName() == portname) {
                    int total = 1;
                    if (an->Ranges()) {
                        for (auto r : *an->Ranges()) {
                            if (r->Left_expr() && r->Right_expr()) {
                                RTLIL::SigSpec ls = import_expression(r->Left_expr());
                                RTLIL::SigSpec rs = import_expression(r->Right_expr());
                                if (ls.is_fully_const() && rs.is_fully_const())
                                    total *= std::abs(ls.as_int() - rs.as_int()) + 1;
                                else { total = 0; break; }
                            }
                        }
                    }
                    int elem_w = 0;
                    if (an->Nets() && !an->Nets()->empty()) {
                        auto inner = (*an->Nets())[0];
                        elem_w = get_width(inner, current_instance);
                    }
                    if (total > 0 && elem_w > 0) {
                        unpacked_count = total;
                        unpacked_elem_w = elem_w;
                        width = total * elem_w;
                        log("UHDM: Port '%s' recovered unpacked dims from "
                            "Array_nets: %d * %d = %d bits\n",
                            portname.c_str(), elem_w, total, width);
                    }
                    break;
                }
            }
        }
    }

    RTLIL::Wire* w = create_wire(portname, width, upto, start_offset);

    // Add source attribute
    add_src_attribute(w->attributes, uhdm_port);

    // If we recovered unpacked dims from Array_nets above, also create per-
    // element wires `\name[0..N-1]` and connect them to slices of the flat
    // port wire so `import_bit_select` resolves `name[i]` as a full element.
    if (unpacked_count > 0 && unpacked_elem_w > 0) {
        for (int i = 0; i < unpacked_count; i++) {
            std::string ename = portname + "[" + std::to_string(i) + "]";
            RTLIL::IdString eid = RTLIL::escape_id(ename);
            if (!module->wire(eid)) {
                RTLIL::Wire* ew = module->addWire(eid, unpacked_elem_w);
                add_src_attribute(ew->attributes, uhdm_port);
                RTLIL::SigSpec slice =
                    RTLIL::SigSpec(w).extract(i * unpacked_elem_w, unpacked_elem_w);
                if (direction == vpiOutput)
                    module->connect(slice, RTLIL::SigSpec(ew));
                else
                    module->connect(RTLIL::SigSpec(ew), slice);
                name_map[ename] = ew;
            }
        }
    }

    // Store packed array metadata for use in bit_select handling
    if (uhdm_port->Typespec()) {
        auto ref_ts = uhdm_port->Typespec();
        if (ref_ts && ref_ts->Actual_typespec()) {
            auto ts = ref_ts->Actual_typespec();
            if (ts->UhdmType() == uhdmlogic_typespec) {
                auto lts = any_cast<const UHDM::logic_typespec*>(ts);
                if (lts->Ranges() && !lts->Ranges()->empty()) {
                    int packed_elem_width = 0;
                    int packed_outer_left = -1, packed_outer_right = -1;

                    auto first_range = (*lts->Ranges())[0];
                    if (first_range->Left_expr() && first_range->Right_expr()) {
                        RTLIL::SigSpec fl = import_expression(first_range->Left_expr());
                        RTLIL::SigSpec fr = import_expression(first_range->Right_expr());
                        if (fl.is_fully_const() && fr.is_fully_const()) {
                            packed_outer_left = fl.as_int();
                            packed_outer_right = fr.as_int();
                        }
                    }

                    if (lts->Ranges()->size() > 1) {
                        packed_elem_width = 1;
                        for (size_t i = 1; i < lts->Ranges()->size(); i++) {
                            auto rng = (*lts->Ranges())[i];
                            if (rng->Left_expr() && rng->Right_expr()) {
                                RTLIL::SigSpec rl = import_expression(rng->Left_expr());
                                RTLIL::SigSpec rr = import_expression(rng->Right_expr());
                                if (rl.is_fully_const() && rr.is_fully_const())
                                    packed_elem_width *= abs(rl.as_int() - rr.as_int()) + 1;
                            }
                        }
                    } else if (lts->Elem_typespec() != nullptr) {
                        auto elem_ref = lts->Elem_typespec();
                        if (elem_ref->Actual_typespec()) {
                            auto elem_actual = elem_ref->Actual_typespec();
                            if (elem_actual->UhdmType() == uhdmlogic_typespec) {
                                auto elem_logic = dynamic_cast<const UHDM::logic_typespec*>(elem_actual);
                                if (elem_logic && elem_logic->Elem_typespec() != nullptr &&
                                    elem_logic->Elem_typespec()->Actual_typespec()) {
                                    packed_elem_width = get_width_from_typespec(
                                        elem_logic->Elem_typespec()->Actual_typespec(), nullptr);
                                } else {
                                    packed_elem_width = get_width_from_typespec(elem_actual, nullptr);
                                }
                            } else {
                                packed_elem_width = get_width_from_typespec(elem_actual, nullptr);
                            }
                        }
                    }

                    if (packed_elem_width > 1) {
                        w->attributes[RTLIL::escape_id("packed_elem_width")] = RTLIL::Const(packed_elem_width);
                        w->attributes[RTLIL::escape_id("packed_outer_left")] = RTLIL::Const(packed_outer_left);
                        w->attributes[RTLIL::escape_id("packed_outer_right")] = RTLIL::Const(packed_outer_right);
                        log("UHDM: Port '%s' packed array: elem_width=%d, outer=[%d:%d]\n",
                            portname.c_str(), packed_elem_width, packed_outer_left, packed_outer_right);
                    }
                }
            }
            // Unpacked-array port (e.g. `input ptab_dat_t iP [4]`).  The
            // flat port wire is sized at `elem_w * count`; additionally
            // create per-element wires `\name[0..N-1]` and connect each
            // to the corresponding slice of the flat port wire so
            // `import_bit_select` resolves `iP[i]` as a full element
            // rather than a single-bit select.
            if (ts->UhdmType() == uhdmarray_typespec) {
                auto ats = any_cast<const UHDM::array_typespec*>(ts);
                int elem_w = 0;
                if (ats->Elem_typespec() && ats->Elem_typespec()->Actual_typespec())
                    elem_w = get_width_from_typespec(
                        ats->Elem_typespec()->Actual_typespec(), current_instance);
                int total = 0;
                if (ats->Ranges()) {
                    total = 1;
                    for (auto r : *ats->Ranges()) {
                        if (r->Left_expr() && r->Right_expr()) {
                            RTLIL::SigSpec lspec = import_expression(r->Left_expr());
                            RTLIL::SigSpec rspec = import_expression(r->Right_expr());
                            if (lspec.is_fully_const() && rspec.is_fully_const())
                                total *= std::abs(lspec.as_int() - rspec.as_int()) + 1;
                            else { total = 0; break; }
                        }
                    }
                }
                if (elem_w > 0 && total > 0 && (long long)elem_w * total == w->width) {
                    for (int i = 0; i < total; i++) {
                        std::string ename = portname + "[" + std::to_string(i) + "]";
                        RTLIL::IdString eid = RTLIL::escape_id(ename);
                        if (!module->wire(eid)) {
                            RTLIL::Wire* ew = module->addWire(eid, elem_w);
                            add_src_attribute(ew->attributes, uhdm_port);
                            RTLIL::SigSpec slice = RTLIL::SigSpec(w).extract(i * elem_w, elem_w);
                            if (direction == vpiOutput)
                                module->connect(slice, RTLIL::SigSpec(ew));
                            else
                                module->connect(RTLIL::SigSpec(ew), slice);
                            name_map[ename] = ew;
                        }
                    }
                    log("UHDM: Port '%s' unpacked array: elem_w=%d, count=%d\n",
                        portname.c_str(), elem_w, total);
                }
            }
        }
    }

    // Check if port is signed
    if (auto ref_typespec = uhdm_port->Typespec()) {
        // Check if typespec indicates signed
        bool is_signed = false;
        const UHDM::typespec* actual_typespec = nullptr;
        
        if (ref_typespec->Actual_typespec()) {
            actual_typespec = ref_typespec->Actual_typespec();
        }
        
        if (actual_typespec) {
            switch (actual_typespec->UhdmType()) {
                case uhdmlogic_typespec:
                    if (auto logic_ts = dynamic_cast<const UHDM::logic_typespec*>(actual_typespec)) {
                        is_signed = logic_ts->VpiSigned();
                    }
                    break;
                case uhdmint_typespec:
                    if (auto ts = dynamic_cast<const UHDM::int_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    break;
                case uhdminteger_typespec:
                    if (auto ts = dynamic_cast<const UHDM::integer_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    break;
                case uhdmbyte_typespec:
                    if (auto ts = dynamic_cast<const UHDM::byte_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    break;
                case uhdmshort_int_typespec:
                    if (auto ts = dynamic_cast<const UHDM::short_int_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    break;
                case uhdmlong_int_typespec:
                    if (auto ts = dynamic_cast<const UHDM::long_int_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    break;
                default:
                    // Other typespec types are not handled
                    break;
            }

            if (is_signed) {
                log("UHDM: Port '%s' is signed\n", portname.c_str());
                w->is_signed = true;
            }
        }
    }
    
    // Set port direction
    if (direction == vpiInput)
        w->port_input = true;
    else if (direction == vpiOutput)
        w->port_output = true;
    else if (direction == vpiInout) {
        w->port_input = true;
        w->port_output = true;
    }
    
    w->port_id = module->ports.size() + 1;
    module->ports.push_back(w->name);
    
    // Store in maps
    wire_map[uhdm_port] = w;
    name_map[portname] = w;
}

// Import a net
void UhdmImporter::import_net(const net* uhdm_net, const UHDM::instance* inst) {
    std::string netname = std::string(uhdm_net->VpiName());
    
    // Handle empty net names
    if (netname.empty()) {
        log_warning("UHDM: Net has empty name, using default name 'unnamed_net'\n");
        netname = "unnamed_net";
    }
    
    if (mode_debug)
        log("  Importing net: %s\n", netname.c_str());
    
    // If already created as port, still check signedness from the net object
    // (ports don't carry VpiSigned, but the corresponding net does)
    if (name_map.count(netname)) {
        RTLIL::Wire* w = name_map[netname];
        if (w && !w->is_signed && uhdm_net->VpiSigned()) {
            log("UHDM: Net '%s' already exists as port, updating signedness from net VpiSigned\n", netname.c_str());
            w->is_signed = true;
        }
        int net_type = uhdm_net->VpiNetType();
        if (net_type == vpiWand)
            w->set_bool_attribute(ID::wand);
        else if (net_type == vpiWor)
            w->set_bool_attribute(ID::wor);
        log_flush();
        return;
    }
    
    // Also check if wire already exists in module
    RTLIL::IdString wire_id = RTLIL::escape_id(netname);
    if (module->wire(wire_id)) {
        log("UHDM: Wire '%s' already exists in module, skipping net import\n", wire_id.c_str());
        // Still update signedness if the net marks it as signed
        RTLIL::Wire* existing_w = module->wire(wire_id);
        if (existing_w && !existing_w->is_signed && uhdm_net->VpiSigned()) {
            log("UHDM: Net '%s' (existing wire): updating is_signed from VpiSigned\n", wire_id.c_str());
            existing_w->is_signed = true;
        }
        log_flush();
        return;
    }
    
    // Also skip if this is a memory that was already created
    if (module->memories.count(wire_id) > 0) {
        log("UHDM: Net '%s' already exists as memory, skipping net import\n", netname.c_str());
        log_flush();
        return;
    }
    
    // Check if this net should be imported as a memory
    if (is_memory_array(uhdm_net)) {
        log("UHDM: Net '%s' has both packed and unpacked dimensions - creating memory\n", netname.c_str());
        
        // Get packed dimension (width) and unpacked dimension (size).
        int width = 1;
        int size = 1;
        if (uhdm_net->Typespec()) {
            auto ref_typespec = uhdm_net->Typespec();
            const UHDM::typespec* typespec = nullptr;

            if (ref_typespec && ref_typespec->Actual_typespec()) {
                typespec = ref_typespec->Actual_typespec();
            }
            if (typespec && typespec->UhdmType() == uhdmlogic_typespec) {
                auto logic_typespec = any_cast<const UHDM::logic_typespec*>(typespec);
                width = get_width_from_typespec(logic_typespec, inst);
            } else if (typespec && typespec->UhdmType() == uhdmarray_typespec) {
                // Typedef'd unpacked array (`ram16x4_t mem;`): width comes from
                // the element typespec, size from the unpacked range(s).
                auto ats = dynamic_cast<const UHDM::array_typespec*>(typespec);
                if (ats) {
                    if (auto et = ats->Elem_typespec()) {
                        if (auto a = et->Actual_typespec())
                            width = get_width_from_typespec(a, inst);
                    }
                    int range_total = 1;
                    if (ats->Ranges()) {
                        for (auto r : *ats->Ranges()) {
                            if (r->Left_expr() && r->Right_expr()) {
                                RTLIL::SigSpec lspec = import_expression(r->Left_expr());
                                RTLIL::SigSpec rspec = import_expression(r->Right_expr());
                                if (lspec.is_fully_const() && rspec.is_fully_const())
                                    range_total *= std::abs(lspec.as_int() - rspec.as_int()) + 1;
                            }
                        }
                    }
                    size = range_total;
                }
            } else {
                log_warning("UHDM: Net '%s' detected as memory but has no recognized array typespec\n", netname.c_str());
            }
        }
        
        // Create RTLIL memory object
        RTLIL::IdString mem_id = RTLIL::escape_id(netname);
        RTLIL::Memory* memory = new RTLIL::Memory;
        memory->name = mem_id;
        memory->width = width;
        memory->size = size;
        memory->start_offset = 0;
        
        // Add source attribute
        add_src_attribute(memory->attributes, uhdm_net);
        
        // Add memory to module
        module->memories[mem_id] = memory;
        
        if (mode_debug)
            log("    Created memory: %s (width=%d, size=%d)\n", mem_id.c_str(), width, size);
        
        // Don't create a wire for memory arrays
        return;
    }
    
    // Normal net - create as wire
    int width = get_width(uhdm_net, inst);
    
    // Check if this net has reversed bit ordering
    bool upto = false;
    int start_offset = 0;
    int left = -1, right = -1;
    
    // Try to get range information from the net's typespec
    if (uhdm_net->Typespec()) {
        auto ref_typespec = uhdm_net->Typespec();
        if (ref_typespec && ref_typespec->Actual_typespec()) {
            auto typespec = ref_typespec->Actual_typespec();
            if (typespec && typespec->UhdmType() == uhdmlogic_typespec) {
                auto logic_typespec = any_cast<const UHDM::logic_typespec*>(typespec);
                if (logic_typespec->Ranges() && !logic_typespec->Ranges()->empty()) {
                    // For packed multidimensional arrays (multiple ranges or Elem_typespec),
                    // the wire is flat - don't set upto/start_offset
                    bool is_packed_multidim = logic_typespec->Ranges()->size() > 1 ||
                                              logic_typespec->Elem_typespec() != nullptr;
                    if (!is_packed_multidim) {
                        auto range = (*logic_typespec->Ranges())[0];
                        if (range->Left_expr() && range->Right_expr()) {
                            RTLIL::SigSpec left_spec = import_expression(range->Left_expr());
                            RTLIL::SigSpec right_spec = import_expression(range->Right_expr());

                            if (left_spec.is_fully_const() && right_spec.is_fully_const()) {
                                left = left_spec.as_int();
                                right = right_spec.as_int();

                                // Check if range is reversed (e.g., [0:7] instead of [7:0])
                                if (left < right) {
                                    upto = true;
                                    start_offset = left;
                                    log("UHDM: Net '%s' has reversed bit ordering [%d:%d]\n", netname.c_str(), left, right);
                                } else {
                                    start_offset = right;
                                    log("UHDM: Net '%s' has normal bit ordering [%d:%d]\n", netname.c_str(), left, right);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    RTLIL::Wire* w = create_wire(netname, width, upto, start_offset);
    add_src_attribute(w->attributes, uhdm_net);
    
    // Check if net is signed
    if (auto ref_typespec = uhdm_net->Typespec()) {
        log("UHDM: Checking signed attribute for net '%s'\n", netname.c_str());
        // Check if typespec indicates signed
        bool is_signed = false;
        const UHDM::typespec* actual_typespec = nullptr;
        
        if (ref_typespec->Actual_typespec()) {
            actual_typespec = ref_typespec->Actual_typespec();
            log("UHDM: Found Actual_typespec, UhdmType=%d\n", actual_typespec->UhdmType());
        }
        
        if (actual_typespec) {
            switch (actual_typespec->UhdmType()) {
                case uhdmlogic_typespec:
                    if (auto logic_ts = dynamic_cast<const UHDM::logic_typespec*>(actual_typespec)) {
                        is_signed = logic_ts->VpiSigned();
                        log("UHDM: logic_typespec VpiSigned=%d\n", is_signed);
                    }
                    break;
                case uhdmint_typespec:
                    if (auto ts = dynamic_cast<const UHDM::int_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    log("UHDM: int_typespec VpiSigned=%d\n", is_signed);
                    break;
                case uhdminteger_typespec:
                    if (auto ts = dynamic_cast<const UHDM::integer_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    log("UHDM: integer_typespec VpiSigned=%d\n", is_signed);
                    break;
                case uhdmbyte_typespec:
                    if (auto ts = dynamic_cast<const UHDM::byte_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    log("UHDM: byte_typespec VpiSigned=%d\n", is_signed);
                    break;
                case uhdmshort_int_typespec:
                    if (auto ts = dynamic_cast<const UHDM::short_int_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    log("UHDM: short_int_typespec VpiSigned=%d\n", is_signed);
                    break;
                case uhdmlong_int_typespec:
                    if (auto ts = dynamic_cast<const UHDM::long_int_typespec*>(actual_typespec))
                        is_signed = ts->VpiSigned();
                    log("UHDM: long_int_typespec VpiSigned=%d\n", is_signed);
                    break;
                default:
                    // Other typespec types are not handled
                    log("UHDM: Unknown typespec type %d\n", actual_typespec->UhdmType());
                    break;
            }

            if (is_signed) {
                log("UHDM: Net '%s' is signed (from typespec), setting is_signed=true\n", netname.c_str());
                w->is_signed = true;
            }
        }
    }

    // Also check VpiSigned() directly on the net object itself
    // (Surelog may set signed on the net rather than the typespec)
    if (!w->is_signed && uhdm_net->VpiSigned()) {
        log("UHDM: Net '%s' is signed (from VpiSigned), setting is_signed=true\n", netname.c_str());
        w->is_signed = true;
    }
    
    // Import attributes (e.g., (* keep *), (* anyconst *))
    // SymbiYosys formal-verification attributes (`(* anyconst *)`,
    // `(* anyseq *)`, `(* allconst *)`, `(* allseq *)`) on a module-level
    // reg become attributes on the corresponding logic_net.  Lower them
    // to the matching RTLIL cell (`$anyconst`/`$anyseq`/`$allconst`/
    // `$allseq`) whose Y output drives the wire, matching what the
    // Verilog frontend does for `$anyconst()` & friends.  Without this,
    // the attribute lives only as metadata on the wire and the wire stays
    // undriven, so `opt` constant-folds it to `x` and all downstream
    // logic gets removed.
    bool net_has_formal_attr = false;
    if (auto net = any_cast<const UHDM::net*>(uhdm_net)) {
        if (net->Attributes()) {
            std::string formal_cell;
            for (auto attr : *net->Attributes()) {
                std::string n = std::string(attr->VpiName());
                if (n == "anyconst" || n == "anyseq" ||
                    n == "allconst" || n == "allseq") {
                    formal_cell = "$" + n;
                    net_has_formal_attr = true;
                    break;
                }
            }
            for (auto attr : *net->Attributes()) {
                std::string attr_name = std::string(attr->VpiName());
                if (attr_name.empty()) continue;
                if (net_has_formal_attr &&
                    (attr_name == "anyconst" || attr_name == "anyseq" ||
                     attr_name == "allconst" || attr_name == "allseq"))
                    continue;
                // Set the attribute to 1 (standard practice for boolean attributes like keep)
                w->attributes[RTLIL::escape_id(attr_name)] = RTLIL::Const(1);
                if (mode_debug)
                    log("UHDM: Added attribute '%s' to net '%s'\n", attr_name.c_str(), netname.c_str());
            }
            if (!formal_cell.empty()) {
                std::string cell_name = formal_cell + "$" +
                                        std::to_string(autoidx++);
                RTLIL::Cell* cell = module->addCell(
                    RTLIL::escape_id(cell_name),
                    RTLIL::escape_id(formal_cell));
                cell->setParam(ID::WIDTH, RTLIL::Const(w->width));
                cell->setPort(ID::Y, RTLIL::SigSpec(w));
                add_src_attribute(cell->attributes, uhdm_net);
                // Yosys's Verilog frontend tags the cell with
                // `(* reg = "<varname>" *)` so the synthesized netlist
                // remembers the originating register.
                cell->attributes[RTLIL::escape_id("reg")] =
                    RTLIL::Const(netname);
                if (mode_debug)
                    log("UHDM: Created %s cell '%s' driving net '%s' (WIDTH=%d)\n",
                        formal_cell.c_str(), cell_name.c_str(),
                        netname.c_str(), w->width);
            }
        }
    }
    
    // Add wiretype attribute for struct types
    log("UHDM: Checking for struct type on net '%s' (UhdmType=%d)\n", netname.c_str(), uhdm_net->UhdmType());
    
    // Check if net has a typespec (works for both logic_net and regular net)
    const ref_typespec* ref_ts = nullptr;
    
    if (uhdm_net->UhdmType() == uhdmlogic_net) {
        auto logic_net = any_cast<const UHDM::logic_net*>(uhdm_net);
        ref_ts = logic_net->Typespec();
        log("UHDM: Net is a logic_net\n");
    } else if (uhdm_net->Typespec()) {
        // Regular net with typespec
        ref_ts = uhdm_net->Typespec();
        log("UHDM: Net has typespec\n");
    }
    
    if (ref_ts) {
        log("UHDM: Found ref_typespec for net '%s'\n", netname.c_str());
        if (auto actual_typespec = ref_ts->Actual_typespec()) {
            log("UHDM: Found actual_typespec (UhdmType=%d) for net '%s'\n", actual_typespec->UhdmType(), netname.c_str());
            if (actual_typespec->UhdmType() == uhdmstruct_typespec) {
                log("UHDM: typespec is a struct_typespec\n");
                // Get the struct type name
                std::string type_name;
                if (!ref_ts->VpiName().empty()) {
                    type_name = ref_ts->VpiName();
                } else if (!actual_typespec->VpiName().empty()) {
                    type_name = actual_typespec->VpiName();
                }
                
                if (!type_name.empty()) {
                    w->attributes[RTLIL::escape_id("wiretype")] = RTLIL::escape_id(type_name);
                    log("UHDM: Added wiretype attribute '\\%s' to wire '%s'\n", type_name.c_str(), w->name.c_str());
                } else {
                    log("UHDM: Could not get type name for struct\n");
                }
            } else if (actual_typespec->UhdmType() == uhdmunion_typespec) {
                log("UHDM: typespec is a union_typespec\n");
                std::string type_name;
                if (!ref_ts->VpiName().empty())
                    type_name = std::string(ref_ts->VpiName());
                else if (!actual_typespec->VpiName().empty())
                    type_name = std::string(actual_typespec->VpiName());
                if (!type_name.empty()) {
                    w->attributes[RTLIL::escape_id("wiretype")] = RTLIL::escape_id(type_name);
                    log("UHDM: Added wiretype attribute '\\%s' to wire '%s'\n", type_name.c_str(), w->name.c_str());
                }
            } else if (actual_typespec->UhdmType() == uhdmlogic_typespec) {
                // For typedef'd logic types (e.g. "typedef logic [3:0] typename"),
                // the logic_typespec has a non-empty VpiName. Set wiretype attribute.
                auto logic_ts = dynamic_cast<const UHDM::logic_typespec*>(actual_typespec);
                if (logic_ts && !logic_ts->VpiName().empty()) {
                    std::string type_name = std::string(logic_ts->VpiName());
                    w->attributes[RTLIL::escape_id("wiretype")] = RTLIL::escape_id(type_name);
                    log("UHDM: Added wiretype attribute '\\%s' to logic net '%s'\n", type_name.c_str(), w->name.c_str());
                }
            } else if (actual_typespec->UhdmType() == uhdmenum_typespec) {
                log("UHDM: typespec is an enum_typespec\n");
                // Handle enum type attributes
                const UHDM::enum_typespec* enum_ts = any_cast<const UHDM::enum_typespec*>(actual_typespec);

                // Add wiretype attribute with the enum type name
                std::string type_name;
                if (!ref_ts->VpiName().empty()) {
                    type_name = ref_ts->VpiName();
                } else if (!enum_ts->VpiName().empty()) {
                    type_name = enum_ts->VpiName();
                }

                if (!type_name.empty()) {
                    w->attributes[RTLIL::escape_id("wiretype")] = RTLIL::escape_id(type_name);
                    log("UHDM: Added wiretype attribute '\\%s' to wire '%s'\n", type_name.c_str(), w->name.c_str());
                }
                
                // Add enum_type attribute (usually $enum0, $enum1, etc.)
                // For simplicity, we'll use a generated name based on the type name
                std::string enum_type_id = "$enum_" + type_name;
                w->attributes[RTLIL::escape_id("enum_type")] = RTLIL::Const(enum_type_id);
                
                // Add enum value attributes
                if (enum_ts->Enum_consts()) {
                    for (auto enum_const : *enum_ts->Enum_consts()) {
                        std::string const_name = std::string(enum_const->VpiName());
                        std::string const_value = std::string(enum_const->VpiValue());
                        
                        // Convert value to binary representation for attribute
                        int value = parse_vpi_value_to_int(const_value);
                        int width = get_width(uhdm_net, inst);
                        RTLIL::Const binary_val(value, width);
                        
                        // Create attribute name like enum_value_00, enum_value_01, etc.
                        std::string attr_name = "enum_value_";
                        for (int i = width - 1; i >= 0; i--) {
                            attr_name += (binary_val[i] == RTLIL::State::S1) ? '1' : '0';
                        }
                        
                        // Set the attribute value to the enum constant name
                        w->attributes[RTLIL::escape_id(attr_name)] = RTLIL::Const("\\" + const_name);
                        log("UHDM: Added enum attribute %s = \\%s to wire '%s'\n", 
                            attr_name.c_str(), const_name.c_str(), w->name.c_str());
                    }
                }
            }
        }
    }
    
    // Handle net type
    int net_type = uhdm_net->VpiNetType();
    if (net_type == vpiReg) {
        // Yosys's Verilog frontend doesn't set `\reg` on register-typed
        // wires (it tags the driving cell with `(* reg = "<name>" *)`
        // instead).  Carrying a `\reg 1` attribute here makes some
        // downstream passes (notably `async2sync`) treat the wire
        // differently from gold, producing divergent equivalence
        // checks.  We retain the bookkeeping for instance-output-
        // driven and formal-attribute nets (where the original logic
        // explicitly opted out) but no longer add the attribute for
        // ordinary regs.
        (void)instance_output_driven_nets;
        (void)net_has_formal_attr;
    } else if (net_type == vpiWand) {
        w->set_bool_attribute(ID::wand);
    } else if (net_type == vpiWor) {
        w->set_bool_attribute(ID::wor);
    }
    
    // Store in maps
    wire_map[uhdm_net] = w;
    name_map[netname] = w;
}

// Import a continuous assignment
void UhdmImporter::import_continuous_assign(const cont_assign* uhdm_assign) {
    if (mode_debug)
        log("  Importing continuous assignment\n");
    
    // Check if this is a net declaration assignment (initialization)
    bool is_net_decl_assign = uhdm_assign->VpiNetDeclAssign();
    
    const expr* lhs_expr = uhdm_assign->Lhs();
    const expr* rhs_expr = uhdm_assign->Rhs();
    
    if (mode_debug && lhs_expr) {
        log("  LHS type: %s, VpiType: %d, NetDeclAssign: %d\n", 
            UHDM::UhdmName(lhs_expr->UhdmType()).c_str(), 
            lhs_expr->VpiType(),
            is_net_decl_assign);
    }
    
    // Log the current generate scope before importing expressions
    std::string current_gen_scope = get_current_gen_scope();
    if (!current_gen_scope.empty()) {
        log("    Importing cont_assign in generate scope: %s\n", current_gen_scope.c_str());
    }
    
    // Skip spurious continuous assignments from generate block wire initializations
    // These show up as assignments to module-level wires with '1 value
    if (lhs_expr && lhs_expr->UhdmType() == uhdmlogic_net &&
        rhs_expr && rhs_expr->UhdmType() == uhdmconstant) {
        const logic_net* net = any_cast<const logic_net*>(lhs_expr);
        const constant* konst = any_cast<const constant*>(rhs_expr);
        std::string net_name = std::string(net->VpiName());
        std::string rhs_val = std::string(konst->VpiValue());

        // Skip if this looks like a generate block initialization ('1)
        if (net_name == "x" && (rhs_val == "BIN:1" || rhs_val == "'1")) {
            log("  Skipping spurious assignment: %s = %s (from generate block)\n",
                net_name.c_str(), rhs_val.c_str());
            return;
        }
    }

    // Net-decl-assign on an unpacked array of structs with an
    // assignment-pattern RHS:
    //   `tl_h2d_t a[1:0] = '{8'h12, 8'h34};`
    // Surelog emits this as a `cont_assign` whose LHS is a single
    // `struct_net` named after the array and whose RHS is a
    // `vpiAssignmentPatternOp` with one operand per element.  The
    // import_expression LHS path then returns either empty or the
    // first element wire — neither of which writes the rest of the
    // array.  Drive each per-element wire directly here so reads of
    // `a[i].field` resolve to the right constant.  SV pattern order:
    // first operand drives the HIGH index, last operand the LOW.
    if (is_net_decl_assign && lhs_expr &&
        lhs_expr->UhdmType() == uhdmstruct_net &&
        rhs_expr && rhs_expr->UhdmType() == uhdmoperation) {
        auto op = any_cast<const UHDM::operation*>(rhs_expr);
        if (op && op->VpiOpType() == vpiAssignmentPatternOp && op->Operands()) {
            std::string nm = std::string(lhs_expr->VpiName());
            // Find the per-element wires created earlier.
            std::vector<RTLIL::Wire*> elems;
            int max_count = (int)op->Operands()->size();
            // Find contiguous `nm[i]` wires for any base index.
            // Try indices 0..N-1, then 1..N to cover [N-1:0] and [N:1].
            for (int base : {0, 1}) {
                std::vector<RTLIL::Wire*> tmp;
                for (int i = 0; i < max_count; i++) {
                    std::string en = nm + "[" + std::to_string(base + i) + "]";
                    if (auto w = module->wire(RTLIL::escape_id(en)))
                        tmp.push_back(w);
                    else
                        break;
                }
                if ((int)tmp.size() == max_count) { elems = tmp; break; }
            }
            if ((int)elems.size() == max_count) {
                int op_idx = 0;
                for (auto cell_any : *op->Operands()) {
                    if (auto ce = dynamic_cast<const UHDM::expr*>(cell_any)) {
                        RTLIL::SigSpec cs = import_expression(ce);
                        if (!cs.is_fully_const()) { op_idx++; continue; }
                        // First operand → HIGH index.
                        int wi = (max_count - 1) - op_idx;
                        if (wi < 0 || wi >= max_count) { op_idx++; continue; }
                        int elem_w = elems[wi]->width;
                        if (cs.size() < elem_w) cs.extend_u0(elem_w);
                        else if (cs.size() > elem_w) cs = cs.extract(0, elem_w);
                        module->connect(RTLIL::SigSpec(elems[wi]), cs);
                        if (mode_debug)
                            log("  Net-decl-assign array init: %s ← const\n",
                                elems[wi]->name.c_str());
                    }
                    op_idx++;
                }
                return;
            }
        }
    }
    
    log("  About to import LHS expression (type=%d, UhdmType=%s)\n", 
        lhs_expr ? lhs_expr->VpiType() : -1,
        lhs_expr ? UHDM::UhdmName(lhs_expr->UhdmType()).c_str() : "null");
    RTLIL::SigSpec lhs = import_expression(lhs_expr);
    // A single packed `struct_net` LHS (e.g. `my_struct s = '{word:125}`) is not
    // resolved by import_expression (only the unpacked array-of-structs path
    // above handles struct_net) — fall back to the same-named module wire so the
    // initializer actually drives it (PatternStruct).
    if (lhs.empty() && lhs_expr && lhs_expr->UhdmType() == uhdmstruct_net) {
        if (RTLIL::Wire *w = module->wire(RTLIL::escape_id(std::string(lhs_expr->VpiName()))))
            lhs = RTLIL::SigSpec(w);
    }
    // Set context width from LHS so arithmetic operations produce correctly-sized results
    // Per Verilog semantics, LHS width propagates into RHS expression evaluation
    expression_context_width = lhs.size();
    RTLIL::SigSpec rhs = import_expression(rhs_expr);
    expression_context_width = 0;
    
    log("  Continuous assignment: LHS size=%d, RHS size=%d, is_net_decl=%d\n", 
        lhs.size(), rhs.size(), is_net_decl_assign);
    if (lhs.size() > 0) {
        log("    LHS signal: %s\n", log_signal(lhs));
        // Check if this is a hierarchical assignment to blk[0].sub.x
        if (lhs_expr && lhs_expr->UhdmType() == uhdmhier_path) {
            const hier_path* hp = any_cast<const hier_path*>(lhs_expr);
            std::string path_name = std::string(hp->VpiName());
            log("    LHS is hier_path: %s\n", path_name.c_str());
        }
    }
    if (rhs.size() > 0 && rhs.is_fully_const()) {
        log("    RHS constant: %s\n", rhs.as_const().as_string().c_str());
    }
    
    // Debug: Check for empty signals
    if (lhs.size() == 0) {
        log_warning("Empty LHS in continuous assignment (generate scope: %s)\n", current_gen_scope.c_str());
        if (lhs_expr) {
            log_warning("  LHS expr type: %s (VpiType=%d)\n", 
                UHDM::UhdmName(lhs_expr->UhdmType()).c_str(), lhs_expr->VpiType());
        }
    }
    if (rhs.size() == 0) {
        log_warning("Empty RHS in continuous assignment (generate scope: %s)\n", current_gen_scope.c_str());
        if (rhs_expr) {
            log_warning("  RHS expr type: %s\n", UHDM::UhdmName(rhs_expr->UhdmType()).c_str());
        }
    }
    
    // Handle size mismatch
    if (lhs.size() != rhs.size()) {
        if (rhs.size() == 1) {
            // Extend single bit to match LHS width by replicating the bit
            // This handles unbased unsized literals like 'x, 'z, '0, '1 correctly
            if (rhs.is_fully_const()) {
                RTLIL::State bit_val = rhs.as_const()[0];
                rhs = RTLIL::SigSpec(RTLIL::Const(bit_val, lhs.size()));
            } else if (rhs.is_wire() && rhs.as_wire()->is_signed) {
                // Non-constant single SIGNED bit: sign-extend by replicating
                // the bit (`wire signed inp` → `xn = {inp,inp,...}`).  Without
                // this it was zero-extended (SignedWire).
                rhs = RTLIL::SigSpec(rhs[0], lhs.size());
            } else {
                // For non-constant single bits, zero-extend (zeros in MSB, value in LSB)
                rhs = {RTLIL::SigSpec(RTLIL::State::S0, lhs.size() - 1), rhs};
            }
        } else if (rhs.size() < lhs.size()) {
            // Extend RHS to match LHS width; sign-extend if the RHS wire is signed
            log_debug("Extending RHS from %d to %d bits\n", rhs.size(), lhs.size());
            bool rhs_is_signed = rhs.is_wire() && rhs.as_wire()->is_signed;
            RTLIL::SigSpec extended = module->addWire(NEW_ID, lhs.size());
            module->addPos(NEW_ID, rhs, extended, rhs_is_signed);
            rhs = extended;
        } else {
            // Truncate RHS to match LHS width
            log_debug("Truncating RHS from %d to %d bits\n", rhs.size(), lhs.size());
            rhs = rhs.extract(0, lhs.size());
        }
    }
    
    if (is_net_decl_assign) {
        // Check if the RHS is a constant expression
        bool is_constant = rhs.is_fully_const();

        // SystemVerilog port default value: `input [3:0] delta = 10`.
        // Surelog emits this as a cont_assign with vpiNetDeclAssign:1 driving
        // the input port's wire to a constant inside the module body.  For
        // each instantiation that *does* connect the port, the constant must
        // not actually drive the wire (the parent's connection should win),
        // so we mirror what the Verilog frontend does: tag the input wire
        // with the `\defaultvalue` attribute and skip emitting any driver.
        // Yosys's hierarchy pass then substitutes the default at instance
        // sites whose port is left unconnected.
        if (is_constant && lhs.is_wire() && lhs.as_wire()->port_input) {
            RTLIL::Wire *w = lhs.as_wire();
            w->attributes[ID::defaultvalue] = rhs.as_const();
            if (mode_debug)
                log("  Set \\defaultvalue on input port '%s'\n", w->name.c_str());
            return;
        }

        // In a generate scope, a constant net declaration assignment (e.g. `reg x = -1`)
        // has no FF driver — the net is effectively a constant wire.  Use module->connect
        // so that constant propagation (opt_expr) can fold it away.
        // Outside generate scopes, use \init to avoid clobbering FF outputs (e.g. a reg
        // driven by an always @(posedge clk) block whose initial value is set by the decl).
        bool in_gen_scope = !gen_scope_stack.empty();

        if (is_constant && in_gen_scope) {
            // Gen-scope net decl with constant RHS — treat as a plain constant driver
            module->connect(lhs, rhs);
            if (mode_debug)
                log("  Created constant driver for gen-scope net declaration '%s'\n",
                    lhs.is_wire() ? lhs.as_wire()->name.c_str() : "?");
        } else if (is_constant) {
            // For reg/logic net declaration initializers (e.g. `reg x = -1`),
            // create a `sync always` process — exactly as the Verilog frontend
            // does for `reg x = val` with no always block.  This makes the
            // signal continuously available with its initial value for formal
            // verification and simulation.  We also set the \init attribute
            // so that FF synthesis tools see the correct reset value if this
            // net is also driven by an always @(posedge clk) block.
            if (lhs.is_wire()) {
                RTLIL::Wire *w = lhs.as_wire();
                w->attributes[ID::init] = rhs.as_const();
            }
            {
                RTLIL::Process *proc = module->addProcess(NEW_ID);
                add_src_attribute(proc->attributes, uhdm_assign);
                RTLIL::SyncRule *sync_always = new RTLIL::SyncRule();
                sync_always->type = RTLIL::SyncType::STa;
                sync_always->actions.push_back(RTLIL::SigSig(lhs, rhs));
                proc->syncs.push_back(sync_always);
                if (mode_debug)
                    log("  Created sync-always process for module-level net declaration '%s'\n",
                        lhs.is_wire() ? lhs.as_wire()->name.c_str() : "?");
            }
        } else {
            // Non-constant expression in net declaration, treat as continuous assignment
            module->connect(lhs, rhs);

            if (mode_debug)
                log("  Created continuous assignment for net declaration with non-constant expression\n");
        }
    } else {
        // Regular continuous assignment
        module->connect(lhs, rhs);
    }
}

// Import a parameter
void UhdmImporter::import_parameter(const any* uhdm_param) {
    if (!uhdm_param) return;
    
    std::string param_name = std::string(uhdm_param->VpiName());
    
    if (param_name.empty()) {
        log_warning("UHDM: Parameter has empty name, skipping\n");
        return;
    }
    
    if (mode_debug)
        log("  Importing parameter: %s\n", param_name.c_str());
    
    // Get the parameter value
    RTLIL::Const param_value;
    bool has_value = false;
    
    // Try to cast to parameter object
    if (auto param_obj = dynamic_cast<const UHDM::parameter*>(uhdm_param)) {
        // Check if parameter has an expression (its value)
        if (auto expr = param_obj->Expr()) {
            RTLIL::SigSpec value_spec = import_expression(expr);
            if (value_spec.is_fully_const()) {
                param_value = value_spec.as_const();
                has_value = true;
                log("UHDM: Parameter '%s' has value: %s\n", param_name.c_str(), 
                    param_value.as_string().c_str());
            } else {
                log_warning("UHDM: Parameter '%s' has non-constant value, defaulting to 0\n", 
                           param_name.c_str());
                param_value = RTLIL::Const(0, 32);
                has_value = true;
            }
        } else {
            log("UHDM: Parameter '%s' has no expression, defaulting to 0\n", param_name.c_str());
            param_value = RTLIL::Const(0, 32);
            has_value = true;
        }
    }
    
    if (has_value) {
        // Add parameter to module
        RTLIL::IdString param_id = RTLIL::escape_id(param_name);
        // Only make non-localparam parameters externally visible
        if (auto param_obj_check = dynamic_cast<const UHDM::parameter*>(uhdm_param)) {
            if (!param_obj_check->VpiLocalParam()) {
                module->avail_parameters(param_id);
            }
        } else {
            module->avail_parameters(param_id);
        }
        module->parameter_default_values[param_id] = param_value;

        // Log successful parameter import
        log("UHDM: Added parameter '%s' to module with value %s\n",
            param_name.c_str(), param_value.as_string().c_str());
    }
}

// Import a module instance
void UhdmImporter::import_instance(const module_inst* uhdm_inst) {
    log("UHDM: import_instance called for '%s' of type '%s'\n", 
        std::string(uhdm_inst->VpiName()).c_str(), 
        std::string(uhdm_inst->VpiDefName()).c_str());
    
    // Get the instance name - use full name if available for hierarchical names
    std::string inst_name;
    std::string full_name = std::string(uhdm_inst->VpiFullName());
    
    if (!full_name.empty()) {
        // Extract the hierarchical name relative to the current module
        // E.g., from "work@generate_test.gen_units[0].even_unit.adder_inst"
        // we want "gen_units[0].even_unit.adder_inst"
        
        // Find the module name in the full path
        std::string module_prefix = "work@" + module->name.substr(1); // Remove leading backslash
        size_t module_pos = full_name.find(module_prefix);
        
        if (module_pos != std::string::npos) {
            // Skip past module name and the dot
            size_t start_pos = module_pos + module_prefix.length();
            if (start_pos < full_name.length() && full_name[start_pos] == '.') {
                start_pos++;
            }
            inst_name = full_name.substr(start_pos);
        } else {
            // The RTLIL module name (possibly parameterized like $paramod\...) doesn't
            // appear verbatim in the UHDM full path.  Try stripping the current
            // elaborated-instance prefix (e.g. "work@Top.gen[0].adder") which is
            // always an ancestor of this child's full path.
            bool extracted = false;
            if (current_instance) {
                std::string ci_fullname = std::string(current_instance->VpiFullName());
                if (!ci_fullname.empty() && full_name.find(ci_fullname) == 0) {
                    size_t start_pos = ci_fullname.size();
                    if (start_pos < full_name.size() && full_name[start_pos] == '.') {
                        start_pos++;
                    }
                    inst_name = full_name.substr(start_pos);
                    extracted = true;
                }
            }
            if (!extracted) {
                // Last resort: prepend any active generate-scope path to VpiName()
                std::string gen_scope = get_current_gen_scope();
                inst_name = std::string(uhdm_inst->VpiName());
                if (!gen_scope.empty()) {
                    inst_name = gen_scope + "." + inst_name;
                }
            }
        }
    } else {
        inst_name = std::string(uhdm_inst->VpiName());
    }
    
    std::string base_module_name = std::string(uhdm_inst->VpiDefName());
    
    // Strip work@ prefix if present
    if (base_module_name.find("work@") == 0) {
        base_module_name = base_module_name.substr(5);
    }
    
    // Build parameterized module name using VpiValue format (matching import_module naming)
    std::string module_name = base_module_name;
    bool has_params = false;
    if (uhdm_inst->Param_assigns()) {
        std::string param_string;
        for (auto param : *uhdm_inst->Param_assigns()) {
            // Skip localparams - they can't be overridden
            if (auto lhs_param = dynamic_cast<const parameter*>(param->Lhs())) {
                if (lhs_param->VpiLocalParam()) continue;
            }
            std::string param_name = std::string(param->Lhs()->VpiName());

            if (auto rhs = param->Rhs()) {
                if (auto const_val = dynamic_cast<const constant*>(rhs)) {
                    std::string val_str = std::string(const_val->VpiValue());

                    // Parse value from format like "UINT:5", "INT:5"
                    size_t colon_pos = val_str.find(':');
                    std::string value_type = "";
                    if (colon_pos != std::string::npos) {
                        value_type = val_str.substr(0, colon_pos);
                        val_str = val_str.substr(colon_pos + 1);
                    }

                    if (!val_str.empty() && value_type != "STRING") {
                        param_string += "\\" + param_name + "=s32'";
                        // Determine numeric base from type prefix
                        int base = 10;
                        if (value_type == "BIN") base = 2;
                        else if (value_type == "HEX") base = 16;
                        try {
                            int val = std::stoi(val_str, nullptr, base);
                            for (int i = 31; i >= 0; i--) {
                                param_string += ((val >> i) & 1) ? "1" : "0";
                            }
                        } catch (const std::exception& e) {
                            param_string += "00000000000000000000000000000000";
                        }
                        has_params = true;
                    }
                }
            }
        }
        if (has_params) {
            module_name = "$paramod\\" + base_module_name + param_string;
        }
    }
    
    // Check if the module definition has interface ports
    // We need to look at the module being instantiated to see if it uses interfaces
    bool has_interface_ports = false;
    if (uhdm_design && uhdm_design->AllModules()) {
        for (const module_inst* mod_def : *uhdm_design->AllModules()) {
            std::string def_name = std::string(mod_def->VpiDefName());
            if (def_name.find("work@") == 0) {
                def_name = def_name.substr(5);
            }
            if (def_name == base_module_name) {
                has_interface_ports = module_has_interface_ports(mod_def);
                break;
            }
        }
    }
    
    // If the module has interface ports, add the interfaces_replaced_in_module attribute
    // but don't modify the module name
    if (has_interface_ports) {
        // We'll add the attribute later when creating the module
    }
    
    if (mode_debug)
        log("  Importing instance: %s of %s\n", inst_name.c_str(), module_name.c_str());
    
    // Check if the module definition exists
    RTLIL::IdString module_id = RTLIL::escape_id(module_name);
    if (!design->module(module_id)) {
        // Module doesn't exist - import it using the elaborated UHDM instance
        // which has parameter-resolved port widths and fully elaborated generate scopes
        log("UHDM: Module %s doesn't exist, importing from elaborated instance\n", module_name.c_str());

        // Save current module context
        RTLIL::Module* saved_module = module;
        const module_inst* saved_instance = current_instance;
        auto saved_wire_map = wire_map;
        auto saved_name_map = name_map;
        auto saved_net_map = net_map;
        auto saved_gen_scope_stack = gen_scope_stack;
        auto saved_initial_signal_assignments = initial_signal_assignments;

        // Clear maps/state before importing child module body — the child
        // module is its own scope, so the parent's gen_scope_stack must not
        // leak in (otherwise inner wires would be named with the parent's
        // generate-scope prefix, e.g., \foo.bar[0].a instead of \bar[0].a).
        wire_map.clear();
        name_map.clear();
        net_map.clear();
        gen_scope_stack.clear();

        // Import the elaborated instance as a module
        // import_module() will build the correct parameterized name,
        // import ports with resolved widths, and import generate scopes
        import_module(uhdm_inst);

        // Restore context
        module = saved_module;
        current_instance = saved_instance;
        wire_map = saved_wire_map;
        name_map = saved_name_map;
        net_map = saved_net_map;
        gen_scope_stack = saved_gen_scope_stack;
        initial_signal_assignments = saved_initial_signal_assignments;

        // Also import the base (non-parameterized) module if it doesn't exist
        RTLIL::IdString base_module_id = RTLIL::escape_id(base_module_name);
        if (!design->module(base_module_id)) {
            if (uhdm_design && uhdm_design->AllModules()) {
                for (const module_inst* mod_def : *uhdm_design->AllModules()) {
                    std::string def_name = std::string(mod_def->VpiDefName());
                    if (def_name.find("work@") == 0) {
                        def_name = def_name.substr(5);
                    }
                    if (def_name == base_module_name) {
                        RTLIL::Module* saved_module2 = module;
                        const module_inst* saved_instance2 = current_instance;
                        auto saved_wire_map2 = wire_map;
                        auto saved_name_map2 = name_map;
                        auto saved_net_map2 = net_map;
                        auto saved_gen_scope_stack2 = gen_scope_stack;
                        auto saved_initial2 = initial_signal_assignments;

                        wire_map.clear();
                        name_map.clear();
                        net_map.clear();
                        gen_scope_stack.clear();

                        import_module(mod_def);

                        module = saved_module2;
                        current_instance = saved_instance2;
                        wire_map = saved_wire_map2;
                        name_map = saved_name_map2;
                        net_map = saved_net_map2;
                        gen_scope_stack = saved_gen_scope_stack2;
                        initial_signal_assignments = saved_initial2;
                        break;
                    }
                }
            }
        }
    }
    
    log("UHDM: Creating cell '%s' of type '%s'\n", inst_name.c_str(), module_id.c_str());
    RTLIL::Cell* cell = module->addCell(new_id(inst_name), module_id);
    
    // Add source attribute to cell
    add_src_attribute(cell->attributes, uhdm_inst);
    
    // Import port connections
    if (uhdm_inst->Ports()) {
        log("UHDM: Processing %d ports for instance\n", (int)uhdm_inst->Ports()->size());
        int positional_port_idx = 0;
        for (auto port : *uhdm_inst->Ports()) {
            std::string port_name = std::string(port->VpiName());
            // Blackbox cells with positional args (e.g.
            // `unknown u(~i, w);` in yosys/tests/various/abc9.v
            // module abc9_test028) get ports with empty VpiName.
            // Yosys's IdString machinery asserts on empty names, so
            // fall back to `$<index>` (the Verilog frontend's own
            // positional-port convention).
            positional_port_idx++;
            if (port_name.empty()) {
                port_name = "$" + std::to_string(positional_port_idx);
            }
            
            // Get the actual connection (high_conn)
            if (port->High_conn()) {
                const any* high_conn = port->High_conn();
                log("    Port %s has High_conn of type %s\n", port_name.c_str(), UhdmName(high_conn->UhdmType()).c_str());
                
                // Check if this is an interface connection
                if (high_conn->UhdmType() == uhdmref_obj) {
                    const ref_obj* ref = any_cast<const ref_obj*>(high_conn);
                    const any* actual = ref->Actual_group();
                    
                    if (actual && actual->UhdmType() == uhdminterface_inst) {
                        const interface_inst* iface = any_cast<const interface_inst*>(actual);
                        std::string iface_name = std::string(iface->VpiName());
                        log("    Port %s is connected to interface %s\n", port_name.c_str(), iface_name.c_str());
                        
                        // For interface connections, we need to expand the interface signals
                        // and connect them individually as bus.a, bus.b, bus.c
                        if (iface->Variables()) {
                            for (auto var : *iface->Variables()) {
                                std::string var_name = std::string(var->VpiName());
                                std::string full_signal_name = iface_name + "." + var_name;
                                std::string port_signal_name = port_name + "." + var_name;
                                
                                if (name_map.count(full_signal_name)) {
                                    RTLIL::Wire* w = name_map[full_signal_name];
                                    cell->setPort(RTLIL::escape_id(port_signal_name), w);
                                    log("      Connected interface signal %s to port %s\n", full_signal_name.c_str(), port_signal_name.c_str());
                                }
                            }
                        }
                        continue;
                    }
                }
                
                // Try to handle as expression directly
                RTLIL::SigSpec actual_sig;
                try {
                    actual_sig = import_expression(any_cast<const expr*>(high_conn));
                } catch (...) {
                    log_warning("Failed to import port connection for %s\n", port_name.c_str());
                    actual_sig = RTLIL::SigSpec();
                }
                
                if (actual_sig.size() > 0) {
                    // Check if the target module has this port marked as an interface port
                    RTLIL::Module* target_module = design->module(cell->type);
                    if (!target_module) {
                        log("    Target module not found for cell type: %s\n", cell->type.c_str());
                    }
                    if (target_module) {
                        RTLIL::Wire* port_wire = target_module->wire(RTLIL::escape_id(port_name));
                        if (!port_wire) {
                            log("    Port wire not found for port: %s\n", port_name.c_str());
                        }
                        
                        // For signed constants connected to wider ports, create a signed
                        // intermediate wire so the hierarchy pass will sign-extend them.
                        // Unsigned constants are left as-is (hierarchy zero-extends).
                        if (actual_sig.is_fully_const()) {
                            const expr* high_conn_expr = any_cast<const expr*>(high_conn);
                            bool is_signed_const = false;
                            if (high_conn_expr && high_conn_expr->UhdmType() == uhdmconstant) {
                                if (auto ref_ts = high_conn_expr->Typespec()) {
                                    if (auto actual_ts = ref_ts->Actual_typespec()) {
                                        if (actual_ts->UhdmType() == uhdmint_typespec) {
                                            is_signed_const = true;
                                        }
                                    }
                                }
                            }
                            if (is_signed_const) {
                                RTLIL::Wire* signed_wire = module->addWire(NEW_ID, actual_sig.size());
                                signed_wire->is_signed = true;
                                module->connect(RTLIL::SigSpec(signed_wire), actual_sig);
                                actual_sig = RTLIL::SigSpec(signed_wire);
                                log("    Created signed intermediate wire for signed constant on port %s\n", port_name.c_str());
                            }
                        }
                        
                        if (port_wire && port_wire->attributes.count(RTLIL::escape_id("interface_port"))) {
                            log("    Port %s is an interface port, creating connection wire\n", port_name.c_str());
                            
                            // For interface ports, we need to create a connection wire
                            // The wire name should follow Yosys convention: $dummywireforinterface\<interface_name>
                            std::string interface_wire_name;
                            if (actual_sig.is_wire() && actual_sig.as_wire()) {
                                std::string interface_name = actual_sig.as_wire()->name.str();
                                if (interface_name[0] == '\\') {
                                    interface_name = interface_name.substr(1);
                                }
                                interface_wire_name = "$dummywireforinterface\\" + interface_name;
                            } else {
                                // Fallback: use instance name + port name
                                interface_wire_name = "$dummywireforinterface\\" + inst_name + "_" + port_name;
                            }
                            
                            // Create or get the interface connection wire
                            RTLIL::Wire* conn_wire = module->wire(RTLIL::escape_id(interface_wire_name));
                            if (!conn_wire) {
                                conn_wire = module->addWire(RTLIL::escape_id(interface_wire_name), 1);
                                conn_wire->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
                                log("    Created interface connection wire: %s\n", interface_wire_name.c_str());
                            }
                            
                            // Connect the cell port to this wire
                            cell->setPort(RTLIL::escape_id(port_name), conn_wire);
                            continue;
                        }
                    }
                    cell->setPort(RTLIL::escape_id(port_name), actual_sig);
                } else {
                    log_warning("Port %s has empty connection\n", port_name.c_str());
                }
                
                log("    Connected port %s to signal of width %d\n", port_name.c_str(), actual_sig.size());
            } else {
                log("    Port %s has no connection (High_conn)\n", port_name.c_str());
            }
        }
    } else {
        log("UHDM: No ports found for instance\n");
    }
    
    // Set parameters on the cell
    //for (const auto& [pname, pval] : params) {
    //    cell->setParam(RTLIL::escape_id(pname), pval);
    //}
}

// Create a wire with the given name and width
RTLIL::Wire* UhdmImporter::create_wire(const std::string& name, int width, bool upto, int start_offset) {
    log("UHDM: Creating wire '%s' (width=%d, upto=%d, start_offset=%d, mode_keep_names=%s)\n", 
        name.c_str(), width, upto ? 1 : 0, start_offset, mode_keep_names ? "true" : "false");
    
    // First check if we already have this wire by base name
    RTLIL::IdString base_name = RTLIL::escape_id(name);
    if (module->wire(base_name)) {
        log("UHDM: Wire '%s' already exists, returning existing wire\n", base_name.c_str());
        return module->wire(base_name);
    }
    
    // Generate wire name (with uniquify if needed)
    RTLIL::IdString wire_name = new_id(name);
    
    // Double-check after name generation
    if (module->wire(wire_name)) {
        log("UHDM: Wire '%s' already exists after uniquify, returning existing wire\n", wire_name.c_str());
        return module->wire(wire_name);
    }
    
    log("UHDM: About to call module->addWire('%s', %d)\n", wire_name.c_str(), width);
    
    try {
        RTLIL::Wire* w = module->addWire(wire_name, width);
        w->upto = upto;
        w->start_offset = start_offset;
        log("UHDM: Successfully created wire '%s' (upto=%d, start_offset=%d)\n", wire_name.c_str(), w->upto ? 1 : 0, w->start_offset);
        
        // Check if this wire is being created for an interface connection
        // Interface connection wires have names like $dummywireforinterface\bus1
        std::string base_name = name;
        if (base_name.find("$dummywireforinterface\\") == 0) {
            // This is an interface connection wire
            w->attributes[RTLIL::escape_id("is_interface")] = RTLIL::Const(1);
            log("UHDM: Marked wire '%s' as interface connection\n", wire_name.c_str());
        }
        
        return w;
    } catch (const std::exception& e) {
        log_error("UHDM: Failed to create wire '%s': %s\n", wire_name.c_str(), e.what());
        return nullptr;
    }
}

// Generate a new unique ID
RTLIL::IdString UhdmImporter::new_id(const std::string& name) {
    std::string safe_name = name;
    
    // Handle empty names
    if (safe_name.empty()) {
        log_warning("UHDM: Creating ID for empty name, using default 'unnamed_object'\n");
        safe_name = "unnamed_object";
    }
    
    if (mode_keep_names) {
        return RTLIL::escape_id(safe_name);
    } else {
        return module->uniquify(RTLIL::escape_id(safe_name));
    }
}

// Get name from UHDM object
std::string UhdmImporter::get_name(const any* uhdm_obj) {
    // Simplified implementation for getting names
    return "unnamed";
}

// Returns true if the (already-resolved) actual_typespec is a signed integral
// typespec. Covers logic/bit/int/integer/shortint/longint/byte.
bool UhdmImporter::is_typespec_signed(const UHDM::any* ts) {
    if (!ts) return false;
    switch (ts->UhdmType()) {
        case uhdmlogic_typespec:
            if (auto t = dynamic_cast<const UHDM::logic_typespec*>(ts)) return t->VpiSigned();
            break;
        case uhdmint_typespec:
            if (auto t = dynamic_cast<const UHDM::int_typespec*>(ts)) return t->VpiSigned();
            break;
        case uhdminteger_typespec:
            if (auto t = dynamic_cast<const UHDM::integer_typespec*>(ts)) return t->VpiSigned();
            break;
        case uhdmshort_int_typespec:
            if (auto t = dynamic_cast<const UHDM::short_int_typespec*>(ts)) return t->VpiSigned();
            break;
        case uhdmlong_int_typespec:
            if (auto t = dynamic_cast<const UHDM::long_int_typespec*>(ts)) return t->VpiSigned();
            break;
        case uhdmbyte_typespec:
            if (auto t = dynamic_cast<const UHDM::byte_typespec*>(ts)) return t->VpiSigned();
            break;
        case uhdmbit_typespec:
            if (auto t = dynamic_cast<const UHDM::bit_typespec*>(ts)) return t->VpiSigned();
            break;
        default:
            break;
    }
    return false;
}

// Get width from UHDM object
int UhdmImporter::get_width(const any* uhdm_obj, const UHDM::scope* inst) {
    if (!uhdm_obj) {
        log("UHDM: get_width called with null object\n");
        return 1;
    }
    
    try {
        log("UHDM: get_width analyzing object type\n");
        
        // Check if it's a hier_path (hierarchical reference like in_struct.base.data)
        if (auto hier = dynamic_cast<const UHDM::hier_path*>(uhdm_obj)) {
            log("UHDM: Found hier_path object\n");
            
            // Use ExprEval to get the typespec of the hier_path
            ExprEval eval;
            bool invalidValue = false;
            
            // Get the typespec using decodeHierPath
            any* typespec_obj = eval.decodeHierPath(
                const_cast<hier_path*>(hier), 
                invalidValue, 
                inst,  // Use the instance scope
                hier,  // pexpr
                ExprEval::ReturnType::TYPESPEC,  // Get the typespec
                false     // muteError
            );
            
            if (!invalidValue && typespec_obj) {
                log("UHDM: decodeHierPath returned typespec\n");
                
                // Get the size from the typespec
                // From Surelog: eval.size(typespec, invalidValue, context, nullptr, !sizeMode)
                uint64_t size = eval.size(typespec_obj, invalidValue, inst, typespec_obj, true, false);
                if (!invalidValue && size > 0) {
                    log("UHDM: ExprEval::size returned %lu\n", (unsigned long)size);
                    return size;
                } else {
                    log("UHDM: ExprEval::size failed or returned 0\n");
                }
            } else {
                log("UHDM: decodeHierPath failed to return typespec\n");
            }
        }
        
        // Check if it's a port and try to get typespec
        if (auto port = dynamic_cast<const UHDM::port*>(uhdm_obj)) {
            log("UHDM: Found port object\n");
            if (auto typespec = port->Typespec()) {
                log("UHDM: Port has typespec, calling get_width_from_typespec\n");
                return get_width_from_typespec(typespec, inst);
            } else {
                log("UHDM: Port has no typespec\n");
            }
        }
        
        // Check if it's a net and try to get typespec
        if (auto net = dynamic_cast<const UHDM::net*>(uhdm_obj)) {
            log("UHDM: Found net object\n");
            if (auto typespec = net->Typespec()) {
                log("UHDM: Net has typespec, calling get_width_from_typespec\n");
                return get_width_from_typespec(typespec, inst);
            } else {
                log("UHDM: Net has no typespec\n");
            }
        }

        // packed_array_var may carry its dims either as Ranges()/Elements()
        // directly on the var (anonymous-struct form: `T [N-1:0][M-1:0] a`)
        // OR as a packed_array_typespec via Typespec() (typedef'd form:
        // `typedef u [0:1] yeah; yeah a;`).  Pick the direct-dims path
        // when present, otherwise fall through to the generic typespec
        // handler below.
        if (auto pav = dynamic_cast<const UHDM::packed_array_var*>(uhdm_obj)) {
            // Function-return case: `logic4 [1:0] f(...)` produces a
            // packed_array_var whose Typespec is a logic_typespec with
            // Elem_typespec (encoding the full type), but whose
            // Elements()[0] is a synthetic logic_var with no typespec of
            // its own.  The direct path below would then compute
            // elem_w=1 from that placeholder.  Prefer the typespec when
            // it already encodes everything (logic_typespec with
            // Elem_typespec, OR packed_array_typespec).
            if (auto ts = pav->Typespec()) {
                if (auto a = ts->Actual_typespec()) {
                    bool typespec_has_full_info = false;
                    if (a->UhdmType() == uhdmpacked_array_typespec) {
                        typespec_has_full_info = true;
                    } else if (a->UhdmType() == uhdmlogic_typespec) {
                        auto lt = dynamic_cast<const UHDM::logic_typespec*>(a);
                        if (lt && lt->Elem_typespec() != nullptr)
                            typespec_has_full_info = true;
                    }
                    if (typespec_has_full_info) {
                        int w = get_width_from_typespec(a, inst);
                        log("UHDM: packed_array_var width from typespec = %d\n", w);
                        return w;
                    }
                }
            }

            bool has_direct = (pav->Ranges() && !pav->Ranges()->empty()) &&
                              (pav->Elements() && !pav->Elements()->empty());
            if (has_direct) {
                log("UHDM: Found packed_array_var with direct ranges/elements\n");
                int range_total = 1;
                for (auto r : *pav->Ranges()) {
                    if (r->Left_expr() && r->Right_expr()) {
                        RTLIL::SigSpec ls = import_expression(r->Left_expr());
                        RTLIL::SigSpec rs = import_expression(r->Right_expr());
                        if (ls.is_fully_const() && rs.is_fully_const()) {
                            range_total *= std::abs(ls.as_int() - rs.as_int()) + 1;
                        }
                    }
                }
                const any* elem0 = (*pav->Elements())[0];
                int elem_width = get_width(elem0, inst);
                // Local-var case: `logic4 [1:0] x` keeps the outer
                // range on pav->Ranges() and stores just the ELEMENT
                // typespec (logic4) on pav->Typespec().  Elements()[0]
                // is a synthetic logic_var with no typespec, so the
                // recursive get_width returns 1.  Recover the real
                // element width from pav->Typespec().
                if (elem_width <= 1) {
                    if (auto ts = pav->Typespec()) {
                        if (auto a = ts->Actual_typespec()) {
                            int w = get_width_from_typespec(a, inst);
                            if (w > elem_width) elem_width = w;
                        }
                    }
                }
                int total = range_total * elem_width;
                log("UHDM: packed_array_var width = %d (ranges=%d, elem_w=%d)\n",
                    total, range_total, elem_width);
                return total;
            }
            // else: fall through to the generic `variables` Typespec path below.
        }

        // Check if it's a net and try to get typespec
        if (auto variable = dynamic_cast<const UHDM::variables*>(uhdm_obj)) {
            log("UHDM: Found net object\n");
            if (auto typespec = variable->Typespec()) {
                log("UHDM: Net has typespec, calling get_width_from_typespec\n");
                return get_width_from_typespec(typespec, inst);
            } else {
                log("UHDM: Net has no typespec\n");
            }
        }

        if (auto variable = dynamic_cast<const UHDM::io_decl*>(uhdm_obj)) {
            log("UHDM: Found net object\n");
            if (auto typespec = variable->Typespec()) {
                log("UHDM: Net has typespec, calling get_width_from_typespec\n");
                int w = get_width_from_typespec(typespec, inst);
                // Multiply by any UNPACKED array dimensions carried on the
                // io_decl itself (`logic [2:0] mat [3:0]` -> packed 3 * unpacked
                // 4 = 12) so a whole-array argument flattens to the right width
                // (SelectFromUnpackedInFunction / 2DUnpackedFunctionArgument).
                if (variable->Ranges())
                    for (auto r : *variable->Ranges()) {
                        if (!r->Left_expr() || !r->Right_expr()) continue;
                        RTLIL::SigSpec l = import_expression(r->Left_expr());
                        RTLIL::SigSpec rr = import_expression(r->Right_expr());
                        if (l.is_fully_const() && rr.is_fully_const())
                            w *= std::abs(l.as_const().as_int() - rr.as_const().as_int()) + 1;
                    }
                return w;
            } else {
                log("UHDM: Net has no typespec\n");
            }
        }
        
        log("UHDM: Object is neither port nor net, or no typespec found\n");
        
    } catch (...) {
        log("UHDM: Exception in get_width\n");
    }
    
    log("UHDM: Defaulting to width=1\n");
    return 1;
}

// Helper function to get width from typespec
int UhdmImporter::get_width_from_typespec(const UHDM::any* typespec, const UHDM::scope* inst) {
    if (!typespec) return 1;
    
    try {
        log("UHDM: Analyzing typespec for width determination\n");
        log("UHDM: Typespec UhdmType = %d\n", typespec->UhdmType());
        
        // Check if this is a ref_typespec and follow the reference
        if (typespec->UhdmType() == uhdmref_typespec) {
            log("UHDM: Found ref_typespec, following reference\n");
            if (auto ref_typespec = dynamic_cast<const UHDM::ref_typespec*>(typespec)) {
                if (auto actual = ref_typespec->Actual_typespec()) {
                    log("UHDM: Following to actual typespec (UhdmType = %s)\n", UhdmName(actual->UhdmType()).c_str());
                    // Check if the actual type is an interface
                    if (actual->UhdmType() == uhdminterface_typespec) {
                        log("UHDM: Found interface_typespec through reference\n");
                        return -1;  // Special value to indicate interface type
                    }
                    // Otherwise recurse to get the actual width
                    return get_width_from_typespec(actual, inst);
                } else {
                    // Try to resolve package type reference
                    std::string type_name = std::string(ref_typespec->VpiName());
                    log("UHDM: ref_typespec has no actual_typespec, checking package types for: %s\n", type_name.c_str());
                    
                    // Check if this is a package type reference
                    if (package_typespec_map.count(type_name)) {
                        const UHDM::typespec* pkg_typespec = package_typespec_map.at(type_name);
                        log("UHDM: Found package typespec for %s\n", type_name.c_str());
                        return get_width_from_typespec(pkg_typespec, inst);
                    }
                    
                    // Try with package:: prefix (in case of qualified name)
                    size_t colonPos = type_name.find("::");
                    if (colonPos != std::string::npos) {
                        if (package_typespec_map.count(type_name)) {
                            const UHDM::typespec* pkg_typespec = package_typespec_map.at(type_name);
                            log("UHDM: Found package typespec for qualified name %s\n", type_name.c_str());
                            return get_width_from_typespec(pkg_typespec, inst);
                        }
                    }
                }
            }
        }
        
        // Check if this is an interface typespec
        if (typespec->UhdmType() == uhdminterface_typespec) {
            log("UHDM: Found interface_typespec, interface ports don't have a simple width\n");
            // Interface ports are special - they don't have a width
            // They represent a bundle of signals
            return -1;  // Special value to indicate interface type
        }
        
        // Check if this is an enum typespec - need to get the base type
        if (typespec->UhdmType() == uhdmenum_typespec) {
            log("UHDM: Found enum_typespec, getting base type\n");
            if (auto enum_typespec = dynamic_cast<const UHDM::enum_typespec*>(typespec)) {
                // Get the base typespec - this defines the actual width
                const any* base_typespec = enum_typespec->Base_typespec();
                
                if (base_typespec) {
                    log("UHDM: Found base typespec for enum (type=%d)\n", base_typespec->UhdmType());
                    // Check if base_typespec is a ref_typespec that needs special handling
                    if (base_typespec->UhdmType() == uhdmref_typespec) {
                        auto base_ref = dynamic_cast<const UHDM::ref_typespec*>(base_typespec);
                        if (base_ref) {
                            log("UHDM: Base is a ref_typespec, name=%s\n", std::string(base_ref->VpiName()).c_str());
                            // Try to get the Actual typespec
                            if (base_ref->Actual_typespec()) {
                                log("UHDM: ref_typespec has Actual_typespec\n");
                            } else {
                                log("UHDM: ref_typespec has NO Actual_typespec\n");
                            }
                        }
                    }
                    return get_width_from_typespec(base_typespec, inst);
                } else {
                    // No explicit base type means default int type (32 bits in SystemVerilog)
                    log("UHDM: No base typespec for enum, defaulting to 32 bits\n");
                    return 32;
                }
            }
        }
        
        // For ref_typespec without Actual, don't call ExprEval::size as it may crash
        if (typespec->UhdmType() == uhdmref_typespec) {
            UHDM::decompile(typespec);
            log("UHDM: ref_typespec without actual - defaulting to width 32 (int)\n");
            return 32;
        }

        // Handle built-in integer types with known widths
        if (typespec->UhdmType() == uhdmbyte_typespec) return 8;
        if (typespec->UhdmType() == uhdmshort_int_typespec) return 16;
        if (typespec->UhdmType() == uhdmint_typespec) return 32;
        if (typespec->UhdmType() == uhdminteger_typespec) return 32;
        if (typespec->UhdmType() == uhdmlong_int_typespec) return 64;

        // Handle array_typespec (unpacked-array typedef like
        // `ptab_dat_t iP [4]`): the flat total width is
        // `element_width * product(ranges)`.  Without this case
        // `ExprEval::size()` returns only the element width, leaving
        // the flat port wire too narrow.
        if (typespec->UhdmType() == uhdmarray_typespec) {
            auto ats = dynamic_cast<const UHDM::array_typespec*>(typespec);
            if (ats) {
                int elem_width = 1;
                if (auto et = ats->Elem_typespec()) {
                    if (auto a = et->Actual_typespec())
                        elem_width = get_width_from_typespec(a, inst);
                }
                int range_total = 1;
                if (ats->Ranges()) {
                    for (auto r : *ats->Ranges()) {
                        if (r->Left_expr() && r->Right_expr()) {
                            RTLIL::SigSpec lspec = import_expression(r->Left_expr());
                            RTLIL::SigSpec rspec = import_expression(r->Right_expr());
                            if (lspec.is_fully_const() && rspec.is_fully_const()) {
                                int l = lspec.as_int();
                                int rv = rspec.as_int();
                                range_total *= std::abs(l - rv) + 1;
                            }
                        }
                    }
                }
                int total = elem_width * range_total;
                log("UHDM: array_typespec: elem_w=%d, range_total=%d, total=%d\n",
                    elem_width, range_total, total);
                return total;
            }
        }

        // Handle packed_array_typespec: width = element_width * product(ranges).
        // ExprEval::size() returns only the range count for these typespecs,
        // so it would report 2 for `u [0:1]` instead of `2 * sizeof(u)`.
        if (typespec->UhdmType() == uhdmpacked_array_typespec) {
            auto pa = dynamic_cast<const UHDM::packed_array_typespec*>(typespec);
            if (pa) {
                int elem_width = 1;
                if (auto et = pa->Elem_typespec()) {
                    if (auto a = et->Actual_typespec())
                        elem_width = get_width_from_typespec(a, inst);
                    else if (!et->VpiName().empty() &&
                             package_typespec_map.count(std::string(et->VpiName())))
                        elem_width = get_width_from_typespec(
                            package_typespec_map.at(std::string(et->VpiName())), inst);
                }
                int range_total = 1;
                if (pa->Ranges()) {
                    for (auto r : *pa->Ranges()) {
                        if (r->Left_expr() && r->Right_expr()) {
                            RTLIL::SigSpec lspec = import_expression(r->Left_expr());
                            RTLIL::SigSpec rspec = import_expression(r->Right_expr());
                            if (lspec.is_fully_const() && rspec.is_fully_const()) {
                                int l = lspec.as_int();
                                int rv = rspec.as_int();
                                range_total *= std::abs(l - rv) + 1;
                            }
                        }
                    }
                }
                int total = elem_width * range_total;
                log("UHDM: packed_array_typespec: elem_w=%d, range_total=%d, total=%d\n",
                    elem_width, range_total, total);
                return total;
            }
        }

        // Handle union_typespec: width = width of widest member
        if (typespec->UhdmType() == uhdmunion_typespec) {
            auto union_ts = dynamic_cast<const UHDM::union_typespec*>(typespec);
            if (union_ts && union_ts->Members()) {
                int max_width = 0;
                for (auto member : *union_ts->Members()) {
                    if (auto ref_ts = member->Typespec()) {
                        if (auto actual_ts = ref_ts->Actual_typespec()) {
                            int w = get_width_from_typespec(actual_ts, inst);
                            if (w > max_width) max_width = w;
                        }
                    }
                }
                if (max_width > 0) {
                    log("UHDM: union_typespec width = %d (widest member)\n", max_width);
                    return max_width;
                }
            }
        }

        // Handle struct_typespec: width = sum of member widths.  Without
        // this case `ExprEval::size()` returns the count of members (or
        // zero) instead of the total flattened bit width.  Recurses into
        // each member's typespec so nested arrays/structs are accounted
        // for (e.g. `struct { foo_t f [7]; }` is 7 * 8 = 56 bits).
        if (typespec->UhdmType() == uhdmstruct_typespec) {
            auto struct_ts = dynamic_cast<const UHDM::struct_typespec*>(typespec);
            if (struct_ts && struct_ts->Members()) {
                int total = 0;
                for (auto member : *struct_ts->Members()) {
                    if (auto ref_ts = member->Typespec()) {
                        if (auto actual_ts = ref_ts->Actual_typespec()) {
                            total += get_width_from_typespec(actual_ts, inst);
                        }
                    }
                }
                if (total > 0) {
                    log("UHDM: struct_typespec width = %d (sum of members)\n", total);
                    return total;
                }
            }
        }

        // Handle bit_typespec with Range (e.g. `bit [7:0]`): width = range size.
        if (typespec->UhdmType() == uhdmbit_typespec) {
            auto bit_ts = dynamic_cast<const UHDM::bit_typespec*>(typespec);
            if (bit_ts && bit_ts->Ranges() && !bit_ts->Ranges()->empty()) {
                int total = 1;
                for (auto r : *bit_ts->Ranges()) {
                    if (r->Left_expr() && r->Right_expr()) {
                        RTLIL::SigSpec ls = import_expression(r->Left_expr());
                        RTLIL::SigSpec rs = import_expression(r->Right_expr());
                        if (ls.is_fully_const() && rs.is_fully_const())
                            total *= std::abs(ls.as_int() - rs.as_int()) + 1;
                    }
                }
                log("UHDM: bit_typespec width = %d\n", total);
                return total;
            }
            // No range → single bit.
            return 1;
        }

        // Handle logic_typespec with a single Range and no Elem_typespec —
        // e.g. `logic [bus.DATA_WIDTH-1:0]` where the bounds are
        // expressions over interface parameters that `ExprEval::size()`
        // can't resolve from the AllModules tree.  Compute the width
        // ourselves by evaluating the Left/Right exprs (our
        // import_expression has the interface-param hier_path resolver
        // and folds the surrounding arithmetic when the module carries
        // `\dynports`).
        if (typespec->UhdmType() == uhdmlogic_typespec) {
            auto logic_ts_simple = dynamic_cast<const UHDM::logic_typespec*>(typespec);
            if (logic_ts_simple && logic_ts_simple->Elem_typespec() == nullptr &&
                logic_ts_simple->Ranges() && logic_ts_simple->Ranges()->size() == 1) {
                auto r = (*logic_ts_simple->Ranges())[0];
                if (r->Left_expr() && r->Right_expr()) {
                    bool saved_fcf = force_const_fold;
                    force_const_fold = true;
                    RTLIL::SigSpec ls = import_expression(r->Left_expr());
                    RTLIL::SigSpec rs = import_expression(r->Right_expr());
                    force_const_fold = saved_fcf;
                    if (ls.is_fully_const() && rs.is_fully_const()) {
                        int range_size = std::abs(ls.as_int() - rs.as_int()) + 1;
                        log("UHDM: logic_typespec simple range width = %d\n", range_size);
                        return range_size;
                    }
                }
            }
        }

        // Handle logic_typespec with Elem_typespec (e.g., reg8_t [0:3] → array of 8-bit elements)
        // ExprEval::size() only returns the outer range size, so we need to multiply by element width
        if (typespec->UhdmType() == uhdmlogic_typespec) {
            auto logic_ts = dynamic_cast<const UHDM::logic_typespec*>(typespec);
            if (logic_ts && logic_ts->Elem_typespec() != nullptr) {
                auto elem_ref = logic_ts->Elem_typespec();
                if (elem_ref->Actual_typespec()) {
                    auto elem_actual = elem_ref->Actual_typespec();
                    // Check if elem is itself a packed array (typedef alias case like reg2dim1_t)
                    // In that case, the range on this typespec is redundant and the elem already
                    // accounts for the full array dimensions
                    bool elem_is_packed_array = false;
                    if (elem_actual->UhdmType() == uhdmlogic_typespec) {
                        auto elem_logic = dynamic_cast<const UHDM::logic_typespec*>(elem_actual);
                        if (elem_logic && elem_logic->Elem_typespec() != nullptr) {
                            elem_is_packed_array = true;
                        }
                    }
                    if (elem_is_packed_array) {
                        // Typedef alias: elem already is the full packed array, just use its width
                        int total = get_width_from_typespec(elem_actual, inst);
                        log("UHDM: logic_typespec with packed-array Elem_typespec (typedef alias): total=%d\n", total);
                        return total;
                    }
                    int elem_width = get_width_from_typespec(elem_actual, inst);
                    if (elem_width > 0 && logic_ts->Ranges() && !logic_ts->Ranges()->empty()) {
                        auto range = (*logic_ts->Ranges())[0];
                        if (range->Left_expr() && range->Right_expr()) {
                            RTLIL::SigSpec left_spec = import_expression(range->Left_expr());
                            RTLIL::SigSpec right_spec = import_expression(range->Right_expr());
                            if (left_spec.is_fully_const() && right_spec.is_fully_const()) {
                                int l = left_spec.as_int();
                                int r = right_spec.as_int();
                                int range_size = abs(l - r) + 1;
                                int total = elem_width * range_size;
                                log("UHDM: logic_typespec with Elem_typespec: elem_width=%d, range_size=%d, total=%d\n",
                                    elem_width, range_size, total);
                                return total;
                            }
                        }
                    }
                }
            }
        }

        // Use UHDM::ExprEval to get the actual size of the typespec
        UHDM::ExprEval eval;
        bool invalidValue = false;
        
        // Call eval.size() like Surelog does
        // From Surelog: eval.size(typespec, invalidValue, context, nullptr, !sizeMode)
        uint64_t size = eval.size(typespec, invalidValue, inst, typespec, true);
        
        if (!invalidValue && size > 0) {
            log("UHDM: ExprEval returned size=%llu for typespec\n", (unsigned long long)size);
            return (int)size;
        } else {
            log("UHDM: ExprEval failed or returned invalid size, defaulting to 1\n");
        }
        
    } catch (const std::exception& e) {
        log("UHDM: Exception in get_width_from_typespec: %s\n", e.what());
    } catch (...) {
        log("UHDM: Unknown exception in get_width_from_typespec\n");
    }
    
    return 1;  // Default to 1 bit
}

// Get source attribute string from UHDM object
std::string UhdmImporter::get_src_attribute(const any* uhdm_obj) {
    if (!uhdm_obj) return "";
    
    try {
        // Get the file name
        std::string filename;
        if (!uhdm_obj->VpiFile().empty()) {
            std::string full_path = std::string(uhdm_obj->VpiFile());
            // Extract just the filename from the path
            size_t last_slash = full_path.find_last_of("/\\");
            if (last_slash != std::string::npos) {
                filename = full_path.substr(last_slash + 1);
            } else {
                filename = full_path;
            }
        } else {
            return "";  // No file info available
        }
        
        // Get line and column information
        int line = uhdm_obj->VpiLineNo();
        int col = uhdm_obj->VpiColumnNo();
        int end_line = uhdm_obj->VpiEndLineNo();
        int end_col = uhdm_obj->VpiEndColumnNo();
        
        // Format the source attribute string
        return filename + ":" + std::to_string(line) + "." + std::to_string(col) + 
               "-" + std::to_string(end_line) + "." + std::to_string(end_col);
               
    } catch (...) {
        // If UHDM API access fails, return empty string
        return "";
    }
}

// Add source attribute to RTLIL object
void UhdmImporter::add_src_attribute(dict<RTLIL::IdString, RTLIL::Const>& attributes, const any* uhdm_obj) {
    std::string src = get_src_attribute(uhdm_obj);
    if (!src.empty()) {
        attributes[ID::src] = RTLIL::Const(src);
    }
}

// Get unique cell name by checking if it already exists
RTLIL::IdString UhdmImporter::get_unique_cell_name(const std::string& base_name) {
    RTLIL::IdString cell_name = RTLIL::escape_id(base_name);
    int suffix = 1;
    while (module->cells_.count(cell_name)) {
        suffix++;
        std::string unique_name = base_name + "_" + std::to_string(suffix);
        cell_name = RTLIL::escape_id(unique_name);
    }
    return cell_name;
}

// Import generate scopes (generate blocks)
void UhdmImporter::import_generate_scopes(const module_inst* uhdm_module) {
    // Check for GenScopeArray which contains generate blocks
    if (uhdm_module->Gen_scope_arrays()) {
        log("UHDM: Found %d generate scope arrays\n", (int)uhdm_module->Gen_scope_arrays()->size());
        for (auto gen_array : *uhdm_module->Gen_scope_arrays()) {
            if (!gen_array) {
                log("UHDM: Skipping null generate scope array\n");
                continue;
            }
            // Check if VpiName() is valid before using it
            std::string_view name_view = gen_array->VpiName();
            if (name_view.empty()) {
                log("UHDM: Generate scope array has empty name, skipping\n");
                continue;
            }
            std::string gen_name = std::string(name_view);
            log("UHDM: Processing generate scope array: %s\n", gen_name.c_str());
            
            // Process each generate scope in the array
            if (gen_array->Gen_scopes()) {
                log("UHDM: Found %d generate scopes in array %s\n", (int)gen_array->Gen_scopes()->size(), gen_name.c_str());
                for (auto gen_scope : *gen_array->Gen_scopes()) {
                    if (!gen_scope) {
                        log("UHDM: Skipping null generate scope\n");
                        continue;
                    }
                    import_gen_scope(gen_scope);
                }
            } else {
                log("UHDM: No generate scopes found in array %s\n", gen_name.c_str());
            }
        }
    } else {
        log("UHDM: No generate scope arrays found in module\n");
    }
}

// Import a single generate scope
void UhdmImporter::import_gen_scope(const gen_scope* uhdm_scope) {
    if (!uhdm_scope) return;
    current_scope = uhdm_scope;
    std::string scope_name = std::string(uhdm_scope->VpiName());
    std::string full_name = std::string(uhdm_scope->VpiFullName());
    
    // If VpiName is empty, extract from full name
    if (scope_name.empty() && !full_name.empty()) {
        // Extract the part after the last dot
        size_t last_dot = full_name.rfind('.');
        if (last_dot != std::string::npos) {
            scope_name = full_name.substr(last_dot + 1);
        } else {
            // No dot found, use everything after @ if present
            size_t at_pos = full_name.rfind('@');
            if (at_pos != std::string::npos) {
                scope_name = full_name.substr(at_pos + 1);
            } else {
                scope_name = full_name;
            }
        }
    }
    
    log("UHDM: Importing generate scope: %s (full: %s)\n", scope_name.c_str(), full_name.c_str());
    
    // Push this scope onto the stack
    gen_scope_stack.push_back(scope_name);
    log("UHDM: Pushed scope '%s', stack depth: %zu, full path: %s\n", 
        scope_name.c_str(), gen_scope_stack.size(), get_current_gen_scope().c_str());
    
    // Import nets declared in the generate scope
    if (uhdm_scope->Nets()) {
        log("UHDM: Found %d nets in generate scope\n", (int)uhdm_scope->Nets()->size());
        for (auto net : *uhdm_scope->Nets()) {
            std::string net_name = std::string(net->VpiName());
            std::string full_gen_path = get_current_gen_scope();
            std::string hierarchical_name = full_gen_path + "." + net_name;
            int width = get_width(net, current_instance);
            
            // Check if we already have this wire with the hierarchical name
            if (!name_map.count(hierarchical_name)) {
                RTLIL::Wire* w = create_wire(hierarchical_name, width);
                wire_map[net] = w;
                // Map the full hierarchical name
                name_map[hierarchical_name] = w;
                log("UHDM: Created wire '%s' (width=%d) for generate scope net\n", hierarchical_name.c_str(), width);
            }
        }
    }
    
    // Import variables declared in the generate scope
    if (uhdm_scope->Variables()) {
        log("UHDM: Found %d variables in generate scope\n", (int)uhdm_scope->Variables()->size());
        for (auto var : *uhdm_scope->Variables()) {
            // Variables can be logic_var or other types, we need to handle them
            // For now, create a wire for each variable
            std::string var_name = std::string(var->VpiName());
            std::string full_gen_path = get_current_gen_scope();
            std::string hierarchical_name = full_gen_path + "." + var_name;
            int width = get_width(var, current_instance);
            
            // The wire may already exist if it was referenced (created on demand)
            // by an outer process before we got here.  In that case we still
            // need to drive its initializer expression — otherwise the wire
            // stays at X.  Look up the existing wire instead of skipping.
            RTLIL::Wire* w = nullptr;
            if (name_map.count(hierarchical_name)) {
                w = name_map[hierarchical_name];
            } else {
                w = create_wire(hierarchical_name, width);
                wire_map[var] = w;
                // Don't map simple name to avoid conflicts between generate instances
                name_map[hierarchical_name] = w;  // Map the full hierarchical name
                // Set signedness for signed variables (e.g., integer)
                if (var->VpiSigned()) {
                    w->is_signed = true;
                }
                log("UHDM: Created wire '%s' (width=%d, signed=%d) for generate scope variable\n",
                    hierarchical_name.c_str(), width, w->is_signed ? 1 : 0);
            }
            if (w) {
                // If the variable has an initializer expression, create a continuous
                // assignment to drive the wire with its initial value.
                // e.g. "integer x = -1;" → "assign \gen.x = 32'hFFFFFFFF;"
                const UHDM::expr* init_expr = var->Expr();
                if (init_expr) {
                    RTLIL::SigSpec init_val = import_expression(init_expr);
                    if (!init_val.empty()) {
                        if (init_val.size() < w->width) {
                            // Determine source signedness to choose between sign- and zero-extension
                            bool src_signed = false;
                            if (init_val.is_wire() && init_val.as_wire()->is_signed) {
                                src_signed = true;
                            } else {
                                // Check the UHDM init expression for signedness.
                                // For ref_obj: VpiSigned() on `variables` may be false even
                                // when the source is `reg signed` — Surelog records the
                                // signedness only on the typespec.  Walk to the typespec.
                                if (init_expr->UhdmType() == uhdmref_obj) {
                                    auto ref = any_cast<const UHDM::ref_obj*>(init_expr);
                                    if (ref && ref->Actual_group()) {
                                        auto* tgt_var = dynamic_cast<const UHDM::variables*>(ref->Actual_group());
                                        auto* tgt_par = dynamic_cast<const UHDM::parameter*>(ref->Actual_group());
                                        // `reg signed` lands as a logic_net (not variables) in
                                        // the elaborated model — handle it explicitly.
                                        auto* tgt_net = dynamic_cast<const UHDM::net*>(ref->Actual_group());
                                        if (tgt_var) {
                                            if (tgt_var->VpiSigned()) src_signed = true;
                                            else if (tgt_var->Typespec() && tgt_var->Typespec()->Actual_typespec())
                                                src_signed = is_typespec_signed(tgt_var->Typespec()->Actual_typespec());
                                        }
                                        if (!src_signed && tgt_par) {
                                            if (tgt_par->VpiSigned()) src_signed = true;
                                            else if (tgt_par->Typespec() && tgt_par->Typespec()->Actual_typespec())
                                                src_signed = is_typespec_signed(tgt_par->Typespec()->Actual_typespec());
                                        }
                                        if (!src_signed && tgt_net) {
                                            if (tgt_net->VpiSigned()) src_signed = true;
                                            else if (tgt_net->Typespec() && tgt_net->Typespec()->Actual_typespec())
                                                src_signed = is_typespec_signed(tgt_net->Typespec()->Actual_typespec());
                                        }
                                    }
                                } else if (init_expr->UhdmType() == uhdmfunc_call) {
                                    // Function return signedness: walk Function -> Return -> Typespec.
                                    auto fc = any_cast<const UHDM::func_call*>(init_expr);
                                    if (fc && fc->Function()) {
                                        if (fc->Function()->VpiSigned())
                                            src_signed = true;
                                        else if (auto ret = fc->Function()->Return()) {
                                            if (ret->VpiSigned()) src_signed = true;
                                            else if (ret->Typespec() && ret->Typespec()->Actual_typespec())
                                                src_signed = is_typespec_signed(ret->Typespec()->Actual_typespec());
                                        }
                                    }
                                }
                            }
                            init_val.extend_u0(w->width, src_signed || w->is_signed);
                        } else if (init_val.size() > w->width) {
                            init_val = init_val.extract(0, w->width);
                        }
                        module->connect(RTLIL::SigSpec(w), init_val);
                        log("UHDM: Added initializer assignment for '%s'\n", hierarchical_name.c_str());
                    }
                }
            }
        }
    }
    
    // Import module instances within the generate scope
    if (uhdm_scope->Modules()) {
        log("UHDM: Found %d module instances in generate scope '%s'\n", 
            (int)uhdm_scope->Modules()->size(), scope_name.c_str());
        
        for (auto mod_inst : *uhdm_scope->Modules()) {
            // Just import the module instance
            // The module definition should already exist from the top-level import
            log("UHDM: Importing module instance '%s' of type '%s' in generate scope\n",
                std::string(mod_inst->VpiName()).c_str(), std::string(mod_inst->VpiDefName()).c_str());
            import_instance(mod_inst);
        }
    }
    
    // Import processes (always blocks) within the generate scope
    if (uhdm_scope->Process()) {
        log("UHDM: Found %d processes in generate scope\n", (int)uhdm_scope->Process()->size());
        for (auto process : *uhdm_scope->Process()) {
            try {
                import_process(process);
            } catch (const std::exception& e) {
                log_error("UHDM: Exception in process import within generate scope: %s\n", e.what());
            }
        }
    }
    
    // Recursively import nested generate scopes BEFORE continuous assignments
    // This ensures all wires in nested scopes are created before assignments reference them
    if (uhdm_scope->Gen_scope_arrays()) {
        log("UHDM: Found nested generate scope arrays\n");
        for (auto nested_array : *uhdm_scope->Gen_scope_arrays()) {
            if (nested_array->Gen_scopes()) {
                for (auto nested_scope : *nested_array->Gen_scopes()) {
                    // The nested scope will push its name onto the stack
                    import_gen_scope(nested_scope);
                }
            }
        }
    }
    
    // Import continuous assignments within the generate scope
    // Do this AFTER nested generate scopes so all wires are available
    if (uhdm_scope->Cont_assigns()) {
        log("UHDM: Found %d continuous assignments in generate scope\n", (int)uhdm_scope->Cont_assigns()->size());
        for (auto cont_assign : *uhdm_scope->Cont_assigns()) {
            try {
                import_continuous_assign(cont_assign);
            } catch (const std::exception& e) {
                log_error("UHDM: Exception in continuous assignment import within generate scope: %s\n", e.what());
            }
        }
    }
    
    // Pop this scope from the stack before returning
    gen_scope_stack.pop_back();
    log("UHDM: Popped scope '%s', stack depth: %zu\n", 
        scope_name.c_str(), gen_scope_stack.size());
    current_scope = nullptr;
}

YOSYS_NAMESPACE_END