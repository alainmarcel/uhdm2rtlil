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
 * File:   SynthSubset.h
 * Author: alaindargelas
 *
 * Created on Feb 16, 2022, 9:03 PM
 */

#ifndef SYNTH_SUBSET_H
#define SYNTH_SUBSET_H

#include <uhdm/VpiListener.h>

#include <iostream>
#include <sstream>
#include <vector>
#include <utility>

namespace UHDM {
class Serializer;
class SynthSubset final : public VpiListener {
 public:
  SynthSubset(Serializer* serializer,
              std::set<const any*>& nonSynthesizableObjects, design* des, bool reportErrors, bool allowFormal);
  ~SynthSubset() override = default;
  void filterNonSynthesizable();
  void report(std::ostream& out);

 private:
  void leaveAny(const any* object, vpiHandle handle) override;
  void leaveSys_task_call(const sys_task_call* object,
                          vpiHandle handle) override;

  void leaveSys_func_call(const sys_func_call* object,
                          vpiHandle handle) override;

  void leaveTask(const task* object, vpiHandle handle) override;

  void leaveClass_typespec(const class_typespec* object,
                           vpiHandle handle) override;

  void leaveClass_var(const class_var* object, vpiHandle handle) override;

  // Apply some rewrite rule for Yosys limitations
  void leaveFor_stmt(const for_stmt* object, vpiHandle handle) override;

  // Apply some rewrite rule for Yosys limitations
  void leaveAlways(const always* object, vpiHandle handle) override;

  // Apply some rewrite rule for Synlig limitations
  void leaveRef_typespec(const ref_typespec* object, vpiHandle handle) override;

  // Signed/Unsigned port transform to allow Yosys to Synthesize
  void leavePort(const port* object, vpiHandle handle) override;

  // Typespec substitution to allow Yosys to perform RAM  Inference
  void leaveArray_var(const array_var* object, vpiHandle handle) override;

  // Remove Typespec information on allModules to allow Yosys to perform RAM Inference
  void leaveLogic_net(const logic_net* object, vpiHandle handle) override;

  void reportError(const any* object);
  void mark(const any* object);
  bool reportedParent(const any* object);

  void sensitivityListRewrite(const always* object, vpiHandle handle);
  void blockingToNonBlockingRewrite(const always* object, vpiHandle handle);

  void removeFromVector(VectorOfany* vec, const any* object);
  void removeFromStmt(any* parent, const any* object);
  sys_func_call* makeStubDisplayStmt(const any* object);

  Serializer* serializer_ = nullptr;
  std::set<const any*>& nonSynthesizableObjects_;
  std::set<std::string, std::less<>> nonSynthSysCalls_;
  design* design_;
  bool reportErrors_;
  bool allowFormal_;
  std::vector<std::pair<VectorOfany*, const any*>> m_scheduledFilteredObjectsInVector;
  std::vector<std::pair<any*, const any*>> m_scheduledFilteredObjectsInStmt;
};

}  // namespace UHDM

#endif
