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
 * File:   config.h
 * Author: hs-apotell
 *
 * Created on April 09, 2023, 12:00 AM
 */
#pragma once

#define UHDM_SYMBOLID_DEBUG_ENABLED 0

#if defined(_MSC_VER)
  // Since windows is built with /w4, disable a few warnings
  // that aren't very useful
  #pragma warning(disable: 4100)  // unreferenced formal parameter
  #pragma warning(disable: 4146)  // unary minus operator applied to unsigned
                                  // type, result still unsigned
  #pragma warning(disable: 4244)  // 'argument' : conversion from 'type1' to
                                  // 'type2', possible loss of data
  #pragma warning(disable: 4267)  // 'argument': conversion from 'size_t' to
                                  // 'unsigned int', possible loss of data
  #pragma warning(disable: 4334)  // '<<': result of 32-bit shift implicitly
                                  // converted to 64 bits (was 64-bit shift
                                  // intended?)
  #pragma warning(disable: 4456)  // declaration of '' hides previous local
                                  // declaration
  #pragma warning(disable: 4457)  // declaration of '' hides function parameter
  #pragma warning(disable: 4458)  // declaration of '' hides class member
  #pragma warning(disable: 4706)  // assignment within conditional expression

  #define S_IRWXU (_S_IREAD | _S_IWRITE)
#elif !(defined(__MINGW32__) || defined(__CYGWIN__))
  #define O_BINARY 0
#endif
