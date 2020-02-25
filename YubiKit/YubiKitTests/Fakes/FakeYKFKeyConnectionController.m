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

#import "FakeYKFKeyConnectionController.h"

@interface FakeYKFKeyConnectionController()

@property (nonatomic, assign) NSUInteger commandExecutionSequenceIndex;

@end

@implementation FakeYKFKeyConnectionController

- (void)setCommandExecutionResponseDataSequence:(NSArray *)commandExecutionResponseDataSequence {
    _commandExecutionResponseDataSequence = commandExecutionResponseDataSequence;
    self.commandExecutionSequenceIndex = 0;
}

- (void)setCommandExecutionResponseErrorSequence:(NSArray *)commandExecutionResponseErrorSequence {
    _commandExecutionResponseErrorSequence = commandExecutionResponseErrorSequence;
    self.commandExecutionSequenceIndex = 0;
}

#pragma mark - YKFKeyConnectionControllerProtocol

- (void)execute:(YKFAPDU *)command completion:(YKFKeyConnectionControllerCommandResponseBlock)completion {
    self.executionCommand = command;
    self.commandResponseBlock = completion;
    
    NSData *responseData = [self nextResponseDataInSequence];
    NSError *responseError = [self nextResponseErrorInSequence];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(responseData, responseError, 0);
    });
    
    ++self.commandExecutionSequenceIndex;
}

- (void)execute:(YKFAPDU *)command configuration:(YKFKeyCommandConfiguration *)configuration completion:(YKFKeyConnectionControllerCommandResponseBlock)completion {
    self.executionCommand = command;
    self.commandResponseBlock = completion;
    
    NSData *responseData = [self nextResponseDataInSequence];
    NSError *responseError = [self nextResponseErrorInSequence];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        completion(responseData, responseError, 0);
    });

    ++self.commandExecutionSequenceIndex;
}

- (void)dispatchOnSequentialQueue:(YKFKeyConnectionControllerCompletionBlock)block delay:(NSTimeInterval)delay {
    self.operationExecutionBlock = block;
    
    if (delay == 0) {
        block();
    } else {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (double)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            block();
        });
    }
}

- (void)dispatchOnSequentialQueue:(nonnull YKFKeyConnectionControllerCompletionBlock)block {
    [self dispatchOnSequentialQueue:block delay:0];
}

- (void)closeConnectionWithCompletion:(YKFKeyConnectionControllerCompletionBlock)completion {
    self.operationExecutionBlock = completion;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        completion();
    });
}

- (void)cancelAllCommands {
    // Do nothing
}

#pragma mark - Helpers

- (NSData *)nextResponseDataInSequence {
    if (!self.commandExecutionResponseDataSequence.count) {
        return nil;
    }
    if (self.commandExecutionSequenceIndex < self.commandExecutionResponseDataSequence.count) {
        return self.commandExecutionResponseDataSequence[self.commandExecutionSequenceIndex];
    }
    
    return nil;
}

- (NSError *)nextResponseErrorInSequence {
    if (!self.commandExecutionResponseErrorSequence.count) {
        return nil;
    }
    if (self.commandExecutionSequenceIndex < self.commandExecutionResponseErrorSequence.count) {
        return self.commandExecutionResponseErrorSequence[self.commandExecutionSequenceIndex];
    }

    return self.commandExecutionResponseErrorSequence[self.commandExecutionSequenceIndex];
}

@end
