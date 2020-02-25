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

#import "YKFDispatch.h"

void ykf_dispatch_thread_async(NSThread* thread, dispatch_block_t block) {
    if ([NSThread currentThread] == thread) {
        block();
    } else {
        block = [block copy];
        [(id)block performSelector: @selector(invoke) onThread: thread withObject: nil waitUntilDone: NO];
    }
}

void ykf_dispatch_thread_sync(NSThread* thread, dispatch_block_t block) {
    if ([NSThread currentThread] == thread) {
        block();
    } else {
        [(id)block performSelector: @selector(invoke) onThread: thread withObject: nil waitUntilDone: YES];
    }
}

void ykf_dispatch_block_main(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

void ykf_dispatch_block_sync_main(dispatch_block_t block) {
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}
