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
#import "YKFOTPURIParser.h"
#import "YKFOTPTokenValidator.h"

@interface YKFOTPURIParserTests: YKFTestCase

@property (nonatomic) YKFOTPURIParser *uriParser;

@end

@implementation YKFOTPURIParserTests

- (void)setUp {
    [super setUp];
    YKFOTPTokenValidator *tokenValidator = [[YKFOTPTokenValidator alloc] init];
    self.uriParser = [[YKFOTPURIParser alloc] initWithValidator:tokenValidator];
}

- (void)tearDown {
    self.uriParser = nil;
    [super tearDown];
}

#pragma mark - Valid Yubico OTP URI tests

- (void)test_WhenPayloadIsURIWithYubicoOTP_OTPAndURIAreParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *payload = @"my.yubico.com/neo/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    NSString *token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    NSString *uri = [self.uriParser uriFromPayload:payload];
    XCTAssert([uri isEqualToString:payload], @"URI metadata not correctly parsed.");
}

- (void)test_WhenPayloadIsOnlyYubicoOTP_OnlyOTPIsParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *payload = expectedToken;
    
    NSString *token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    NSString *uri = [self.uriParser uriFromPayload:payload];
    XCTAssert(uri.length == 0, @"URI metadata not correctly parsed.");
}

- (void)test_WhenPayloadIsURIWithYubicoOTPWithPoundSign_OTPAndURIAreParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *payload = @"my.yubico.com/neo/#ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    NSString *token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    NSString *uri = [self.uriParser uriFromPayload:payload];
    XCTAssert([uri isEqualToString:payload], @"URI metadata not correctly parsed.");
}

- (void)test_WhenPayloadIsCustomURIWithYubicoOTPWithPoundSign_OTPAndURIAreParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *payload = @"https://www.example.com/custom/#ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    NSString *token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    NSString *uri = [self.uriParser uriFromPayload:payload];
    XCTAssert([uri isEqualToString:payload], @"URI metadata not correctly parsed.");
}

- (void)test_WhenPayloadIsCustomURIWithYubicoOTP_OTPAndURIAreParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *payload = @"https://www.example.com/custom/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    NSString *token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    NSString *uri = [self.uriParser uriFromPayload:payload];
    XCTAssert([uri isEqualToString:payload], @"URI metadata not correctly parsed.");
}

- (void)test_WhenPayloadIsModernURIWithWithPoundSign_OTPAndURIAreParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *expectedURI = @"https://my.yubico.com/yk/#ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    NSString *payload = @"my.yubico.com/yk/#ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    payload = [NSString stringWithFormat:@"%c%@", 0x04, payload];
    
    NSString *token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    NSString *uri = [self.uriParser uriFromPayload:payload];
    XCTAssert([uri isEqualToString:expectedURI], @"URI metadata not correctly parsed.");
}

- (void)test_WhenPayloadIsPrependedURIWithYubicoOTP_OTPAndURIAreParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";

    // No prepending
    
    NSString *payload = @"my.yubico.com/neo/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *expectedURI = @"my.yubico.com/neo/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    payload = [NSString stringWithFormat:@"%c%@", 0x00, payload];

    NSString *token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    NSString *uri = [self.uriParser uriFromPayload:payload];
    XCTAssert([uri isEqualToString:expectedURI], @"URI metadata not correctly parsed.");
    
    // Https prepending
    
    payload = @"my.yubico.com/neo/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    expectedURI = @"https://my.yubico.com/neo/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    payload = [NSString stringWithFormat:@"%c%@", 0x04, payload];
    
    token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    uri = [self.uriParser uriFromPayload:payload];
    XCTAssert([uri isEqualToString:expectedURI], @"URI metadata not correctly parsed.");
    
    // Http prepending
    
    payload = @"my.yubico.com/neo/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    expectedURI = @"http://my.yubico.com/neo/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    payload = [NSString stringWithFormat:@"%c%@", 0x03, payload];
    
    token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    uri = [self.uriParser uriFromPayload:payload];
    XCTAssert([uri isEqualToString:expectedURI], @"URI metadata not correctly parsed.");
}

#pragma mark - Valid HOTP URI tests

- (void)test_WhenPayloadIsURIWithHOTP_OTPAndURIAreParsed {
    NSString *expectedToken = @"12345678";
    NSString *payload = @"my.yubico.com/neo/12345678";
    
    NSString *token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    NSString *uri = [self.uriParser uriFromPayload:payload];
    XCTAssert([uri isEqualToString:payload], @"URI metadata not correctly parsed.");
}

- (void)test_WhenPayloadIsOnlyHOTP_OnlyOTPIsParsed {
    NSString *expectedToken = @"12345678";
    NSString *payload = expectedToken;
    
    NSString *token = [self.uriParser tokenFromPayload:payload];
    XCTAssert([token isEqualToString:expectedToken], @"OTP Token not correctly parsed.");
    
    NSString *uri = [self.uriParser uriFromPayload:payload];
    XCTAssert(uri.length == 0, @"URI metadata not correctly parsed.");
}

@end
