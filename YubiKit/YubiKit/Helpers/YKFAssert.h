// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/*
 Checks for condition to be true. If the condition is false it will nullify self and return nil from the initializer.
 This macro must be used in initializers only!
 */
#define YKFAbortInitWhen(condition) if (condition) { self = nil; return nil; }

/*
 This macro is an extension of ykf_abort_init_when(condition). It has a different behaviour between release and debug builds:
 - In release builds it will behave like ykf_abort_init_when(condition) because assertions are disabled.
 - In debug builds it will assert for state to be true and stop the execution.
 This macro must be used in initializers only!
 */
#define YKFAssertAbortInit(state) NSAssert(state, @"Did not satisfy initializer requirements."); YKFAbortInitWhen(!(state))

/*
 This macro has a different behaviour between release and debug builds:
 - In release builds it will return because assertions are disabled.
 - In debug builds it will assert for state to be true and stop the execution.
 */
#define YKFParameterAssertReturn(state) NSAssert(state, @"Did not satisfy parameter requirements."); if (!(state)) { return; }

/*
 This macro has a different behaviour between release and debug builds:
 - In release builds it will return the specified value because assertions are disabled.
 - In debug builds it will assert for state to be true and stop the execution.
 */
#define YKFParameterAssertReturnValue(state, value) NSParameterAssert(state); if (!(state)) { return value; }

/*
 This macro has a different behaviour between release and debug builds:
 - In release builds it will return because assertions are disabled.
 - In debug builds it will assert for state to be true and stop the execution.
 */
#define YKFAssertReturn(state, message) NSAssert(state, message); if (!(state)) { return; }

/*
 This macro has a different behaviour between release and debug builds:
 - In release builds it will return the specified value because assertions are disabled.
 - In debug builds it will assert for state to be true and stop the execution.
 */
#define YKFAssertReturnValue(state, message, value) NSAssert(state, message); if (!(state)) { return value; }

//
// Thread Execution Assertions
//

/*
 Asserts that the execution happens off the main thread.
 */
#define YKFAssertOffMainThread() NSAssert(![NSThread isMainThread], @"Execution not allowed on the main thread.")

/*
 Asserts that the execution happens off the main thread (C Version).
 */
#define YKFCAssertOffMainThread() NSCAssert(![NSThread isMainThread], @"Execution not allowed on the main thread.")

/*
 Asserts that the execution happens on the main thread.
 */
#define YKFAssertOnMainThread() NSAssert([NSThread isMainThread], @"Execution not allowed off the main thread.")

/*
 Asserts that the execution happens on the main thread (C Version).
 */
#define YKFCAssertOnMainThread() NSCAssert([NSThread isMainThread], @"Execution not allowed off the main thread.")
