// -*- c++ -*-

/*

 Copyright 2019 Alain Dargelas

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
 * File:   UhdmListener.h
 * Author: hs
 *
 * Created on March 11, 2022, 00:00 AM
 */

#ifndef UHDM_UHDMLISTENER_H
#define UHDM_UHDMLISTENER_H

#include <uhdm/containers.h>
#include <uhdm/sv_vpi_user.h>

#include <algorithm>
#include <unordered_set>
#include <vector>


namespace UHDM {
class ScopedVpiHandle final {
 public:
  ScopedVpiHandle(const UHDM::any *const any);
  ~ScopedVpiHandle();

  operator vpiHandle() const { return handle; }

 private:
  const vpiHandle handle = nullptr;
};

class UhdmListener {
protected:
  typedef std::unordered_set<const any *> any_set_t;
  typedef std::vector<const any *> any_stack_t;

  any_set_t visited;
  any_stack_t callstack;

public:
  // Use implicit constructor to initialize all members
  // VpiListener()
  virtual ~UhdmListener() = default;

public:
  any_set_t &getVisited() { return visited; }
  const any_set_t &getVisited() const { return visited; }

  const any_stack_t &getCallstack() const { return callstack; }

  bool isOnCallstack(const any *const what) const {
    return std::find(callstack.crbegin(), callstack.crend(), what) !=
           callstack.rend();
  }

  bool isOnCallstack(const std::unordered_set<UHDM_OBJECT_TYPE> &types) const {
    return std::find_if(callstack.crbegin(), callstack.crend(),
                        [&types](const any *const which) {
                          return types.find(which->UhdmType()) != types.end();
                        }) != callstack.rend();
  }

  bool didVisitAll(const Serializer &serializer) const;

  void listenAny(const any *const object);
  void listenAlias_stmt(const alias_stmt *const object);
  void listenAlways(const always *const object);
  void listenAny_pattern(const any_pattern *const object);
  void listenArray_expr(const array_expr *const object);
  void listenArray_net(const array_net *const object);
  void listenArray_typespec(const array_typespec *const object);
  void listenArray_var(const array_var *const object);
  void listenAssert_stmt(const assert_stmt *const object);
  void listenAssign_stmt(const assign_stmt *const object);
  void listenAssignment(const assignment *const object);
  void listenAssume(const assume *const object);
  void listenAttribute(const attribute *const object);
  void listenBegin(const begin *const object);
  void listenBit_select(const bit_select *const object);
  void listenBit_typespec(const bit_typespec *const object);
  void listenBit_var(const bit_var *const object);
  void listenBreak_stmt(const break_stmt *const object);
  void listenByte_typespec(const byte_typespec *const object);
  void listenByte_var(const byte_var *const object);
  void listenCase_item(const case_item *const object);
  void listenCase_property(const case_property *const object);
  void listenCase_property_item(const case_property_item *const object);
  void listenCase_stmt(const case_stmt *const object);
  void listenChandle_typespec(const chandle_typespec *const object);
  void listenChandle_var(const chandle_var *const object);
  void listenChecker_decl(const checker_decl *const object);
  void listenChecker_inst(const checker_inst *const object);
  void listenChecker_inst_port(const checker_inst_port *const object);
  void listenChecker_port(const checker_port *const object);
  void listenClass_defn(const class_defn *const object);
  void listenClass_obj(const class_obj *const object);
  void listenClass_typespec(const class_typespec *const object);
  void listenClass_var(const class_var *const object);
  void listenClocked_property(const clocked_property *const object);
  void listenClocked_seq(const clocked_seq *const object);
  void listenClocking_block(const clocking_block *const object);
  void listenClocking_io_decl(const clocking_io_decl *const object);
  void listenConstant(const constant *const object);
  void listenConstr_foreach(const constr_foreach *const object);
  void listenConstr_if(const constr_if *const object);
  void listenConstr_if_else(const constr_if_else *const object);
  void listenConstraint(const constraint *const object);
  void listenConstraint_ordering(const constraint_ordering *const object);
  void listenCont_assign(const cont_assign *const object);
  void listenCont_assign_bit(const cont_assign_bit *const object);
  void listenContinue_stmt(const continue_stmt *const object);
  void listenCover(const cover *const object);
  void listenDeassign(const deassign *const object);
  void listenDef_param(const def_param *const object);
  void listenDelay_control(const delay_control *const object);
  void listenDelay_term(const delay_term *const object);
  void listenDesign(const design *const object);
  void listenDisable(const disable *const object);
  void listenDisable_fork(const disable_fork *const object);
  void listenDist_item(const dist_item *const object);
  void listenDistribution(const distribution *const object);
  void listenDo_while(const do_while *const object);
  void listenEnum_const(const enum_const *const object);
  void listenEnum_net(const enum_net *const object);
  void listenEnum_typespec(const enum_typespec *const object);
  void listenEnum_var(const enum_var *const object);
  void listenEvent_control(const event_control *const object);
  void listenEvent_stmt(const event_stmt *const object);
  void listenEvent_typespec(const event_typespec *const object);
  void listenExpect_stmt(const expect_stmt *const object);
  void listenExtends(const extends *const object);
  void listenFinal_stmt(const final_stmt *const object);
  void listenFor_stmt(const for_stmt *const object);
  void listenForce(const force *const object);
  void listenForeach_stmt(const foreach_stmt *const object);
  void listenForever_stmt(const forever_stmt *const object);
  void listenFork_stmt(const fork_stmt *const object);
  void listenFunc_call(const func_call *const object);
  void listenFunction(const function *const object);
  void listenGate(const gate *const object);
  void listenGate_array(const gate_array *const object);
  void listenGen_case(const gen_case *const object);
  void listenGen_for(const gen_for *const object);
  void listenGen_if(const gen_if *const object);
  void listenGen_if_else(const gen_if_else *const object);
  void listenGen_region(const gen_region *const object);
  void listenGen_scope(const gen_scope *const object);
  void listenGen_scope_array(const gen_scope_array *const object);
  void listenGen_var(const gen_var *const object);
  void listenHier_path(const hier_path *const object);
  void listenIf_else(const if_else *const object);
  void listenIf_stmt(const if_stmt *const object);
  void listenImmediate_assert(const immediate_assert *const object);
  void listenImmediate_assume(const immediate_assume *const object);
  void listenImmediate_cover(const immediate_cover *const object);
  void listenImplication(const implication *const object);
  void listenImport_typespec(const import_typespec *const object);
  void listenInclude_file_info(const include_file_info *const object);
  void listenIndexed_part_select(const indexed_part_select *const object);
  void listenInitial(const initial *const object);
  void listenInt_typespec(const int_typespec *const object);
  void listenInt_var(const int_var *const object);
  void listenInteger_net(const integer_net *const object);
  void listenInteger_typespec(const integer_typespec *const object);
  void listenInteger_var(const integer_var *const object);
  void listenInterface_array(const interface_array *const object);
  void listenInterface_inst(const interface_inst *const object);
  void listenInterface_tf_decl(const interface_tf_decl *const object);
  void listenInterface_typespec(const interface_typespec *const object);
  void listenIo_decl(const io_decl *const object);
  void listenLet_decl(const let_decl *const object);
  void listenLet_expr(const let_expr *const object);
  void listenLogic_net(const logic_net *const object);
  void listenLogic_typespec(const logic_typespec *const object);
  void listenLogic_var(const logic_var *const object);
  void listenLong_int_typespec(const long_int_typespec *const object);
  void listenLong_int_var(const long_int_var *const object);
  void listenMethod_func_call(const method_func_call *const object);
  void listenMethod_task_call(const method_task_call *const object);
  void listenMod_path(const mod_path *const object);
  void listenModport(const modport *const object);
  void listenModule_array(const module_array *const object);
  void listenModule_inst(const module_inst *const object);
  void listenModule_typespec(const module_typespec *const object);
  void listenMulticlock_sequence_expr(const multiclock_sequence_expr *const object);
  void listenNamed_begin(const named_begin *const object);
  void listenNamed_event(const named_event *const object);
  void listenNamed_event_array(const named_event_array *const object);
  void listenNamed_fork(const named_fork *const object);
  void listenNet_bit(const net_bit *const object);
  void listenNull_stmt(const null_stmt *const object);
  void listenOperation(const operation *const object);
  void listenOrdered_wait(const ordered_wait *const object);
  void listenPackage(const package *const object);
  void listenPacked_array_net(const packed_array_net *const object);
  void listenPacked_array_typespec(const packed_array_typespec *const object);
  void listenPacked_array_var(const packed_array_var *const object);
  void listenParam_assign(const param_assign *const object);
  void listenParameter(const parameter *const object);
  void listenPart_select(const part_select *const object);
  void listenPath_term(const path_term *const object);
  void listenPort(const port *const object);
  void listenPort_bit(const port_bit *const object);
  void listenPrim_term(const prim_term *const object);
  void listenProgram(const program *const object);
  void listenProgram_array(const program_array *const object);
  void listenProp_formal_decl(const prop_formal_decl *const object);
  void listenProperty_decl(const property_decl *const object);
  void listenProperty_inst(const property_inst *const object);
  void listenProperty_spec(const property_spec *const object);
  void listenProperty_typespec(const property_typespec *const object);
  void listenRange(const range *const object);
  void listenReal_typespec(const real_typespec *const object);
  void listenReal_var(const real_var *const object);
  void listenRef_module(const ref_module *const object);
  void listenRef_obj(const ref_obj *const object);
  void listenRef_typespec(const ref_typespec *const object);
  void listenRef_var(const ref_var *const object);
  void listenReg(const reg *const object);
  void listenReg_array(const reg_array *const object);
  void listenRelease(const release *const object);
  void listenRepeat(const repeat *const object);
  void listenRepeat_control(const repeat_control *const object);
  void listenRestrict(const restrict *const object);
  void listenReturn_stmt(const return_stmt *const object);
  void listenSeq_formal_decl(const seq_formal_decl *const object);
  void listenSequence_decl(const sequence_decl *const object);
  void listenSequence_inst(const sequence_inst *const object);
  void listenSequence_typespec(const sequence_typespec *const object);
  void listenShort_int_typespec(const short_int_typespec *const object);
  void listenShort_int_var(const short_int_var *const object);
  void listenShort_real_typespec(const short_real_typespec *const object);
  void listenShort_real_var(const short_real_var *const object);
  void listenSoft_disable(const soft_disable *const object);
  void listenSpec_param(const spec_param *const object);
  void listenString_typespec(const string_typespec *const object);
  void listenString_var(const string_var *const object);
  void listenStruct_net(const struct_net *const object);
  void listenStruct_pattern(const struct_pattern *const object);
  void listenStruct_typespec(const struct_typespec *const object);
  void listenStruct_var(const struct_var *const object);
  void listenSwitch_array(const switch_array *const object);
  void listenSwitch_tran(const switch_tran *const object);
  void listenSys_func_call(const sys_func_call *const object);
  void listenSys_task_call(const sys_task_call *const object);
  void listenTable_entry(const table_entry *const object);
  void listenTagged_pattern(const tagged_pattern *const object);
  void listenTask(const task *const object);
  void listenTask_call(const task_call *const object);
  void listenTchk(const tchk *const object);
  void listenTchk_term(const tchk_term *const object);
  void listenThread_obj(const thread_obj *const object);
  void listenTime_net(const time_net *const object);
  void listenTime_typespec(const time_typespec *const object);
  void listenTime_var(const time_var *const object);
  void listenType_parameter(const type_parameter *const object);
  void listenTypespec_member(const typespec_member *const object);
  void listenUdp(const udp *const object);
  void listenUdp_array(const udp_array *const object);
  void listenUdp_defn(const udp_defn *const object);
  void listenUnion_typespec(const union_typespec *const object);
  void listenUnion_var(const union_var *const object);
  void listenUnsupported_expr(const unsupported_expr *const object);
  void listenUnsupported_stmt(const unsupported_stmt *const object);
  void listenUnsupported_typespec(const unsupported_typespec *const object);
  void listenUser_systf(const user_systf *const object);
  void listenVar_bit(const var_bit *const object);
  void listenVar_select(const var_select *const object);
  void listenVirtual_interface_var(const virtual_interface_var *const object);
  void listenVoid_typespec(const void_typespec *const object);
  void listenWait_fork(const wait_fork *const object);
  void listenWait_stmt(const wait_stmt *const object);
  void listenWhile_stmt(const while_stmt *const object);

  virtual void enterAny(const any* const object) {}
  virtual void leaveAny(const any* const object) {}

  virtual void enterAlias_stmt(const alias_stmt* const object) {}
  virtual void leaveAlias_stmt(const alias_stmt* const object) {}

  virtual void enterAlways(const always* const object) {}
  virtual void leaveAlways(const always* const object) {}

  virtual void enterAny_pattern(const any_pattern* const object) {}
  virtual void leaveAny_pattern(const any_pattern* const object) {}

  virtual void enterArray_expr(const array_expr* const object) {}
  virtual void leaveArray_expr(const array_expr* const object) {}

  virtual void enterArray_net(const array_net* const object) {}
  virtual void leaveArray_net(const array_net* const object) {}

  virtual void enterArray_typespec(const array_typespec* const object) {}
  virtual void leaveArray_typespec(const array_typespec* const object) {}

  virtual void enterArray_var(const array_var* const object) {}
  virtual void leaveArray_var(const array_var* const object) {}

  virtual void enterAssert_stmt(const assert_stmt* const object) {}
  virtual void leaveAssert_stmt(const assert_stmt* const object) {}

  virtual void enterAssign_stmt(const assign_stmt* const object) {}
  virtual void leaveAssign_stmt(const assign_stmt* const object) {}

  virtual void enterAssignment(const assignment* const object) {}
  virtual void leaveAssignment(const assignment* const object) {}

  virtual void enterAssume(const assume* const object) {}
  virtual void leaveAssume(const assume* const object) {}

  virtual void enterAttribute(const attribute* const object) {}
  virtual void leaveAttribute(const attribute* const object) {}

  virtual void enterBegin(const begin* const object) {}
  virtual void leaveBegin(const begin* const object) {}

  virtual void enterBit_select(const bit_select* const object) {}
  virtual void leaveBit_select(const bit_select* const object) {}

  virtual void enterBit_typespec(const bit_typespec* const object) {}
  virtual void leaveBit_typespec(const bit_typespec* const object) {}

  virtual void enterBit_var(const bit_var* const object) {}
  virtual void leaveBit_var(const bit_var* const object) {}

  virtual void enterBreak_stmt(const break_stmt* const object) {}
  virtual void leaveBreak_stmt(const break_stmt* const object) {}

  virtual void enterByte_typespec(const byte_typespec* const object) {}
  virtual void leaveByte_typespec(const byte_typespec* const object) {}

  virtual void enterByte_var(const byte_var* const object) {}
  virtual void leaveByte_var(const byte_var* const object) {}

  virtual void enterCase_item(const case_item* const object) {}
  virtual void leaveCase_item(const case_item* const object) {}

  virtual void enterCase_property(const case_property* const object) {}
  virtual void leaveCase_property(const case_property* const object) {}

  virtual void enterCase_property_item(const case_property_item* const object) {}
  virtual void leaveCase_property_item(const case_property_item* const object) {}

  virtual void enterCase_stmt(const case_stmt* const object) {}
  virtual void leaveCase_stmt(const case_stmt* const object) {}

  virtual void enterChandle_typespec(const chandle_typespec* const object) {}
  virtual void leaveChandle_typespec(const chandle_typespec* const object) {}

  virtual void enterChandle_var(const chandle_var* const object) {}
  virtual void leaveChandle_var(const chandle_var* const object) {}

  virtual void enterChecker_decl(const checker_decl* const object) {}
  virtual void leaveChecker_decl(const checker_decl* const object) {}

  virtual void enterChecker_inst(const checker_inst* const object) {}
  virtual void leaveChecker_inst(const checker_inst* const object) {}

  virtual void enterChecker_inst_port(const checker_inst_port* const object) {}
  virtual void leaveChecker_inst_port(const checker_inst_port* const object) {}

  virtual void enterChecker_port(const checker_port* const object) {}
  virtual void leaveChecker_port(const checker_port* const object) {}

  virtual void enterClass_defn(const class_defn* const object) {}
  virtual void leaveClass_defn(const class_defn* const object) {}

  virtual void enterClass_obj(const class_obj* const object) {}
  virtual void leaveClass_obj(const class_obj* const object) {}

  virtual void enterClass_typespec(const class_typespec* const object) {}
  virtual void leaveClass_typespec(const class_typespec* const object) {}

  virtual void enterClass_var(const class_var* const object) {}
  virtual void leaveClass_var(const class_var* const object) {}

  virtual void enterClocked_property(const clocked_property* const object) {}
  virtual void leaveClocked_property(const clocked_property* const object) {}

  virtual void enterClocked_seq(const clocked_seq* const object) {}
  virtual void leaveClocked_seq(const clocked_seq* const object) {}

  virtual void enterClocking_block(const clocking_block* const object) {}
  virtual void leaveClocking_block(const clocking_block* const object) {}

  virtual void enterClocking_io_decl(const clocking_io_decl* const object) {}
  virtual void leaveClocking_io_decl(const clocking_io_decl* const object) {}

  virtual void enterConstant(const constant* const object) {}
  virtual void leaveConstant(const constant* const object) {}

  virtual void enterConstr_foreach(const constr_foreach* const object) {}
  virtual void leaveConstr_foreach(const constr_foreach* const object) {}

  virtual void enterConstr_if(const constr_if* const object) {}
  virtual void leaveConstr_if(const constr_if* const object) {}

  virtual void enterConstr_if_else(const constr_if_else* const object) {}
  virtual void leaveConstr_if_else(const constr_if_else* const object) {}

  virtual void enterConstraint(const constraint* const object) {}
  virtual void leaveConstraint(const constraint* const object) {}

  virtual void enterConstraint_ordering(const constraint_ordering* const object) {}
  virtual void leaveConstraint_ordering(const constraint_ordering* const object) {}

  virtual void enterCont_assign(const cont_assign* const object) {}
  virtual void leaveCont_assign(const cont_assign* const object) {}

  virtual void enterCont_assign_bit(const cont_assign_bit* const object) {}
  virtual void leaveCont_assign_bit(const cont_assign_bit* const object) {}

  virtual void enterContinue_stmt(const continue_stmt* const object) {}
  virtual void leaveContinue_stmt(const continue_stmt* const object) {}

  virtual void enterCover(const cover* const object) {}
  virtual void leaveCover(const cover* const object) {}

  virtual void enterDeassign(const deassign* const object) {}
  virtual void leaveDeassign(const deassign* const object) {}

  virtual void enterDef_param(const def_param* const object) {}
  virtual void leaveDef_param(const def_param* const object) {}

  virtual void enterDelay_control(const delay_control* const object) {}
  virtual void leaveDelay_control(const delay_control* const object) {}

  virtual void enterDelay_term(const delay_term* const object) {}
  virtual void leaveDelay_term(const delay_term* const object) {}

  virtual void enterDesign(const design* const object) {}
  virtual void leaveDesign(const design* const object) {}

  virtual void enterDisable(const disable* const object) {}
  virtual void leaveDisable(const disable* const object) {}

  virtual void enterDisable_fork(const disable_fork* const object) {}
  virtual void leaveDisable_fork(const disable_fork* const object) {}

  virtual void enterDist_item(const dist_item* const object) {}
  virtual void leaveDist_item(const dist_item* const object) {}

  virtual void enterDistribution(const distribution* const object) {}
  virtual void leaveDistribution(const distribution* const object) {}

  virtual void enterDo_while(const do_while* const object) {}
  virtual void leaveDo_while(const do_while* const object) {}

  virtual void enterEnum_const(const enum_const* const object) {}
  virtual void leaveEnum_const(const enum_const* const object) {}

  virtual void enterEnum_net(const enum_net* const object) {}
  virtual void leaveEnum_net(const enum_net* const object) {}

  virtual void enterEnum_typespec(const enum_typespec* const object) {}
  virtual void leaveEnum_typespec(const enum_typespec* const object) {}

  virtual void enterEnum_var(const enum_var* const object) {}
  virtual void leaveEnum_var(const enum_var* const object) {}

  virtual void enterEvent_control(const event_control* const object) {}
  virtual void leaveEvent_control(const event_control* const object) {}

  virtual void enterEvent_stmt(const event_stmt* const object) {}
  virtual void leaveEvent_stmt(const event_stmt* const object) {}

  virtual void enterEvent_typespec(const event_typespec* const object) {}
  virtual void leaveEvent_typespec(const event_typespec* const object) {}

  virtual void enterExpect_stmt(const expect_stmt* const object) {}
  virtual void leaveExpect_stmt(const expect_stmt* const object) {}

  virtual void enterExtends(const extends* const object) {}
  virtual void leaveExtends(const extends* const object) {}

  virtual void enterFinal_stmt(const final_stmt* const object) {}
  virtual void leaveFinal_stmt(const final_stmt* const object) {}

  virtual void enterFor_stmt(const for_stmt* const object) {}
  virtual void leaveFor_stmt(const for_stmt* const object) {}

  virtual void enterForce(const force* const object) {}
  virtual void leaveForce(const force* const object) {}

  virtual void enterForeach_stmt(const foreach_stmt* const object) {}
  virtual void leaveForeach_stmt(const foreach_stmt* const object) {}

  virtual void enterForever_stmt(const forever_stmt* const object) {}
  virtual void leaveForever_stmt(const forever_stmt* const object) {}

  virtual void enterFork_stmt(const fork_stmt* const object) {}
  virtual void leaveFork_stmt(const fork_stmt* const object) {}

  virtual void enterFunc_call(const func_call* const object) {}
  virtual void leaveFunc_call(const func_call* const object) {}

  virtual void enterFunction(const function* const object) {}
  virtual void leaveFunction(const function* const object) {}

  virtual void enterGate(const gate* const object) {}
  virtual void leaveGate(const gate* const object) {}

  virtual void enterGate_array(const gate_array* const object) {}
  virtual void leaveGate_array(const gate_array* const object) {}

  virtual void enterGen_case(const gen_case* const object) {}
  virtual void leaveGen_case(const gen_case* const object) {}

  virtual void enterGen_for(const gen_for* const object) {}
  virtual void leaveGen_for(const gen_for* const object) {}

  virtual void enterGen_if(const gen_if* const object) {}
  virtual void leaveGen_if(const gen_if* const object) {}

  virtual void enterGen_if_else(const gen_if_else* const object) {}
  virtual void leaveGen_if_else(const gen_if_else* const object) {}

  virtual void enterGen_region(const gen_region* const object) {}
  virtual void leaveGen_region(const gen_region* const object) {}

  virtual void enterGen_scope(const gen_scope* const object) {}
  virtual void leaveGen_scope(const gen_scope* const object) {}

  virtual void enterGen_scope_array(const gen_scope_array* const object) {}
  virtual void leaveGen_scope_array(const gen_scope_array* const object) {}

  virtual void enterGen_var(const gen_var* const object) {}
  virtual void leaveGen_var(const gen_var* const object) {}

  virtual void enterHier_path(const hier_path* const object) {}
  virtual void leaveHier_path(const hier_path* const object) {}

  virtual void enterIf_else(const if_else* const object) {}
  virtual void leaveIf_else(const if_else* const object) {}

  virtual void enterIf_stmt(const if_stmt* const object) {}
  virtual void leaveIf_stmt(const if_stmt* const object) {}

  virtual void enterImmediate_assert(const immediate_assert* const object) {}
  virtual void leaveImmediate_assert(const immediate_assert* const object) {}

  virtual void enterImmediate_assume(const immediate_assume* const object) {}
  virtual void leaveImmediate_assume(const immediate_assume* const object) {}

  virtual void enterImmediate_cover(const immediate_cover* const object) {}
  virtual void leaveImmediate_cover(const immediate_cover* const object) {}

  virtual void enterImplication(const implication* const object) {}
  virtual void leaveImplication(const implication* const object) {}

  virtual void enterImport_typespec(const import_typespec* const object) {}
  virtual void leaveImport_typespec(const import_typespec* const object) {}

  virtual void enterInclude_file_info(const include_file_info* const object) {}
  virtual void leaveInclude_file_info(const include_file_info* const object) {}

  virtual void enterIndexed_part_select(const indexed_part_select* const object) {}
  virtual void leaveIndexed_part_select(const indexed_part_select* const object) {}

  virtual void enterInitial(const initial* const object) {}
  virtual void leaveInitial(const initial* const object) {}

  virtual void enterInt_typespec(const int_typespec* const object) {}
  virtual void leaveInt_typespec(const int_typespec* const object) {}

  virtual void enterInt_var(const int_var* const object) {}
  virtual void leaveInt_var(const int_var* const object) {}

  virtual void enterInteger_net(const integer_net* const object) {}
  virtual void leaveInteger_net(const integer_net* const object) {}

  virtual void enterInteger_typespec(const integer_typespec* const object) {}
  virtual void leaveInteger_typespec(const integer_typespec* const object) {}

  virtual void enterInteger_var(const integer_var* const object) {}
  virtual void leaveInteger_var(const integer_var* const object) {}

  virtual void enterInterface_array(const interface_array* const object) {}
  virtual void leaveInterface_array(const interface_array* const object) {}

  virtual void enterInterface_inst(const interface_inst* const object) {}
  virtual void leaveInterface_inst(const interface_inst* const object) {}

  virtual void enterInterface_tf_decl(const interface_tf_decl* const object) {}
  virtual void leaveInterface_tf_decl(const interface_tf_decl* const object) {}

  virtual void enterInterface_typespec(const interface_typespec* const object) {}
  virtual void leaveInterface_typespec(const interface_typespec* const object) {}

  virtual void enterIo_decl(const io_decl* const object) {}
  virtual void leaveIo_decl(const io_decl* const object) {}

  virtual void enterLet_decl(const let_decl* const object) {}
  virtual void leaveLet_decl(const let_decl* const object) {}

  virtual void enterLet_expr(const let_expr* const object) {}
  virtual void leaveLet_expr(const let_expr* const object) {}

  virtual void enterLogic_net(const logic_net* const object) {}
  virtual void leaveLogic_net(const logic_net* const object) {}

  virtual void enterLogic_typespec(const logic_typespec* const object) {}
  virtual void leaveLogic_typespec(const logic_typespec* const object) {}

  virtual void enterLogic_var(const logic_var* const object) {}
  virtual void leaveLogic_var(const logic_var* const object) {}

  virtual void enterLong_int_typespec(const long_int_typespec* const object) {}
  virtual void leaveLong_int_typespec(const long_int_typespec* const object) {}

  virtual void enterLong_int_var(const long_int_var* const object) {}
  virtual void leaveLong_int_var(const long_int_var* const object) {}

  virtual void enterMethod_func_call(const method_func_call* const object) {}
  virtual void leaveMethod_func_call(const method_func_call* const object) {}

  virtual void enterMethod_task_call(const method_task_call* const object) {}
  virtual void leaveMethod_task_call(const method_task_call* const object) {}

  virtual void enterMod_path(const mod_path* const object) {}
  virtual void leaveMod_path(const mod_path* const object) {}

  virtual void enterModport(const modport* const object) {}
  virtual void leaveModport(const modport* const object) {}

  virtual void enterModule_array(const module_array* const object) {}
  virtual void leaveModule_array(const module_array* const object) {}

  virtual void enterModule_inst(const module_inst* const object) {}
  virtual void leaveModule_inst(const module_inst* const object) {}

  virtual void enterModule_typespec(const module_typespec* const object) {}
  virtual void leaveModule_typespec(const module_typespec* const object) {}

  virtual void enterMulticlock_sequence_expr(const multiclock_sequence_expr* const object) {}
  virtual void leaveMulticlock_sequence_expr(const multiclock_sequence_expr* const object) {}

  virtual void enterNamed_begin(const named_begin* const object) {}
  virtual void leaveNamed_begin(const named_begin* const object) {}

  virtual void enterNamed_event(const named_event* const object) {}
  virtual void leaveNamed_event(const named_event* const object) {}

  virtual void enterNamed_event_array(const named_event_array* const object) {}
  virtual void leaveNamed_event_array(const named_event_array* const object) {}

  virtual void enterNamed_fork(const named_fork* const object) {}
  virtual void leaveNamed_fork(const named_fork* const object) {}

  virtual void enterNet_bit(const net_bit* const object) {}
  virtual void leaveNet_bit(const net_bit* const object) {}

  virtual void enterNull_stmt(const null_stmt* const object) {}
  virtual void leaveNull_stmt(const null_stmt* const object) {}

  virtual void enterOperation(const operation* const object) {}
  virtual void leaveOperation(const operation* const object) {}

  virtual void enterOrdered_wait(const ordered_wait* const object) {}
  virtual void leaveOrdered_wait(const ordered_wait* const object) {}

  virtual void enterPackage(const package* const object) {}
  virtual void leavePackage(const package* const object) {}

  virtual void enterPacked_array_net(const packed_array_net* const object) {}
  virtual void leavePacked_array_net(const packed_array_net* const object) {}

  virtual void enterPacked_array_typespec(const packed_array_typespec* const object) {}
  virtual void leavePacked_array_typespec(const packed_array_typespec* const object) {}

  virtual void enterPacked_array_var(const packed_array_var* const object) {}
  virtual void leavePacked_array_var(const packed_array_var* const object) {}

  virtual void enterParam_assign(const param_assign* const object) {}
  virtual void leaveParam_assign(const param_assign* const object) {}

  virtual void enterParameter(const parameter* const object) {}
  virtual void leaveParameter(const parameter* const object) {}

  virtual void enterPart_select(const part_select* const object) {}
  virtual void leavePart_select(const part_select* const object) {}

  virtual void enterPath_term(const path_term* const object) {}
  virtual void leavePath_term(const path_term* const object) {}

  virtual void enterPort(const port* const object) {}
  virtual void leavePort(const port* const object) {}

  virtual void enterPort_bit(const port_bit* const object) {}
  virtual void leavePort_bit(const port_bit* const object) {}

  virtual void enterPrim_term(const prim_term* const object) {}
  virtual void leavePrim_term(const prim_term* const object) {}

  virtual void enterProgram(const program* const object) {}
  virtual void leaveProgram(const program* const object) {}

  virtual void enterProgram_array(const program_array* const object) {}
  virtual void leaveProgram_array(const program_array* const object) {}

  virtual void enterProp_formal_decl(const prop_formal_decl* const object) {}
  virtual void leaveProp_formal_decl(const prop_formal_decl* const object) {}

  virtual void enterProperty_decl(const property_decl* const object) {}
  virtual void leaveProperty_decl(const property_decl* const object) {}

  virtual void enterProperty_inst(const property_inst* const object) {}
  virtual void leaveProperty_inst(const property_inst* const object) {}

  virtual void enterProperty_spec(const property_spec* const object) {}
  virtual void leaveProperty_spec(const property_spec* const object) {}

  virtual void enterProperty_typespec(const property_typespec* const object) {}
  virtual void leaveProperty_typespec(const property_typespec* const object) {}

  virtual void enterRange(const range* const object) {}
  virtual void leaveRange(const range* const object) {}

  virtual void enterReal_typespec(const real_typespec* const object) {}
  virtual void leaveReal_typespec(const real_typespec* const object) {}

  virtual void enterReal_var(const real_var* const object) {}
  virtual void leaveReal_var(const real_var* const object) {}

  virtual void enterRef_module(const ref_module* const object) {}
  virtual void leaveRef_module(const ref_module* const object) {}

  virtual void enterRef_obj(const ref_obj* const object) {}
  virtual void leaveRef_obj(const ref_obj* const object) {}

  virtual void enterRef_typespec(const ref_typespec* const object) {}
  virtual void leaveRef_typespec(const ref_typespec* const object) {}

  virtual void enterRef_var(const ref_var* const object) {}
  virtual void leaveRef_var(const ref_var* const object) {}

  virtual void enterReg(const reg* const object) {}
  virtual void leaveReg(const reg* const object) {}

  virtual void enterReg_array(const reg_array* const object) {}
  virtual void leaveReg_array(const reg_array* const object) {}

  virtual void enterRelease(const release* const object) {}
  virtual void leaveRelease(const release* const object) {}

  virtual void enterRepeat(const repeat* const object) {}
  virtual void leaveRepeat(const repeat* const object) {}

  virtual void enterRepeat_control(const repeat_control* const object) {}
  virtual void leaveRepeat_control(const repeat_control* const object) {}

  virtual void enterRestrict(const restrict* const object) {}
  virtual void leaveRestrict(const restrict* const object) {}

  virtual void enterReturn_stmt(const return_stmt* const object) {}
  virtual void leaveReturn_stmt(const return_stmt* const object) {}

  virtual void enterSeq_formal_decl(const seq_formal_decl* const object) {}
  virtual void leaveSeq_formal_decl(const seq_formal_decl* const object) {}

  virtual void enterSequence_decl(const sequence_decl* const object) {}
  virtual void leaveSequence_decl(const sequence_decl* const object) {}

  virtual void enterSequence_inst(const sequence_inst* const object) {}
  virtual void leaveSequence_inst(const sequence_inst* const object) {}

  virtual void enterSequence_typespec(const sequence_typespec* const object) {}
  virtual void leaveSequence_typespec(const sequence_typespec* const object) {}

  virtual void enterShort_int_typespec(const short_int_typespec* const object) {}
  virtual void leaveShort_int_typespec(const short_int_typespec* const object) {}

  virtual void enterShort_int_var(const short_int_var* const object) {}
  virtual void leaveShort_int_var(const short_int_var* const object) {}

  virtual void enterShort_real_typespec(const short_real_typespec* const object) {}
  virtual void leaveShort_real_typespec(const short_real_typespec* const object) {}

  virtual void enterShort_real_var(const short_real_var* const object) {}
  virtual void leaveShort_real_var(const short_real_var* const object) {}

  virtual void enterSoft_disable(const soft_disable* const object) {}
  virtual void leaveSoft_disable(const soft_disable* const object) {}

  virtual void enterSpec_param(const spec_param* const object) {}
  virtual void leaveSpec_param(const spec_param* const object) {}

  virtual void enterString_typespec(const string_typespec* const object) {}
  virtual void leaveString_typespec(const string_typespec* const object) {}

  virtual void enterString_var(const string_var* const object) {}
  virtual void leaveString_var(const string_var* const object) {}

  virtual void enterStruct_net(const struct_net* const object) {}
  virtual void leaveStruct_net(const struct_net* const object) {}

  virtual void enterStruct_pattern(const struct_pattern* const object) {}
  virtual void leaveStruct_pattern(const struct_pattern* const object) {}

  virtual void enterStruct_typespec(const struct_typespec* const object) {}
  virtual void leaveStruct_typespec(const struct_typespec* const object) {}

  virtual void enterStruct_var(const struct_var* const object) {}
  virtual void leaveStruct_var(const struct_var* const object) {}

  virtual void enterSwitch_array(const switch_array* const object) {}
  virtual void leaveSwitch_array(const switch_array* const object) {}

  virtual void enterSwitch_tran(const switch_tran* const object) {}
  virtual void leaveSwitch_tran(const switch_tran* const object) {}

  virtual void enterSys_func_call(const sys_func_call* const object) {}
  virtual void leaveSys_func_call(const sys_func_call* const object) {}

  virtual void enterSys_task_call(const sys_task_call* const object) {}
  virtual void leaveSys_task_call(const sys_task_call* const object) {}

  virtual void enterTable_entry(const table_entry* const object) {}
  virtual void leaveTable_entry(const table_entry* const object) {}

  virtual void enterTagged_pattern(const tagged_pattern* const object) {}
  virtual void leaveTagged_pattern(const tagged_pattern* const object) {}

  virtual void enterTask(const task* const object) {}
  virtual void leaveTask(const task* const object) {}

  virtual void enterTask_call(const task_call* const object) {}
  virtual void leaveTask_call(const task_call* const object) {}

  virtual void enterTchk(const tchk* const object) {}
  virtual void leaveTchk(const tchk* const object) {}

  virtual void enterTchk_term(const tchk_term* const object) {}
  virtual void leaveTchk_term(const tchk_term* const object) {}

  virtual void enterThread_obj(const thread_obj* const object) {}
  virtual void leaveThread_obj(const thread_obj* const object) {}

  virtual void enterTime_net(const time_net* const object) {}
  virtual void leaveTime_net(const time_net* const object) {}

  virtual void enterTime_typespec(const time_typespec* const object) {}
  virtual void leaveTime_typespec(const time_typespec* const object) {}

  virtual void enterTime_var(const time_var* const object) {}
  virtual void leaveTime_var(const time_var* const object) {}

  virtual void enterType_parameter(const type_parameter* const object) {}
  virtual void leaveType_parameter(const type_parameter* const object) {}

  virtual void enterTypespec_member(const typespec_member* const object) {}
  virtual void leaveTypespec_member(const typespec_member* const object) {}

  virtual void enterUdp(const udp* const object) {}
  virtual void leaveUdp(const udp* const object) {}

  virtual void enterUdp_array(const udp_array* const object) {}
  virtual void leaveUdp_array(const udp_array* const object) {}

  virtual void enterUdp_defn(const udp_defn* const object) {}
  virtual void leaveUdp_defn(const udp_defn* const object) {}

  virtual void enterUnion_typespec(const union_typespec* const object) {}
  virtual void leaveUnion_typespec(const union_typespec* const object) {}

  virtual void enterUnion_var(const union_var* const object) {}
  virtual void leaveUnion_var(const union_var* const object) {}

  virtual void enterUnsupported_expr(const unsupported_expr* const object) {}
  virtual void leaveUnsupported_expr(const unsupported_expr* const object) {}

  virtual void enterUnsupported_stmt(const unsupported_stmt* const object) {}
  virtual void leaveUnsupported_stmt(const unsupported_stmt* const object) {}

  virtual void enterUnsupported_typespec(const unsupported_typespec* const object) {}
  virtual void leaveUnsupported_typespec(const unsupported_typespec* const object) {}

  virtual void enterUser_systf(const user_systf* const object) {}
  virtual void leaveUser_systf(const user_systf* const object) {}

  virtual void enterVar_bit(const var_bit* const object) {}
  virtual void leaveVar_bit(const var_bit* const object) {}

  virtual void enterVar_select(const var_select* const object) {}
  virtual void leaveVar_select(const var_select* const object) {}

  virtual void enterVirtual_interface_var(const virtual_interface_var* const object) {}
  virtual void leaveVirtual_interface_var(const virtual_interface_var* const object) {}

  virtual void enterVoid_typespec(const void_typespec* const object) {}
  virtual void leaveVoid_typespec(const void_typespec* const object) {}

  virtual void enterWait_fork(const wait_fork* const object) {}
  virtual void leaveWait_fork(const wait_fork* const object) {}

  virtual void enterWait_stmt(const wait_stmt* const object) {}
  virtual void leaveWait_stmt(const wait_stmt* const object) {}

  virtual void enterWhile_stmt(const while_stmt* const object) {}
  virtual void leaveWhile_stmt(const while_stmt* const object) {}

  virtual void enterAlias_stmts(const any* const object, const VectorOfalias_stmt& objects) {}
  virtual void leaveAlias_stmts(const any* const object, const VectorOfalias_stmt& objects) {}

  virtual void enterAllClasses(const any* const object, const VectorOfclass_defn& objects) {}
  virtual void leaveAllClasses(const any* const object, const VectorOfclass_defn& objects) {}

  virtual void enterAllInterfaces(const any* const object, const VectorOfinterface_inst& objects) {}
  virtual void leaveAllInterfaces(const any* const object, const VectorOfinterface_inst& objects) {}

  virtual void enterAllModules(const any* const object, const VectorOfmodule_inst& objects) {}
  virtual void leaveAllModules(const any* const object, const VectorOfmodule_inst& objects) {}

  virtual void enterAllPackages(const any* const object, const VectorOfpackage& objects) {}
  virtual void leaveAllPackages(const any* const object, const VectorOfpackage& objects) {}

  virtual void enterAllPrograms(const any* const object, const VectorOfprogram& objects) {}
  virtual void leaveAllPrograms(const any* const object, const VectorOfprogram& objects) {}

  virtual void enterAllUdps(const any* const object, const VectorOfudp_defn& objects) {}
  virtual void leaveAllUdps(const any* const object, const VectorOfudp_defn& objects) {}

  virtual void enterArguments(const any* const object, const VectorOfexpr& objects) {}
  virtual void leaveArguments(const any* const object, const VectorOfexpr& objects) {}

  virtual void enterArray_nets(const any* const object, const VectorOfarray_net& objects) {}
  virtual void leaveArray_nets(const any* const object, const VectorOfarray_net& objects) {}

  virtual void enterArray_var_mems(const any* const object, const VectorOfarray_var& objects) {}
  virtual void leaveArray_var_mems(const any* const object, const VectorOfarray_var& objects) {}

  virtual void enterArray_vars(const any* const object, const VectorOfarray_var& objects) {}
  virtual void leaveArray_vars(const any* const object, const VectorOfarray_var& objects) {}

  virtual void enterAssertions(const any* const object, const VectorOfany& objects) {}
  virtual void leaveAssertions(const any* const object, const VectorOfany& objects) {}

  virtual void enterAttributes(const any* const object, const VectorOfattribute& objects) {}
  virtual void leaveAttributes(const any* const object, const VectorOfattribute& objects) {}

  virtual void enterBits(const any* const object, const VectorOfport_bit& objects) {}
  virtual void leaveBits(const any* const object, const VectorOfport_bit& objects) {}

  virtual void enterCase_items(const any* const object, const VectorOfcase_item& objects) {}
  virtual void leaveCase_items(const any* const object, const VectorOfcase_item& objects) {}

  virtual void enterCase_property_items(const any* const object, const VectorOfcase_property_item& objects) {}
  virtual void leaveCase_property_items(const any* const object, const VectorOfcase_property_item& objects) {}

  virtual void enterClass_defns(const any* const object, const VectorOfclass_defn& objects) {}
  virtual void leaveClass_defns(const any* const object, const VectorOfclass_defn& objects) {}

  virtual void enterClass_typespecs(const any* const object, const VectorOfclass_typespec& objects) {}
  virtual void leaveClass_typespecs(const any* const object, const VectorOfclass_typespec& objects) {}

  virtual void enterClocked_seqs(const any* const object, const VectorOfclocked_seq& objects) {}
  virtual void leaveClocked_seqs(const any* const object, const VectorOfclocked_seq& objects) {}

  virtual void enterClocking_blocks(const any* const object, const VectorOfclocking_block& objects) {}
  virtual void leaveClocking_blocks(const any* const object, const VectorOfclocking_block& objects) {}

  virtual void enterClocking_io_decls(const any* const object, const VectorOfclocking_io_decl& objects) {}
  virtual void leaveClocking_io_decls(const any* const object, const VectorOfclocking_io_decl& objects) {}

  virtual void enterConcurrent_assertions(const any* const object, const VectorOfconcurrent_assertions& objects) {}
  virtual void leaveConcurrent_assertions(const any* const object, const VectorOfconcurrent_assertions& objects) {}

  virtual void enterConstraint_exprs(const any* const object, const VectorOfconstraint_expr& objects) {}
  virtual void leaveConstraint_exprs(const any* const object, const VectorOfconstraint_expr& objects) {}

  virtual void enterConstraint_items(const any* const object, const VectorOfany& objects) {}
  virtual void leaveConstraint_items(const any* const object, const VectorOfany& objects) {}

  virtual void enterConstraints(const any* const object, const VectorOfconstraint& objects) {}
  virtual void leaveConstraints(const any* const object, const VectorOfconstraint& objects) {}

  virtual void enterCont_assign_bits(const any* const object, const VectorOfcont_assign_bit& objects) {}
  virtual void leaveCont_assign_bits(const any* const object, const VectorOfcont_assign_bit& objects) {}

  virtual void enterCont_assigns(const any* const object, const VectorOfcont_assign& objects) {}
  virtual void leaveCont_assigns(const any* const object, const VectorOfcont_assign& objects) {}

  virtual void enterDef_params(const any* const object, const VectorOfdef_param& objects) {}
  virtual void leaveDef_params(const any* const object, const VectorOfdef_param& objects) {}

  virtual void enterDeriveds(const any* const object, const VectorOfclass_defn& objects) {}
  virtual void leaveDeriveds(const any* const object, const VectorOfclass_defn& objects) {}

  virtual void enterDist_items(const any* const object, const VectorOfdist_item& objects) {}
  virtual void leaveDist_items(const any* const object, const VectorOfdist_item& objects) {}

  virtual void enterDrivers(const any* const object, const VectorOfnet_drivers& objects) {}
  virtual void leaveDrivers(const any* const object, const VectorOfnet_drivers& objects) {}

  virtual void enterElab_tasks(const any* const object, const VectorOftf_call& objects) {}
  virtual void leaveElab_tasks(const any* const object, const VectorOftf_call& objects) {}

  virtual void enterElements(const any* const object, const VectorOfany& objects) {}
  virtual void leaveElements(const any* const object, const VectorOfany& objects) {}

  virtual void enterElse_constraint_exprs(const any* const object, const VectorOfconstraint_expr& objects) {}
  virtual void leaveElse_constraint_exprs(const any* const object, const VectorOfconstraint_expr& objects) {}

  virtual void enterEnum_consts(const any* const object, const VectorOfenum_const& objects) {}
  virtual void leaveEnum_consts(const any* const object, const VectorOfenum_const& objects) {}

  virtual void enterExpr_indexes(const any* const object, const VectorOfexpr& objects) {}
  virtual void leaveExpr_indexes(const any* const object, const VectorOfexpr& objects) {}

  virtual void enterExpr_tchk_terms(const any* const object, const VectorOfany& objects) {}
  virtual void leaveExpr_tchk_terms(const any* const object, const VectorOfany& objects) {}

  virtual void enterExpressions(const any* const object, const VectorOfexpr& objects) {}
  virtual void leaveExpressions(const any* const object, const VectorOfexpr& objects) {}

  virtual void enterExprs(const any* const object, const VectorOfexpr& objects) {}
  virtual void leaveExprs(const any* const object, const VectorOfexpr& objects) {}

  virtual void enterFunctions(const any* const object, const VectorOffunction& objects) {}
  virtual void leaveFunctions(const any* const object, const VectorOffunction& objects) {}

  virtual void enterGen_scope_arrays(const any* const object, const VectorOfgen_scope_array& objects) {}
  virtual void leaveGen_scope_arrays(const any* const object, const VectorOfgen_scope_array& objects) {}

  virtual void enterGen_scopes(const any* const object, const VectorOfgen_scope& objects) {}
  virtual void leaveGen_scopes(const any* const object, const VectorOfgen_scope& objects) {}

  virtual void enterGen_stmts(const any* const object, const VectorOfgen_stmt& objects) {}
  virtual void leaveGen_stmts(const any* const object, const VectorOfgen_stmt& objects) {}

  virtual void enterInclude_file_infos(const any* const object, const VectorOfinclude_file_info& objects) {}
  virtual void leaveInclude_file_infos(const any* const object, const VectorOfinclude_file_info& objects) {}

  virtual void enterIndexes(const any* const object, const VectorOfexpr& objects) {}
  virtual void leaveIndexes(const any* const object, const VectorOfexpr& objects) {}

  virtual void enterInstance_items(const any* const object, const VectorOfany& objects) {}
  virtual void leaveInstance_items(const any* const object, const VectorOfany& objects) {}

  virtual void enterInstances(const any* const object, const VectorOfinstance& objects) {}
  virtual void leaveInstances(const any* const object, const VectorOfinstance& objects) {}

  virtual void enterInterface_arrays(const any* const object, const VectorOfinterface_array& objects) {}
  virtual void leaveInterface_arrays(const any* const object, const VectorOfinterface_array& objects) {}

  virtual void enterInterface_tf_decls(const any* const object, const VectorOfinterface_tf_decl& objects) {}
  virtual void leaveInterface_tf_decls(const any* const object, const VectorOfinterface_tf_decl& objects) {}

  virtual void enterInterfaces(const any* const object, const VectorOfinterface_inst& objects) {}
  virtual void leaveInterfaces(const any* const object, const VectorOfinterface_inst& objects) {}

  virtual void enterIo_decls(const any* const object, const VectorOfio_decl& objects) {}
  virtual void leaveIo_decls(const any* const object, const VectorOfio_decl& objects) {}

  virtual void enterLet_decls(const any* const object, const VectorOflet_decl& objects) {}
  virtual void leaveLet_decls(const any* const object, const VectorOflet_decl& objects) {}

  virtual void enterLoads(const any* const object, const VectorOfnet_loads& objects) {}
  virtual void leaveLoads(const any* const object, const VectorOfnet_loads& objects) {}

  virtual void enterLocal_drivers(const any* const object, const VectorOfnet_drivers& objects) {}
  virtual void leaveLocal_drivers(const any* const object, const VectorOfnet_drivers& objects) {}

  virtual void enterLocal_loads(const any* const object, const VectorOfnet_loads& objects) {}
  virtual void leaveLocal_loads(const any* const object, const VectorOfnet_loads& objects) {}

  virtual void enterLogic_vars(const any* const object, const VectorOflogic_var& objects) {}
  virtual void leaveLogic_vars(const any* const object, const VectorOflogic_var& objects) {}

  virtual void enterMembers(const any* const object, const VectorOftypespec_member& objects) {}
  virtual void leaveMembers(const any* const object, const VectorOftypespec_member& objects) {}

  virtual void enterMessages(const any* const object, const VectorOfexpr& objects) {}
  virtual void leaveMessages(const any* const object, const VectorOfexpr& objects) {}

  virtual void enterMod_paths(const any* const object, const VectorOfmod_path& objects) {}
  virtual void leaveMod_paths(const any* const object, const VectorOfmod_path& objects) {}

  virtual void enterModports(const any* const object, const VectorOfmodport& objects) {}
  virtual void leaveModports(const any* const object, const VectorOfmodport& objects) {}

  virtual void enterModule_arrays(const any* const object, const VectorOfmodule_array& objects) {}
  virtual void leaveModule_arrays(const any* const object, const VectorOfmodule_array& objects) {}

  virtual void enterModules(const any* const object, const VectorOfmodule_inst& objects) {}
  virtual void leaveModules(const any* const object, const VectorOfmodule_inst& objects) {}

  virtual void enterNamed_event_arrays(const any* const object, const VectorOfnamed_event_array& objects) {}
  virtual void leaveNamed_event_arrays(const any* const object, const VectorOfnamed_event_array& objects) {}

  virtual void enterNamed_event_sequence_expr_groups(const any* const object, const VectorOfany& objects) {}
  virtual void leaveNamed_event_sequence_expr_groups(const any* const object, const VectorOfany& objects) {}

  virtual void enterNamed_events(const any* const object, const VectorOfnamed_event& objects) {}
  virtual void leaveNamed_events(const any* const object, const VectorOfnamed_event& objects) {}

  virtual void enterNet_bits(const any* const object, const VectorOfnet_bit& objects) {}
  virtual void leaveNet_bits(const any* const object, const VectorOfnet_bit& objects) {}

  virtual void enterNets(const any* const object, const VectorOfnet& objects) {}
  virtual void leaveNets(const any* const object, const VectorOfnet& objects) {}

  virtual void enterNets(const any* const object, const VectorOfnets& objects) {}
  virtual void leaveNets(const any* const object, const VectorOfnets& objects) {}

  virtual void enterOperands(const any* const object, const VectorOfany& objects) {}
  virtual void leaveOperands(const any* const object, const VectorOfany& objects) {}

  virtual void enterParam_assigns(const any* const object, const VectorOfparam_assign& objects) {}
  virtual void leaveParam_assigns(const any* const object, const VectorOfparam_assign& objects) {}

  virtual void enterParameters(const any* const object, const VectorOfany& objects) {}
  virtual void leaveParameters(const any* const object, const VectorOfany& objects) {}

  virtual void enterPath_elems(const any* const object, const VectorOfany& objects) {}
  virtual void leavePath_elems(const any* const object, const VectorOfany& objects) {}

  virtual void enterPath_terms(const any* const object, const VectorOfpath_term& objects) {}
  virtual void leavePath_terms(const any* const object, const VectorOfpath_term& objects) {}

  virtual void enterPorts(const any* const object, const VectorOfchecker_inst_port& objects) {}
  virtual void leavePorts(const any* const object, const VectorOfchecker_inst_port& objects) {}

  virtual void enterPorts(const any* const object, const VectorOfchecker_port& objects) {}
  virtual void leavePorts(const any* const object, const VectorOfchecker_port& objects) {}

  virtual void enterPorts(const any* const object, const VectorOfport& objects) {}
  virtual void leavePorts(const any* const object, const VectorOfport& objects) {}

  virtual void enterPorts(const any* const object, const VectorOfports& objects) {}
  virtual void leavePorts(const any* const object, const VectorOfports& objects) {}

  virtual void enterPrim_terms(const any* const object, const VectorOfprim_term& objects) {}
  virtual void leavePrim_terms(const any* const object, const VectorOfprim_term& objects) {}

  virtual void enterPrimitive_arrays(const any* const object, const VectorOfprimitive_array& objects) {}
  virtual void leavePrimitive_arrays(const any* const object, const VectorOfprimitive_array& objects) {}

  virtual void enterPrimitives(const any* const object, const VectorOfprimitive& objects) {}
  virtual void leavePrimitives(const any* const object, const VectorOfprimitive& objects) {}

  virtual void enterProcess(const any* const object, const VectorOfprocess_stmt& objects) {}
  virtual void leaveProcess(const any* const object, const VectorOfprocess_stmt& objects) {}

  virtual void enterProgram_arrays(const any* const object, const VectorOfprogram& objects) {}
  virtual void leaveProgram_arrays(const any* const object, const VectorOfprogram& objects) {}

  virtual void enterPrograms(const any* const object, const VectorOfprogram& objects) {}
  virtual void leavePrograms(const any* const object, const VectorOfprogram& objects) {}

  virtual void enterProp_formal_decls(const any* const object, const VectorOfprop_formal_decl& objects) {}
  virtual void leaveProp_formal_decls(const any* const object, const VectorOfprop_formal_decl& objects) {}

  virtual void enterProperty_decls(const any* const object, const VectorOfproperty_decl& objects) {}
  virtual void leaveProperty_decls(const any* const object, const VectorOfproperty_decl& objects) {}

  virtual void enterRanges(const any* const object, const VectorOfrange& objects) {}
  virtual void leaveRanges(const any* const object, const VectorOfrange& objects) {}

  virtual void enterRef_modules(const any* const object, const VectorOfref_module& objects) {}
  virtual void leaveRef_modules(const any* const object, const VectorOfref_module& objects) {}

  virtual void enterRegs(const any* const object, const VectorOfreg& objects) {}
  virtual void leaveRegs(const any* const object, const VectorOfreg& objects) {}

  virtual void enterScopes(const any* const object, const VectorOfscope& objects) {}
  virtual void leaveScopes(const any* const object, const VectorOfscope& objects) {}

  virtual void enterSeq_formal_decls(const any* const object, const VectorOfseq_formal_decl& objects) {}
  virtual void leaveSeq_formal_decls(const any* const object, const VectorOfseq_formal_decl& objects) {}

  virtual void enterSequence_decls(const any* const object, const VectorOfsequence_decl& objects) {}
  virtual void leaveSequence_decls(const any* const object, const VectorOfsequence_decl& objects) {}

  virtual void enterSolve_afters(const any* const object, const VectorOfexpr& objects) {}
  virtual void leaveSolve_afters(const any* const object, const VectorOfexpr& objects) {}

  virtual void enterSolve_befores(const any* const object, const VectorOfexpr& objects) {}
  virtual void leaveSolve_befores(const any* const object, const VectorOfexpr& objects) {}

  virtual void enterSpec_params(const any* const object, const VectorOfspec_param& objects) {}
  virtual void leaveSpec_params(const any* const object, const VectorOfspec_param& objects) {}

  virtual void enterStmts(const any* const object, const VectorOfany& objects) {}
  virtual void leaveStmts(const any* const object, const VectorOfany& objects) {}

  virtual void enterTable_entrys(const any* const object, const VectorOftable_entry& objects) {}
  virtual void leaveTable_entrys(const any* const object, const VectorOftable_entry& objects) {}

  virtual void enterTask_funcs(const any* const object, const VectorOftask_func& objects) {}
  virtual void leaveTask_funcs(const any* const object, const VectorOftask_func& objects) {}

  virtual void enterTasks(const any* const object, const VectorOftask& objects) {}
  virtual void leaveTasks(const any* const object, const VectorOftask& objects) {}

  virtual void enterTchk_terms(const any* const object, const VectorOftchk_term& objects) {}
  virtual void leaveTchk_terms(const any* const object, const VectorOftchk_term& objects) {}

  virtual void enterTchks(const any* const object, const VectorOftchk& objects) {}
  virtual void leaveTchks(const any* const object, const VectorOftchk& objects) {}

  virtual void enterTf_call_args(const any* const object, const VectorOfany& objects) {}
  virtual void leaveTf_call_args(const any* const object, const VectorOfany& objects) {}

  virtual void enterThreads(const any* const object, const VectorOfthread_obj& objects) {}
  virtual void leaveThreads(const any* const object, const VectorOfthread_obj& objects) {}

  virtual void enterTopModules(const any* const object, const VectorOfmodule_inst& objects) {}
  virtual void leaveTopModules(const any* const object, const VectorOfmodule_inst& objects) {}

  virtual void enterTopPackages(const any* const object, const VectorOfpackage& objects) {}
  virtual void leaveTopPackages(const any* const object, const VectorOfpackage& objects) {}

  virtual void enterTypespecs(const any* const object, const VectorOftypespec& objects) {}
  virtual void leaveTypespecs(const any* const object, const VectorOftypespec& objects) {}

  virtual void enterVar_bits(const any* const object, const VectorOfvar_bit& objects) {}
  virtual void leaveVar_bits(const any* const object, const VectorOfvar_bit& objects) {}

  virtual void enterVar_selects(const any* const object, const VectorOfvar_select& objects) {}
  virtual void leaveVar_selects(const any* const object, const VectorOfvar_select& objects) {}

  virtual void enterVariable_drivers(const any* const object, const VectorOfany& objects) {}
  virtual void leaveVariable_drivers(const any* const object, const VectorOfany& objects) {}

  virtual void enterVariable_loads(const any* const object, const VectorOfany& objects) {}
  virtual void leaveVariable_loads(const any* const object, const VectorOfany& objects) {}

  virtual void enterVariables(const any* const object, const VectorOfvariables& objects) {}
  virtual void leaveVariables(const any* const object, const VectorOfvariables& objects) {}

  virtual void enterVirtual_interface_vars(const any* const object, const VectorOfvirtual_interface_var& objects) {}
  virtual void leaveVirtual_interface_vars(const any* const object, const VectorOfvirtual_interface_var& objects) {}

  virtual void enterVpiArguments(const any* const object, const VectorOfany& objects) {}
  virtual void leaveVpiArguments(const any* const object, const VectorOfany& objects) {}

  virtual void enterVpiConditions(const any* const object, const VectorOfany& objects) {}
  virtual void leaveVpiConditions(const any* const object, const VectorOfany& objects) {}

  virtual void enterVpiExprs(const any* const object, const VectorOfany& objects) {}
  virtual void leaveVpiExprs(const any* const object, const VectorOfany& objects) {}

  virtual void enterVpiForIncStmts(const any* const object, const VectorOfany& objects) {}
  virtual void leaveVpiForIncStmts(const any* const object, const VectorOfany& objects) {}

  virtual void enterVpiForInitStmts(const any* const object, const VectorOfany& objects) {}
  virtual void leaveVpiForInitStmts(const any* const object, const VectorOfany& objects) {}

  virtual void enterVpiLoopVars(const any* const object, const VectorOfany& objects) {}
  virtual void leaveVpiLoopVars(const any* const object, const VectorOfany& objects) {}

  virtual void enterVpiUses(const any* const object, const VectorOfany& objects) {}
  virtual void leaveVpiUses(const any* const object, const VectorOfany& objects) {}

private:
  void listenBaseClass_(const any *const object);
  void listenAlias_stmt_(const alias_stmt* const object);
  void listenAlways_(const always* const object);
  void listenAny_pattern_(const any_pattern* const object);
  void listenArray_expr_(const array_expr* const object);
  void listenArray_net_(const array_net* const object);
  void listenArray_typespec_(const array_typespec* const object);
  void listenArray_var_(const array_var* const object);
  void listenAssert_stmt_(const assert_stmt* const object);
  void listenAssign_stmt_(const assign_stmt* const object);
  void listenAssignment_(const assignment* const object);
  void listenAssume_(const assume* const object);
  void listenAtomic_stmt_(const atomic_stmt* const object);
  void listenAttribute_(const attribute* const object);
  void listenBegin_(const begin* const object);
  void listenBit_select_(const bit_select* const object);
  void listenBit_typespec_(const bit_typespec* const object);
  void listenBit_var_(const bit_var* const object);
  void listenBreak_stmt_(const break_stmt* const object);
  void listenByte_typespec_(const byte_typespec* const object);
  void listenByte_var_(const byte_var* const object);
  void listenCase_item_(const case_item* const object);
  void listenCase_property_(const case_property* const object);
  void listenCase_property_item_(const case_property_item* const object);
  void listenCase_stmt_(const case_stmt* const object);
  void listenChandle_typespec_(const chandle_typespec* const object);
  void listenChandle_var_(const chandle_var* const object);
  void listenChecker_decl_(const checker_decl* const object);
  void listenChecker_inst_(const checker_inst* const object);
  void listenChecker_inst_port_(const checker_inst_port* const object);
  void listenChecker_port_(const checker_port* const object);
  void listenClass_defn_(const class_defn* const object);
  void listenClass_obj_(const class_obj* const object);
  void listenClass_typespec_(const class_typespec* const object);
  void listenClass_var_(const class_var* const object);
  void listenClocked_property_(const clocked_property* const object);
  void listenClocked_seq_(const clocked_seq* const object);
  void listenClocking_block_(const clocking_block* const object);
  void listenClocking_io_decl_(const clocking_io_decl* const object);
  void listenConcurrent_assertions_(const concurrent_assertions* const object);
  void listenConstant_(const constant* const object);
  void listenConstr_foreach_(const constr_foreach* const object);
  void listenConstr_if_(const constr_if* const object);
  void listenConstr_if_else_(const constr_if_else* const object);
  void listenConstraint_(const constraint* const object);
  void listenConstraint_expr_(const constraint_expr* const object);
  void listenConstraint_ordering_(const constraint_ordering* const object);
  void listenCont_assign_(const cont_assign* const object);
  void listenCont_assign_bit_(const cont_assign_bit* const object);
  void listenContinue_stmt_(const continue_stmt* const object);
  void listenCover_(const cover* const object);
  void listenDeassign_(const deassign* const object);
  void listenDef_param_(const def_param* const object);
  void listenDelay_control_(const delay_control* const object);
  void listenDelay_term_(const delay_term* const object);
  void listenDesign_(const design* const object);
  void listenDisable_(const disable* const object);
  void listenDisable_fork_(const disable_fork* const object);
  void listenDisables_(const disables* const object);
  void listenDist_item_(const dist_item* const object);
  void listenDistribution_(const distribution* const object);
  void listenDo_while_(const do_while* const object);
  void listenEnum_const_(const enum_const* const object);
  void listenEnum_net_(const enum_net* const object);
  void listenEnum_typespec_(const enum_typespec* const object);
  void listenEnum_var_(const enum_var* const object);
  void listenEvent_control_(const event_control* const object);
  void listenEvent_stmt_(const event_stmt* const object);
  void listenEvent_typespec_(const event_typespec* const object);
  void listenExpect_stmt_(const expect_stmt* const object);
  void listenExpr_(const expr* const object);
  void listenExtends_(const extends* const object);
  void listenFinal_stmt_(const final_stmt* const object);
  void listenFor_stmt_(const for_stmt* const object);
  void listenForce_(const force* const object);
  void listenForeach_stmt_(const foreach_stmt* const object);
  void listenForever_stmt_(const forever_stmt* const object);
  void listenFork_stmt_(const fork_stmt* const object);
  void listenFunc_call_(const func_call* const object);
  void listenFunction_(const function* const object);
  void listenGate_(const gate* const object);
  void listenGate_array_(const gate_array* const object);
  void listenGen_case_(const gen_case* const object);
  void listenGen_for_(const gen_for* const object);
  void listenGen_if_(const gen_if* const object);
  void listenGen_if_else_(const gen_if_else* const object);
  void listenGen_region_(const gen_region* const object);
  void listenGen_scope_(const gen_scope* const object);
  void listenGen_scope_array_(const gen_scope_array* const object);
  void listenGen_stmt_(const gen_stmt* const object);
  void listenGen_var_(const gen_var* const object);
  void listenHier_path_(const hier_path* const object);
  void listenIf_else_(const if_else* const object);
  void listenIf_stmt_(const if_stmt* const object);
  void listenImmediate_assert_(const immediate_assert* const object);
  void listenImmediate_assume_(const immediate_assume* const object);
  void listenImmediate_cover_(const immediate_cover* const object);
  void listenImplication_(const implication* const object);
  void listenImport_typespec_(const import_typespec* const object);
  void listenInclude_file_info_(const include_file_info* const object);
  void listenIndexed_part_select_(const indexed_part_select* const object);
  void listenInitial_(const initial* const object);
  void listenInstance_(const instance* const object);
  void listenInstance_array_(const instance_array* const object);
  void listenInt_typespec_(const int_typespec* const object);
  void listenInt_var_(const int_var* const object);
  void listenInteger_net_(const integer_net* const object);
  void listenInteger_typespec_(const integer_typespec* const object);
  void listenInteger_var_(const integer_var* const object);
  void listenInterface_array_(const interface_array* const object);
  void listenInterface_inst_(const interface_inst* const object);
  void listenInterface_tf_decl_(const interface_tf_decl* const object);
  void listenInterface_typespec_(const interface_typespec* const object);
  void listenIo_decl_(const io_decl* const object);
  void listenLet_decl_(const let_decl* const object);
  void listenLet_expr_(const let_expr* const object);
  void listenLogic_net_(const logic_net* const object);
  void listenLogic_typespec_(const logic_typespec* const object);
  void listenLogic_var_(const logic_var* const object);
  void listenLong_int_typespec_(const long_int_typespec* const object);
  void listenLong_int_var_(const long_int_var* const object);
  void listenMethod_func_call_(const method_func_call* const object);
  void listenMethod_task_call_(const method_task_call* const object);
  void listenMod_path_(const mod_path* const object);
  void listenModport_(const modport* const object);
  void listenModule_array_(const module_array* const object);
  void listenModule_inst_(const module_inst* const object);
  void listenModule_typespec_(const module_typespec* const object);
  void listenMulticlock_sequence_expr_(const multiclock_sequence_expr* const object);
  void listenNamed_begin_(const named_begin* const object);
  void listenNamed_event_(const named_event* const object);
  void listenNamed_event_array_(const named_event_array* const object);
  void listenNamed_fork_(const named_fork* const object);
  void listenNet_(const net* const object);
  void listenNet_bit_(const net_bit* const object);
  void listenNets_(const nets* const object);
  void listenNull_stmt_(const null_stmt* const object);
  void listenOperation_(const operation* const object);
  void listenOrdered_wait_(const ordered_wait* const object);
  void listenPackage_(const package* const object);
  void listenPacked_array_net_(const packed_array_net* const object);
  void listenPacked_array_typespec_(const packed_array_typespec* const object);
  void listenPacked_array_var_(const packed_array_var* const object);
  void listenParam_assign_(const param_assign* const object);
  void listenParameter_(const parameter* const object);
  void listenPart_select_(const part_select* const object);
  void listenPath_term_(const path_term* const object);
  void listenPort_(const port* const object);
  void listenPort_bit_(const port_bit* const object);
  void listenPorts_(const ports* const object);
  void listenPrim_term_(const prim_term* const object);
  void listenPrimitive_(const primitive* const object);
  void listenPrimitive_array_(const primitive_array* const object);
  void listenProcess_stmt_(const process_stmt* const object);
  void listenProgram_(const program* const object);
  void listenProgram_array_(const program_array* const object);
  void listenProp_formal_decl_(const prop_formal_decl* const object);
  void listenProperty_decl_(const property_decl* const object);
  void listenProperty_inst_(const property_inst* const object);
  void listenProperty_spec_(const property_spec* const object);
  void listenProperty_typespec_(const property_typespec* const object);
  void listenRange_(const range* const object);
  void listenReal_typespec_(const real_typespec* const object);
  void listenReal_var_(const real_var* const object);
  void listenRef_module_(const ref_module* const object);
  void listenRef_obj_(const ref_obj* const object);
  void listenRef_typespec_(const ref_typespec* const object);
  void listenRef_var_(const ref_var* const object);
  void listenReg_(const reg* const object);
  void listenReg_array_(const reg_array* const object);
  void listenRelease_(const release* const object);
  void listenRepeat_(const repeat* const object);
  void listenRepeat_control_(const repeat_control* const object);
  void listenRestrict_(const restrict* const object);
  void listenReturn_stmt_(const return_stmt* const object);
  void listenScope_(const scope* const object);
  void listenSeq_formal_decl_(const seq_formal_decl* const object);
  void listenSequence_decl_(const sequence_decl* const object);
  void listenSequence_inst_(const sequence_inst* const object);
  void listenSequence_typespec_(const sequence_typespec* const object);
  void listenShort_int_typespec_(const short_int_typespec* const object);
  void listenShort_int_var_(const short_int_var* const object);
  void listenShort_real_typespec_(const short_real_typespec* const object);
  void listenShort_real_var_(const short_real_var* const object);
  void listenSimple_expr_(const simple_expr* const object);
  void listenSoft_disable_(const soft_disable* const object);
  void listenSpec_param_(const spec_param* const object);
  void listenString_typespec_(const string_typespec* const object);
  void listenString_var_(const string_var* const object);
  void listenStruct_net_(const struct_net* const object);
  void listenStruct_pattern_(const struct_pattern* const object);
  void listenStruct_typespec_(const struct_typespec* const object);
  void listenStruct_var_(const struct_var* const object);
  void listenSwitch_array_(const switch_array* const object);
  void listenSwitch_tran_(const switch_tran* const object);
  void listenSys_func_call_(const sys_func_call* const object);
  void listenSys_task_call_(const sys_task_call* const object);
  void listenTable_entry_(const table_entry* const object);
  void listenTagged_pattern_(const tagged_pattern* const object);
  void listenTask_(const task* const object);
  void listenTask_call_(const task_call* const object);
  void listenTask_func_(const task_func* const object);
  void listenTchk_(const tchk* const object);
  void listenTchk_term_(const tchk_term* const object);
  void listenTf_call_(const tf_call* const object);
  void listenThread_obj_(const thread_obj* const object);
  void listenTime_net_(const time_net* const object);
  void listenTime_typespec_(const time_typespec* const object);
  void listenTime_var_(const time_var* const object);
  void listenType_parameter_(const type_parameter* const object);
  void listenTypespec_(const typespec* const object);
  void listenTypespec_member_(const typespec_member* const object);
  void listenUdp_(const udp* const object);
  void listenUdp_array_(const udp_array* const object);
  void listenUdp_defn_(const udp_defn* const object);
  void listenUnion_typespec_(const union_typespec* const object);
  void listenUnion_var_(const union_var* const object);
  void listenUnsupported_expr_(const unsupported_expr* const object);
  void listenUnsupported_stmt_(const unsupported_stmt* const object);
  void listenUnsupported_typespec_(const unsupported_typespec* const object);
  void listenUser_systf_(const user_systf* const object);
  void listenVar_bit_(const var_bit* const object);
  void listenVar_select_(const var_select* const object);
  void listenVariables_(const variables* const object);
  void listenVirtual_interface_var_(const virtual_interface_var* const object);
  void listenVoid_typespec_(const void_typespec* const object);
  void listenWait_fork_(const wait_fork* const object);
  void listenWait_stmt_(const wait_stmt* const object);
  void listenWaits_(const waits* const object);
  void listenWhile_stmt_(const while_stmt* const object);
};
}  // namespace UHDM


#endif  // UHDM_UHDMLISTENER_H
