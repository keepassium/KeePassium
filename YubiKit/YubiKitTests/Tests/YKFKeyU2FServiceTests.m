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
#import "YKFKeyU2FService.h"
#import "YKFKeyU2FService+Private.h"
#import "FakeYKFKeyConnectionController.h"

#import "YKFKeyU2FSignRequest.h"
#import "YKFKeyU2FRegisterRequest.h"

#import "YKFKeyAPDUError.h"
#import "YKFKeyU2FError.h"

@interface YKFKeyU2FServiceTests: YKFTestCase

@property (nonatomic) FakeYKFKeyConnectionController *keyConnectionController;
@property (nonatomic) YKFKeyU2FService *u2fService;

// Predefined U2F params
@property (nonatomic) NSString *challenge;
@property (nonatomic) NSString *keyHandle;
@property (nonatomic) NSString *appId;

@end

@implementation YKFKeyU2FServiceTests

- (void)setUp {
    [super setUp];
    
    self.challenge = @"J3tMC4hiRP9PDQ1M4IsOp8A-_oh6hge0c38CqwiqYmo";
    self.keyHandle  = @"UiC-Kth0iN3JmoSHFeHPu5M8GUvbhC-Gv8n0q0OBt42F3S1qTZBX81UudCuT29utRQZlTP5QpO_OncQFn5Mjaw";
    self.appId = @"https://demo.yubico.com";
    
    self.keyConnectionController = [[FakeYKFKeyConnectionController alloc] init];
    self.u2fService = [[YKFKeyU2FService alloc] initWithConnectionController:self.keyConnectionController];
}

- (void)test_WhenExecutingRegisterRequest_RequestIsForwarededToTheKey {
    NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *commandResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, commandResponse];
    
    __block BOOL completionBlockExecuted = NO;
    YKFKeyU2FRegisterRequest *registerRequest = [[YKFKeyU2FRegisterRequest alloc] initWithChallenge:self.challenge appId:self.appId];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    
    YKFKeyU2FServiceRegisterCompletionBlock completionBlock = ^(YKFKeyU2FRegisterResponse *response, NSError *error) {
        completionBlockExecuted = YES;
        [expectation fulfill];
    };
    [self.u2fService executeRegisterRequest:registerRequest completion:completionBlock];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");

    XCTAssertNotNil(self.keyConnectionController.executionCommand, @"No command data executed on the connection controller.");
    XCTAssertTrue(completionBlockExecuted, @"Completion block not executed.");
}

- (void)test_WhenExecutingSignRequest_RequestIsForwarededToTheKey {
    NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *commandResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, commandResponse];

    __block BOOL completionBlockExecuted = NO;
    YKFKeyU2FSignRequest *signRequest = [[YKFKeyU2FSignRequest alloc] initWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    
    YKFKeyU2FServiceSignCompletionBlock completionBlock = ^(YKFKeyU2FSignResponse *response, NSError *error) {
        completionBlockExecuted = YES;
        [expectation fulfill];
    };
    [self.u2fService executeSignRequest:signRequest completion:completionBlock];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    
    XCTAssertNotNil(self.keyConnectionController.executionCommand, @"No command data executed on the connection controller.");
    XCTAssertTrue(completionBlockExecuted, @"Completion block not executed.");
}

#pragma mark - Generic Error Tests

- (void)test_WhenExecutingRegisterRequestWithStatusErrorResponse_ErrorIsReceivedBack {
    NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [self dataWithBytes:@[@(0x00), @(0x6A), @(0x88)]];
    NSUInteger expectedErrorCode = 0x6A88;
    
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];
    
    __block BOOL errorReceived = NO;
    YKFKeyU2FRegisterRequest *registerRequest = [[YKFKeyU2FRegisterRequest alloc] initWithChallenge:self.challenge appId:self.appId];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    
    YKFKeyU2FServiceRegisterCompletionBlock completionBlock = ^(YKFKeyU2FRegisterResponse *response, NSError *error) {
        errorReceived = error.code == expectedErrorCode;
        [expectation fulfill];
    };
    [self.u2fService executeRegisterRequest:registerRequest completion:completionBlock];
    
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    
    XCTAssertTrue(errorReceived, @"Status error not received back.");
}

- (void)test_WhenExecutingSignRequestWithStatusErrorResponse_ErrorIsReceivedBack {
    NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [self dataWithBytes:@[@(0x00), @(0x69), @(0x84)]];
    NSUInteger expectedErrorCode = 0x6984;
    
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];
    __block BOOL errorReceived = NO;
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    
    YKFKeyU2FSignRequest *signRequest = [[YKFKeyU2FSignRequest alloc] initWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId];
    YKFKeyU2FServiceSignCompletionBlock completionBlock = ^(YKFKeyU2FSignResponse *response, NSError *error) {
        errorReceived = error.code == expectedErrorCode;
        [expectation fulfill];
    };
    
    [self.u2fService executeSignRequest:signRequest completion:completionBlock];

    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    
    XCTAssertTrue(errorReceived, @"Status error not received back.");
}

- (void)test_WhenExecutingSignRequestWithKnownStatusErrorResponse_ErrorIsReceivedBack {
    NSArray *listOfErrorStatusCodes = @[
        @[@(0x00), @(0x69), @(0x84), @(YKFKeyAPDUErrorCodeDataInvalid)],
        @[@(0x00), @(0x67), @(0x00), @(YKFKeyAPDUErrorCodeWrongLength)],
        @[@(0x00), @(0x6E), @(0x00), @(YKFKeyAPDUErrorCodeCLANotSupported)],
        @[@(0x00), @(0x6F), @(0x00), @(YKFKeyAPDUErrorCodeUnknown)]
    ];
    
    for (NSArray *statusCode in listOfErrorStatusCodes) {
        NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
        NSData *errorResponse = [self dataWithBytes:@[statusCode[0], statusCode[1], statusCode[2]]];
        int expectedErrorCode = [statusCode[3] intValue];
        
        self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];
        
        __block BOOL errorReceived = NO;
        YKFKeyU2FSignRequest *signRequest = [[YKFKeyU2FSignRequest alloc] initWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId];
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
        
        YKFKeyU2FServiceSignCompletionBlock completionBlock = ^(YKFKeyU2FSignResponse *response, NSError *error) {
            errorReceived = error.code == expectedErrorCode;
            [expectation fulfill];
        };
        
        [self.u2fService executeSignRequest:signRequest completion:completionBlock];

        XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
        XCTAssert(result == XCTWaiterResultCompleted, @"");
        
        XCTAssertTrue(errorReceived, @"Status error not received back.");
    }
}

- (void)test_WhenExecutingU2FRequestWithU2FDisabled_DisabledApplicationErrorIsReceivedBack {
    NSArray *listOfErrorStatusCodes = @[
        @[@(0x00), @(0x6D), @(0x00), @(YKFKeySessionErrorMissingApplicationCode)], // Ins Not Supported
        @[@(0x00), @(0x6A), @(0x82), @(YKFKeySessionErrorMissingApplicationCode)]  // Missing file
    ];
    
    for (NSArray *statusCode in listOfErrorStatusCodes) {
        NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
        if ([statusCode[1] intValue] == 0x6A) { // Missing file 
            applicationSelectionResponse = [self dataWithBytes:@[statusCode[0], statusCode[1], statusCode[2]]];
        }
        
        NSData *errorResponse = [self dataWithBytes:@[statusCode[0], statusCode[1], statusCode[2]]];
        int expectedErrorCode = [statusCode[3] intValue];
        
        self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];
        
        __block BOOL errorReceived = NO;
        YKFKeyU2FSignRequest *signRequest = [[YKFKeyU2FSignRequest alloc] initWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId];
        XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
        
        YKFKeyU2FServiceSignCompletionBlock completionBlock = ^(YKFKeyU2FSignResponse *response, NSError *error) {
            errorReceived = error.code == expectedErrorCode;
            [expectation fulfill];
        };
        
        [self.u2fService executeSignRequest:signRequest completion:completionBlock];
        
        XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
        XCTAssert(result == XCTWaiterResultCompleted, @"");
        
        XCTAssertTrue(errorReceived, @"Disabled application error not received back.");
    }
}

#pragma mark - Mapped Error Tests

- (void)test_WhenExecutingSignRequestWithoutRegistration_MappedErrorIsReceivedBack {
    NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [self dataWithBytes:@[@(0x00), @(0x6A), @(0x80)]]; // Wrong data code
    NSUInteger expectedErrorCode = YKFKeyU2FErrorCodeU2FSigningUnavailable;
    
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];
    
    __block BOOL errorReceived = NO;
    YKFKeyU2FSignRequest *signRequest = [[YKFKeyU2FSignRequest alloc] initWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    
    YKFKeyU2FServiceSignCompletionBlock completionBlock = ^(YKFKeyU2FSignResponse *response, NSError *error) {
        errorReceived = error.code == expectedErrorCode;
        [expectation fulfill];
    };
    [self.u2fService executeSignRequest:signRequest completion:completionBlock];
    
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    
    XCTAssertTrue(errorReceived, @"Status error not received back.");
}

#pragma mark - Key State Tests

- (void)test_WhenExecutingRegisterRequestWithTouchRequired_KeyStateIsUpdatingToTouchKey {
    NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [self dataWithBytes:@[@(0x00), @(0x69), @(0x85)]]; // Condition not satisified - touch the key
    NSData *successResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse, successResponse];
    
    YKFKeyU2FRegisterRequest *registerRequest = [[YKFKeyU2FRegisterRequest alloc] initWithChallenge:self.challenge appId:self.appId];
    YKFKeyU2FServiceRegisterCompletionBlock completionBlock = ^(YKFKeyU2FRegisterResponse *response, NSError *error) {};
    [self.u2fService executeRegisterRequest:registerRequest completion:completionBlock];
    
    [self waitForTimeInterval:0.3]; // give time to update the property
    
    YKFKeyU2FServiceKeyState keyState = self.u2fService.keyState;
    
    XCTAssertTrue(keyState == YKFKeyU2FServiceKeyStateTouchKey, @"The keys state did not update to touch key.");
}

- (void)disabled_test_WhenExecutingSignRequestWithTouchRequired_KeyStateIsUpdatingToTouchKey {
    NSData *applicationSelectionResponse = [self dataWithBytes:@[@(0x00), @(0x90), @(0x00)]];
    NSData *errorResponse = [self dataWithBytes:@[@(0x00), @(0x69), @(0x85)]]; // Condition not satisified - touch the key
    
    self.keyConnectionController.commandExecutionResponseDataSequence = @[applicationSelectionResponse, errorResponse];
    
    YKFKeyU2FSignRequest *signRequest = [[YKFKeyU2FSignRequest alloc] initWithChallenge:self.challenge keyHandle:self.keyHandle appId:self.appId];
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"U2F"];
    
    YKFKeyU2FServiceSignCompletionBlock completionBlock = ^(YKFKeyU2FSignResponse *response, NSError *error) {
        [expectation fulfill];
    };
    [self.u2fService executeSignRequest:signRequest completion:completionBlock];
    
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:10];
    XCTAssert(result == XCTWaiterResultCompleted, @"");
    
    YKFKeyU2FServiceKeyState keyState = self.u2fService.keyState;
    
    XCTAssertTrue(keyState == YKFKeyU2FServiceKeyStateTouchKey, @"The keys state did not update to touch key.");
}

- (void)test_WhenNoRequestWasSentToTheKey_KeyStateIsIdle {
    YKFKeyU2FServiceKeyState keyState = self.u2fService.keyState;
    XCTAssertTrue(keyState == YYKFKeyU2FServiceKeyStateIdle, @"The keys state idle when the service does not execute a request.");
}

@end
