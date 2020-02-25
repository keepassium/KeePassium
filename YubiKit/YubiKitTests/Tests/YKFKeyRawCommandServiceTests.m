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

#import <XCTest/XCTest.h>
#import "YKFTestCase.h"
#import "YKFKeyRawCommandService.h"
#import "YKFKeyRawCommandService+Private.h"
#import "FakeYKFKeyConnectionController.h"
#import "YKFAPDU+Private.h"

@interface YKFKeyRawCommandServiceTests: YKFTestCase

@property (nonatomic) FakeYKFKeyConnectionController *keyConnectionController;
@property (nonatomic) YKFKeyRawCommandService *rawCommandService;


@end

@implementation YKFKeyRawCommandServiceTests

- (void)setUp {
    self.keyConnectionController = [[FakeYKFKeyConnectionController alloc] init];
    self.rawCommandService = [[YKFKeyRawCommandService alloc] initWithConnectionController:self.keyConnectionController];
}

#pragma mark - Sync commands

- (void)test_WhenRunningSyncRawCommandsAgainstTheKey_CommandsAreForwardedToTheKey {
    NSData *command = [self dataWithBytes:@[@(0x01), @(0x02)]];
    NSData *commandResponse = [self dataWithBytes:@[@(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[commandResponse];
    
    NSData *responseData = [self executeSyncCommand:command];
    XCTAssertNotNil(responseData);
    
    YKFAPDU *executionCommand = self.keyConnectionController.executionCommand;
    XCTAssert([executionCommand.apduData isEqualToData:command], @"Command sent to the key does not match the initial command.");
}

- (void)test_WhenRunningSyncRawCommandsAgainstTheKey_StatusCodesAreReturned {
    NSData *command = [self dataWithBytes:@[@(0x01), @(0x02)]];
    NSData *commandResponse = [self dataWithBytes:@[@(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[commandResponse];
    
    NSData *responseData = [self executeSyncCommand:command];
    
    XCTAssertEqual(responseData.length, 2, @"Response data too short.");
    XCTAssert([responseData isEqualToData:commandResponse]);
}

#pragma mark - Async commands

- (void)test_WhenRunningAsyncRawCommandsAgainstTheKey_CommandsAreForwardedToTheKey {
    NSData *command = [self dataWithBytes:@[@(0x01), @(0x02)]];
    NSData *commandResponse = [self dataWithBytes:@[@(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[commandResponse];
    
    NSData *responseData = [self executeAsyncCommand:command];
    XCTAssertNotNil(responseData);
    
    YKFAPDU *executionCommand = self.keyConnectionController.executionCommand;
    XCTAssert([executionCommand.apduData isEqualToData:command], @"Command sent to the key does not match the initial command.");
}

- (void)test_WhenRunningAsyncRawCommandsAgainstTheKey_StatusCodesAreReturned {
    NSData *command = [self dataWithBytes:@[@(0x01), @(0x02)]];
    NSData *commandResponse = [self dataWithBytes:@[@(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[commandResponse];
    
    NSData *responseData = [self executeAsyncCommand:command];
    
    XCTAssertEqual(responseData.length, 2, @"Response data too short.");
    XCTAssert([responseData isEqualToData:commandResponse]);
}

#pragma mark - Helpers

- (NSData *)executeSyncCommand:(NSData *)command {
    __block BOOL completionBlockExecuted = NO;
    __block NSData *responseData = nil;
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Application selection."];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        YKFAPDU *commandAPDU = [[YKFAPDU alloc] initWithData:command];
        YKFKeyRawCommandServiceResponseBlock completionBlock = ^(NSData *response, NSError *error) {
            if (error) {
                return;
            }            
            completionBlockExecuted = YES;
            responseData = response;
        };
        [self.rawCommandService executeSyncCommand:commandAPDU completion:completionBlock];
        [expectation fulfill];
    });
    
    [self waitForTimeInterval:0.2];
    XCTAssertTrue(completionBlockExecuted, @"Completion block not executed.");

    return responseData;
}

- (NSData *)executeAsyncCommand:(NSData *)command {
    __block BOOL completionBlockExecuted = NO;
    __block NSData *responseData = nil;
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Application selection."];
    
    YKFAPDU *commandAPDU = [[YKFAPDU alloc] initWithData:command];
    [self.rawCommandService executeCommand:commandAPDU completion:^(NSData *response, NSError *error) {
        if (error) {
            return;
        }
        completionBlockExecuted = YES;
        responseData = response;
        [expectation fulfill];
    }];
    
    [self waitForTimeInterval:0.2];
    XCTAssertTrue(completionBlockExecuted, @"Completion block not executed.");
    
    return responseData;
}

@end
