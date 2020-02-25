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
#import "YKFOATHCredential.h"
#import "YKFOATHCredentialValidator.h"
#import "YKFKeyOATHError.h"

static NSString* const YKFOATHCredentialValidatorTestsVeryLargeSecret = @"HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ";

@interface YKFOATHCredentialValidatorTests: YKFTestCase
@end

@implementation YKFOATHCredentialValidatorTests

- (void)test_WhenValidatorReceivesValidTOTPCredential_NoErrorIsReturned {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNotNil(credential);
    
    YKFKeySessionError *error = [YKFOATHCredentialValidator validateCredential:credential includeSecret:YES];
    XCTAssertNil(error);
}

- (void)test_WhenValidatorReceivesValidHOTPCredential_NoErrorIsReturned {
    NSString *url = @"otpauth://hotp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&counter=123";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNotNil(credential);
    
    YKFKeySessionError *error = [YKFOATHCredentialValidator validateCredential:credential includeSecret:YES];
    XCTAssertNil(error);
}

- (void)test_WhenValidatorIsRequestedToValidateWithoutSecret_SecretIsNotValidated {
    NSString *urlFormat = @"otpauth://hotp/ACME:john@example.com?secret=%@&issuer=ACME&algorithm=SHA256&digits=6&counter=123";
    NSString *url = [NSString stringWithFormat:urlFormat, YKFOATHCredentialValidatorTestsVeryLargeSecret];
    
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNotNil(credential);

    YKFKeySessionError *error = [YKFOATHCredentialValidator validateCredential:credential includeSecret:NO];
    XCTAssertNil(error);
}

#pragma mark - Large Key Tests

- (void)test_WhenValidatorReceivesInvalidCredentialKey_ErrorIsReturnedBack {
    NSString *urlFormat = @"otpauth://hotp/ACME:john_with_too_long_name_which_does_not_really_fit_in_the_key@example.com?secret=%@&issuer=ACME&algorithm=SHA1&digits=6&counter=123";
    NSString *url = [NSString stringWithFormat:urlFormat, YKFOATHCredentialValidatorTestsVeryLargeSecret];
    
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNotNil(credential);
    
    YKFKeySessionError *error = [YKFOATHCredentialValidator validateCredential:credential includeSecret:YES];
    XCTAssertEqual(error.code, YKFKeyOATHErrorCodeNameTooLong);
}

@end
