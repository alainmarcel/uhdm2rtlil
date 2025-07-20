// -*- c++ -*-

/*

 Copyright 2019-2022 Alain Dargelas

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

/*
 * File:   SynthSubset.cpp
 * Author: alaindargelas
 *
 * Created on Feb 16, 2022, 9:03 PM
 */
#include <string.h>
#include <uhdm/SynthSubset.h>
#include <uhdm/ExprEval.h>
#include <uhdm/ElaboratorListener.h>
#include <uhdm/clone_tree.h>
#include <uhdm/uhdm.h>
#include <uhdm/vpi_visitor.h>
#include <uhdm/Serializer.h>

namespace UHDM {

SynthSubset::SynthSubset(Serializer* serializer,
                         std::set<const any*>& nonSynthesizableObjects,
                         design* des,
                         bool reportErrors, bool allowFormal)
    : serializer_(serializer),
      nonSynthesizableObjects_(nonSynthesizableObjects),
      design_(des),
      reportErrors_(reportErrors),
      allowFormal_(allowFormal) {
  constexpr std::string_view kDollar("$");
  for (auto s :
       {// "display",
        "write", "strobe", "monitor", "monitoron", "monitoroff", "displayb",
        "writeb", "strobeb", "monitorb", "displayo", "writeo", "strobeo",
        "monitoro", "displayh", "writeh", "strobeh", "monitorh", "fopen",
        "fclose", "frewind", "fflush", "fseek", "ftell", "fdisplay", "fwrite",
        "swrite", "fstrobe", "fmonitor", "fread", "fscanf", "fdisplayb",
        "fwriteb", "swriteb", "fstrobeb", "fmonitorb", "fdisplayo", "fwriteo",
        "swriteo", "fstrobeo", "fmonitoro", "fdisplayh", "fwriteh", "swriteh",
        "fstrobeh", "fmonitorh", "sscanf", "sdf_annotate", "sformat",
        // "cast",
        "assertkill", "assertoff", "asserton",
        // "bits",
        // "bitstoshortreal",
        "countones", "coverage_control", "coverage_merge", "coverage_save",
        // "dimensions",
        // "error",
        "exit",
        // "fatal",
        "fell", "get_coverage", "coverage_get", "coverage_get_max",
        // "high",
        //"increment",
        "info", "isunbounded", "isunknown",
        // "left",
        "load_coverage_db",
        // "low",
        "onehot", "past",
        // "readmemb",
        // "readmemh",
        //"right",
        "root", "rose", "sampled", "set_coverage_db_name",
        // "shortrealtobits",
        // "size",
        "stable",
        // "typename",
        // "typeof",
        "unit", "urandom", "srandom", "urandom_range", "set_randstate",
        "get_randstate", "dist_uniform", "dist_normal", "dist_exponential",
        "dist_poisson", "dist_chi_square", "dist_t", "dist_erlang",
        // "warning",
        // "writememb",
        // "writememh",
        "value$plusargs"}) {
    nonSynthSysCalls_.emplace(std::move(std::string(kDollar).append(s)));
  }
}

void SynthSubset::report(std::ostream& out) {
  for (auto object : nonSynthesizableObjects_) {
    VisitedContainer visitedObjects;

    vpiHandle dh =
        object->GetSerializer()->MakeUhdmHandle(object->UhdmType(), object);

    visit_object(dh, out, true);
    vpi_release_handle(dh);
  }
}

void SynthSubset::reportError(const any* object) {
  const any* tmp = object;
  while (tmp && tmp->VpiFile().empty()) {
    tmp = tmp->VpiParent();
  }
  if (tmp) object = tmp;
  if (reportErrors_ && !reportedParent(object)) {
    if (!object->VpiFile().empty()) {
      const std::string errMsg(object->VpiName());
      serializer_->GetErrorHandler()(ErrorType::UHDM_NON_SYNTHESIZABLE, errMsg,
                                     object, nullptr);
    }
  }
  mark(object);
}

void SynthSubset::leaveAny(const any* object, vpiHandle handle) {
  switch (object->UhdmType()) {
    case UHDM_OBJECT_TYPE::uhdmfinal_stmt:
    case UHDM_OBJECT_TYPE::uhdmdelay_control:
    case UHDM_OBJECT_TYPE::uhdmdelay_term:
    case UHDM_OBJECT_TYPE::uhdmthread_obj:
    case UHDM_OBJECT_TYPE::uhdmwait_stmt:
    case UHDM_OBJECT_TYPE::uhdmwait_fork:
    case UHDM_OBJECT_TYPE::uhdmordered_wait:
    case UHDM_OBJECT_TYPE::uhdmdisable:
    case UHDM_OBJECT_TYPE::uhdmdisable_fork:
    case UHDM_OBJECT_TYPE::uhdmforce:
    case UHDM_OBJECT_TYPE::uhdmdeassign:
    case UHDM_OBJECT_TYPE::uhdmrelease:
    case UHDM_OBJECT_TYPE::uhdmsequence_inst:
    case UHDM_OBJECT_TYPE::uhdmseq_formal_decl:
    case UHDM_OBJECT_TYPE::uhdmsequence_decl:
    case UHDM_OBJECT_TYPE::uhdmprop_formal_decl:
    case UHDM_OBJECT_TYPE::uhdmproperty_inst:
    case UHDM_OBJECT_TYPE::uhdmproperty_spec:
    case UHDM_OBJECT_TYPE::uhdmproperty_decl:
    case UHDM_OBJECT_TYPE::uhdmclocked_property:
    case UHDM_OBJECT_TYPE::uhdmcase_property_item:
    case UHDM_OBJECT_TYPE::uhdmcase_property:
    case UHDM_OBJECT_TYPE::uhdmmulticlock_sequence_expr:
    case UHDM_OBJECT_TYPE::uhdmclocked_seq:
    case UHDM_OBJECT_TYPE::uhdmreal_var:
    case UHDM_OBJECT_TYPE::uhdmtime_var:
    case UHDM_OBJECT_TYPE::uhdmchandle_var:
    case UHDM_OBJECT_TYPE::uhdmchecker_port:
    case UHDM_OBJECT_TYPE::uhdmchecker_inst_port:
    case UHDM_OBJECT_TYPE::uhdmswitch_tran:
    case UHDM_OBJECT_TYPE::uhdmudp:
    case UHDM_OBJECT_TYPE::uhdmmod_path:
    case UHDM_OBJECT_TYPE::uhdmtchk:
    case UHDM_OBJECT_TYPE::uhdmudp_defn:
    case UHDM_OBJECT_TYPE::uhdmtable_entry:
    case UHDM_OBJECT_TYPE::uhdmclocking_block:
    case UHDM_OBJECT_TYPE::uhdmclocking_io_decl:
    case UHDM_OBJECT_TYPE::uhdmprogram_array:
    case UHDM_OBJECT_TYPE::uhdmswitch_array:
    case UHDM_OBJECT_TYPE::uhdmudp_array:
    case UHDM_OBJECT_TYPE::uhdmtchk_term:
    case UHDM_OBJECT_TYPE::uhdmtime_net:
    case UHDM_OBJECT_TYPE::uhdmnamed_event:
    case UHDM_OBJECT_TYPE::uhdmvirtual_interface_var:
    case UHDM_OBJECT_TYPE::uhdmextends:
    case UHDM_OBJECT_TYPE::uhdmclass_defn:
    case UHDM_OBJECT_TYPE::uhdmclass_obj:
    case UHDM_OBJECT_TYPE::uhdmprogram:
    case UHDM_OBJECT_TYPE::uhdmchecker_decl:
    case UHDM_OBJECT_TYPE::uhdmchecker_inst:
    case UHDM_OBJECT_TYPE::uhdmshort_real_typespec:
    case UHDM_OBJECT_TYPE::uhdmreal_typespec:
    case UHDM_OBJECT_TYPE::uhdmtime_typespec:
    case UHDM_OBJECT_TYPE::uhdmchandle_typespec:
    case UHDM_OBJECT_TYPE::uhdmsequence_typespec:
    case UHDM_OBJECT_TYPE::uhdmproperty_typespec:
    case UHDM_OBJECT_TYPE::uhdmuser_systf:
    case UHDM_OBJECT_TYPE::uhdmmethod_func_call:
    case UHDM_OBJECT_TYPE::uhdmmethod_task_call:
    case UHDM_OBJECT_TYPE::uhdmconstraint_ordering:
    case UHDM_OBJECT_TYPE::uhdmconstraint:
    case UHDM_OBJECT_TYPE::uhdmdistribution:
    case UHDM_OBJECT_TYPE::uhdmdist_item:
    case UHDM_OBJECT_TYPE::uhdmimplication:
    case UHDM_OBJECT_TYPE::uhdmconstr_if:
    case UHDM_OBJECT_TYPE::uhdmconstr_if_else:
    case UHDM_OBJECT_TYPE::uhdmconstr_foreach:
    case UHDM_OBJECT_TYPE::uhdmsoft_disable:
    case UHDM_OBJECT_TYPE::uhdmfork_stmt:
    case UHDM_OBJECT_TYPE::uhdmnamed_fork:
    case UHDM_OBJECT_TYPE::uhdmevent_stmt:
    case UHDM_OBJECT_TYPE::uhdmevent_typespec:
      reportError(object);
      break;
    case UHDM_OBJECT_TYPE::uhdmexpect_stmt:
    case UHDM_OBJECT_TYPE::uhdmcover:
    case UHDM_OBJECT_TYPE::uhdmassume:
    case UHDM_OBJECT_TYPE::uhdmrestrict:
    case UHDM_OBJECT_TYPE::uhdmimmediate_assume:
    case UHDM_OBJECT_TYPE::uhdmimmediate_cover:
      if (!allowFormal_) reportError(object);
      break;  
    default:
      break;
  }
}

void SynthSubset::leaveTask(const task* topobject, vpiHandle handle) {
  // Give specific error for non-synthesizable tasks
  std::function<void(const any*, const any*)> inst_visit =
      [&inst_visit, this](const any* stmt, const any* top) {
        UHDM_OBJECT_TYPE type = stmt->UhdmType();
        UHDM::VectorOfany* stmts = nullptr;
        if (type == UHDM_OBJECT_TYPE::uhdmbegin) {
          begin* b = (begin*)stmt;
          stmts = b->Stmts();
        } else if (type == UHDM_OBJECT_TYPE::uhdmnamed_begin) {
          named_begin* b = (named_begin*)stmt;
          stmts = b->Stmts();
        }
        if (stmts) {
          for (auto st : *stmts) {
            UHDM_OBJECT_TYPE sttype = st->UhdmType();
            switch (sttype) {
              case UHDM_OBJECT_TYPE::uhdmwait_stmt:
              case UHDM_OBJECT_TYPE::uhdmwait_fork:
              case UHDM_OBJECT_TYPE::uhdmordered_wait:
              case UHDM_OBJECT_TYPE::uhdmdisable:
              case UHDM_OBJECT_TYPE::uhdmdisable_fork:
              case UHDM_OBJECT_TYPE::uhdmforce:
              case UHDM_OBJECT_TYPE::uhdmdeassign:
              case UHDM_OBJECT_TYPE::uhdmrelease:
              case UHDM_OBJECT_TYPE::uhdmsoft_disable:
              case UHDM_OBJECT_TYPE::uhdmfork_stmt:
              case UHDM_OBJECT_TYPE::uhdmnamed_fork:
              case UHDM_OBJECT_TYPE::uhdmevent_stmt: {
                reportError(top);
                break;
              }
              default: {
              }
            }
            inst_visit(st, top);
          }
        }
      };

  if (const any* stmt = topobject->Stmt()) {
    inst_visit(stmt, topobject);
  }
}

void SynthSubset::leaveSys_task_call(const sys_task_call* object,
                                     vpiHandle handle) {
  const std::string_view name = object->VpiName();
  if (nonSynthSysCalls_.find(name) != nonSynthSysCalls_.end()) {
    reportError(object);
  }
}

sys_func_call* SynthSubset::makeStubDisplayStmt(const any* object) {
  sys_func_call* display = serializer_->MakeSys_func_call();
  display->VpiName("$display");
  VectorOfany* arguments = serializer_->MakeAnyVec();
  constant *c = serializer_->MakeConstant();
  c->VpiConstType(vpiStringVal);
  std::string text = "Stub for non-synthesizable stmt";
  c->VpiValue("STRING:" + text);
  c->VpiDecompile(text);
  c->VpiSize(text.size());
  arguments->push_back(c);
  display->Tf_call_args(arguments);
  return display;
}

bool objectIsInitialBlock(const any* object) {
  bool inInitialBlock = false;
  const any* parent = object->VpiParent();
  while (parent) {
    if (parent->UhdmType() == uhdminitial) {
      inInitialBlock = true;
      break;
    }
    parent = parent->VpiParent();
  }
  return inInitialBlock;
}

void SynthSubset::removeFromVector(VectorOfany* vec, const any* object) {
  VectorOfany::iterator itr = vec->begin();
  for (auto s : *vec) {
    if (s == object) {
      vec->erase(itr);
      if (vec->empty()) {
        const std::string_view name = object->VpiName();
        if (name == "$error" || name == "$finish" || name == "$display") {
          bool inInitialBLock = objectIsInitialBlock(object);
          if (!inInitialBLock)
            vec->push_back(makeStubDisplayStmt(object));
        } else {
          vec->push_back(makeStubDisplayStmt(object));
        }
      }
      break;
    }
    itr++;
  }
}

void SynthSubset::removeFromStmt(any* parent, const any* object) {
  if (parent->UhdmType() == uhdmfor_stmt) {
    for_stmt* st = (for_stmt*) parent;
    st->VpiStmt(makeStubDisplayStmt(object));
  } else if (parent->UhdmType() == uhdmif_stmt) {
    if_stmt* st = (if_stmt*) parent;
    st->VpiStmt(makeStubDisplayStmt(object));
  } else if (parent->UhdmType() == uhdmif_else) {
    if_else* st = (if_else*) parent;
    if (st->VpiStmt() && (st->VpiStmt() == object))
      st->VpiStmt(makeStubDisplayStmt(object));
    else if (st->VpiElseStmt() && (st->VpiElseStmt() == object))
      st->VpiElseStmt(makeStubDisplayStmt(object)); 
  } else if (parent->UhdmType() == uhdminitial) {
    initial* st = (initial*) parent;
    const std::string_view name = object->VpiName();
    if (name == "$error" || name == "$finish") {
      st->Stmt(makeStubDisplayStmt(object));
    } else if (name == "$display") {
      // No better alternative than to keep the statement
    } else {
      st->Stmt(makeStubDisplayStmt(object));
    }
  } 
}

void SynthSubset::filterNonSynthesizable() {
  for (auto p : m_scheduledFilteredObjectsInVector) {
    removeFromVector(p.first, p.second);
  }
  for (auto p : m_scheduledFilteredObjectsInStmt) {
    removeFromStmt(p.first, p.second);
  }
}

void SynthSubset::leaveSys_func_call(const sys_func_call* object,
                                     vpiHandle handle) {
  const std::string_view name = object->VpiName();
  if (nonSynthSysCalls_.find(name) != nonSynthSysCalls_.end()) {
    reportError(object);
    const any* parent = object->VpiParent();
    if (parent->UhdmType() == uhdmbegin) {
      begin* st = (begin*) parent;
      if (st->Stmts()) {
        m_scheduledFilteredObjectsInVector.emplace_back(st->Stmts(), object);
      }
    } else if (parent->UhdmType() == uhdmnamed_begin) {
      named_begin* st = (named_begin*) parent;
      if (st->Stmts()) {
        m_scheduledFilteredObjectsInVector.emplace_back(st->Stmts(), object);
      }
    } else if (parent->UhdmType() == uhdmfor_stmt) {
      for_stmt* st = (for_stmt*) parent;
      if (st->VpiStmt()) {
        m_scheduledFilteredObjectsInStmt.emplace_back(st, object);
      }
    } else if (parent->UhdmType() == uhdmif_stmt) {
      if_stmt* st = (if_stmt*) parent;
      if (st->VpiStmt()) {
        m_scheduledFilteredObjectsInStmt.emplace_back(st, object);
      }
    } else if (parent->UhdmType() == uhdmif_else) {
      if_else* st = (if_else*) parent;
      if (st->VpiStmt() && (st->VpiStmt() == object)) {
        m_scheduledFilteredObjectsInStmt.emplace_back(st, object);
      } else if (st->VpiElseStmt() && (st->VpiElseStmt() == object)) {
        m_scheduledFilteredObjectsInStmt.emplace_back(st, object);
      }
    } else if (parent->UhdmType() == uhdminitial) {
      initial* st = (initial*) parent;
      if (st->Stmt()) {
        m_scheduledFilteredObjectsInStmt.emplace_back(st, object);
      }
    } 
  }
  // Filter out sys func calls stmt from initial block
  if (name == "$error" || name == "$finish" || name == "$display") {
    bool inInitialBlock = objectIsInitialBlock(object);
    if (inInitialBlock) {
      const any* parent = object->VpiParent();
      if (parent->UhdmType() == uhdmbegin) {
        begin* st = (begin*) parent;
        if (st->Stmts()) {
          m_scheduledFilteredObjectsInVector.emplace_back(st->Stmts(), object);
        }
      } else if (parent->UhdmType() == uhdmnamed_begin) {
        named_begin* st = (named_begin*) parent;
        if (st->Stmts()) {
          m_scheduledFilteredObjectsInVector.emplace_back(st->Stmts(), object);
        }
      } else if (parent->UhdmType() == uhdminitial) {
        initial* st = (initial*) parent;
        if (st->Stmt()) {
          m_scheduledFilteredObjectsInStmt.emplace_back(st, object);
        }
      }
    }
  }
}

void SynthSubset::leaveClass_typespec(const class_typespec* object,
                                      vpiHandle handle) {
  if (const any* def = object->Class_defn())
    reportError(def);
  else
    reportError(object);
}

void SynthSubset::leaveClass_var(const class_var* object, vpiHandle handle) {
  if (const ref_typespec* rt = object->Typespec()) {
    if (const class_typespec* spec = rt->Actual_typespec<class_typespec>()) {
      if (const class_defn* def = spec->Class_defn()) {
        if (reportedParent(def)) {
          mark(object);
          return;
        }
      }
    }
  }
  reportError(object);
}

void SynthSubset::mark(const any* object) {
  nonSynthesizableObjects_.insert(object);
}

bool SynthSubset::reportedParent(const any* object) {
  if (object->UhdmType() == UHDM_OBJECT_TYPE::uhdmpackage) {
    if (object->VpiName() == "builtin") return true;
  } else if (object->UhdmType() == UHDM_OBJECT_TYPE::uhdmclass_defn) {
    if (object->VpiName() == "work@semaphore" ||
        object->VpiName() == "work@process" ||
        object->VpiName() == "work@mailbox")
      return true;
  }
  if (nonSynthesizableObjects_.find(object) != nonSynthesizableObjects_.end()) {
    return true;
  }
  if (const any* parent = object->VpiParent()) {
    return reportedParent(parent);
  }
  return false;
}

// Apply some rewrite rule for Synlig limitations, namely Synlig handles aliased typespec incorrectly.
void SynthSubset::leaveRef_typespec(const ref_typespec* object,
                                    vpiHandle handle) {
  if (const typespec* actual = object->Actual_typespec()) {
    if (const ref_typespec* ref_alias = actual->Typedef_alias()) {
      // Make the typespec point to the aliased typespec if they are of the same
      // type:
      //   typedef lc_tx_e lc_tx_t;
      // When extra dimensions are added using a packed_array_typespec like in:
      //  typedef lc_tx_e [1:0] lc_tx_t;
      //  We will need to uniquify and create a new typespec instance
      if ((ref_alias->Actual_typespec()->UhdmType() == actual->UhdmType()) &&
          !ref_alias->Actual_typespec()->VpiName().empty()) {
        ((ref_typespec*)object)
            ->Actual_typespec((typespec*)ref_alias->Actual_typespec());
      }
    }
  }
}

void SynthSubset::leaveFor_stmt(const for_stmt* object, vpiHandle handle) {
  if (const expr* cond = object->VpiCondition()) {
    if (cond->UhdmType() == uhdmoperation) {
      operation* topOp = (operation*)cond;
      VectorOfany* operands = topOp->Operands();
      const any* parent = object->VpiParent();
      if (topOp->VpiOpType() == vpiLogAndOp) {
        // Rewrite rule for Yosys (Cannot handle non-constant expression in for
        // loop condition besides loop var)
        // Transforms:
        //  for (int i=0; i<32 && found==0; i++) begin
        //  end
        // Into:
        //  for (int i=0; i<32; i++) begin
        //    if (found==0) break;
        //  end
        //
        // Assumes lhs is comparator over loop var
        // rhs is any expression
        any* lhs = operands->at(0);
        any* rhs = operands->at(1);
        ((for_stmt*)object)->VpiCondition((expr*)lhs);
        VectorOfany* stlist = nullptr;
        if (const any* stmt = object->VpiStmt()) {
          if (stmt->UhdmType() == uhdmbegin) {
            begin* st = (begin*)stmt;
            stlist = st->Stmts();
          } else if (stmt->UhdmType() == uhdmnamed_begin) {
            named_begin* st = (named_begin*)stmt;
            stlist = st->Stmts();
          }
          if (stlist) {
            if_stmt* ifstmt = serializer_->MakeIf_stmt();
            stlist->insert(stlist->begin(), ifstmt);
            ifstmt->VpiCondition((expr*)rhs);
            break_stmt* brk = serializer_->MakeBreak_stmt();
            ifstmt->VpiStmt(brk);
          }
        }
      } else {
        if (isInUhdmAllIterator()) return;
        // Rewrite rule for Yosys (Cannot handle non-constant expression as a
        // bound for loop var) Transforms:
        //   logic [1:0] bound;
        //   for(j=0;j<bound;j=j+1) Q = 1'b1;
        // Into:
        //   case (i)
        //     0 :
        //       for(j=0;j<0;j=j+1) Q = 1'b1;
        //     1 :
        //       for(j=0;j<1;j=j+1) Q = 1'b1;
        //   endcase
        bool needsTransform = false;
        logic_net* var = nullptr;
        if (operands->size() == 2) {
          any* op = operands->at(1);
          if (op->UhdmType() == uhdmref_obj) {
            ref_obj* ref = (ref_obj*)op;
            any* actual = ref->Actual_group();
            if (actual) {
              if (actual->UhdmType() == uhdmlogic_net) {
                needsTransform = true;
                var = (logic_net*)actual;
              }
            }
          }
        }
        if (needsTransform) {
          // Check that we are in an always stmt
          needsTransform = false;
          const any* tmp = parent;
          while (tmp) {
            if (tmp->UhdmType() == uhdmalways) {
              needsTransform = true;
              break;
            }
            tmp = tmp->VpiParent();
          }
        }
        if (needsTransform) {
          ExprEval eval;
          bool invalidValue = false;
          uint32_t size = eval.size(var, invalidValue, parent->VpiParent(),
                                    parent, true, true);
          case_stmt* case_st = serializer_->MakeCase_stmt();
          case_st->VpiCaseType(vpiCaseExact);
          case_st->VpiParent((any*)parent);
          VectorOfany* stmts = nullptr;
          if (parent->UhdmType() == uhdmbegin) {
            stmts = any_cast<begin*>(parent)->Stmts();
          } else if (parent->UhdmType() == uhdmnamed_begin) {
            stmts = any_cast<named_begin*>(parent)->Stmts();
          }
          if (stmts) {
            // Substitute the for loop with a case stmt
            for (VectorOfany::iterator itr = stmts->begin();
                 itr != stmts->end(); itr++) {
              if ((*itr) == object) {
                stmts->insert(itr, case_st);
                break;
              }
            }
            for (VectorOfany::iterator itr = stmts->begin();
                 itr != stmts->end(); itr++) {
              if ((*itr) == object) {
                stmts->erase(itr);
                break;
              }
            }
          }
          // Construct the case stmt
          ref_obj* ref = serializer_->MakeRef_obj();
          ref->VpiName(var->VpiName());
          ref->Actual_group(var);
          ref->VpiParent(case_st);
          case_st->VpiCondition(ref);
          VectorOfcase_item* items = serializer_->MakeCase_itemVec();
          case_st->Case_items(items);
          for (uint32_t i = 0; i < size; i++) {
            case_item* item = serializer_->MakeCase_item();
            item->VpiParent(case_st);
            constant* c = serializer_->MakeConstant();
            c->VpiConstType(vpiUIntConst);
            c->VpiValue("UINT:" + std::to_string(i));
            c->VpiDecompile(std::to_string(i));
            c->VpiParent(item);
            VectorOfany* exprs = serializer_->MakeAnyVec();
            exprs->push_back(c);
            item->VpiExprs(exprs);
            items->push_back(item);
            ElaboratorContext elaboratorContext(serializer_);
            for_stmt* clone = (for_stmt*)clone_tree(object, &elaboratorContext);
            clone->VpiParent(item);
            operation* cond_op = any_cast<operation*>(clone->VpiCondition());
            VectorOfany* operands = cond_op->Operands();
            for (uint32_t ot = 0; ot < operands->size(); ot++) {
              if (operands->at(ot)->VpiName() == var->VpiName()) {
                operands->at(ot) = c;
                break;
              }
            }
            item->Stmt(clone);
          }
        }
      }
    }
  }
}

void SynthSubset::leavePort(const port* object, vpiHandle handle) {
  if (isInUhdmAllIterator()) return;
  bool signedLowConn = false;
  if (const any* lc = object->Low_conn()) {
    if (const ref_obj* ref = any_cast<const ref_obj*>(lc)) {
      if (const any* actual = ref->Actual_group()) {
        if (actual->UhdmType() == uhdmlogic_var) {
          logic_var* var = (logic_var*)actual;
          if (var->VpiSigned()) {
            signedLowConn = true;
          }
        }
        if (actual->UhdmType() == uhdmlogic_net) {
          logic_net* var = (logic_net*)actual;
          if (var->VpiSigned()) {
            signedLowConn = true;
          }
        }
      }
    }
  }
  if (signedLowConn) return;

  std::string highConnSignal;
  const any* reportObject = object;
  if (const any* hc = object->High_conn()) {
    if (const ref_obj* ref = any_cast<const ref_obj*>(hc)) {
      reportObject = ref;
      if (const any* actual = ref->Actual_group()) {
        if (actual->UhdmType() == uhdmlogic_var) {
          logic_var* var = (logic_var*)actual;
          if (var->VpiSigned()) {
            highConnSignal = actual->VpiName();
            var->VpiSigned(false);
            if (const ref_typespec* tps = var->Typespec()) {
              if (const logic_typespec* ltps =
                      any_cast<const logic_typespec*>(tps->Actual_typespec())) {
                ((logic_typespec*)ltps)->VpiSigned(false);
              }
            }
          }
        }
        if (actual->UhdmType() == uhdmlogic_net) {
          logic_net* var = (logic_net*)actual;
          if (var->VpiSigned()) {
            highConnSignal = actual->VpiName();
            var->VpiSigned(false);
            if (const ref_typespec* tps = var->Typespec()) {
              if (const logic_typespec* ltps =
                      any_cast<const logic_typespec*>(tps->Actual_typespec())) {
                ((logic_typespec*)ltps)->VpiSigned(false);
              }
            }
          }
        }
      }
    }
  }
  if (!highConnSignal.empty()) {
    const std::string errMsg(highConnSignal);
    serializer_->GetErrorHandler()(ErrorType::UHDM_FORCING_UNSIGNED_TYPE,
                                   errMsg, reportObject, nullptr);
  }
}

void SynthSubset::leaveAlways(const always* object, vpiHandle handle) {
  sensitivityListRewrite(object, handle);
  blockingToNonBlockingRewrite(object, handle);
}

// Transform 3 vars sensitivity list into 2 vars sensitivity list because of a
// Yosys limitation
void SynthSubset::sensitivityListRewrite(const always* object, vpiHandle handle) {
  // Transform: always @ (posedge clk or posedge rst or posedge start)
  //              if (rst | start) ...
  // Into:
  //            wire \synlig_tmp = rst | start;
  //            always @ (posedge clk or posedge \synlig_tmp )
  //               if (\synlig_tmp ) ...
  if (const UHDM::any* stmt = object->Stmt()) {
    if (const event_control* ec = any_cast<event_control*>(stmt)) {
      if (const operation* cond_op = any_cast<operation*>(ec->VpiCondition())) {
        VectorOfany* operands_top = cond_op->Operands();
        VectorOfany* operands_op0 = nullptr;
        VectorOfany* operands_op1 = nullptr;
        any* opLast = nullptr;
        int totalOperands = 0;
        if (operands_top->size() > 1) {
          if (operands_top->at(0)->UhdmType() == uhdmoperation) {
            operation* op = (operation*)operands_top->at(0);
            operands_op0 = op->Operands();
            totalOperands += operands_op0->size();
          }
          if (operands_top->at(1)->UhdmType() == uhdmoperation) {
            operation* op = (operation*)operands_top->at(1);
            opLast = op;
            operands_op1 = op->Operands();
            totalOperands += operands_op1->size();
          }
        }
        if (totalOperands != 3) {
          return;
        }
        any* opMiddle = operands_op0->at(1);
        if (opMiddle->UhdmType() == uhdmoperation &&
            opLast->UhdmType() == uhdmoperation) {
          operation* opM = (operation*)opMiddle;
          operation* opL = (operation*)opLast;
          any* midVar = opM->Operands()->at(0);
          std::string_view var2Name = midVar->VpiName();
          std::string_view var3Name = opL->Operands()->at(0)->VpiName();
          if (opM->VpiOpType() == opL->VpiOpType()) {
            VectorOfany* stmts = nullptr;
            if (const UHDM::scope* st = any_cast<scope*>(ec->Stmt())) {
              if (st->UhdmType() == uhdmbegin) {
                stmts = any_cast<begin*>(st)->Stmts();
              } else if (st->UhdmType() == uhdmnamed_begin) {
                stmts = any_cast<named_begin*>(st)->Stmts();
              }
            } else if (const UHDM::any* st = any_cast<any*>(ec->Stmt())) {
              stmts = serializer_->MakeAnyVec();
              stmts->push_back((any*)st);
            }
            if (!stmts) return;
            for (auto stmt : *stmts) {
              expr* cond = nullptr;
              if (stmt->UhdmType() == uhdmif_else) {
                cond = any_cast<if_else*>(stmt)->VpiCondition();
              } else if (stmt->UhdmType() == uhdmif_stmt) {
                cond = any_cast<if_stmt*>(stmt)->VpiCondition();
              } else if (stmt->UhdmType() == uhdmcase_stmt) {
                cond = any_cast<case_stmt*>(stmt)->VpiCondition();
              }
              if (cond->UhdmType() == uhdmoperation) {
                operation* op = (operation*)cond;
                // Check that the sensitivity vars are used as a or-ed
                // condition
                if (op->VpiOpType() == vpiBitOrOp) {
                  VectorOfany* operands = op->Operands();
                  if (operands->at(0)->VpiName() == var2Name &&
                      operands->at(1)->VpiName() == var3Name) {
                    // All conditions are met, perform the transformation

                    // Remove: "posedge rst" from that part of the tree
                    operands_op0->pop_back();

                    // Create expression: rst | start
                    operation* orOp = serializer_->MakeOperation();
                    orOp->VpiOpType(vpiBitOrOp);
                    orOp->Operands(serializer_->MakeAnyVec());
                    orOp->Operands()->push_back(midVar);
                    orOp->Operands()->push_back(opL->Operands()->at(0));

                    // Move up the tree: posedge clk
                    operands_top->at(0) = operands_op0->at(0);

                    // Create: wire \synlig_tmp = rst | start;
                    cont_assign* ass = serializer_->MakeCont_assign();
                    logic_net* lhs = serializer_->MakeLogic_net();
                    std::string tmpName = std::string("synlig_tmp_") +
                                          std::string(var2Name) + "_or_" +
                                          std::string(var3Name);
                    lhs->VpiName(tmpName);
                    ass->Lhs(lhs);
                    ref_obj* ref = serializer_->MakeRef_obj();
                    ref->VpiName(tmpName);
                    ref->Actual_group(lhs);
                    ass->Rhs(orOp);
                    const any* instance = object->VpiParent();
                    if (instance->UhdmType() == uhdmmodule_inst) {
                      module_inst* mod = (module_inst*)instance;
                      if (mod->Cont_assigns() == nullptr) {
                        mod->Cont_assigns(serializer_->MakeCont_assignVec());
                      }
                      bool found = false;
                      for (cont_assign* ca : *mod->Cont_assigns()) {
                        if (ca->Lhs()->VpiName() == tmpName) {
                          found = true;
                          break;
                        }
                      }
                      if (!found) mod->Cont_assigns()->push_back(ass);
                    }

                    // Redirect condition to: if (\synlig_tmp ) ...
                    if (stmt->UhdmType() == uhdmif_else) {
                      any_cast<if_else*>(stmt)->VpiCondition(ref);
                    } else if (stmt->UhdmType() == uhdmif_stmt) {
                      any_cast<if_stmt*>(stmt)->VpiCondition(ref);
                    } else if (stmt->UhdmType() == uhdmcase_stmt) {
                      any_cast<case_stmt*>(stmt)->VpiCondition(ref);
                    }

                    // Redirect 2nd sensitivity list signal to: posedge
                    // \synlig_tmp
                    opL->Operands()->at(0) = ref;
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

void collectAssignmentStmt(const any* stmt, std::vector<const assignment*>& blocking_assigns, std::vector<const assignment*>& nonblocking_assigns) {
  if (stmt == nullptr)
    return;
  UHDM_OBJECT_TYPE stmt_type = stmt->UhdmType();
  switch (stmt_type) {
    case uhdmbegin: {
      VectorOfany* stmts = any_cast<begin*>(stmt)->Stmts();
      if (stmts)
        for (auto stmt : *stmts) {
          collectAssignmentStmt(stmt, blocking_assigns, nonblocking_assigns);
        }
      break;
    }
    case uhdmnamed_begin: {
      VectorOfany* stmts = any_cast<named_begin*>(stmt)->Stmts();
      if (stmts)
        for (auto stmt : *stmts) {
          collectAssignmentStmt(stmt, blocking_assigns, nonblocking_assigns);
        }
      break;
    }
    case uhdmif_else: {
      const any* the_stmt = any_cast<if_else*>(stmt)->VpiStmt();
      collectAssignmentStmt(the_stmt, blocking_assigns, nonblocking_assigns);
      const any* else_stmt = any_cast<if_else*>(stmt)->VpiElseStmt();
      collectAssignmentStmt(else_stmt, blocking_assigns, nonblocking_assigns);
      break;
    }
    case uhdmif_stmt: {
      const any* the_stmt = any_cast<if_stmt*>(stmt)->VpiStmt();
      collectAssignmentStmt(the_stmt, blocking_assigns, nonblocking_assigns);
      break;
    }
    case uhdmcase_stmt: {
      //VectorOfcase_item* items = any_cast<case_stmt*>(stmt)->Case_items();
      // TODO
      break;
    }
    case uhdmassignment: {
      const assignment* as = any_cast<assignment*>(stmt);
      if (as->VpiBlocking()) {
        blocking_assigns.push_back(as);
      } else { 
        nonblocking_assigns.push_back(as);
      }
      break;
    }
    default:
      break;
  }
}

// Transforms the following to enable RAM inference:
//    if (we)
//      RAM[addr] = di;
//    read = RAM[addr];
// Into:
//    if (we)
//      RAM[addr] <= di;
//    read <= RAM[addr];
void SynthSubset::blockingToNonBlockingRewrite(const always* object,
                                               vpiHandle handle) {
  if (const UHDM::any* stmt = object->Stmt()) {
    if (const event_control* ec = any_cast<event_control*>(stmt)) {
      // Collect all the blocking and non blocking assignments
      std::vector<const assignment*> blocking_assigns;
      std::vector<const assignment*> nonblocking_assigns;
      collectAssignmentStmt(ec->Stmt(), blocking_assigns, nonblocking_assigns);
      // Identify a potential RAM in the LHSs
      std::string ram_name;
      // 1) It has to be a LHS of a blocking assignment to be a candidate
      for (const assignment* stmt : blocking_assigns) {
        const expr* lhs = stmt->Lhs();
        // LHS assigns to a bit select 
        // RAM[addr] = ...
        if (lhs->UhdmType() == uhdmbit_select) {
          // The actual has to be an array_net with 2 dimensions (packed and unpacked):
          const bit_select* bs = any_cast<bit_select*>(lhs);
          const any* actual = bs->Actual_group();
          if (actual && (actual->UhdmType() == uhdmarray_net)) {
            const array_net* arr_net = any_cast<array_net*>(actual);
            if (arr_net->Ranges()) { // Unpacked dimension
              if (VectorOfnet* nets = arr_net->Nets()) {
                if (nets->size()) {
                  net* n = nets->at(0);
                  ref_typespec* reft = n->Typespec();
                  typespec* tps = reft->Actual_typespec();
                  bool has_packed_dimm = false; // Packed dimension
                  if (tps->UhdmType() == uhdmlogic_typespec) {
                    logic_typespec* ltps = any_cast<logic_typespec*>(tps);
                    if (ltps->Ranges()) {
                      has_packed_dimm = true;
                    }
                  }
                  if (has_packed_dimm) {
                    ram_name = lhs->VpiName();
                  }
                }
              }
            }
          }
        }
      }
      // 2) It cannot be a LHS of a non blocking assignment
      for (const assignment* stmt : nonblocking_assigns) {
        const expr* lhs = stmt->Lhs();
        if (lhs->VpiName() == ram_name) {
          // Invalidate the candidate
          ram_name = "";
        }
      }
      // 3) Check that it is referenced in RHS of blocking assignments exactly once, and assigned exactly once
      int countAssignments = 0;
      int countUsages = 0;
      if (!ram_name.empty()) {
        for (const assignment* stmt : blocking_assigns) {
          const expr* lhs = stmt->Lhs();
          const any* rhs = stmt->Rhs();
          if (lhs && lhs->VpiName() == ram_name) {
            countAssignments++;
          }
          if (rhs && rhs->VpiName() == ram_name) {
            countUsages++;
          }
        }
      }
      if ((countUsages == 1) && (countAssignments == 1)) { 
        // Match all the criteria: Convert all blocking assignments writing or reading the ram to non blocking
        for (const assignment* stmt : blocking_assigns) {
          const expr* lhs = stmt->Lhs();
          const any* rhs = stmt->Rhs();
          if ((lhs && lhs->VpiName() == ram_name) || (rhs && rhs->VpiName() == ram_name)) {
            ((assignment*)stmt)->VpiBlocking(false);
          }
        }
      }
    }
  }
}

void SynthSubset::leaveArray_var(const array_var* object, vpiHandle handle) {
  VectorOfvariables* vars = object->Variables();
  if (!vars) return;
  if (vars->empty()) return;
  variables* var = vars->at(0);
  const ref_typespec* ref_tps = var->Typespec();
  if (!ref_tps) return;
  const typespec* tps = ref_tps->Actual_typespec();
  if (tps->UhdmType() == uhdmlogic_typespec) {
    logic_typespec* ltps = (logic_typespec*)tps;
    if ((tps->VpiName().empty())) {
      if (ltps->Ranges() && ltps->Ranges()->size() == 1) {
        ((array_var*)object)->Typespec((ref_typespec*)ref_tps);
      }
    } else {
      if (ltps->Ranges() && ltps->Ranges()->size() == 1) {
        ElaboratorContext elaboratorContext(serializer_);
        logic_typespec* clone =
            (logic_typespec*)clone_tree(ltps, &elaboratorContext);
        clone->VpiName("");
        ((ref_typespec*)ref_tps)->Actual_typespec(clone);
        ((array_var*)object)->Typespec((ref_typespec*)ref_tps);
      }
    }
  }
}

void SynthSubset::leaveLogic_net(const logic_net* object, vpiHandle handle) {
  if (!isInUhdmAllIterator()) return;
  ((logic_net*) object)->Typespec(nullptr);
}

}  // namespace UHDM
