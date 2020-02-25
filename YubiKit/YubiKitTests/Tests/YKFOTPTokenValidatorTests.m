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
#import "YKFOTPTokenValidator.h"

@interface YKFOTPTokenValidatorTests: YKFTestCase

@property (nonatomic) YKFOTPTokenValidator *otpTokenValidator;

@end

@implementation YKFOTPTokenValidatorTests

- (void)setUp {
    [super setUp];
    self.otpTokenValidator = [[YKFOTPTokenValidator alloc] init];
}

- (void)tearDown {
    self.otpTokenValidator = nil;
    [super tearDown];
}

#pragma mark - Valid Yubico OTP tests

- (void)test_WhenTokenIsDefaultYubicoOTP_TokenIsValid {
    NSString *otp = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(valid, @"Valid Yubico OTP not correctly detected.");
}

- (void)test_WhenTokenIsShortYubicoOTP_TokenIsValid {
    NSString *otp = @"ccccccibhhbfbugtukgjtflbhikgetvh";
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(valid, @"Valid Yubico OTP not correctly detected.");
}

- (void)test_WhenTokenIsLongYubicoOTP_TokenIsValid {
    NSString *otp = @"ccccccibhhbfbugtukgjtflbhikgetvhibhhbfbugtukgjtflbhikgetvhkgetvh";
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(valid, @"Valid Yubico OTP not correctly detected.");
}

#pragma mark - Invalid Yubico OTP tests

- (void)test_WhenYubicoOTPIsTooShort_TokenIsNotValid {
    NSString *otp = @"ccccccibhhbfbugtukgjtflbhik";
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(!valid, @"Invalid Yubico OTP not correctly detected.");
}

- (void)test_WhenYubicoOTPIsTooLong_TokenIsNotValid {
    NSString *otp = @"ccccccibhhbfbugtukgjtflbhikgetvhibhhbfbugtukgjtflbhikgetvhkgetvhttt";
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(!valid, @"Invalid Yubico OTP not correctly detected.");
}

- (void)test_WhenYubicoOTPIsNotModhexEncoded_TokenIsNotValid {
    NSString *otp = @"000000ibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(!valid, @"Invalid Yubico OTP not correctly detected.");
}

- (void)test_WhenTokenIsHOTP_TokenIsNotYubicoOTP {
    NSArray *hotps = @[@"123456", @"A123456", @"AB123456", @"12345678", @"A12345678"];
    
    for (NSString *hotp in hotps) {
        BOOL valid = [self.otpTokenValidator maybeYubicoOTP:hotp];
        XCTAssert(!valid, @"Invalid Yubico OTP not correctly detected (%@).", hotp);
    }
}

#pragma mark - Valid HOTP tests

- (void)test_WhenTokenIsLongHOTP_TokenIsValid {
    NSString *otp = @"12345678";
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(valid, @"Valid HOTP not correctly detected.");
}

- (void)test_WhenTokenIsShortHOTP_TokenIsValid {
    NSString *otp = @"123456";
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(valid, @"Valid HOTP not correctly detected.");
}

- (void)test_WhenTokenIsPrefixedShortHOTP_TokenIsValid {
    NSArray *hotps = @[@"ABCD123456", @"A123456"];
    
    for (NSString *hotp in hotps) {
        BOOL valid = [self.otpTokenValidator validateToken:hotp];
        XCTAssert(valid, @"Invalid HOTP not correctly detected (%@).", hotp);
    }
}

- (void)test_WhenTokenIsPrefixedLongHOTP_TokenIsValid {
    NSArray *hotps = @[@"ABCD12345678", @"A12345678"];
    
    for (NSString *hotp in hotps) {
        BOOL valid = [self.otpTokenValidator validateToken:hotp];
        XCTAssert(valid, @"Invalid HOTP not correctly detected (%@).", hotp);
    }
}

#pragma mark - Invalid HOTP tests

- (void)test_WhenTokenIsShortHOTPWithLetters_TokenIsNotValid {
    NSArray *hotps = @[@"12345X", @"12345A", @"123X56", @"A23456"];
    
    for (NSString *hotp in hotps) {
        BOOL valid = [self.otpTokenValidator validateToken:hotp];
        XCTAssert(!valid, @"Invalid HOTP not correctly detected (%@).", hotp);
    }
}

- (void)test_WhenHOTPTokenIsTooShort_TokenIsNotValid {
    NSArray *hotps = @[@"12345", @"1234", @"123", @"12", @"1", @""];
    
    for (NSString *hotp in hotps) {
        BOOL valid = [self.otpTokenValidator validateToken:hotp];
        XCTAssert(!valid, @"Invalid HOTP not correctly detected (%@).", hotp);
    }
}

- (void)test_WhenTokenIsYubicoOTP_TokenIsNotHOTP {
    NSArray *otps = @[@"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk",
                      @"ccccccibhhbfbugtukgjtflbhikgetvh",
                      @"ccccccibhhbfbugtukgjtflbhikgetvhibhhbfbugtukgjtflbhikgetvhkgetvh"];
    
    for (NSString *otp in otps) {
        BOOL valid = [self.otpTokenValidator maybeHOTP:otp];
        XCTAssert(!valid, @"Invalid HOTP not correctly detected (%@).", otp);
    }
}

#pragma mark - Other

- (void)test_WhenTokenIsEmpty_TokenIsNotValid {
    NSString *otp = @"";
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(!valid, @"Invalid empty OTP not correctly detected.");
}

- (void)test_WhenTokenIsNil_TokenIsNotValid {
    NSString *otp = nil;
    
    BOOL valid = [self.otpTokenValidator validateToken:otp];
    XCTAssert(!valid, @"Invalid nil OTP not correctly detected.");
}

@end
