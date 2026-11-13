/*
 * Tagged unions and pattern matching (IEEE 1800-2017 7.3.2, 12.6)
 *
 * Layout.  A tagged union is the tag in the MSBs followed by the widest
 * member; a narrower member is left-justified, immediately below the tag,
 * and its unused LSBs are zero.  The tag of member i is i (declaration
 * order) in ceil(log2(N)) bits.  The same layout is used for an unpacked
 * tagged union, whose representation the LRM leaves to the implementation.
 *
 *   `tagged m e`                  -> {tag(m), e, 0...}
 *   `x matches p`                 -> 1-bit match, binding `.v` variables
 *   `case (x) matches ... endcase` -> rewritten up front to an if/else chain
 *                                     of match operations (first match wins)
 *
 * Surelog encodes `.v` as an any_pattern named "v", `.*` as one named "*",
 * `p &&& e` as vpiCompAndOp, and `x matches p ? a : b` as a vpiConditionOp
 * over the vpiMatchOp.  A use of a pattern variable is a ref_obj with no
 * actual; import_ref_obj resolves it through pattern_var_binds_.
 */

#include "uhdm2rtlil.h"
#include <uhdm/uhdm.h>

YOSYS_NAMESPACE_BEGIN

using namespace UHDM;

static const typespec* actual_of(const ref_typespec* rt) {
    return rt ? rt->Actual_typespec() : nullptr;
}

bool UhdmImporter::tagged_union_layout(const typespec* ts, TaggedLayout& out) {
    if (!ts || ts->UhdmType() != uhdmunion_typespec) return false;
    auto uts = any_cast<const union_typespec*>(ts);
    if (!uts->VpiTagged() || !uts->Members()) return false;
    out = TaggedLayout();
    for (auto m : *uts->Members()) {
        const typespec* mts = actual_of(m->Typespec());
        int w = 0;
        if (mts && mts->UhdmType() != uhdmvoid_typespec)
            w = get_width_from_typespec(mts, current_instance);
        if (w < 0) w = 0;
        out.members.emplace_back(std::string(m->VpiName()), mts);
        out.widths.push_back(w);
        out.body = std::max(out.body, w);
    }
    size_t n = out.members.size();
    while (n > 1 && (1u << out.tag_bits) < n) out.tag_bits++;
    return true;
}

// The declared type of the value a pattern is matched against.
const typespec* UhdmImporter::match_typespec_of(const any* e) {
    if (!e) return nullptr;
    if (e->UhdmType() == uhdmref_obj) {
        const any* a = any_cast<const ref_obj*>(e)->Actual_group();
        if (a) {
            if (auto ex = dynamic_cast<const expr*>(a))
                if (auto ts = actual_of(ex->Typespec())) return ts;
        }
    }
    if (auto ex = dynamic_cast<const expr*>(e))
        if (auto ts = actual_of(ex->Typespec())) return ts;
    return nullptr;
}

// A tagged union of the design declaring `member`: the fallback when the
// matched or assigned value's type is not reachable from the expression.
const typespec* UhdmImporter::tagged_union_with_member(const std::string& member) {
    static std::map<const void*, std::vector<const union_typespec*>> cache;
    auto& unions = cache[uhdm_design];
    if (unions.empty() && uhdm_design && uhdm_design->GetSerializer()) {
        for (auto& kv : uhdm_design->GetSerializer()->AllObjects()) {
            auto o = kv.first;
            if (o && o->UhdmType() == uhdmunion_typespec) {
                auto u = any_cast<const union_typespec*>(o);
                if (u->VpiTagged()) unions.push_back(u);
            }
        }
    }
    for (auto u : unions)
        if (u->Members())
            for (auto m : *u->Members())
                if (m->VpiName() == member) return u;
    return nullptr;
}

// The type an expression is assigned to, for a `tagged m e` RHS.
static const any* assigned_lhs(const any* e) {
    for (const any* p = e ? e->VpiParent() : nullptr; p; p = p->VpiParent()) {
        if (p->UhdmType() == uhdmassignment)
            return any_cast<const assignment*>(p)->Lhs();
        if (p->UhdmType() == uhdmcont_assign)
            return any_cast<const cont_assign*>(p)->Lhs();
        if (p->UhdmType() != uhdmoperation) break;
    }
    return nullptr;
}

RTLIL::SigSpec UhdmImporter::import_tagged_value(const any* obj, const typespec* ts) {
    auto tp = any_cast<const tagged_pattern*>(obj);
    std::string name(tp->VpiName());
    TaggedLayout L;
    if (!tagged_union_layout(ts, L)) {
        if (expression_context_typespec && tagged_union_layout(expression_context_typespec, L)) {
        } else if (tagged_union_layout(match_typespec_of(assigned_lhs(tp)), L)) {
        } else if (!tagged_union_layout(tagged_union_with_member(name), L)) {
            return RTLIL::SigSpec();
        }
    }
    int idx = L.index(name);
    if (idx < 0) {
        log_warning("tagged expression: '%s' is not a member of the tagged union\n", name.c_str());
        return RTLIL::SigSpec(RTLIL::State::Sx, L.width());
    }
    int w = L.widths[idx];
    const typespec* mts = L.members[idx].second;
    RTLIL::SigSpec val;
    if (w > 0 && tp->Pattern()) {
        const any* pe = tp->Pattern();
        if (pe->UhdmType() == uhdmtagged_pattern) {
            TaggedLayout inner;
            if (tagged_union_layout(mts, inner))
                val = import_tagged_value(pe, mts);
        }
        if (val.size() == 0) {
            auto saved_ts = expression_context_typespec;
            int saved_w = expression_context_width;
            expression_context_typespec = mts;
            expression_context_width = w;
            val = import_expression(any_cast<const expr*>(pe));
            expression_context_typespec = saved_ts;
            expression_context_width = saved_w;
        }
    }
    val.extend_u0(w);
    RTLIL::SigSpec sig(RTLIL::Const(0, L.body - w));
    sig.append(val);
    sig.append(RTLIL::Const(idx, L.tag_bits));
    return sig;
}

static RTLIL::SigSpec and_bits(RTLIL::Module* m, RTLIL::SigSpec a, RTLIL::SigSpec b) {
    if (a == RTLIL::SigSpec(RTLIL::State::S1)) return b;
    if (b == RTLIL::SigSpec(RTLIL::State::S1)) return a;
    if (a == RTLIL::SigSpec(RTLIL::State::S0) || b == RTLIL::SigSpec(RTLIL::State::S0))
        return RTLIL::SigSpec(RTLIL::State::S0);
    return m->LogicAnd(NEW_ID, a, b);
}

// Field geometry of a packed structure, MSB-first: name, typespec, offset, width.
struct StructField { std::string name; const typespec* ts; int off; int w; };

RTLIL::SigSpec UhdmImporter::import_pattern_match(const any* pat, RTLIL::SigSpec value,
                                                  const typespec* ts, int case_type) {
    const RTLIL::SigSpec one(RTLIL::State::S1), zero(RTLIL::State::S0);
    if (!pat) return one;
    switch (pat->UhdmType()) {
        case uhdmany_pattern: {
            std::string n(any_cast<const any_pattern*>(pat)->VpiName());
            if (n != "*" && !n.empty()) pattern_var_binds_[n] = value;
            return one;
        }
        case uhdmtagged_pattern: {
            auto tp = any_cast<const tagged_pattern*>(pat);
            std::string n(tp->VpiName());
            TaggedLayout L;
            if (!tagged_union_layout(ts, L) &&
                !tagged_union_layout(tagged_union_with_member(n), L)) {
                log_warning("matches: no tagged union declares member '%s'\n", n.c_str());
                return zero;
            }
            int idx = L.index(n);
            if (idx < 0) return zero;
            value.extend_u0(L.width());
            RTLIL::SigSpec ok = one;
            if (L.tag_bits > 0)
                ok = module->Eq(NEW_ID, value.extract(L.body, L.tag_bits),
                                RTLIL::Const(idx, L.tag_bits));
            int w = L.widths[idx];
            RTLIL::SigSpec member = value.extract(L.body - w, w);
            return and_bits(module, ok,
                            import_pattern_match(tp->Pattern(), member, L.members[idx].second, case_type));
        }
        case uhdmstruct_pattern:
        case uhdmoperation: {
            const operation* op = pat->UhdmType() == uhdmoperation ? any_cast<const operation*>(pat) : nullptr;
            if (op && op->VpiOpType() != vpiListOp && op->VpiOpType() != vpiAssignmentPatternOp &&
                op->VpiOpType() != vpiConcatOp)
                break;  // an ordinary expression: compared below
            // Structure pattern '{p0, p1, ...} or '{name: p, ...}.
            std::vector<StructField> fields;
            if (ts && ts->UhdmType() == uhdmstruct_typespec) {
                auto sts = any_cast<const struct_typespec*>(ts);
                int total = 0;
                if (sts->Members())
                    for (auto m : *sts->Members()) {
                        const typespec* mts = actual_of(m->Typespec());
                        int w = mts ? get_width_from_typespec(mts, current_instance) : 0;
                        fields.push_back({std::string(m->VpiName()), mts, 0, w});
                        total += w;
                    }
                int off = total;
                for (auto& f : fields) { off -= f.w; f.off = off; }
                value.extend_u0(total);
            }
            std::vector<const any*> items;
            if (op && op->Operands()) for (auto o : *op->Operands()) items.push_back(o);
            if (!op) items.push_back(pat);
            RTLIL::SigSpec ok = one;
            for (size_t i = 0; i < items.size(); i++) {
                const any* it = items[i];
                const StructField* f = nullptr;
                const any* sub = it;
                std::string fname;
                if (it->UhdmType() == uhdmstruct_pattern) {
                    fname = std::string(any_cast<const struct_pattern*>(it)->VpiName());
                    sub = any_cast<const struct_pattern*>(it)->Pattern();
                } else if (it->UhdmType() == uhdmtagged_pattern && !fields.empty()) {
                    // `'{name: p}` -- a member name, not a union tag
                    std::string n(any_cast<const tagged_pattern*>(it)->VpiName());
                    for (auto& fl : fields) if (fl.name == n) fname = n;
                    if (!fname.empty()) sub = any_cast<const tagged_pattern*>(it)->Pattern();
                }
                if (!fname.empty()) {
                    for (auto& fl : fields) if (fl.name == fname) f = &fl;
                } else if (i < fields.size()) {
                    f = &fields[i];
                }
                if (!f) {
                    log_warning("matches: structure pattern element %zu has no field\n", i);
                    return zero;
                }
                ok = and_bits(module, ok,
                              import_pattern_match(sub, value.extract(f->off, f->w), f->ts, case_type));
            }
            return ok;
        }
        default:
            break;
    }
    // A constant expression pattern: `===`, so an x or z bit never matches
    // a synthesized (two-state) value -- unless casez / casex matches makes
    // it a wildcard (LRM 12.6.1).
    if (pat->UhdmType() == uhdmconstant) {
        auto c = any_cast<const constant*>(pat);
        if (c->VpiSize() != -1) {
            RTLIL::SigSpec k = import_expression(any_cast<const expr*>(pat));
            if (k.is_fully_const()) {
                RTLIL::SigSpec kc = k;
                kc.extend_u0(value.size(), false);
                RTLIL::SigSpec a, b;
                for (int i = 0; i < value.size() && i < kc.size(); i++) {
                    RTLIL::State s = kc[i].data;
                    if (s == RTLIL::State::S0 || s == RTLIL::State::S1) {
                        a.append(value[i]); b.append(s);
                    } else if ((s == RTLIL::State::Sz || s == RTLIL::State::Sa) &&
                               (case_type == vpiCaseZ || case_type == vpiCaseX)) {
                        continue;
                    } else if (s == RTLIL::State::Sx && case_type == vpiCaseX) {
                        continue;
                    } else {
                        return zero;
                    }
                }
                if (a.size() == 0) return one;
                return module->Eq(NEW_ID, a, b);
            }
        }
    }
    int saved_w = expression_context_width;
    expression_context_width = value.size();
    RTLIL::SigSpec k = import_expression(any_cast<const expr*>(pat));
    expression_context_width = saved_w;
    if (k.size() == 0) return zero;
    int w = std::max(value.size(), k.size());
    value.extend_u0(w);
    k.extend_u0(w);
    return module->Eq(NEW_ID, value, k);
}

RTLIL::SigSpec UhdmImporter::import_match_operation(const operation* op) {
    if (pattern_var_binds_module_ != module) {
        pattern_var_binds_.clear();
        pattern_var_binds_module_ = module;
    }
    auto ops = op->Operands();
    if (!ops || ops->empty()) return RTLIL::SigSpec(RTLIL::State::S0);
    if (op->VpiOpType() == vpiMatchOp) {
        if (ops->size() < 2) return RTLIL::SigSpec(RTLIL::State::S0);
        const any* e = (*ops)[0];
        const any* pat = (*ops)[1];
        const typespec* ts = match_typespec_of(e);
        if (pat->UhdmType() == uhdmtagged_pattern) {
            TaggedLayout L;
            if (!tagged_union_layout(ts, L))
                ts = tagged_union_with_member(std::string(any_cast<const tagged_pattern*>(pat)->VpiName()));
        }
        RTLIL::SigSpec value = import_expression(any_cast<const expr*>(e));
        int case_type = 0;
        auto it = match_case_type_.find(op);
        if (it != match_case_type_.end()) case_type = it->second;
        return import_pattern_match(pat, value, ts, case_type);
    }
    // vpiCompAndOp (`&&&`): every term in order, so a guard sees the
    // variables the patterns before it bound.
    RTLIL::SigSpec ok(RTLIL::State::S1);
    for (auto o : *ops) {
        RTLIL::SigSpec t;
        if (o->UhdmType() == uhdmoperation &&
            (any_cast<const operation*>(o)->VpiOpType() == vpiMatchOp ||
             any_cast<const operation*>(o)->VpiOpType() == vpiCompAndOp))
            t = import_match_operation(any_cast<const operation*>(o));
        else
            t = import_expression(any_cast<const expr*>(o));
        if (t.size() != 1) t = module->ReduceBool(NEW_ID, t);
        ok = and_bits(module, ok, t);
    }
    return ok;
}

// ---------------------------------------------------------------------------
// `case (e) matches` -> if / else-if chain of match operations.

static bool is_pattern_item(const any* e) {
    if (!e) return false;
    switch (e->UhdmType()) {
        case uhdmtagged_pattern:
        case uhdmany_pattern:
        case uhdmstruct_pattern:
            return true;
        case uhdmoperation: {
            auto op = any_cast<const operation*>(e);
            if (op->VpiOpType() == vpiCompAndOp) return true;
            if ((op->VpiOpType() == vpiListOp || op->VpiOpType() == vpiAssignmentPatternOp) &&
                op->Operands())
                for (auto o : *op->Operands())
                    if (is_pattern_item(o)) return true;
            return false;
        }
        default:
            return false;
    }
}

static bool replace_child_stmt(any* parent, const any* from, any* to) {
    switch (parent->UhdmType()) {
        case uhdmbegin:
        case uhdmnamed_begin:
        case uhdmfork_stmt:
        case uhdmnamed_fork: {
            VectorOfany* v = nullptr;
            if (parent->UhdmType() == uhdmbegin) v = ((begin*)parent)->Stmts();
            else if (parent->UhdmType() == uhdmnamed_begin) v = ((named_begin*)parent)->Stmts();
            else if (parent->UhdmType() == uhdmfork_stmt) v = ((fork_stmt*)parent)->Stmts();
            else v = ((named_fork*)parent)->Stmts();
            bool done = false;
            if (v) for (auto& s : *v) if (s == from) { s = to; done = true; }
            return done;
        }
        case uhdmalways: case uhdminitial: case uhdmfinal_stmt:
            if (((process_stmt*)parent)->Stmt() != from) return false;
            ((process_stmt*)parent)->Stmt(to); return true;
        case uhdmif_stmt:
            if (((if_stmt*)parent)->VpiStmt() != from) return false;
            ((if_stmt*)parent)->VpiStmt(to); return true;
        case uhdmif_else:
            if (((if_else*)parent)->VpiStmt() == from) { ((if_else*)parent)->VpiStmt(to); return true; }
            if (((if_else*)parent)->VpiElseStmt() == from) { ((if_else*)parent)->VpiElseStmt(to); return true; }
            return false;
        case uhdmcase_item:
            if (((case_item*)parent)->Stmt() != from) return false;
            ((case_item*)parent)->Stmt(to); return true;
        case uhdmfor_stmt:
            if (((for_stmt*)parent)->VpiStmt() != from) return false;
            ((for_stmt*)parent)->VpiStmt(to); return true;
        case uhdmwhile_stmt:
            if (((while_stmt*)parent)->VpiStmt() != from) return false;
            ((while_stmt*)parent)->VpiStmt(to); return true;
        case uhdmrepeat:
            if (((repeat*)parent)->VpiStmt() != from) return false;
            ((repeat*)parent)->VpiStmt(to); return true;
        case uhdmforever_stmt:
            if (((forever_stmt*)parent)->VpiStmt() != from) return false;
            ((forever_stmt*)parent)->VpiStmt(to); return true;
        case uhdmdo_while:
            if (((do_while*)parent)->VpiStmt() != from) return false;
            ((do_while*)parent)->VpiStmt(to); return true;
        case uhdmforeach_stmt:
            if (((foreach_stmt*)parent)->VpiStmt() != from) return false;
            ((foreach_stmt*)parent)->VpiStmt(to); return true;
        case uhdmfunction: case uhdmtask:
            if (((task_func*)parent)->Stmt() != from) return false;
            ((task_func*)parent)->Stmt(to); return true;
        case uhdmevent_control:
            if (((event_control*)parent)->Stmt() != from) return false;
            ((event_control*)parent)->Stmt(to); return true;
        case uhdmdelay_control:
            if (((delay_control*)parent)->Stmt() != from) return false;
            ((delay_control*)parent)->Stmt(to); return true;
        default:
            return false;
    }
}

template <typename T>
static void copy_loc(T* dst, const any* src) {
    dst->VpiFile(src->VpiFile());
    dst->VpiLineNo(src->VpiLineNo());
    dst->VpiColumnNo(src->VpiColumnNo());
    dst->VpiEndLineNo(src->VpiEndLineNo());
    dst->VpiEndColumnNo(src->VpiEndColumnNo());
}

// Wrap a `tagged m e` used as a value in a cast to its union type: a
// tagged_pattern is not an expr, and the assignment paths only read exprs.
static bool replace_value(any* parent, const any* from, any* to) {
    switch (parent->UhdmType()) {
        case uhdmassignment:
            if (((assignment*)parent)->Rhs() != from) return false;
            ((assignment*)parent)->Rhs(to); return true;
        case uhdmcont_assign:
            if (((cont_assign*)parent)->Rhs() != from) return false;
            ((cont_assign*)parent)->Rhs((expr*)to); return true;
        case uhdmreturn_stmt:
            if (((return_stmt*)parent)->VpiCondition() != from) return false;
            ((return_stmt*)parent)->VpiCondition((expr*)to); return true;
        case uhdmoperation: {
            auto op = (operation*)parent;
            int t = op->VpiOpType();
            if (t != vpiConditionOp && t != vpiConcatOp) return false;
            bool done = false;
            if (op->Operands()) for (auto& o : *op->Operands()) if (o == from) { o = to; done = true; }
            return done;
        }
        default:
            return false;
    }
}

void UhdmImporter::desugar_case_matches() {
    if (!uhdm_design || !uhdm_design->GetSerializer()) return;
    Serializer* s = uhdm_design->GetSerializer();
    std::vector<tagged_pattern*> values;
    for (auto& kv : s->AllObjects())
        if (kv.first && kv.first->UhdmType() == uhdmtagged_pattern)
            values.push_back((tagged_pattern*)kv.first);
    for (auto tp : values) {
        any* parent = (any*)tp->VpiParent();
        if (!parent) continue;
        const typespec* ts = nullptr;
        TaggedLayout L;
        if (parent->UhdmType() == uhdmassignment)
            ts = match_typespec_of(((assignment*)parent)->Lhs());
        else if (parent->UhdmType() == uhdmcont_assign)
            ts = match_typespec_of(((cont_assign*)parent)->Lhs());
        if (!tagged_union_layout(ts, L) || L.index(std::string(tp->VpiName())) < 0)
            ts = tagged_union_with_member(std::string(tp->VpiName()));
        if (!ts) continue;
        operation* cast = s->MakeOperation();
        cast->VpiOpType(vpiCastOp);
        copy_loc(cast, tp);
        ref_typespec* rt = s->MakeRef_typespec();
        rt->Actual_typespec((typespec*)ts);
        rt->VpiParent(cast);
        cast->Typespec(rt);
        VectorOfany* ops = s->MakeAnyVec();
        ops->push_back(tp);
        cast->Operands(ops);
        cast->VpiParent(parent);
        if (replace_value(parent, tp, cast)) {
            tp->VpiParent(cast);
        }
    }
    std::vector<case_stmt*> todo;
    for (auto& kv : s->AllObjects()) {
        if (!kv.first || kv.first->UhdmType() != uhdmcase_stmt) continue;
        auto cs = (case_stmt*)kv.first;
        if (!cs->Case_items()) continue;
        bool matches = false;
        for (auto ci : *cs->Case_items())
            if (ci->VpiExprs())
                for (auto e : *ci->VpiExprs())
                    if (is_pattern_item(e)) matches = true;
        if (matches) todo.push_back(cs);
    }
    for (auto cs : todo) {
        any* parent = (any*)cs->VpiParent();
        if (!parent) continue;
        any* chain = nullptr;      // the else branch built so far
        // default first, if any
        for (auto ci : *cs->Case_items())
            if (!ci->VpiExprs() || ci->VpiExprs()->empty())
                chain = ci->Stmt() ? (any*)ci->Stmt() : nullptr;
        for (auto it = cs->Case_items()->rbegin(); it != cs->Case_items()->rend(); ++it) {
            case_item* ci = *it;
            if (!ci->VpiExprs() || ci->VpiExprs()->empty()) continue;
            // `case matches` items carry exactly one pattern; a plain
            // `case` item list ORs its expressions.
            expr* cond = nullptr;
            for (auto e : *ci->VpiExprs()) {
                const any* pat = e;
                const any* guard = nullptr;
                if (e->UhdmType() == uhdmoperation &&
                    any_cast<const operation*>(e)->VpiOpType() == vpiCompAndOp &&
                    any_cast<const operation*>(e)->Operands() &&
                    any_cast<const operation*>(e)->Operands()->size() == 2) {
                    pat = (*any_cast<const operation*>(e)->Operands())[0];
                    guard = (*any_cast<const operation*>(e)->Operands())[1];
                }
                operation* m = s->MakeOperation();
                m->VpiOpType(vpiMatchOp);
                copy_loc(m, e);
                VectorOfany* mops = s->MakeAnyVec();
                mops->push_back((any*)cs->VpiCondition());
                mops->push_back((any*)pat);
                m->Operands(mops);
                if (cs->VpiCaseType() == vpiCaseZ || cs->VpiCaseType() == vpiCaseX)
                    match_case_type_[m] = cs->VpiCaseType();
                expr* term = m;
                if (guard) {
                    operation* a = s->MakeOperation();
                    a->VpiOpType(vpiCompAndOp);
                    copy_loc(a, e);
                    VectorOfany* aops = s->MakeAnyVec();
                    aops->push_back(m);
                    aops->push_back((any*)guard);
                    a->Operands(aops);
                    m->VpiParent(a);
                    term = a;
                }
                if (cond) {
                    operation* o = s->MakeOperation();
                    o->VpiOpType(vpiLogOrOp);
                    copy_loc(o, e);
                    VectorOfany* oops = s->MakeAnyVec();
                    oops->push_back(cond);
                    oops->push_back(term);
                    o->Operands(oops);
                    cond = o;
                } else {
                    cond = term;
                }
            }
            any* body = ci->Stmt() ? (any*)ci->Stmt() : nullptr;
            if (!body) {
                begin* b = s->MakeBegin();
                copy_loc(b, ci);
                b->Stmts(s->MakeAnyVec());
                body = b;
            }
            any* node;
            if (chain) {
                if_else* ie = s->MakeIf_else();
                copy_loc(ie, ci);
                ie->VpiCondition(cond);
                ie->VpiStmt(body);
                ie->VpiElseStmt(chain);
                chain->VpiParent(ie);
                node = ie;
            } else {
                if_stmt* is = s->MakeIf_stmt();
                copy_loc(is, ci);
                is->VpiCondition(cond);
                is->VpiStmt(body);
                node = is;
            }
            cond->VpiParent(node);
            body->VpiParent(node);
            chain = node;
        }
        if (!chain) {
            begin* b = s->MakeBegin();
            copy_loc(b, cs);
            b->Stmts(s->MakeAnyVec());
            chain = b;
        }
        chain->VpiParent(parent);
        if (!replace_child_stmt(parent, cs, chain))
            log_warning("case matches at %s:%d: unsupported enclosing statement, left as is\n",
                        std::string(cs->VpiFile()).c_str(), cs->VpiLineNo());
        else if (mode_debug)
            log("UHDM: case matches at line %d rewritten to an if/else chain\n", cs->VpiLineNo());
    }
}

YOSYS_NAMESPACE_END
