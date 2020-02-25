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

#import "YKFKeyRawCommandService.h"
#import "YKFKeyRawCommandService+Private.h"
#import "YKFAccessoryConnectionController.h"
#import "YKFKeyCommandConfiguration.h"
#import "YKFKeySessionError.h"
#import "YKFBlockMacros.h"
#import "YKFAssert.h"

#import "YKFAPDU+Private.h"
#import "YKFKeyService+Private.h"
#import "YKFKeySessionError+Private.h"

// Make a long timeout. This should be double checked by WTX responses.
static const NSTimeInterval YKFKeyRawCommandServiceCommandTimeout = 600;

@interface YKFKeyRawCommandService()

@property (nonatomic) id<YKFKeyConnectionControllerProtocol> connectionController;
@property (nonatomic) YKFKeyCommandConfiguration *commandExecutionConfiguration;

@end

@implementation YKFKeyRawCommandService

- (instancetype)initWithConnectionController:(id<YKFKeyConnectionControllerProtocol>)connectionController {
    YKFAssertAbortInit(connectionController);
    
    self = [super init];
    if (self) {
        self.connectionController = connectionController;
        self.commandExecutionConfiguration = [YKFKeyCommandConfiguration defaultCommandCofiguration];
    }
    return self;
}

#pragma mark - Command Execution

- (void)executeCommand:(YKFAPDU *)apdu completion:(YKFKeyRawCommandServiceResponseBlock)completion {
    YKFParameterAssertReturn(apdu);
    YKFParameterAssertReturn(completion);
    
    [self.delegate keyService:self willExecuteRequest:nil];
    
    [self.connectionController execute:apdu
                         configuration:self.commandExecutionConfiguration
                            completion:^(NSData *response, NSError * error, NSTimeInterval executionTime) {
        if (error) {
            completion(nil, error);
            return;
        }
        completion(response, nil);
    }];
}

- (void)executeSyncCommand:(YKFAPDU *)apdu completion:(YKFKeyRawCommandServiceResponseBlock)completion {
    YKFParameterAssertReturn(apdu);
    YKFParameterAssertReturn(completion);
    
    YKFAssertOffMainThread();
    
    [self.delegate keyService:self willExecuteRequest:nil];
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    ykf_weak_self();
    [self.connectionController execute:apdu
                         configuration:self.commandExecutionConfiguration
                            completion:^(NSData *response, NSError * error, NSTimeInterval executionTime) {
        ykf_safe_strong_self();
        if (error) {
            completion(nil, error);
            dispatch_semaphore_signal(semaphore);
            return;
        }
        
        completion(response, nil);
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(YKFKeyRawCommandServiceCommandTimeout * NSEC_PER_SEC));
    long requestDidTimeout = dispatch_semaphore_wait(semaphore, timeout);
    
    if (requestDidTimeout) {
        completion(nil, [YKFKeySessionError errorWithCode:YKFKeySessionErrorReadTimeoutCode]);
    }
}

@end
