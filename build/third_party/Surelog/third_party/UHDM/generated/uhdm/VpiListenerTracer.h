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
 * File:   VpiListenerTracer.h
 * Author: hs
 *
 * Created on October 11, 2020, 9:00 PM
 */

#ifndef UHDM_VPILISTENERTRACER_H
#define UHDM_VPILISTENERTRACER_H

#include "VpiListener.h"

#include "uhdm/uhdm.h"  // Needed to know how to access VPI line/column

#include <ostream>
#include <string>

#define TRACE_CONTEXT                 \
  "[" << object->VpiLineNo() <<       \
  "," << object->VpiColumnNo() <<     \
  ":" << object->VpiEndLineNo() <<    \
  "," << object->VpiEndColumnNo() <<  \
  "]"

#define TRACE_ENTER strm                \
  << std::string(++indent * 2, ' ')     \
  << __func__ << ": " << TRACE_CONTEXT  \
  << std::endl
#define TRACE_LEAVE strm                \
  << std::string(2 * indent--, ' ')     \
  << __func__ << ": " << TRACE_CONTEXT  \
  << std::endl

namespace UHDM {

  class VpiListenerTracer : public VpiListener {
  public:
    VpiListenerTracer(std::ostream &strm) : strm(strm) {}

    virtual ~VpiListenerTracer() = default;

  virtual void enterAttribute(const attribute* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveAttribute(const attribute* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterVirtual_interface_var(const virtual_interface_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveVirtual_interface_var(const virtual_interface_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterLet_decl(const let_decl* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveLet_decl(const let_decl* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterAlways(const always* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveAlways(const always* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterFinal_stmt(const final_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveFinal_stmt(const final_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInitial(const initial* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInitial(const initial* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDelay_control(const delay_control* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDelay_control(const delay_control* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDelay_term(const delay_term* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDelay_term(const delay_term* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterEvent_control(const event_control* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveEvent_control(const event_control* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterRepeat_control(const repeat_control* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveRepeat_control(const repeat_control* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterBegin(const begin* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveBegin(const begin* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterNamed_begin(const named_begin* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveNamed_begin(const named_begin* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterNamed_fork(const named_fork* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveNamed_fork(const named_fork* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterFork_stmt(const fork_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveFork_stmt(const fork_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterFor_stmt(const for_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveFor_stmt(const for_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterIf_stmt(const if_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveIf_stmt(const if_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterEvent_stmt(const event_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveEvent_stmt(const event_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterThread_obj(const thread_obj* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveThread_obj(const thread_obj* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterForever_stmt(const forever_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveForever_stmt(const forever_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterWait_stmt(const wait_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveWait_stmt(const wait_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterWait_fork(const wait_fork* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveWait_fork(const wait_fork* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterOrdered_wait(const ordered_wait* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveOrdered_wait(const ordered_wait* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDisable(const disable* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDisable(const disable* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDisable_fork(const disable_fork* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDisable_fork(const disable_fork* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterContinue_stmt(const continue_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveContinue_stmt(const continue_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterBreak_stmt(const break_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveBreak_stmt(const break_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterReturn_stmt(const return_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveReturn_stmt(const return_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterWhile_stmt(const while_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveWhile_stmt(const while_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterRepeat(const repeat* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveRepeat(const repeat* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDo_while(const do_while* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDo_while(const do_while* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterIf_else(const if_else* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveIf_else(const if_else* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterCase_stmt(const case_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveCase_stmt(const case_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterForce(const force* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveForce(const force* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterAssign_stmt(const assign_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveAssign_stmt(const assign_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDeassign(const deassign* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDeassign(const deassign* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterRelease(const release* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveRelease(const release* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterNull_stmt(const null_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveNull_stmt(const null_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterExpect_stmt(const expect_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveExpect_stmt(const expect_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterForeach_stmt(const foreach_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveForeach_stmt(const foreach_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGen_scope(const gen_scope* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGen_scope(const gen_scope* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGen_var(const gen_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGen_var(const gen_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGen_scope_array(const gen_scope_array* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGen_scope_array(const gen_scope_array* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterAssert_stmt(const assert_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveAssert_stmt(const assert_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterCover(const cover* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveCover(const cover* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterAssume(const assume* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveAssume(const assume* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterRestrict(const restrict* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveRestrict(const restrict* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterImmediate_assert(const immediate_assert* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveImmediate_assert(const immediate_assert* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterImmediate_assume(const immediate_assume* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveImmediate_assume(const immediate_assume* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterImmediate_cover(const immediate_cover* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveImmediate_cover(const immediate_cover* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterCase_item(const case_item* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveCase_item(const case_item* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterAssignment(const assignment* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveAssignment(const assignment* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterAny_pattern(const any_pattern* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveAny_pattern(const any_pattern* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTagged_pattern(const tagged_pattern* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTagged_pattern(const tagged_pattern* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterStruct_pattern(const struct_pattern* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveStruct_pattern(const struct_pattern* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterUnsupported_expr(const unsupported_expr* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveUnsupported_expr(const unsupported_expr* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterUnsupported_stmt(const unsupported_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveUnsupported_stmt(const unsupported_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInclude_file_info(const include_file_info* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInclude_file_info(const include_file_info* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSequence_inst(const sequence_inst* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSequence_inst(const sequence_inst* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSeq_formal_decl(const seq_formal_decl* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSeq_formal_decl(const seq_formal_decl* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSequence_decl(const sequence_decl* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSequence_decl(const sequence_decl* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterProp_formal_decl(const prop_formal_decl* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveProp_formal_decl(const prop_formal_decl* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterProperty_inst(const property_inst* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveProperty_inst(const property_inst* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterProperty_spec(const property_spec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveProperty_spec(const property_spec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterProperty_decl(const property_decl* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveProperty_decl(const property_decl* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterClocked_property(const clocked_property* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveClocked_property(const clocked_property* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterCase_property_item(const case_property_item* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveCase_property_item(const case_property_item* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterCase_property(const case_property* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveCase_property(const case_property* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterMulticlock_sequence_expr(const multiclock_sequence_expr* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveMulticlock_sequence_expr(const multiclock_sequence_expr* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterClocked_seq(const clocked_seq* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveClocked_seq(const clocked_seq* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterConstant(const constant* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveConstant(const constant* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterLet_expr(const let_expr* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveLet_expr(const let_expr* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterOperation(const operation* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveOperation(const operation* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterRef_obj(const ref_obj* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveRef_obj(const ref_obj* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterRef_module(const ref_module* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveRef_module(const ref_module* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterRef_typespec(const ref_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveRef_typespec(const ref_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterPart_select(const part_select* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leavePart_select(const part_select* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterIndexed_part_select(const indexed_part_select* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveIndexed_part_select(const indexed_part_select* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterVar_select(const var_select* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveVar_select(const var_select* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterBit_select(const bit_select* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveBit_select(const bit_select* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterHier_path(const hier_path* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveHier_path(const hier_path* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterRef_var(const ref_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveRef_var(const ref_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterShort_real_var(const short_real_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveShort_real_var(const short_real_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterReal_var(const real_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveReal_var(const real_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterByte_var(const byte_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveByte_var(const byte_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterShort_int_var(const short_int_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveShort_int_var(const short_int_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInt_var(const int_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInt_var(const int_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterLong_int_var(const long_int_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveLong_int_var(const long_int_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInteger_var(const integer_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInteger_var(const integer_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTime_var(const time_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTime_var(const time_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterArray_var(const array_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveArray_var(const array_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterArray_expr(const array_expr* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveArray_expr(const array_expr* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterReg_array(const reg_array* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveReg_array(const reg_array* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterReg(const reg* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveReg(const reg* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterPacked_array_var(const packed_array_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leavePacked_array_var(const packed_array_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterBit_var(const bit_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveBit_var(const bit_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterLogic_var(const logic_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveLogic_var(const logic_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterStruct_var(const struct_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveStruct_var(const struct_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterUnion_var(const union_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveUnion_var(const union_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterEnum_var(const enum_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveEnum_var(const enum_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterString_var(const string_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveString_var(const string_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterChandle_var(const chandle_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveChandle_var(const chandle_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterVar_bit(const var_bit* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveVar_bit(const var_bit* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTask(const task* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTask(const task* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterFunction(const function* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveFunction(const function* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterModport(const modport* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveModport(const modport* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInterface_tf_decl(const interface_tf_decl* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInterface_tf_decl(const interface_tf_decl* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterCont_assign(const cont_assign* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveCont_assign(const cont_assign* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterCont_assign_bit(const cont_assign_bit* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveCont_assign_bit(const cont_assign_bit* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterPort(const port* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leavePort(const port* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterPort_bit(const port_bit* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leavePort_bit(const port_bit* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterChecker_port(const checker_port* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveChecker_port(const checker_port* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterChecker_inst_port(const checker_inst_port* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveChecker_inst_port(const checker_inst_port* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGate(const gate* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGate(const gate* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSwitch_tran(const switch_tran* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSwitch_tran(const switch_tran* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterUdp(const udp* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveUdp(const udp* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterMod_path(const mod_path* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveMod_path(const mod_path* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTchk(const tchk* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTchk(const tchk* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterRange(const range* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveRange(const range* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterUdp_defn(const udp_defn* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveUdp_defn(const udp_defn* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTable_entry(const table_entry* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTable_entry(const table_entry* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterIo_decl(const io_decl* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveIo_decl(const io_decl* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterAlias_stmt(const alias_stmt* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveAlias_stmt(const alias_stmt* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterClocking_block(const clocking_block* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveClocking_block(const clocking_block* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterClocking_io_decl(const clocking_io_decl* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveClocking_io_decl(const clocking_io_decl* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterParam_assign(const param_assign* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveParam_assign(const param_assign* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInterface_array(const interface_array* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInterface_array(const interface_array* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterProgram_array(const program_array* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveProgram_array(const program_array* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterModule_array(const module_array* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveModule_array(const module_array* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGate_array(const gate_array* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGate_array(const gate_array* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSwitch_array(const switch_array* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSwitch_array(const switch_array* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterUdp_array(const udp_array* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveUdp_array(const udp_array* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterPrim_term(const prim_term* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leavePrim_term(const prim_term* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterPath_term(const path_term* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leavePath_term(const path_term* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTchk_term(const tchk_term* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTchk_term(const tchk_term* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterNet_bit(const net_bit* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveNet_bit(const net_bit* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterStruct_net(const struct_net* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveStruct_net(const struct_net* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterEnum_net(const enum_net* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveEnum_net(const enum_net* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInteger_net(const integer_net* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInteger_net(const integer_net* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTime_net(const time_net* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTime_net(const time_net* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterLogic_net(const logic_net* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveLogic_net(const logic_net* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterArray_net(const array_net* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveArray_net(const array_net* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterPacked_array_net(const packed_array_net* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leavePacked_array_net(const packed_array_net* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterEvent_typespec(const event_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveEvent_typespec(const event_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterNamed_event(const named_event* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveNamed_event(const named_event* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterNamed_event_array(const named_event_array* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveNamed_event_array(const named_event_array* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterParameter(const parameter* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveParameter(const parameter* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDef_param(const def_param* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDef_param(const def_param* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSpec_param(const spec_param* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSpec_param(const spec_param* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterClass_typespec(const class_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveClass_typespec(const class_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterExtends(const extends* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveExtends(const extends* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterClass_defn(const class_defn* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveClass_defn(const class_defn* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterClass_obj(const class_obj* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveClass_obj(const class_obj* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterClass_var(const class_var* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveClass_var(const class_var* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInterface_inst(const interface_inst* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInterface_inst(const interface_inst* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterProgram(const program* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveProgram(const program* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterPackage(const package* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leavePackage(const package* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterModule_inst(const module_inst* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveModule_inst(const module_inst* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterChecker_decl(const checker_decl* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveChecker_decl(const checker_decl* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterChecker_inst(const checker_inst* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveChecker_inst(const checker_inst* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterShort_real_typespec(const short_real_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveShort_real_typespec(const short_real_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterReal_typespec(const real_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveReal_typespec(const real_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterByte_typespec(const byte_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveByte_typespec(const byte_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterShort_int_typespec(const short_int_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveShort_int_typespec(const short_int_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInt_typespec(const int_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInt_typespec(const int_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterLong_int_typespec(const long_int_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveLong_int_typespec(const long_int_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInteger_typespec(const integer_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInteger_typespec(const integer_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTime_typespec(const time_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTime_typespec(const time_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterEnum_typespec(const enum_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveEnum_typespec(const enum_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterString_typespec(const string_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveString_typespec(const string_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterChandle_typespec(const chandle_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveChandle_typespec(const chandle_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterModule_typespec(const module_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveModule_typespec(const module_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterStruct_typespec(const struct_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveStruct_typespec(const struct_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterUnion_typespec(const union_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveUnion_typespec(const union_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterLogic_typespec(const logic_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveLogic_typespec(const logic_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterPacked_array_typespec(const packed_array_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leavePacked_array_typespec(const packed_array_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterArray_typespec(const array_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveArray_typespec(const array_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterVoid_typespec(const void_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveVoid_typespec(const void_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterUnsupported_typespec(const unsupported_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveUnsupported_typespec(const unsupported_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSequence_typespec(const sequence_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSequence_typespec(const sequence_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterProperty_typespec(const property_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveProperty_typespec(const property_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterInterface_typespec(const interface_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveInterface_typespec(const interface_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterType_parameter(const type_parameter* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveType_parameter(const type_parameter* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTypespec_member(const typespec_member* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTypespec_member(const typespec_member* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterEnum_const(const enum_const* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveEnum_const(const enum_const* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterBit_typespec(const bit_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveBit_typespec(const bit_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterUser_systf(const user_systf* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveUser_systf(const user_systf* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSys_func_call(const sys_func_call* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSys_func_call(const sys_func_call* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSys_task_call(const sys_task_call* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSys_task_call(const sys_task_call* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterMethod_func_call(const method_func_call* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveMethod_func_call(const method_func_call* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterMethod_task_call(const method_task_call* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveMethod_task_call(const method_task_call* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterFunc_call(const func_call* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveFunc_call(const func_call* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterTask_call(const task_call* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveTask_call(const task_call* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterConstraint_ordering(const constraint_ordering* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveConstraint_ordering(const constraint_ordering* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterConstraint(const constraint* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveConstraint(const constraint* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterImport_typespec(const import_typespec* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveImport_typespec(const import_typespec* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDist_item(const dist_item* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDist_item(const dist_item* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDistribution(const distribution* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDistribution(const distribution* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterImplication(const implication* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveImplication(const implication* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterConstr_if(const constr_if* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveConstr_if(const constr_if* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterConstr_if_else(const constr_if_else* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveConstr_if_else(const constr_if_else* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterConstr_foreach(const constr_foreach* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveConstr_foreach(const constr_foreach* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterSoft_disable(const soft_disable* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveSoft_disable(const soft_disable* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGen_if(const gen_if* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGen_if(const gen_if* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGen_if_else(const gen_if_else* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGen_if_else(const gen_if_else* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGen_for(const gen_for* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGen_for(const gen_for* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGen_case(const gen_case* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGen_case(const gen_case* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterGen_region(const gen_region* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveGen_region(const gen_region* object, vpiHandle handle) { TRACE_LEAVE; }

  virtual void enterDesign(const design* object, vpiHandle handle) { TRACE_ENTER; }
  virtual void leaveDesign(const design* object, vpiHandle handle) { TRACE_LEAVE; }


  protected:
   std::ostream &strm;
   int32_t indent = -1;
  };
};

#endif
