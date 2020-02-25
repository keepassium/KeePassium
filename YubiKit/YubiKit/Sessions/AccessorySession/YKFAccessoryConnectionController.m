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

#import "YKFAccessoryConnectionController.h"
#import "YKFKeyAPDUError.h"
#import "YKFLogger.h"
#import "YKFDispatch.h"
#import "YKFBlockMacros.h"
#import "YKFAssert.h"

#import "YKFNSDataAdditions+Private.h"
#import "YKFKeySessionError+Private.h"
#import "YKFAPDU+Private.h"

typedef void (^YKFKeyConnectionControllerCommunicationQueueBlock)(NSOperation *operation);

@interface YKFAccessoryConnectionController()

@property (nonatomic) NSOperationQueue *communicationQueue;
@property (nonatomic) NSMutableDictionary *delayedDispatches;

@property (nonatomic) NSInputStream *inputStream;
@property (nonatomic) NSOutputStream *outputStream;
@property (nonatomic) NSThread *streamsThread;

@end

@implementation YKFAccessoryConnectionController

static NSUInteger const YubiKeyConnectionControllerReadBufferSize = 512; // bytes

- (instancetype)initWithSession:(id<YKFEASessionProtocol>)session operationQueue:(NSOperationQueue *)operationQueue {
    YKFAssertAbortInit(session);
    YKFAssertAbortInit(operationQueue);
    
    self = [super init];
    if (self) {
        self.communicationQueue = operationQueue;
        self.inputStream = session.inputStream;
        self.outputStream = session.outputStream;
        
        YKFAssertAbortInit(self.inputStream);
        YKFAssertAbortInit(self.outputStream);
        
        self.delayedDispatches = [[NSMutableDictionary alloc] init];
        
        self.streamsThread = [[NSThread alloc] initWithTarget: self selector:@selector(streamsThreadExecution) object:nil];
        [self.streamsThread start];
        
        ykf_weak_self();
        [self dispatchBlockOnCommunicationQueue:^(NSOperation *operation){
            ykf_safe_strong_self();
            [strongSelf setupConnectionInputStream:strongSelf.inputStream outputStream:strongSelf.outputStream];
        }];
    }
    return self;
}

- (void)closeConnectionWithCompletion:(YKFKeyConnectionControllerCompletionBlock)completionBlock {
    YKFParameterAssertReturn(completionBlock);
    
    [self cancelAllCommands];
    
    ykf_weak_self();
    [self dispatchBlockOnCommunicationQueue:^(NSOperation *operation){
        ykf_safe_strong_self();
        [strongSelf closeConnectionInputStream:strongSelf.inputStream outputStream:strongSelf.outputStream];
        completionBlock();
    }];
}

#pragma mark - Dispatching

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

- (void)streamsThreadExecution {
    YKFAssertOffMainThread();
    
    // This adds a dummy port to keep the run look alive so the accessory input/output
    // streams will be able to be attached to the existing run loop and receive events.
    NSPort* keepAlivePort = [NSPort port];
    [keepAlivePort scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    CFRunLoopRun();
    [keepAlivePort removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
}

#pragma mark - Stream setup

- (void)setupConnectionInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    YKFAssertOffMainThread();
    YKFAssertReturn(self.streamsThread, @"Cannot start communication streams. Thread not available.");
    
    // Streams are opened on a dedicated background thread with its own runloop to avoid
    // the delays from the main thread when the UI work is intensive on low end devices.
    ykf_dispatch_thread_async(self.streamsThread, ^{
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        
        [inputStream scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        [inputStream open];
        
        [outputStream scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        [outputStream open];
        
        YKFLogInfo(@"YubiKey communication streams opened.");
    });
}

- (void)closeConnectionInputStream:(NSInputStream *)inputStream outputStream:(NSOutputStream *)outputStream {
    YKFAssertOffMainThread();
    
    // The streams must be closed on the same runloop as the one they started on.
    ykf_dispatch_thread_async(self.streamsThread, ^{
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        
        if (inputStream.streamStatus != NSStreamStatusClosed) {
            [inputStream close];
        }
        [inputStream removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        
        if (outputStream.streamStatus != NSStreamStatusClosed) {
            [outputStream close];
        }
        [outputStream removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
        
        CFRunLoopStop(CFRunLoopGetCurrent());
        
        YKFLogInfo(@"YubiKey communication streams closed.");
    });
}

#pragma mark - Stream IO

- (BOOL)writeData:(NSData *)data configuration:(YKFKeyCommandConfiguration *)configuration parentOperation:(NSOperation *)operation {
    YKFAssertOffMainThread();
    
    YKFParameterAssertReturnValue(data, NO);
    YKFParameterAssertReturnValue(self.outputStream, NO);
    
    NSMutableData *writeData = [data mutableCopy];
    NSTimeInterval totalSleepTime = 0;
    
    while (writeData.length > 0 && !operation.isCancelled) {
        while (self.outputStream.hasSpaceAvailable && writeData.length > 0 && !operation.isCancelled) {
            NSInteger bytesWritten = [self.outputStream write:writeData.bytes maxLength:writeData.length];
            if (bytesWritten > 0) {
                [writeData replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
            } else if (bytesWritten == -1) { // Write error.
                return NO;
            }
        }
        
        [NSThread sleepForTimeInterval: configuration.commandProbeTime];
        totalSleepTime += configuration.commandProbeTime;
        if (totalSleepTime >= configuration.commandTimeout) {
            return NO;
        }
    }
    
    if (operation.isCancelled) {
        return  NO;
    }
    
    return YES;
}

- (BOOL)readData:(NSData**)readData configuration:(YKFKeyCommandConfiguration *)configuration parentOperation:(NSOperation *)operation {
    YKFAssertOffMainThread();
    YKFParameterAssertReturnValue(self.inputStream, NO);
    
    NSMutableData *buffer = [[NSMutableData alloc] init];
    UInt8 readBuffer[YubiKeyConnectionControllerReadBufferSize];
    
    NSTimeInterval totalSleepTime = 0;
    while (!self.inputStream.hasBytesAvailable && !operation.isCancelled) {
        [NSThread sleepForTimeInterval: configuration.commandProbeTime];
        totalSleepTime += configuration.commandProbeTime;
        if (totalSleepTime >= configuration.commandTimeout) {
            return NO;
        }
    }
    
    if (operation.isCancelled) {
        return NO;
    }
    
    // Read the data while available.
    while (self.inputStream.hasBytesAvailable) {
        NSInteger bytesRead = [self.inputStream read:readBuffer maxLength:YubiKeyConnectionControllerReadBufferSize];
        if (bytesRead > 0) {
            [buffer appendBytes:readBuffer length:bytesRead];
        } else if (bytesRead == -1) { // Read error.
            return NO;
        }
    }
    
    *readData = [buffer copy];
    
    return YES;
}

#pragma mark - Commands

- (void)execute:(YKFAPDU *)command completion:(YKFKeyConnectionControllerCommandResponseBlock)completion {
    [self execute:command configuration:[YKFKeyCommandConfiguration defaultCommandCofiguration] completion:completion];
}

- (void)execute:(YKFAPDU *)command configuration:(YKFKeyCommandConfiguration *)configuration completion:(YKFKeyConnectionControllerCommandResponseBlock)completion {
    YKFParameterAssertReturn(command);
    YKFParameterAssertReturn(configuration);
    YKFParameterAssertReturn(completion);
    
    YKFLogVerbose(@"AccessoryConnectionController - Execute command...");
    
    ykf_weak_self();
    [self dispatchBlockOnCommunicationQueue:^(NSOperation *operation) {
        ykf_safe_strong_self();
        NSDate *commandStartDate = [NSDate date];
        
        // 1. Send the command to the key.
        BOOL success = [strongSelf writeData:command.ylpApduData configuration:configuration parentOperation:operation];
        
        if (!success && !operation.isCancelled) {
            NSError *error = nil;
            if (strongSelf.outputStream.streamError) {
                error = [strongSelf.outputStream.streamError copy];
            } else {
                error = [YKFKeySessionError errorWithCode:YKFKeySessionErrorWriteTimeoutCode];
            }
            
            NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate: commandStartDate];
            completion(nil, error, executionTime);
            return;
        }

        // Do not wait for the command to process if the operation was canceled.
        if (operation.isCancelled) {
            return;
        }

        BOOL keyIsBusyProcesssing = YES;
        NSData *commandResult = nil;

        while (keyIsBusyProcesssing) {
            // 2. Wait for the key to process the command.
            if (configuration.commandTime > 0) {
                [NSThread sleepForTimeInterval: configuration.commandTime];
            }
            
            // 3. Read the command result.
            success = [strongSelf readData:&commandResult configuration:configuration parentOperation:operation];
            
            if ((!success || commandResult.length == 0) && !operation.isCancelled) {
                NSError *error = nil;
                if (strongSelf.inputStream.streamError) {
                    error = [strongSelf.inputStream.streamError copy];
                } else {
                    error = [YKFKeySessionError errorWithCode:YKFKeySessionErrorReadTimeoutCode];
                }
                
                NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate: commandStartDate];
                completion(nil, error, executionTime);
                return;
            }
            
            // Do not notify if the operation was canceled.
            if (operation.isCancelled) {
                return;
            }
            
            keyIsBusyProcesssing = [strongSelf isKeyBusyProcessingResult:commandResult];
            if (keyIsBusyProcesssing) {
                YKFLogVerbose(@"The key is busy, processing the request. Waiting for response...");
            }
        }
        
        NSTimeInterval executionTime = [[NSDate date] timeIntervalSinceDate: commandStartDate];
        commandResult = [self dataAndStatusFromKeyResponse:commandResult];
        
        completion(commandResult, nil, executionTime);
        
        YKFLogVerbose(@"Command execution time: %lf seconds", executionTime);
    }];
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

/*
 Returns YES if the key returned a status code with the header 0x01 (key is busy processing the request).
 This status code is usually returned by CCID operations which require time to
 complete like a certificate generation. When the key will finish to process the request it will send
 again a new response, 0x9000 if the processig was successful or error code.
 
 These responses should be received periodically (~500ms) while the key is processing.
 */
- (BOOL)isKeyBusyProcessingResult:(NSData *)result {
    YKFParameterAssertReturnValue(result, NO);
    YKFParameterAssertReturnValue(result.length >= 3, NO);
    
    UInt8 headerByte;
    [result getBytes:&headerByte length:1];
    
    // BUG #62 - Workaround for WTX == 0x01 while status is 0x9000 (success).
    BOOL statusIsSuccess = [result ykf_getBigEndianIntegerInRange:NSMakeRange(result.length - 2, 2)] == YKFKeyAPDUErrorCodeNoError;
    // ~
    
    return headerByte == 0x01 && !statusIsSuccess;
}

- (NSData *)dataAndStatusFromKeyResponse:(NSData *)response {
    YKFParameterAssertReturnValue(response, [NSData data]);
    YKFAssertReturnValue(response.length >= 3, @"Key response data is too short.", [NSData data]);
    
    UInt8 *bytes = (UInt8 *)response.bytes;
    YKFParameterAssertReturnValue(bytes[0] == 0x00 || bytes[0] == 0x01, [NSData data]);
    
    if (bytes[0] == 0x00) {
        // Remove the first byte (the YLP key protocol header)
        NSRange range = {1, response.length - 1};
        return [response subdataWithRange:range];
    }
    else if (bytes[0] == 0x01) {
        // Remove the first byte (the YLP key protocol header) and the WTX
        NSRange range = {4, response.length - 4};
        return [response subdataWithRange:range];
    }
    
    return [NSData data];
}

@end
