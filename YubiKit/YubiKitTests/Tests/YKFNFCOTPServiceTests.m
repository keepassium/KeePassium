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
#import "YKFNFCOTPService.h"
#import "YKFNFCOTPService+Private.h"
#import "YKFOTPTokenParser.h"
#import "YubiKitDeviceCapabilities+Testing.h"
#import "FakeNFCNDEFReaderSession.h"
#import "FakeYubiKitDeviceCapabilities.h"

@interface YKFNFCOTPServiceTests: YKFTestCase

@property (nonatomic) YKFNFCOTPService *nfcOtpService;
@property (nonatomic) FakeNFCNDEFReaderSession *fakeReaderSession;
@property (nonatomic) YKFOTPTokenParser *tokenParser;

@end

@implementation YKFNFCOTPServiceTests

- (void)setUp {
    [super setUp];
    
    YubiKitDeviceCapabilities.fakeDeviceCapabilities = [[FakeYubiKitDeviceCapabilities alloc] init];
    
    self.tokenParser = [[YKFOTPTokenParser alloc] init];
    self.fakeReaderSession = [[FakeNFCNDEFReaderSession alloc] init];
    self.nfcOtpService = [[YKFNFCOTPService alloc] initWithTokenParser:self.tokenParser session:self.fakeReaderSession];
    
    self.fakeReaderSession.delegate = (id<NFCNDEFReaderSessionDelegate>)self.nfcOtpService;
}

- (void)tearDown {    
    YubiKitDeviceCapabilities.fakeDeviceCapabilities = nil;
    
    self.tokenParser = nil;
    self.fakeReaderSession = nil;
    self.nfcOtpService = nil;
    
    [super tearDown];
}

#pragma mark - Error handlig

- (void)test_WhenNFCSessionInvalidatesWithError_ErrorIsReceived {
    __block BOOL errorReceived = NO;
    [self.nfcOtpService requestOTPToken:^(id<YKFOTPTokenProtocol> token, NSError *error) {
        if (error) {
            errorReceived = YES;
        }
    }];
    
    // Fire a random error
    NSError *error = [NSError errorWithDomain:@"" code:1 userInfo:nil];
    [self.fakeReaderSession.delegate readerSession:(NFCNDEFReaderSession *)self.fakeReaderSession didInvalidateWithError:error];
    
    XCTAssert(errorReceived, @"Error not correctly propagated.");
}

- (void)test_WhenSessionIsInvalidatedAfterFirstRead_ErrorIsSilenced {
    __block BOOL errorReceived = NO;
    [self.nfcOtpService requestOTPToken:^(id<YKFOTPTokenProtocol> token, NSError *error) {
        if (error.code == NFCReaderSessionInvalidationErrorFirstNDEFTagRead) {
            errorReceived = YES;
        }
    }];
    
    // Fire the error
    NSError *error = [NSError errorWithDomain:@"" code:NFCReaderSessionInvalidationErrorFirstNDEFTagRead userInfo:nil];
    [self.fakeReaderSession.delegate readerSession:(NFCNDEFReaderSession *)self.fakeReaderSession didInvalidateWithError:error];
    
    XCTAssert(!errorReceived, @"Error not correctly silenced.");
}

#pragma mark - Other

- (void)test_WhenRequestingOTPToken_TheNFCSessionIsStarted {
    [self.nfcOtpService requestOTPToken:^(id<YKFOTPTokenProtocol> token, NSError *error) {}];
    XCTAssert(self.fakeReaderSession.sessionStarted, @"NFC session is not started when requesting an OTP token.");
}

@end
