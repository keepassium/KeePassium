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
#import "YKFAccessoryConnectionController.h"
#import "FakeEASession.h"
#import "YKFAPDU+Private.h"

@interface YKFAccessoryConnectionControllerTests: YKFTestCase

@property (nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic) dispatch_queue_t sharedDispatchQueue;

@property (nonatomic) FakeEASession *eaSession;

@end

@implementation YKFAccessoryConnectionControllerTests

- (void)setUp {
    [super setUp];
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = 1;
    
    dispatch_queue_attr_t dispatchQueueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, -1);
    self.sharedDispatchQueue = dispatch_queue_create("com.yubico.YKCommunication", dispatchQueueAttributes);
    
    self.operationQueue.underlyingQueue = self.sharedDispatchQueue;
}

- (void)tearDown {
    [super tearDown];
    self.operationQueue = nil;
    self.sharedDispatchQueue = nil;
}

- (void)test_WhenConnectionControllerIsCreated_SessionStreamsAreOpened {
    NSData *inputData = [@"data" dataUsingEncoding:NSUTF8StringEncoding];
    self.eaSession = [[FakeEASession alloc] initWithInputData:inputData accessory:nil protocol:@"YLP"];
    
    YKFAccessoryConnectionController *connectionController = [[YKFAccessoryConnectionController alloc] initWithSession:self.eaSession operationQueue:self.operationQueue];
    [self waitForTimeInterval:0.2];
    
    XCTAssert(self.eaSession.inputStream.streamStatus == NSStreamStatusOpen);
    XCTAssert(self.eaSession.outputStream.streamStatus == NSStreamStatusOpen);
    
    connectionController = nil;
}

- (void)test_WhenConnectionControllerIsClosed_SessionStreamsAreClosed {
    NSData *inputData = [@"data" dataUsingEncoding:NSUTF8StringEncoding];
    self.eaSession = [[FakeEASession alloc] initWithInputData:inputData accessory:nil protocol:@"YLP"];
    
    YKFAccessoryConnectionController *connectionController = [[YKFAccessoryConnectionController alloc] initWithSession:self.eaSession operationQueue:self.operationQueue];
    
    [self waitForTimeInterval:0.2];
    
    XCTAssert(self.eaSession.inputStream.streamStatus == NSStreamStatusOpen);
    XCTAssert(self.eaSession.outputStream.streamStatus == NSStreamStatusOpen);
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Close key connection controller completion"];
    [connectionController closeConnectionWithCompletion:^{
        [expectation fulfill];
    }];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:1];
    XCTAssert(result == XCTWaiterResultCompleted);
    
    [self waitForTimeInterval:0.2];
    
    XCTAssert(self.eaSession.inputStream.streamStatus == NSStreamStatusClosed);
    XCTAssert(self.eaSession.outputStream.streamStatus == NSStreamStatusClosed);
}

- (void)test_WhenConnectionControllerWritesCommands_CommandsAreWrittenToTheOutputStream {
    UInt8 inputBytes[] = {0x00, 0x90, 0x00};
    NSData *inputData = [[NSData alloc] initWithBytes:inputBytes length:3];
    
    self.eaSession = [[FakeEASession alloc] initWithInputData:inputData accessory:nil protocol:@"YLP"];
    
    YKFAccessoryConnectionController *connectionController = [[YKFAccessoryConnectionController alloc] initWithSession:self.eaSession operationQueue:self.operationQueue];
    [self waitForTimeInterval:0.2];
    
    XCTAssert(self.eaSession.inputStream.streamStatus == NSStreamStatusOpen);
    XCTAssert(self.eaSession.outputStream.streamStatus == NSStreamStatusOpen);
    
    // Execute command
    
    NSData *commandData = [@"command" dataUsingEncoding:NSUTF8StringEncoding];
    YKFAPDU *command = [[YKFAPDU alloc] initWithData:commandData];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Command execution completion."];
    [connectionController execute:command completion:^(NSData *result, NSError *error, NSTimeInterval executionTime) {
        [expectation fulfill];
    }];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:1];
    XCTAssert(result == XCTWaiterResultCompleted);

    // Check the written data
    
    NSData *writtenData = [self.eaSession outputStreamData];
    XCTAssert([writtenData isEqualToData:command.ylpApduData], @"Command data doesn't match written data.");
}

- (void)test_WhenConnectionControllerWritesCommands_ResponseIsReadFromTheInputStream {
    UInt8 inputBytes[] = {0x00, 0x90, 0x00};
    NSData *inputData = [[NSData alloc] initWithBytes:inputBytes length:3];

    self.eaSession = [[FakeEASession alloc] initWithInputData:inputData accessory:nil protocol:@"YLP"];
    
    YKFAccessoryConnectionController *connectionController = [[YKFAccessoryConnectionController alloc] initWithSession:self.eaSession operationQueue:self.operationQueue];
    [self waitForTimeInterval:0.2];
    
    XCTAssert(self.eaSession.inputStream.streamStatus == NSStreamStatusOpen);
    XCTAssert(self.eaSession.outputStream.streamStatus == NSStreamStatusOpen);
    
    // Execute command
    
    NSData *commandData = [@"command" dataUsingEncoding:NSUTF8StringEncoding];
    YKFAPDU *command = [[YKFAPDU alloc] initWithData:commandData];
    
    __block NSData *response = nil;
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Command execution completion."];
    [connectionController execute:command completion:^(NSData *result, NSError *error, NSTimeInterval executionTime) {
        response = result;
        [expectation fulfill];
    }];
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:1];
    XCTAssert(result == XCTWaiterResultCompleted);
    
    // Check the response data
    
    XCTAssert([response isEqualToData:[inputData subdataWithRange:NSMakeRange(1, 2)]], @"Response data doesn't match the input data.");
}

- (void)test_WhenDispatchingAnExecutionBlockOnTheCommunicationQueue_BlockIsExecuted {
    NSData *inputData = [@"input_data" dataUsingEncoding:NSUTF8StringEncoding];
    self.eaSession = [[FakeEASession alloc] initWithInputData:inputData accessory:nil protocol:@"YLP"];
    
    YKFAccessoryConnectionController *connectionController = [[YKFAccessoryConnectionController alloc] initWithSession:self.eaSession operationQueue:self.operationQueue];
    [self waitForTimeInterval:0.2];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Execution on communication queue completion."];
    [connectionController dispatchOnSequentialQueue:^{
        [expectation fulfill];
    }];
     
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:1];
    XCTAssert(result == XCTWaiterResultCompleted);
}

- (void)test_WhenDispatchingAnExecutionBlockOnTheCommunicationQueueWithDelay_BlockIsExecuted {
    NSData *inputData = [@"input_data" dataUsingEncoding:NSUTF8StringEncoding];
    self.eaSession = [[FakeEASession alloc] initWithInputData:inputData accessory:nil protocol:@"YLP"];
    
    YKFAccessoryConnectionController *connectionController = [[YKFAccessoryConnectionController alloc] initWithSession:self.eaSession operationQueue:self.operationQueue];
    [self waitForTimeInterval:0.2];
    
    NSTimeInterval delay = 1;
    NSTimeInterval deviation = 0.2;
    
    NSDate *startDate = [NSDate date];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Execution on communication queue completion."];
    [connectionController dispatchOnSequentialQueue:^{
        [expectation fulfill];
    } delay: delay];
    
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:delay + deviation];
    XCTAssert(result == XCTWaiterResultCompleted);
    
    NSDate *endDate = [NSDate date];
    NSTimeInterval time = [endDate timeIntervalSinceDate:startDate];
    
    XCTAssert(time <= delay + deviation, @"Execution time exceeded.");
}

#pragma mark - Delayed Responses

- (void)test_WhenConnectionControllerReadsDelayedResponse_ControllerWaitsForResult {
    
    NSData *inputData = [self dataWithBytes:@[@(0x01), @(0x00), @(0x00)]];
    self.eaSession = [[FakeEASession alloc] initWithInputData:inputData accessory:nil protocol:@"YLP"];
    
    YKFAccessoryConnectionController *connectionController = [[YKFAccessoryConnectionController alloc] initWithSession:self.eaSession operationQueue:self.operationQueue];
    [self waitForTimeInterval:0.2];
    
    XCTAssert(self.eaSession.inputStream.streamStatus == NSStreamStatusOpen);
    XCTAssert(self.eaSession.outputStream.streamStatus == NSStreamStatusOpen);
    
    // Execute command
    
    NSData *commandData = [@"command" dataUsingEncoding:NSUTF8StringEncoding];
    YKFAPDU *command = [[YKFAPDU alloc] initWithData:commandData];
    
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"Command execution completion."];
    [connectionController execute:command completion:^(NSData *result, NSError *error, NSTimeInterval executionTime) {
        [expectation fulfill];
    }];
    
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:0.5];
    XCTAssert(result == XCTWaiterResultTimedOut); // The result should time out because the key didn't reply to the request.
}

@end
