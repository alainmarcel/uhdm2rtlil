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
 * File:   VpiListener.h
 * Author: alaindargelas
 *
 * Created on December 14, 2019, 10:03 PM
 */

#ifndef UHDM_VPILISTENER_H
#define UHDM_VPILISTENER_H

#include <uhdm/containers.h>
#include <uhdm/vpi_user.h>

namespace UHDM {
class VpiListener {
protected:
  typedef std::vector<const any *> any_stack_t;

  VisitedContainer visited;
  any_stack_t callstack;

public:
  // Use implicit constructor to initialize all members
  // VpiListener()

  virtual ~VpiListener() = default;

public:
  void listenAny(vpiHandle handle);
  void listenDesigns(const std::vector<vpiHandle>& designs);
  void listenAlias_stmt(vpiHandle handle);
  void listenAlways(vpiHandle handle);
  void listenAny_pattern(vpiHandle handle);
  void listenArray_expr(vpiHandle handle);
  void listenArray_net(vpiHandle handle);
  void listenArray_typespec(vpiHandle handle);
  void listenArray_var(vpiHandle handle);
  void listenAssert_stmt(vpiHandle handle);
  void listenAssign_stmt(vpiHandle handle);
  void listenAssignment(vpiHandle handle);
  void listenAssume(vpiHandle handle);
  void listenAttribute(vpiHandle handle);
  void listenBegin(vpiHandle handle);
  void listenBit_select(vpiHandle handle);
  void listenBit_typespec(vpiHandle handle);
  void listenBit_var(vpiHandle handle);
  void listenBreak_stmt(vpiHandle handle);
  void listenByte_typespec(vpiHandle handle);
  void listenByte_var(vpiHandle handle);
  void listenCase_item(vpiHandle handle);
  void listenCase_property(vpiHandle handle);
  void listenCase_property_item(vpiHandle handle);
  void listenCase_stmt(vpiHandle handle);
  void listenChandle_typespec(vpiHandle handle);
  void listenChandle_var(vpiHandle handle);
  void listenChecker_decl(vpiHandle handle);
  void listenChecker_inst(vpiHandle handle);
  void listenChecker_inst_port(vpiHandle handle);
  void listenChecker_port(vpiHandle handle);
  void listenClass_defn(vpiHandle handle);
  void listenClass_obj(vpiHandle handle);
  void listenClass_typespec(vpiHandle handle);
  void listenClass_var(vpiHandle handle);
  void listenClocked_property(vpiHandle handle);
  void listenClocked_seq(vpiHandle handle);
  void listenClocking_block(vpiHandle handle);
  void listenClocking_io_decl(vpiHandle handle);
  void listenConstant(vpiHandle handle);
  void listenConstr_foreach(vpiHandle handle);
  void listenConstr_if(vpiHandle handle);
  void listenConstr_if_else(vpiHandle handle);
  void listenConstraint(vpiHandle handle);
  void listenConstraint_ordering(vpiHandle handle);
  void listenCont_assign(vpiHandle handle);
  void listenCont_assign_bit(vpiHandle handle);
  void listenContinue_stmt(vpiHandle handle);
  void listenCover(vpiHandle handle);
  void listenDeassign(vpiHandle handle);
  void listenDef_param(vpiHandle handle);
  void listenDelay_control(vpiHandle handle);
  void listenDelay_term(vpiHandle handle);
  void listenDesign(vpiHandle handle);
  void listenDisable(vpiHandle handle);
  void listenDisable_fork(vpiHandle handle);
  void listenDist_item(vpiHandle handle);
  void listenDistribution(vpiHandle handle);
  void listenDo_while(vpiHandle handle);
  void listenEnum_const(vpiHandle handle);
  void listenEnum_net(vpiHandle handle);
  void listenEnum_typespec(vpiHandle handle);
  void listenEnum_var(vpiHandle handle);
  void listenEvent_control(vpiHandle handle);
  void listenEvent_stmt(vpiHandle handle);
  void listenEvent_typespec(vpiHandle handle);
  void listenExpect_stmt(vpiHandle handle);
  void listenExtends(vpiHandle handle);
  void listenFinal_stmt(vpiHandle handle);
  void listenFor_stmt(vpiHandle handle);
  void listenForce(vpiHandle handle);
  void listenForeach_stmt(vpiHandle handle);
  void listenForever_stmt(vpiHandle handle);
  void listenFork_stmt(vpiHandle handle);
  void listenFunc_call(vpiHandle handle);
  void listenFunction(vpiHandle handle);
  void listenGate(vpiHandle handle);
  void listenGate_array(vpiHandle handle);
  void listenGen_case(vpiHandle handle);
  void listenGen_for(vpiHandle handle);
  void listenGen_if(vpiHandle handle);
  void listenGen_if_else(vpiHandle handle);
  void listenGen_region(vpiHandle handle);
  void listenGen_scope(vpiHandle handle);
  void listenGen_scope_array(vpiHandle handle);
  void listenGen_var(vpiHandle handle);
  void listenHier_path(vpiHandle handle);
  void listenIf_else(vpiHandle handle);
  void listenIf_stmt(vpiHandle handle);
  void listenImmediate_assert(vpiHandle handle);
  void listenImmediate_assume(vpiHandle handle);
  void listenImmediate_cover(vpiHandle handle);
  void listenImplication(vpiHandle handle);
  void listenImport_typespec(vpiHandle handle);
  void listenInclude_file_info(vpiHandle handle);
  void listenIndexed_part_select(vpiHandle handle);
  void listenInitial(vpiHandle handle);
  void listenInt_typespec(vpiHandle handle);
  void listenInt_var(vpiHandle handle);
  void listenInteger_net(vpiHandle handle);
  void listenInteger_typespec(vpiHandle handle);
  void listenInteger_var(vpiHandle handle);
  void listenInterface_array(vpiHandle handle);
  void listenInterface_inst(vpiHandle handle);
  void listenInterface_tf_decl(vpiHandle handle);
  void listenInterface_typespec(vpiHandle handle);
  void listenIo_decl(vpiHandle handle);
  void listenLet_decl(vpiHandle handle);
  void listenLet_expr(vpiHandle handle);
  void listenLogic_net(vpiHandle handle);
  void listenLogic_typespec(vpiHandle handle);
  void listenLogic_var(vpiHandle handle);
  void listenLong_int_typespec(vpiHandle handle);
  void listenLong_int_var(vpiHandle handle);
  void listenMethod_func_call(vpiHandle handle);
  void listenMethod_task_call(vpiHandle handle);
  void listenMod_path(vpiHandle handle);
  void listenModport(vpiHandle handle);
  void listenModule_array(vpiHandle handle);
  void listenModule_inst(vpiHandle handle);
  void listenModule_typespec(vpiHandle handle);
  void listenMulticlock_sequence_expr(vpiHandle handle);
  void listenNamed_begin(vpiHandle handle);
  void listenNamed_event(vpiHandle handle);
  void listenNamed_event_array(vpiHandle handle);
  void listenNamed_fork(vpiHandle handle);
  void listenNet_bit(vpiHandle handle);
  void listenNull_stmt(vpiHandle handle);
  void listenOperation(vpiHandle handle);
  void listenOrdered_wait(vpiHandle handle);
  void listenPackage(vpiHandle handle);
  void listenPacked_array_net(vpiHandle handle);
  void listenPacked_array_typespec(vpiHandle handle);
  void listenPacked_array_var(vpiHandle handle);
  void listenParam_assign(vpiHandle handle);
  void listenParameter(vpiHandle handle);
  void listenPart_select(vpiHandle handle);
  void listenPath_term(vpiHandle handle);
  void listenPort(vpiHandle handle);
  void listenPort_bit(vpiHandle handle);
  void listenPrim_term(vpiHandle handle);
  void listenProgram(vpiHandle handle);
  void listenProgram_array(vpiHandle handle);
  void listenProp_formal_decl(vpiHandle handle);
  void listenProperty_decl(vpiHandle handle);
  void listenProperty_inst(vpiHandle handle);
  void listenProperty_spec(vpiHandle handle);
  void listenProperty_typespec(vpiHandle handle);
  void listenRange(vpiHandle handle);
  void listenReal_typespec(vpiHandle handle);
  void listenReal_var(vpiHandle handle);
  void listenRef_module(vpiHandle handle);
  void listenRef_obj(vpiHandle handle);
  void listenRef_typespec(vpiHandle handle);
  void listenRef_var(vpiHandle handle);
  void listenReg(vpiHandle handle);
  void listenReg_array(vpiHandle handle);
  void listenRelease(vpiHandle handle);
  void listenRepeat(vpiHandle handle);
  void listenRepeat_control(vpiHandle handle);
  void listenRestrict(vpiHandle handle);
  void listenReturn_stmt(vpiHandle handle);
  void listenSeq_formal_decl(vpiHandle handle);
  void listenSequence_decl(vpiHandle handle);
  void listenSequence_inst(vpiHandle handle);
  void listenSequence_typespec(vpiHandle handle);
  void listenShort_int_typespec(vpiHandle handle);
  void listenShort_int_var(vpiHandle handle);
  void listenShort_real_typespec(vpiHandle handle);
  void listenShort_real_var(vpiHandle handle);
  void listenSoft_disable(vpiHandle handle);
  void listenSpec_param(vpiHandle handle);
  void listenString_typespec(vpiHandle handle);
  void listenString_var(vpiHandle handle);
  void listenStruct_net(vpiHandle handle);
  void listenStruct_pattern(vpiHandle handle);
  void listenStruct_typespec(vpiHandle handle);
  void listenStruct_var(vpiHandle handle);
  void listenSwitch_array(vpiHandle handle);
  void listenSwitch_tran(vpiHandle handle);
  void listenSys_func_call(vpiHandle handle);
  void listenSys_task_call(vpiHandle handle);
  void listenTable_entry(vpiHandle handle);
  void listenTagged_pattern(vpiHandle handle);
  void listenTask(vpiHandle handle);
  void listenTask_call(vpiHandle handle);
  void listenTchk(vpiHandle handle);
  void listenTchk_term(vpiHandle handle);
  void listenThread_obj(vpiHandle handle);
  void listenTime_net(vpiHandle handle);
  void listenTime_typespec(vpiHandle handle);
  void listenTime_var(vpiHandle handle);
  void listenType_parameter(vpiHandle handle);
  void listenTypespec_member(vpiHandle handle);
  void listenUdp(vpiHandle handle);
  void listenUdp_array(vpiHandle handle);
  void listenUdp_defn(vpiHandle handle);
  void listenUnion_typespec(vpiHandle handle);
  void listenUnion_var(vpiHandle handle);
  void listenUnsupported_expr(vpiHandle handle);
  void listenUnsupported_stmt(vpiHandle handle);
  void listenUnsupported_typespec(vpiHandle handle);
  void listenUser_systf(vpiHandle handle);
  void listenVar_bit(vpiHandle handle);
  void listenVar_select(vpiHandle handle);
  void listenVirtual_interface_var(vpiHandle handle);
  void listenVoid_typespec(vpiHandle handle);
  void listenWait_fork(vpiHandle handle);
  void listenWait_stmt(vpiHandle handle);
  void listenWhile_stmt(vpiHandle handle);

  virtual void enterAny(const any* object, vpiHandle handle) {}
  virtual void leaveAny(const any* object, vpiHandle handle) {}

  virtual void enterAlias_stmt(const alias_stmt* object, vpiHandle handle) {}
  virtual void leaveAlias_stmt(const alias_stmt* object, vpiHandle handle) {}

  virtual void enterAlways(const always* object, vpiHandle handle) {}
  virtual void leaveAlways(const always* object, vpiHandle handle) {}

  virtual void enterAny_pattern(const any_pattern* object, vpiHandle handle) {}
  virtual void leaveAny_pattern(const any_pattern* object, vpiHandle handle) {}

  virtual void enterArray_expr(const array_expr* object, vpiHandle handle) {}
  virtual void leaveArray_expr(const array_expr* object, vpiHandle handle) {}

  virtual void enterArray_net(const array_net* object, vpiHandle handle) {}
  virtual void leaveArray_net(const array_net* object, vpiHandle handle) {}

  virtual void enterArray_typespec(const array_typespec* object, vpiHandle handle) {}
  virtual void leaveArray_typespec(const array_typespec* object, vpiHandle handle) {}

  virtual void enterArray_var(const array_var* object, vpiHandle handle) {}
  virtual void leaveArray_var(const array_var* object, vpiHandle handle) {}

  virtual void enterAssert_stmt(const assert_stmt* object, vpiHandle handle) {}
  virtual void leaveAssert_stmt(const assert_stmt* object, vpiHandle handle) {}

  virtual void enterAssign_stmt(const assign_stmt* object, vpiHandle handle) {}
  virtual void leaveAssign_stmt(const assign_stmt* object, vpiHandle handle) {}

  virtual void enterAssignment(const assignment* object, vpiHandle handle) {}
  virtual void leaveAssignment(const assignment* object, vpiHandle handle) {}

  virtual void enterAssume(const assume* object, vpiHandle handle) {}
  virtual void leaveAssume(const assume* object, vpiHandle handle) {}

  virtual void enterAttribute(const attribute* object, vpiHandle handle) {}
  virtual void leaveAttribute(const attribute* object, vpiHandle handle) {}

  virtual void enterBegin(const begin* object, vpiHandle handle) {}
  virtual void leaveBegin(const begin* object, vpiHandle handle) {}

  virtual void enterBit_select(const bit_select* object, vpiHandle handle) {}
  virtual void leaveBit_select(const bit_select* object, vpiHandle handle) {}

  virtual void enterBit_typespec(const bit_typespec* object, vpiHandle handle) {}
  virtual void leaveBit_typespec(const bit_typespec* object, vpiHandle handle) {}

  virtual void enterBit_var(const bit_var* object, vpiHandle handle) {}
  virtual void leaveBit_var(const bit_var* object, vpiHandle handle) {}

  virtual void enterBreak_stmt(const break_stmt* object, vpiHandle handle) {}
  virtual void leaveBreak_stmt(const break_stmt* object, vpiHandle handle) {}

  virtual void enterByte_typespec(const byte_typespec* object, vpiHandle handle) {}
  virtual void leaveByte_typespec(const byte_typespec* object, vpiHandle handle) {}

  virtual void enterByte_var(const byte_var* object, vpiHandle handle) {}
  virtual void leaveByte_var(const byte_var* object, vpiHandle handle) {}

  virtual void enterCase_item(const case_item* object, vpiHandle handle) {}
  virtual void leaveCase_item(const case_item* object, vpiHandle handle) {}

  virtual void enterCase_property(const case_property* object, vpiHandle handle) {}
  virtual void leaveCase_property(const case_property* object, vpiHandle handle) {}

  virtual void enterCase_property_item(const case_property_item* object, vpiHandle handle) {}
  virtual void leaveCase_property_item(const case_property_item* object, vpiHandle handle) {}

  virtual void enterCase_stmt(const case_stmt* object, vpiHandle handle) {}
  virtual void leaveCase_stmt(const case_stmt* object, vpiHandle handle) {}

  virtual void enterChandle_typespec(const chandle_typespec* object, vpiHandle handle) {}
  virtual void leaveChandle_typespec(const chandle_typespec* object, vpiHandle handle) {}

  virtual void enterChandle_var(const chandle_var* object, vpiHandle handle) {}
  virtual void leaveChandle_var(const chandle_var* object, vpiHandle handle) {}

  virtual void enterChecker_decl(const checker_decl* object, vpiHandle handle) {}
  virtual void leaveChecker_decl(const checker_decl* object, vpiHandle handle) {}

  virtual void enterChecker_inst(const checker_inst* object, vpiHandle handle) {}
  virtual void leaveChecker_inst(const checker_inst* object, vpiHandle handle) {}

  virtual void enterChecker_inst_port(const checker_inst_port* object, vpiHandle handle) {}
  virtual void leaveChecker_inst_port(const checker_inst_port* object, vpiHandle handle) {}

  virtual void enterChecker_port(const checker_port* object, vpiHandle handle) {}
  virtual void leaveChecker_port(const checker_port* object, vpiHandle handle) {}

  virtual void enterClass_defn(const class_defn* object, vpiHandle handle) {}
  virtual void leaveClass_defn(const class_defn* object, vpiHandle handle) {}

  virtual void enterClass_obj(const class_obj* object, vpiHandle handle) {}
  virtual void leaveClass_obj(const class_obj* object, vpiHandle handle) {}

  virtual void enterClass_typespec(const class_typespec* object, vpiHandle handle) {}
  virtual void leaveClass_typespec(const class_typespec* object, vpiHandle handle) {}

  virtual void enterClass_var(const class_var* object, vpiHandle handle) {}
  virtual void leaveClass_var(const class_var* object, vpiHandle handle) {}

  virtual void enterClocked_property(const clocked_property* object, vpiHandle handle) {}
  virtual void leaveClocked_property(const clocked_property* object, vpiHandle handle) {}

  virtual void enterClocked_seq(const clocked_seq* object, vpiHandle handle) {}
  virtual void leaveClocked_seq(const clocked_seq* object, vpiHandle handle) {}

  virtual void enterClocking_block(const clocking_block* object, vpiHandle handle) {}
  virtual void leaveClocking_block(const clocking_block* object, vpiHandle handle) {}

  virtual void enterClocking_io_decl(const clocking_io_decl* object, vpiHandle handle) {}
  virtual void leaveClocking_io_decl(const clocking_io_decl* object, vpiHandle handle) {}

  virtual void enterConstant(const constant* object, vpiHandle handle) {}
  virtual void leaveConstant(const constant* object, vpiHandle handle) {}

  virtual void enterConstr_foreach(const constr_foreach* object, vpiHandle handle) {}
  virtual void leaveConstr_foreach(const constr_foreach* object, vpiHandle handle) {}

  virtual void enterConstr_if(const constr_if* object, vpiHandle handle) {}
  virtual void leaveConstr_if(const constr_if* object, vpiHandle handle) {}

  virtual void enterConstr_if_else(const constr_if_else* object, vpiHandle handle) {}
  virtual void leaveConstr_if_else(const constr_if_else* object, vpiHandle handle) {}

  virtual void enterConstraint(const constraint* object, vpiHandle handle) {}
  virtual void leaveConstraint(const constraint* object, vpiHandle handle) {}

  virtual void enterConstraint_ordering(const constraint_ordering* object, vpiHandle handle) {}
  virtual void leaveConstraint_ordering(const constraint_ordering* object, vpiHandle handle) {}

  virtual void enterCont_assign(const cont_assign* object, vpiHandle handle) {}
  virtual void leaveCont_assign(const cont_assign* object, vpiHandle handle) {}

  virtual void enterCont_assign_bit(const cont_assign_bit* object, vpiHandle handle) {}
  virtual void leaveCont_assign_bit(const cont_assign_bit* object, vpiHandle handle) {}

  virtual void enterContinue_stmt(const continue_stmt* object, vpiHandle handle) {}
  virtual void leaveContinue_stmt(const continue_stmt* object, vpiHandle handle) {}

  virtual void enterCover(const cover* object, vpiHandle handle) {}
  virtual void leaveCover(const cover* object, vpiHandle handle) {}

  virtual void enterDeassign(const deassign* object, vpiHandle handle) {}
  virtual void leaveDeassign(const deassign* object, vpiHandle handle) {}

  virtual void enterDef_param(const def_param* object, vpiHandle handle) {}
  virtual void leaveDef_param(const def_param* object, vpiHandle handle) {}

  virtual void enterDelay_control(const delay_control* object, vpiHandle handle) {}
  virtual void leaveDelay_control(const delay_control* object, vpiHandle handle) {}

  virtual void enterDelay_term(const delay_term* object, vpiHandle handle) {}
  virtual void leaveDelay_term(const delay_term* object, vpiHandle handle) {}

  virtual void enterDesign(const design* object, vpiHandle handle) {}
  virtual void leaveDesign(const design* object, vpiHandle handle) {}

  virtual void enterDisable(const disable* object, vpiHandle handle) {}
  virtual void leaveDisable(const disable* object, vpiHandle handle) {}

  virtual void enterDisable_fork(const disable_fork* object, vpiHandle handle) {}
  virtual void leaveDisable_fork(const disable_fork* object, vpiHandle handle) {}

  virtual void enterDist_item(const dist_item* object, vpiHandle handle) {}
  virtual void leaveDist_item(const dist_item* object, vpiHandle handle) {}

  virtual void enterDistribution(const distribution* object, vpiHandle handle) {}
  virtual void leaveDistribution(const distribution* object, vpiHandle handle) {}

  virtual void enterDo_while(const do_while* object, vpiHandle handle) {}
  virtual void leaveDo_while(const do_while* object, vpiHandle handle) {}

  virtual void enterEnum_const(const enum_const* object, vpiHandle handle) {}
  virtual void leaveEnum_const(const enum_const* object, vpiHandle handle) {}

  virtual void enterEnum_net(const enum_net* object, vpiHandle handle) {}
  virtual void leaveEnum_net(const enum_net* object, vpiHandle handle) {}

  virtual void enterEnum_typespec(const enum_typespec* object, vpiHandle handle) {}
  virtual void leaveEnum_typespec(const enum_typespec* object, vpiHandle handle) {}

  virtual void enterEnum_var(const enum_var* object, vpiHandle handle) {}
  virtual void leaveEnum_var(const enum_var* object, vpiHandle handle) {}

  virtual void enterEvent_control(const event_control* object, vpiHandle handle) {}
  virtual void leaveEvent_control(const event_control* object, vpiHandle handle) {}

  virtual void enterEvent_stmt(const event_stmt* object, vpiHandle handle) {}
  virtual void leaveEvent_stmt(const event_stmt* object, vpiHandle handle) {}

  virtual void enterEvent_typespec(const event_typespec* object, vpiHandle handle) {}
  virtual void leaveEvent_typespec(const event_typespec* object, vpiHandle handle) {}

  virtual void enterExpect_stmt(const expect_stmt* object, vpiHandle handle) {}
  virtual void leaveExpect_stmt(const expect_stmt* object, vpiHandle handle) {}

  virtual void enterExtends(const extends* object, vpiHandle handle) {}
  virtual void leaveExtends(const extends* object, vpiHandle handle) {}

  virtual void enterFinal_stmt(const final_stmt* object, vpiHandle handle) {}
  virtual void leaveFinal_stmt(const final_stmt* object, vpiHandle handle) {}

  virtual void enterFor_stmt(const for_stmt* object, vpiHandle handle) {}
  virtual void leaveFor_stmt(const for_stmt* object, vpiHandle handle) {}

  virtual void enterForce(const force* object, vpiHandle handle) {}
  virtual void leaveForce(const force* object, vpiHandle handle) {}

  virtual void enterForeach_stmt(const foreach_stmt* object, vpiHandle handle) {}
  virtual void leaveForeach_stmt(const foreach_stmt* object, vpiHandle handle) {}

  virtual void enterForever_stmt(const forever_stmt* object, vpiHandle handle) {}
  virtual void leaveForever_stmt(const forever_stmt* object, vpiHandle handle) {}

  virtual void enterFork_stmt(const fork_stmt* object, vpiHandle handle) {}
  virtual void leaveFork_stmt(const fork_stmt* object, vpiHandle handle) {}

  virtual void enterFunc_call(const func_call* object, vpiHandle handle) {}
  virtual void leaveFunc_call(const func_call* object, vpiHandle handle) {}

  virtual void enterFunction(const function* object, vpiHandle handle) {}
  virtual void leaveFunction(const function* object, vpiHandle handle) {}

  virtual void enterGate(const gate* object, vpiHandle handle) {}
  virtual void leaveGate(const gate* object, vpiHandle handle) {}

  virtual void enterGate_array(const gate_array* object, vpiHandle handle) {}
  virtual void leaveGate_array(const gate_array* object, vpiHandle handle) {}

  virtual void enterGen_case(const gen_case* object, vpiHandle handle) {}
  virtual void leaveGen_case(const gen_case* object, vpiHandle handle) {}

  virtual void enterGen_for(const gen_for* object, vpiHandle handle) {}
  virtual void leaveGen_for(const gen_for* object, vpiHandle handle) {}

  virtual void enterGen_if(const gen_if* object, vpiHandle handle) {}
  virtual void leaveGen_if(const gen_if* object, vpiHandle handle) {}

  virtual void enterGen_if_else(const gen_if_else* object, vpiHandle handle) {}
  virtual void leaveGen_if_else(const gen_if_else* object, vpiHandle handle) {}

  virtual void enterGen_region(const gen_region* object, vpiHandle handle) {}
  virtual void leaveGen_region(const gen_region* object, vpiHandle handle) {}

  virtual void enterGen_scope(const gen_scope* object, vpiHandle handle) {}
  virtual void leaveGen_scope(const gen_scope* object, vpiHandle handle) {}

  virtual void enterGen_scope_array(const gen_scope_array* object, vpiHandle handle) {}
  virtual void leaveGen_scope_array(const gen_scope_array* object, vpiHandle handle) {}

  virtual void enterGen_var(const gen_var* object, vpiHandle handle) {}
  virtual void leaveGen_var(const gen_var* object, vpiHandle handle) {}

  virtual void enterHier_path(const hier_path* object, vpiHandle handle) {}
  virtual void leaveHier_path(const hier_path* object, vpiHandle handle) {}

  virtual void enterIf_else(const if_else* object, vpiHandle handle) {}
  virtual void leaveIf_else(const if_else* object, vpiHandle handle) {}

  virtual void enterIf_stmt(const if_stmt* object, vpiHandle handle) {}
  virtual void leaveIf_stmt(const if_stmt* object, vpiHandle handle) {}

  virtual void enterImmediate_assert(const immediate_assert* object, vpiHandle handle) {}
  virtual void leaveImmediate_assert(const immediate_assert* object, vpiHandle handle) {}

  virtual void enterImmediate_assume(const immediate_assume* object, vpiHandle handle) {}
  virtual void leaveImmediate_assume(const immediate_assume* object, vpiHandle handle) {}

  virtual void enterImmediate_cover(const immediate_cover* object, vpiHandle handle) {}
  virtual void leaveImmediate_cover(const immediate_cover* object, vpiHandle handle) {}

  virtual void enterImplication(const implication* object, vpiHandle handle) {}
  virtual void leaveImplication(const implication* object, vpiHandle handle) {}

  virtual void enterImport_typespec(const import_typespec* object, vpiHandle handle) {}
  virtual void leaveImport_typespec(const import_typespec* object, vpiHandle handle) {}

  virtual void enterInclude_file_info(const include_file_info* object, vpiHandle handle) {}
  virtual void leaveInclude_file_info(const include_file_info* object, vpiHandle handle) {}

  virtual void enterIndexed_part_select(const indexed_part_select* object, vpiHandle handle) {}
  virtual void leaveIndexed_part_select(const indexed_part_select* object, vpiHandle handle) {}

  virtual void enterInitial(const initial* object, vpiHandle handle) {}
  virtual void leaveInitial(const initial* object, vpiHandle handle) {}

  virtual void enterInt_typespec(const int_typespec* object, vpiHandle handle) {}
  virtual void leaveInt_typespec(const int_typespec* object, vpiHandle handle) {}

  virtual void enterInt_var(const int_var* object, vpiHandle handle) {}
  virtual void leaveInt_var(const int_var* object, vpiHandle handle) {}

  virtual void enterInteger_net(const integer_net* object, vpiHandle handle) {}
  virtual void leaveInteger_net(const integer_net* object, vpiHandle handle) {}

  virtual void enterInteger_typespec(const integer_typespec* object, vpiHandle handle) {}
  virtual void leaveInteger_typespec(const integer_typespec* object, vpiHandle handle) {}

  virtual void enterInteger_var(const integer_var* object, vpiHandle handle) {}
  virtual void leaveInteger_var(const integer_var* object, vpiHandle handle) {}

  virtual void enterInterface_array(const interface_array* object, vpiHandle handle) {}
  virtual void leaveInterface_array(const interface_array* object, vpiHandle handle) {}

  virtual void enterInterface_inst(const interface_inst* object, vpiHandle handle) {}
  virtual void leaveInterface_inst(const interface_inst* object, vpiHandle handle) {}

  virtual void enterInterface_tf_decl(const interface_tf_decl* object, vpiHandle handle) {}
  virtual void leaveInterface_tf_decl(const interface_tf_decl* object, vpiHandle handle) {}

  virtual void enterInterface_typespec(const interface_typespec* object, vpiHandle handle) {}
  virtual void leaveInterface_typespec(const interface_typespec* object, vpiHandle handle) {}

  virtual void enterIo_decl(const io_decl* object, vpiHandle handle) {}
  virtual void leaveIo_decl(const io_decl* object, vpiHandle handle) {}

  virtual void enterLet_decl(const let_decl* object, vpiHandle handle) {}
  virtual void leaveLet_decl(const let_decl* object, vpiHandle handle) {}

  virtual void enterLet_expr(const let_expr* object, vpiHandle handle) {}
  virtual void leaveLet_expr(const let_expr* object, vpiHandle handle) {}

  virtual void enterLogic_net(const logic_net* object, vpiHandle handle) {}
  virtual void leaveLogic_net(const logic_net* object, vpiHandle handle) {}

  virtual void enterLogic_typespec(const logic_typespec* object, vpiHandle handle) {}
  virtual void leaveLogic_typespec(const logic_typespec* object, vpiHandle handle) {}

  virtual void enterLogic_var(const logic_var* object, vpiHandle handle) {}
  virtual void leaveLogic_var(const logic_var* object, vpiHandle handle) {}

  virtual void enterLong_int_typespec(const long_int_typespec* object, vpiHandle handle) {}
  virtual void leaveLong_int_typespec(const long_int_typespec* object, vpiHandle handle) {}

  virtual void enterLong_int_var(const long_int_var* object, vpiHandle handle) {}
  virtual void leaveLong_int_var(const long_int_var* object, vpiHandle handle) {}

  virtual void enterMethod_func_call(const method_func_call* object, vpiHandle handle) {}
  virtual void leaveMethod_func_call(const method_func_call* object, vpiHandle handle) {}

  virtual void enterMethod_task_call(const method_task_call* object, vpiHandle handle) {}
  virtual void leaveMethod_task_call(const method_task_call* object, vpiHandle handle) {}

  virtual void enterMod_path(const mod_path* object, vpiHandle handle) {}
  virtual void leaveMod_path(const mod_path* object, vpiHandle handle) {}

  virtual void enterModport(const modport* object, vpiHandle handle) {}
  virtual void leaveModport(const modport* object, vpiHandle handle) {}

  virtual void enterModule_array(const module_array* object, vpiHandle handle) {}
  virtual void leaveModule_array(const module_array* object, vpiHandle handle) {}

  virtual void enterModule_inst(const module_inst* object, vpiHandle handle) {}
  virtual void leaveModule_inst(const module_inst* object, vpiHandle handle) {}

  virtual void enterModule_typespec(const module_typespec* object, vpiHandle handle) {}
  virtual void leaveModule_typespec(const module_typespec* object, vpiHandle handle) {}

  virtual void enterMulticlock_sequence_expr(const multiclock_sequence_expr* object, vpiHandle handle) {}
  virtual void leaveMulticlock_sequence_expr(const multiclock_sequence_expr* object, vpiHandle handle) {}

  virtual void enterNamed_begin(const named_begin* object, vpiHandle handle) {}
  virtual void leaveNamed_begin(const named_begin* object, vpiHandle handle) {}

  virtual void enterNamed_event(const named_event* object, vpiHandle handle) {}
  virtual void leaveNamed_event(const named_event* object, vpiHandle handle) {}

  virtual void enterNamed_event_array(const named_event_array* object, vpiHandle handle) {}
  virtual void leaveNamed_event_array(const named_event_array* object, vpiHandle handle) {}

  virtual void enterNamed_fork(const named_fork* object, vpiHandle handle) {}
  virtual void leaveNamed_fork(const named_fork* object, vpiHandle handle) {}

  virtual void enterNet_bit(const net_bit* object, vpiHandle handle) {}
  virtual void leaveNet_bit(const net_bit* object, vpiHandle handle) {}

  virtual void enterNull_stmt(const null_stmt* object, vpiHandle handle) {}
  virtual void leaveNull_stmt(const null_stmt* object, vpiHandle handle) {}

  virtual void enterOperation(const operation* object, vpiHandle handle) {}
  virtual void leaveOperation(const operation* object, vpiHandle handle) {}

  virtual void enterOrdered_wait(const ordered_wait* object, vpiHandle handle) {}
  virtual void leaveOrdered_wait(const ordered_wait* object, vpiHandle handle) {}

  virtual void enterPackage(const package* object, vpiHandle handle) {}
  virtual void leavePackage(const package* object, vpiHandle handle) {}

  virtual void enterPacked_array_net(const packed_array_net* object, vpiHandle handle) {}
  virtual void leavePacked_array_net(const packed_array_net* object, vpiHandle handle) {}

  virtual void enterPacked_array_typespec(const packed_array_typespec* object, vpiHandle handle) {}
  virtual void leavePacked_array_typespec(const packed_array_typespec* object, vpiHandle handle) {}

  virtual void enterPacked_array_var(const packed_array_var* object, vpiHandle handle) {}
  virtual void leavePacked_array_var(const packed_array_var* object, vpiHandle handle) {}

  virtual void enterParam_assign(const param_assign* object, vpiHandle handle) {}
  virtual void leaveParam_assign(const param_assign* object, vpiHandle handle) {}

  virtual void enterParameter(const parameter* object, vpiHandle handle) {}
  virtual void leaveParameter(const parameter* object, vpiHandle handle) {}

  virtual void enterPart_select(const part_select* object, vpiHandle handle) {}
  virtual void leavePart_select(const part_select* object, vpiHandle handle) {}

  virtual void enterPath_term(const path_term* object, vpiHandle handle) {}
  virtual void leavePath_term(const path_term* object, vpiHandle handle) {}

  virtual void enterPort(const port* object, vpiHandle handle) {}
  virtual void leavePort(const port* object, vpiHandle handle) {}

  virtual void enterPort_bit(const port_bit* object, vpiHandle handle) {}
  virtual void leavePort_bit(const port_bit* object, vpiHandle handle) {}

  virtual void enterPrim_term(const prim_term* object, vpiHandle handle) {}
  virtual void leavePrim_term(const prim_term* object, vpiHandle handle) {}

  virtual void enterProgram(const program* object, vpiHandle handle) {}
  virtual void leaveProgram(const program* object, vpiHandle handle) {}

  virtual void enterProgram_array(const program_array* object, vpiHandle handle) {}
  virtual void leaveProgram_array(const program_array* object, vpiHandle handle) {}

  virtual void enterProp_formal_decl(const prop_formal_decl* object, vpiHandle handle) {}
  virtual void leaveProp_formal_decl(const prop_formal_decl* object, vpiHandle handle) {}

  virtual void enterProperty_decl(const property_decl* object, vpiHandle handle) {}
  virtual void leaveProperty_decl(const property_decl* object, vpiHandle handle) {}

  virtual void enterProperty_inst(const property_inst* object, vpiHandle handle) {}
  virtual void leaveProperty_inst(const property_inst* object, vpiHandle handle) {}

  virtual void enterProperty_spec(const property_spec* object, vpiHandle handle) {}
  virtual void leaveProperty_spec(const property_spec* object, vpiHandle handle) {}

  virtual void enterProperty_typespec(const property_typespec* object, vpiHandle handle) {}
  virtual void leaveProperty_typespec(const property_typespec* object, vpiHandle handle) {}

  virtual void enterRange(const range* object, vpiHandle handle) {}
  virtual void leaveRange(const range* object, vpiHandle handle) {}

  virtual void enterReal_typespec(const real_typespec* object, vpiHandle handle) {}
  virtual void leaveReal_typespec(const real_typespec* object, vpiHandle handle) {}

  virtual void enterReal_var(const real_var* object, vpiHandle handle) {}
  virtual void leaveReal_var(const real_var* object, vpiHandle handle) {}

  virtual void enterRef_module(const ref_module* object, vpiHandle handle) {}
  virtual void leaveRef_module(const ref_module* object, vpiHandle handle) {}

  virtual void enterRef_obj(const ref_obj* object, vpiHandle handle) {}
  virtual void leaveRef_obj(const ref_obj* object, vpiHandle handle) {}

  virtual void enterRef_typespec(const ref_typespec* object, vpiHandle handle) {}
  virtual void leaveRef_typespec(const ref_typespec* object, vpiHandle handle) {}

  virtual void enterRef_var(const ref_var* object, vpiHandle handle) {}
  virtual void leaveRef_var(const ref_var* object, vpiHandle handle) {}

  virtual void enterReg(const reg* object, vpiHandle handle) {}
  virtual void leaveReg(const reg* object, vpiHandle handle) {}

  virtual void enterReg_array(const reg_array* object, vpiHandle handle) {}
  virtual void leaveReg_array(const reg_array* object, vpiHandle handle) {}

  virtual void enterRelease(const release* object, vpiHandle handle) {}
  virtual void leaveRelease(const release* object, vpiHandle handle) {}

  virtual void enterRepeat(const repeat* object, vpiHandle handle) {}
  virtual void leaveRepeat(const repeat* object, vpiHandle handle) {}

  virtual void enterRepeat_control(const repeat_control* object, vpiHandle handle) {}
  virtual void leaveRepeat_control(const repeat_control* object, vpiHandle handle) {}

  virtual void enterRestrict(const restrict* object, vpiHandle handle) {}
  virtual void leaveRestrict(const restrict* object, vpiHandle handle) {}

  virtual void enterReturn_stmt(const return_stmt* object, vpiHandle handle) {}
  virtual void leaveReturn_stmt(const return_stmt* object, vpiHandle handle) {}

  virtual void enterSeq_formal_decl(const seq_formal_decl* object, vpiHandle handle) {}
  virtual void leaveSeq_formal_decl(const seq_formal_decl* object, vpiHandle handle) {}

  virtual void enterSequence_decl(const sequence_decl* object, vpiHandle handle) {}
  virtual void leaveSequence_decl(const sequence_decl* object, vpiHandle handle) {}

  virtual void enterSequence_inst(const sequence_inst* object, vpiHandle handle) {}
  virtual void leaveSequence_inst(const sequence_inst* object, vpiHandle handle) {}

  virtual void enterSequence_typespec(const sequence_typespec* object, vpiHandle handle) {}
  virtual void leaveSequence_typespec(const sequence_typespec* object, vpiHandle handle) {}

  virtual void enterShort_int_typespec(const short_int_typespec* object, vpiHandle handle) {}
  virtual void leaveShort_int_typespec(const short_int_typespec* object, vpiHandle handle) {}

  virtual void enterShort_int_var(const short_int_var* object, vpiHandle handle) {}
  virtual void leaveShort_int_var(const short_int_var* object, vpiHandle handle) {}

  virtual void enterShort_real_typespec(const short_real_typespec* object, vpiHandle handle) {}
  virtual void leaveShort_real_typespec(const short_real_typespec* object, vpiHandle handle) {}

  virtual void enterShort_real_var(const short_real_var* object, vpiHandle handle) {}
  virtual void leaveShort_real_var(const short_real_var* object, vpiHandle handle) {}

  virtual void enterSoft_disable(const soft_disable* object, vpiHandle handle) {}
  virtual void leaveSoft_disable(const soft_disable* object, vpiHandle handle) {}

  virtual void enterSpec_param(const spec_param* object, vpiHandle handle) {}
  virtual void leaveSpec_param(const spec_param* object, vpiHandle handle) {}

  virtual void enterString_typespec(const string_typespec* object, vpiHandle handle) {}
  virtual void leaveString_typespec(const string_typespec* object, vpiHandle handle) {}

  virtual void enterString_var(const string_var* object, vpiHandle handle) {}
  virtual void leaveString_var(const string_var* object, vpiHandle handle) {}

  virtual void enterStruct_net(const struct_net* object, vpiHandle handle) {}
  virtual void leaveStruct_net(const struct_net* object, vpiHandle handle) {}

  virtual void enterStruct_pattern(const struct_pattern* object, vpiHandle handle) {}
  virtual void leaveStruct_pattern(const struct_pattern* object, vpiHandle handle) {}

  virtual void enterStruct_typespec(const struct_typespec* object, vpiHandle handle) {}
  virtual void leaveStruct_typespec(const struct_typespec* object, vpiHandle handle) {}

  virtual void enterStruct_var(const struct_var* object, vpiHandle handle) {}
  virtual void leaveStruct_var(const struct_var* object, vpiHandle handle) {}

  virtual void enterSwitch_array(const switch_array* object, vpiHandle handle) {}
  virtual void leaveSwitch_array(const switch_array* object, vpiHandle handle) {}

  virtual void enterSwitch_tran(const switch_tran* object, vpiHandle handle) {}
  virtual void leaveSwitch_tran(const switch_tran* object, vpiHandle handle) {}

  virtual void enterSys_func_call(const sys_func_call* object, vpiHandle handle) {}
  virtual void leaveSys_func_call(const sys_func_call* object, vpiHandle handle) {}

  virtual void enterSys_task_call(const sys_task_call* object, vpiHandle handle) {}
  virtual void leaveSys_task_call(const sys_task_call* object, vpiHandle handle) {}

  virtual void enterTable_entry(const table_entry* object, vpiHandle handle) {}
  virtual void leaveTable_entry(const table_entry* object, vpiHandle handle) {}

  virtual void enterTagged_pattern(const tagged_pattern* object, vpiHandle handle) {}
  virtual void leaveTagged_pattern(const tagged_pattern* object, vpiHandle handle) {}

  virtual void enterTask(const task* object, vpiHandle handle) {}
  virtual void leaveTask(const task* object, vpiHandle handle) {}

  virtual void enterTask_call(const task_call* object, vpiHandle handle) {}
  virtual void leaveTask_call(const task_call* object, vpiHandle handle) {}

  virtual void enterTchk(const tchk* object, vpiHandle handle) {}
  virtual void leaveTchk(const tchk* object, vpiHandle handle) {}

  virtual void enterTchk_term(const tchk_term* object, vpiHandle handle) {}
  virtual void leaveTchk_term(const tchk_term* object, vpiHandle handle) {}

  virtual void enterThread_obj(const thread_obj* object, vpiHandle handle) {}
  virtual void leaveThread_obj(const thread_obj* object, vpiHandle handle) {}

  virtual void enterTime_net(const time_net* object, vpiHandle handle) {}
  virtual void leaveTime_net(const time_net* object, vpiHandle handle) {}

  virtual void enterTime_typespec(const time_typespec* object, vpiHandle handle) {}
  virtual void leaveTime_typespec(const time_typespec* object, vpiHandle handle) {}

  virtual void enterTime_var(const time_var* object, vpiHandle handle) {}
  virtual void leaveTime_var(const time_var* object, vpiHandle handle) {}

  virtual void enterType_parameter(const type_parameter* object, vpiHandle handle) {}
  virtual void leaveType_parameter(const type_parameter* object, vpiHandle handle) {}

  virtual void enterTypespec_member(const typespec_member* object, vpiHandle handle) {}
  virtual void leaveTypespec_member(const typespec_member* object, vpiHandle handle) {}

  virtual void enterUdp(const udp* object, vpiHandle handle) {}
  virtual void leaveUdp(const udp* object, vpiHandle handle) {}

  virtual void enterUdp_array(const udp_array* object, vpiHandle handle) {}
  virtual void leaveUdp_array(const udp_array* object, vpiHandle handle) {}

  virtual void enterUdp_defn(const udp_defn* object, vpiHandle handle) {}
  virtual void leaveUdp_defn(const udp_defn* object, vpiHandle handle) {}

  virtual void enterUnion_typespec(const union_typespec* object, vpiHandle handle) {}
  virtual void leaveUnion_typespec(const union_typespec* object, vpiHandle handle) {}

  virtual void enterUnion_var(const union_var* object, vpiHandle handle) {}
  virtual void leaveUnion_var(const union_var* object, vpiHandle handle) {}

  virtual void enterUnsupported_expr(const unsupported_expr* object, vpiHandle handle) {}
  virtual void leaveUnsupported_expr(const unsupported_expr* object, vpiHandle handle) {}

  virtual void enterUnsupported_stmt(const unsupported_stmt* object, vpiHandle handle) {}
  virtual void leaveUnsupported_stmt(const unsupported_stmt* object, vpiHandle handle) {}

  virtual void enterUnsupported_typespec(const unsupported_typespec* object, vpiHandle handle) {}
  virtual void leaveUnsupported_typespec(const unsupported_typespec* object, vpiHandle handle) {}

  virtual void enterUser_systf(const user_systf* object, vpiHandle handle) {}
  virtual void leaveUser_systf(const user_systf* object, vpiHandle handle) {}

  virtual void enterVar_bit(const var_bit* object, vpiHandle handle) {}
  virtual void leaveVar_bit(const var_bit* object, vpiHandle handle) {}

  virtual void enterVar_select(const var_select* object, vpiHandle handle) {}
  virtual void leaveVar_select(const var_select* object, vpiHandle handle) {}

  virtual void enterVirtual_interface_var(const virtual_interface_var* object, vpiHandle handle) {}
  virtual void leaveVirtual_interface_var(const virtual_interface_var* object, vpiHandle handle) {}

  virtual void enterVoid_typespec(const void_typespec* object, vpiHandle handle) {}
  virtual void leaveVoid_typespec(const void_typespec* object, vpiHandle handle) {}

  virtual void enterWait_fork(const wait_fork* object, vpiHandle handle) {}
  virtual void leaveWait_fork(const wait_fork* object, vpiHandle handle) {}

  virtual void enterWait_stmt(const wait_stmt* object, vpiHandle handle) {}
  virtual void leaveWait_stmt(const wait_stmt* object, vpiHandle handle) {}

  virtual void enterWhile_stmt(const while_stmt* object, vpiHandle handle) {}
  virtual void leaveWhile_stmt(const while_stmt* object, vpiHandle handle) {}

  bool isInUhdmAllIterator() const { return uhdmAllIterator; }
  bool inCallstackOfType(UHDM_OBJECT_TYPE type);
  virtual void ignoreLastInstance(bool ignore) {}
  design* currentDesign() { return currentDesign_; }
protected:
  bool uhdmAllIterator = false;
  design* currentDesign_ = nullptr;
private:
  void listenAttribute_(vpiHandle handle);
  void listenVirtual_interface_var_(vpiHandle handle);
  void listenLet_decl_(vpiHandle handle);
  void listenConcurrent_assertions_(vpiHandle handle);
  void listenProcess_stmt_(vpiHandle handle);
  void listenAlways_(vpiHandle handle);
  void listenFinal_stmt_(vpiHandle handle);
  void listenInitial_(vpiHandle handle);
  void listenAtomic_stmt_(vpiHandle handle);
  void listenDelay_control_(vpiHandle handle);
  void listenDelay_term_(vpiHandle handle);
  void listenEvent_control_(vpiHandle handle);
  void listenRepeat_control_(vpiHandle handle);
  void listenScope_(vpiHandle handle);
  void listenBegin_(vpiHandle handle);
  void listenNamed_begin_(vpiHandle handle);
  void listenNamed_fork_(vpiHandle handle);
  void listenFork_stmt_(vpiHandle handle);
  void listenFor_stmt_(vpiHandle handle);
  void listenIf_stmt_(vpiHandle handle);
  void listenEvent_stmt_(vpiHandle handle);
  void listenThread_obj_(vpiHandle handle);
  void listenForever_stmt_(vpiHandle handle);
  void listenWaits_(vpiHandle handle);
  void listenWait_stmt_(vpiHandle handle);
  void listenWait_fork_(vpiHandle handle);
  void listenOrdered_wait_(vpiHandle handle);
  void listenDisables_(vpiHandle handle);
  void listenDisable_(vpiHandle handle);
  void listenDisable_fork_(vpiHandle handle);
  void listenContinue_stmt_(vpiHandle handle);
  void listenBreak_stmt_(vpiHandle handle);
  void listenReturn_stmt_(vpiHandle handle);
  void listenWhile_stmt_(vpiHandle handle);
  void listenRepeat_(vpiHandle handle);
  void listenDo_while_(vpiHandle handle);
  void listenIf_else_(vpiHandle handle);
  void listenCase_stmt_(vpiHandle handle);
  void listenForce_(vpiHandle handle);
  void listenAssign_stmt_(vpiHandle handle);
  void listenDeassign_(vpiHandle handle);
  void listenRelease_(vpiHandle handle);
  void listenNull_stmt_(vpiHandle handle);
  void listenExpect_stmt_(vpiHandle handle);
  void listenForeach_stmt_(vpiHandle handle);
  void listenGen_scope_(vpiHandle handle);
  void listenGen_var_(vpiHandle handle);
  void listenGen_scope_array_(vpiHandle handle);
  void listenAssert_stmt_(vpiHandle handle);
  void listenCover_(vpiHandle handle);
  void listenAssume_(vpiHandle handle);
  void listenRestrict_(vpiHandle handle);
  void listenImmediate_assert_(vpiHandle handle);
  void listenImmediate_assume_(vpiHandle handle);
  void listenImmediate_cover_(vpiHandle handle);
  void listenExpr_(vpiHandle handle);
  void listenCase_item_(vpiHandle handle);
  void listenAssignment_(vpiHandle handle);
  void listenAny_pattern_(vpiHandle handle);
  void listenTagged_pattern_(vpiHandle handle);
  void listenStruct_pattern_(vpiHandle handle);
  void listenUnsupported_expr_(vpiHandle handle);
  void listenUnsupported_stmt_(vpiHandle handle);
  void listenInclude_file_info_(vpiHandle handle);
  void listenSequence_inst_(vpiHandle handle);
  void listenSeq_formal_decl_(vpiHandle handle);
  void listenSequence_decl_(vpiHandle handle);
  void listenProp_formal_decl_(vpiHandle handle);
  void listenProperty_inst_(vpiHandle handle);
  void listenProperty_spec_(vpiHandle handle);
  void listenProperty_decl_(vpiHandle handle);
  void listenClocked_property_(vpiHandle handle);
  void listenCase_property_item_(vpiHandle handle);
  void listenCase_property_(vpiHandle handle);
  void listenMulticlock_sequence_expr_(vpiHandle handle);
  void listenClocked_seq_(vpiHandle handle);
  void listenSimple_expr_(vpiHandle handle);
  void listenConstant_(vpiHandle handle);
  void listenLet_expr_(vpiHandle handle);
  void listenOperation_(vpiHandle handle);
  void listenRef_obj_(vpiHandle handle);
  void listenRef_module_(vpiHandle handle);
  void listenRef_typespec_(vpiHandle handle);
  void listenPart_select_(vpiHandle handle);
  void listenIndexed_part_select_(vpiHandle handle);
  void listenVar_select_(vpiHandle handle);
  void listenBit_select_(vpiHandle handle);
  void listenVariables_(vpiHandle handle);
  void listenHier_path_(vpiHandle handle);
  void listenRef_var_(vpiHandle handle);
  void listenShort_real_var_(vpiHandle handle);
  void listenReal_var_(vpiHandle handle);
  void listenByte_var_(vpiHandle handle);
  void listenShort_int_var_(vpiHandle handle);
  void listenInt_var_(vpiHandle handle);
  void listenLong_int_var_(vpiHandle handle);
  void listenInteger_var_(vpiHandle handle);
  void listenTime_var_(vpiHandle handle);
  void listenArray_var_(vpiHandle handle);
  void listenArray_expr_(vpiHandle handle);
  void listenReg_array_(vpiHandle handle);
  void listenReg_(vpiHandle handle);
  void listenPacked_array_var_(vpiHandle handle);
  void listenBit_var_(vpiHandle handle);
  void listenLogic_var_(vpiHandle handle);
  void listenStruct_var_(vpiHandle handle);
  void listenUnion_var_(vpiHandle handle);
  void listenEnum_var_(vpiHandle handle);
  void listenString_var_(vpiHandle handle);
  void listenChandle_var_(vpiHandle handle);
  void listenVar_bit_(vpiHandle handle);
  void listenTask_func_(vpiHandle handle);
  void listenTask_(vpiHandle handle);
  void listenFunction_(vpiHandle handle);
  void listenModport_(vpiHandle handle);
  void listenInterface_tf_decl_(vpiHandle handle);
  void listenCont_assign_(vpiHandle handle);
  void listenCont_assign_bit_(vpiHandle handle);
  void listenPorts_(vpiHandle handle);
  void listenPort_(vpiHandle handle);
  void listenPort_bit_(vpiHandle handle);
  void listenChecker_port_(vpiHandle handle);
  void listenChecker_inst_port_(vpiHandle handle);
  void listenPrimitive_(vpiHandle handle);
  void listenGate_(vpiHandle handle);
  void listenSwitch_tran_(vpiHandle handle);
  void listenUdp_(vpiHandle handle);
  void listenMod_path_(vpiHandle handle);
  void listenTchk_(vpiHandle handle);
  void listenRange_(vpiHandle handle);
  void listenUdp_defn_(vpiHandle handle);
  void listenTable_entry_(vpiHandle handle);
  void listenIo_decl_(vpiHandle handle);
  void listenAlias_stmt_(vpiHandle handle);
  void listenClocking_block_(vpiHandle handle);
  void listenClocking_io_decl_(vpiHandle handle);
  void listenParam_assign_(vpiHandle handle);
  void listenInstance_array_(vpiHandle handle);
  void listenInterface_array_(vpiHandle handle);
  void listenProgram_array_(vpiHandle handle);
  void listenModule_array_(vpiHandle handle);
  void listenPrimitive_array_(vpiHandle handle);
  void listenGate_array_(vpiHandle handle);
  void listenSwitch_array_(vpiHandle handle);
  void listenUdp_array_(vpiHandle handle);
  void listenTypespec_(vpiHandle handle);
  void listenPrim_term_(vpiHandle handle);
  void listenPath_term_(vpiHandle handle);
  void listenTchk_term_(vpiHandle handle);
  void listenNets_(vpiHandle handle);
  void listenNet_bit_(vpiHandle handle);
  void listenNet_(vpiHandle handle);
  void listenStruct_net_(vpiHandle handle);
  void listenEnum_net_(vpiHandle handle);
  void listenInteger_net_(vpiHandle handle);
  void listenTime_net_(vpiHandle handle);
  void listenLogic_net_(vpiHandle handle);
  void listenArray_net_(vpiHandle handle);
  void listenPacked_array_net_(vpiHandle handle);
  void listenEvent_typespec_(vpiHandle handle);
  void listenNamed_event_(vpiHandle handle);
  void listenNamed_event_array_(vpiHandle handle);
  void listenParameter_(vpiHandle handle);
  void listenDef_param_(vpiHandle handle);
  void listenSpec_param_(vpiHandle handle);
  void listenClass_typespec_(vpiHandle handle);
  void listenExtends_(vpiHandle handle);
  void listenClass_defn_(vpiHandle handle);
  void listenClass_obj_(vpiHandle handle);
  void listenClass_var_(vpiHandle handle);
  void listenInstance_(vpiHandle handle);
  void listenInterface_inst_(vpiHandle handle);
  void listenProgram_(vpiHandle handle);
  void listenPackage_(vpiHandle handle);
  void listenModule_inst_(vpiHandle handle);
  void listenChecker_decl_(vpiHandle handle);
  void listenChecker_inst_(vpiHandle handle);
  void listenShort_real_typespec_(vpiHandle handle);
  void listenReal_typespec_(vpiHandle handle);
  void listenByte_typespec_(vpiHandle handle);
  void listenShort_int_typespec_(vpiHandle handle);
  void listenInt_typespec_(vpiHandle handle);
  void listenLong_int_typespec_(vpiHandle handle);
  void listenInteger_typespec_(vpiHandle handle);
  void listenTime_typespec_(vpiHandle handle);
  void listenEnum_typespec_(vpiHandle handle);
  void listenString_typespec_(vpiHandle handle);
  void listenChandle_typespec_(vpiHandle handle);
  void listenModule_typespec_(vpiHandle handle);
  void listenStruct_typespec_(vpiHandle handle);
  void listenUnion_typespec_(vpiHandle handle);
  void listenLogic_typespec_(vpiHandle handle);
  void listenPacked_array_typespec_(vpiHandle handle);
  void listenArray_typespec_(vpiHandle handle);
  void listenVoid_typespec_(vpiHandle handle);
  void listenUnsupported_typespec_(vpiHandle handle);
  void listenSequence_typespec_(vpiHandle handle);
  void listenProperty_typespec_(vpiHandle handle);
  void listenInterface_typespec_(vpiHandle handle);
  void listenType_parameter_(vpiHandle handle);
  void listenTypespec_member_(vpiHandle handle);
  void listenEnum_const_(vpiHandle handle);
  void listenBit_typespec_(vpiHandle handle);
  void listenTf_call_(vpiHandle handle);
  void listenUser_systf_(vpiHandle handle);
  void listenSys_func_call_(vpiHandle handle);
  void listenSys_task_call_(vpiHandle handle);
  void listenMethod_func_call_(vpiHandle handle);
  void listenMethod_task_call_(vpiHandle handle);
  void listenFunc_call_(vpiHandle handle);
  void listenTask_call_(vpiHandle handle);
  void listenConstraint_expr_(vpiHandle handle);
  void listenConstraint_ordering_(vpiHandle handle);
  void listenConstraint_(vpiHandle handle);
  void listenImport_typespec_(vpiHandle handle);
  void listenDist_item_(vpiHandle handle);
  void listenDistribution_(vpiHandle handle);
  void listenImplication_(vpiHandle handle);
  void listenConstr_if_(vpiHandle handle);
  void listenConstr_if_else_(vpiHandle handle);
  void listenConstr_foreach_(vpiHandle handle);
  void listenSoft_disable_(vpiHandle handle);
  void listenGen_stmt_(vpiHandle handle);
  void listenGen_if_(vpiHandle handle);
  void listenGen_if_else_(vpiHandle handle);
  void listenGen_for_(vpiHandle handle);
  void listenGen_case_(vpiHandle handle);
  void listenGen_region_(vpiHandle handle);
  void listenDesign_(vpiHandle handle);
};
}  // namespace UHDM

#endif  // UHDM_VPILISTENER_H
