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

#import "YKFNFCConnectionController.h"
#import "YKFNSMutableDataAdditions.h"
#import "YKFBlockMacros.h"
#import "YKFLogger.h"
#import "YKFAssert.h"
#import "YKFAPDU+Private.h"

typedef void (^YKFKeyConnectionControllerCommunicationQueueBlock)(NSOperation *operation);

@interface YKFNFCConnectionController()

@property (nonatomic) NSOperationQueue *communicationQueue;
@property (nonatomic) NSMutableDictionary *delayedDispatches;

@property (nonatomic) id<NFCISO7816Tag> tag;

@end

@implementation YKFNFCConnectionController

- (instancetype)initWithNFCTag:(id<NFCISO7816Tag>)tag operationQueue:(NSOperationQueue *)operationQueue {
    self = [super init];
    if (self) {
        self.tag = tag;
        self.communicationQueue = operationQueue;        
        self.delayedDispatches = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Commands

- (void)execute:(nonnull YKFAPDU *)command completion:(nonnull YKFKeyConnectionControllerCommandResponseBlock)completion {
    [self execute:command configuration:[YKFKeyCommandConfiguration defaultCommandCofiguration] completion:completion];
}

- (void)execute:(nonnull YKFAPDU *)command configuration:(nonnull YKFKeyCommandConfiguration *)configuration completion:(nonnull YKFKeyConnectionControllerCommandResponseBlock)completion {
    YKFParameterAssertReturn(command);
    YKFParameterAssertReturn(configuration);
    YKFParameterAssertReturn(completion);
    
    YKFLogVerbose(@"NFCConnectionController - Execute command...");
    
    ykf_weak_self();
    [self dispatchBlockOnCommunicationQueue:^(NSOperation *operation) {
        ykf_safe_strong_self();
      
        // Do not wait for the command to process if the operation was canceled.
        if (operation.isCancelled) {
            return;
        }
        
        // Check availability before executing. If the command is queued, the tag may become unavailable at execution time.
        if (!strongSelf.tag.isAvailable) {
            return;
        }
                
        NFCISO7816APDU *cnApdu = [[NFCISO7816APDU alloc] initWithData:command.apduData];
        YKFAssertReturn(cnApdu, @"Could not create a Core NFC APDU object from the command data.");

        __block NSError *executionError = nil;
        __block NSData *executionResult = nil;
        NSDate *commandStartDate = [NSDate date];
        dispatch_semaphore_t executionSemaphore = dispatch_semaphore_create(0);
        
        [strongSelf.tag sendCommandAPDU:cnApdu completionHandler:^(NSData *responseData, uint8_t sw1, uint8_t sw2, NSError *error) {
            if (error) {
                executionError = error;
                dispatch_semaphore_signal(executionSemaphore);
                return;
            }
            
            NSMutableData *fullResponse = [[NSMutableData alloc] initWithData:responseData];
            [fullResponse ykf_appendByte:sw1];
            [fullResponse ykf_appendByte:sw2];
            executionResult = [fullResponse copy];
            
            dispatch_semaphore_signal(executionSemaphore);
        }];
        
        // Lock the async call to enforce the sequential execution using the library dispatch queue.
        dispatch_semaphore_wait(executionSemaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(configuration.commandTimeout * NSEC_PER_SEC)));
        
        // Do not notify if the operation was canceled.
        if (operation.isCancelled) {
            return;
        }

        NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate: commandStartDate];
        if (executionError) {
            completion(nil, executionError, executionTime);
        } else {
            YKFAssertReturn(executionResult, @"The command did not return any response data when error was not nil.");
            completion(executionResult, nil, executionTime);
        }
        
        YKFLogVerbose(@"Command execution time: %lf seconds", executionTime);
    }];
}

- (void)closeConnectionWithCompletion:(nonnull YKFKeyConnectionControllerCompletionBlock)completion {
    // Does nothing: The NFCISO7816Tag doesn't expose a stream for communication.
    completion();
}

- (void)dispatchOnSequentialQueue:(YKFKeyConnectionControllerCompletionBlock)block delay:(NSTimeInterval)delay {
    dispatch_queue_t sharedDispatchQueue = self.communicationQueue.underlyingQueue;
    
    YKFParameterAssertReturn(sharedDispatchQueue);
    YKFParameterAssertReturn(block);

    block = [block copy]; // heap block
    
    if (delay == 0) {
        dispatch_async(sharedDispatchQueue, block);
    } else {
        NSString *blockId = [NSUUID UUID].UUIDString;
        
        ykf_weak_self();
        dispatch_block_t delayedBlock = dispatch_block_create(0, ^{
            ykf_safe_strong_self();
            dispatch_block_t blockReference = strongSelf.delayedDispatches[blockId];
            strongSelf.delayedDispatches[blockId] = nil;
            
            // In case the block started already to run.
            if (blockReference && dispatch_block_testcancel(blockReference)) {
                return;
            }
            
            block();
        });
        
        self.delayedDispatches[blockId] = delayedBlock;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), sharedDispatchQueue, delayedBlock);
    }
}

- (void)dispatchOnSequentialQueue:(YKFKeyConnectionControllerCompletionBlock)block {
    YKFParameterAssertReturn(block);
    [self dispatchOnSequentialQueue:block delay:0];
}

- (void)cancelAllCommands {
    self.communicationQueue.suspended = YES;
    dispatch_suspend(self.communicationQueue.underlyingQueue);
    
    [self.communicationQueue cancelAllOperations];
    
    NSArray *keys = self.delayedDispatches.allKeys;
    for (NSString *key in keys) {
        dispatch_block_t block = self.delayedDispatches[key];
        dispatch_block_cancel(block);
    };
    [self.delayedDispatches removeAllObjects];
    
    dispatch_resume(self.communicationQueue.underlyingQueue);
    self.communicationQueue.suspended = NO;
}

#pragma mark - Helpers

- (void)dispatchBlockOnCommunicationQueue:(YKFKeyConnectionControllerCommunicationQueueBlock)block {
    YKFParameterAssertReturn(block);
    
    NSBlockOperation *operation = [[NSBlockOperation alloc] init];
    __weak NSBlockOperation *weakOperation = operation;
    
    [operation addExecutionBlock:^{
        __strong NSBlockOperation *strongOperation = weakOperation;
        if (!strongOperation || strongOperation.isCancelled) {
            return;
        }
        block(strongOperation); // Execute the operation if it's still alive and not canceled.
    }];
    
    [self.communicationQueue addOperation:operation];
}

@end
