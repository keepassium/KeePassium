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
#import "YKFOATHCredential+Private.h"

@interface YKFOATHCredentialTests : XCTestCase
@end

@implementation YKFOATHCredentialTests

#pragma mark - Basic valid URL tests

- (void)test_WhenCredentialIsCreatedWithValidTOTPURL_CredentialIsNotNil {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNotNil(credential, @"Valid TOTP url was not parsed correctly");
}

- (void)test_WhenCredentialIsCreatedWithValidHOTPURL_CredentialIsNotNil {
    NSString *url = @"otpauth://hotp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&counter=1234";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNotNil(credential, @"Valid HOTP url was not parsed correctly");
}

#pragma mark - HOTP URLs tests

- (void)test_WhenCredentialIsCreatedWithHOTPURL_CredentialTypeIsHOTP {
    NSString *url = @"otpauth://hotp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&counter=1234";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.type == YKFOATHCredentialTypeHOTP, @"Credential type incorrectly detected.");
}

- (void)test_WhenCredentialIsCreatedWithHOTPURLWithoutCounter_CredentialIsNil {
    NSString *url = @"otpauth://hotp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNil(credential, @"HOTP credential is not nil when counter is missing.");
}

- (void)test_WhenCredentialIsCreatedWithValidHOTPURL_PeriodIsZero {
    NSString *url = @"otpauth://hotp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&counter=1234";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.period == 0, @"HOTP credential has a validity period.");
}

- (void)test_WhenCredentialIsCreatedWithHOTPURL_DefaultNameIsLabel {
    NSString *url = @"otpauth://hotp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&counter=123";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    
    XCTAssert([credential.key isEqualToString:credential.label], @"Credential key not correctly generated");
}

#pragma mark - TOTP URLs tests

- (void)test_WhenCredentialIsCreatedWithTOTPURL_CredentialParametersAreCorrectlyParsed {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&period=40";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    
    XCTAssert(credential.type == YKFOATHCredentialTypeTOTP, @"");
    XCTAssert(credential.algorithm == YKFOATHCredentialAlgorithmSHA1, @"");
    XCTAssert([credential.issuer isEqualToString:@"ACME"], @"");
    XCTAssertNotNil(credential.secret, @"");
    XCTAssert(credential.digits == 6, @"");
    XCTAssert(credential.period == 40, @"");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURL_CredentialTypeIsTOTP {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.type == YKFOATHCredentialTypeTOTP, @"Credential type incorrectly detected.");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURLWithoutPeriod_CredentialPeriodIsDefault {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.period == 30, @"Credential period is not default.");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURL_NameDoesNotContainThePeriodWhenDefault {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    
    NSString *credentialName =credential.label;
    XCTAssert([credential.key isEqualToString:credentialName], @"Credential key not correctly generated");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURL_NameContainsThePeriodWhenNotDefault {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&period=40";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    
    NSString *credentialName = [NSString stringWithFormat:@"%ld/%@", credential.period, credential.label];
    XCTAssert([credential.key isEqualToString:credentialName], @"Credential key not correctly generated");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURL_SmallerThanDefaultPeriodsAreAccepted {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&period=20";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    
    XCTAssert(credential.period == 20, @"Credential period not correctly parsed.");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURL_PeriodIsDefaultIfNotProvided {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    
    XCTAssert(credential.period == 30, @"Default period was not correctly set.");
}

#pragma mark - Issuer

- (void)test_WhenCredentialIsCreatedWithURLWithoutIssuerInURLParam_IssuerIsParsedFromTheLabel {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert([credential.issuer isEqualToString:@"ACME"], @"Credential is missing the issuer.");
}

- (void)test_WhenCredentialIsCreatedWithURLWithIssuerInURLParamButNotInLabel_IssuerIsParsedFromTheURLl {
    NSString *url = @"otpauth://totp/john@example.com?issuer=ACME&secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert([credential.issuer isEqualToString:@"ACME"], @"Credential is missing the issuer.");
}

- (void)test_WhenCredentialIsCreatedWithURLWithoutIssuer_CredentialCanBeCreated {
    NSString *url = @"otpauth://totp/john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    
    XCTAssertNil(credential.issuer, @"Issuer is not nil when key URI does not contain an issuer.");
}

#pragma mark - Label

- (void)test_WhenCredentialIsManuallyCreatedWithLabel_AssignedLabelIsReturnedWhenReadingTheProperty {
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] init];
    NSString *label = @"issuer:account";
    
    credential.label = label;
    XCTAssert([credential.label isEqualToString:label], @"Credential label is not returned if assigned.");
}

- (void)test_WhenCredentialIsManuallyCreatedWithoutLabel_LabelIsBuildFromTheIssuerAndAccount {
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] init];
    NSString *label = @"issuer:account";
    
    credential.issuer = @"issuer";
    credential.account = @"account";
    
    XCTAssert([credential.label isEqualToString:label], @"Credential label is not built if missing.");
}

- (void)test_WhenCredentialIsManuallyCreatedWithoutLabelAndIssuer_LabelIsBuildFromTheAccount {
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] init];
    credential.account = @"account";
    
    XCTAssert([credential.label isEqualToString:credential.account], @"Credential label is not built if missing.");
}

#pragma mark - Key

- (void)test_WhenCredentialIsCreatedWithHOTPURL_KeyIsTheLabel {
    NSString *url = @"otpauth://hotp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&digits=6&counter=0";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert([credential.key isEqualToString:credential.label], @"Credential key for HOTP is not the label.");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURLWithDefaultPeriod_KeyIsTheLabel {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&digits=6";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert([credential.key isEqualToString:credential.label], @"Credential key for HOTP is not the label.");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURLWithCustomPeriodAndIssuer_KeyContainsThePeriod {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&digits=6&period=15";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    
    NSString *expectedKey = [NSString stringWithFormat:@"%d/%@", 15, credential.label];
    XCTAssert([credential.key isEqualToString:expectedKey], @"Credential key for TOTP with custom period does not contain the period.");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURLWithCustomPeriod_KeyContainsThePeriod {
    NSString *url = @"otpauth://totp/john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&digits=6&period=15";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    
    NSString *expectedKey = [NSString stringWithFormat:@"%d/%@", 15, credential.label];
    XCTAssert([credential.key isEqualToString:expectedKey], @"Credential key for TOTP with custom period does not contain the period.");
}

#pragma mark - Digits

- (void)test_WhenCredentialIsCreatedWithURLWith7DigitsLength_CredentialParametersAreCorrectlyParsed {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=7&period=40";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.digits == 7, @"");
}
- (void)test_WhenCredentialIsCreatedWithURLWith8DigitsLength_CredentialParametersAreCorrectlyParsed {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=8&period=40";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.digits == 8, @"");
}

- (void)test_WhenCredentialIsCreatedWithURLWithInvalidDigitsLength_CredentialIsNil {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=10&period=40";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNil(credential, @"Credential with invalid digits secret is not nil.");
}

#pragma mark - Misc

- (void)test_WhenCredentialIsCreatedWithHOTPURLWithoutSecret_CredentialIsNil {
    NSString *url = @"otpauth://hotp/ACME:john@example.com?issuer=ACME&algorithm=SHA1&digits=6&counter=1234";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNil(credential, @"Credential without secret is not nil.");
}

- (void)test_WhenCredentialIsCreatedWithShortSecret_CredentialSecretIsPadded {
    NSString *url = @"otpauth://totp/Label?secret=HXDMVJEC&issuer=Issuer";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.secret.length == 14, @"Credential with short secret is not padded");
}

- (void)test_WhenCredentialIsCreatedWithLongSHA1Secret_CredentialSecretIsHashed {
    NSString *url = @"otpauth://totp/Label?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXHXDMVJECJJWS&issuer=Issuer";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.secret.length <= 64, @"Credential with long secret is not hashed.");
}

- (void)test_WhenCredentialIsCreatedWithLongSHA256Secret_CredentialSecretIsHashed {
    NSString *url = @"otpauth://totp/Label?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXHXDMVJECJJWS&issuer=Issuer&algorithm=SHA256";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.secret.length <= 64, @"Credential with long secret is not hashed.");
}

- (void)test_WhenCredentialIsCreatedWithLongSHA512Secret_CredentialSecretIsHashed {
    NSString *url = @"otpauth://totp/Label?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXHXDMVJECJJWSHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZHXDMVJECJJWSRB3HWIZR4IFUGFTMXHXDMVJECJJWS&issuer=Issuer&algorithm=SHA512";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.secret.length <= 128, @"Credential with long secret is not hashed.");
}

- (void)test_WhenCredentialIsCreatedWithTOTPURLWithoutSecret_CredentialIsNil {
    NSString *url = @"otpauth://totp/ACME:john@example.com?issuer=ACME&algorithm=SHA1&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNil(credential, @"Credential without secret is not nil.");
}


- (void)test_WhenCredentialIsCreatedWithURLWithoutLabel_CredentialIsNil {
    NSString *url = @"otpauth://totp?issuer=ACME&algorithm=SHA1&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNil(credential, @"Credential with missing label is not nil.");
}

- (void)test_WhenCredentialIsCreatedWithURLWithoutOTPType_CredentialIsNil {
    NSString *url = @"otpauth://ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&algorithm=SHA1&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssertNil(credential, @"Credential with missing label is not nil.");
}

- (void)test_WhenCredentialIsCreatedWithURLWithoutAlgorithm_CredentialAlgorithmIsSHA1 {
    NSString *url = @"otpauth://totp/ACME:john@example.com?secret=HXDMVJECJJWSRB3HWIZR4IFUGFTMXBOZ&issuer=ACME&digits=6&period=30";
    YKFOATHCredential *credential = [[YKFOATHCredential alloc] initWithURL:[NSURL URLWithString:url]];
    XCTAssert(credential.algorithm == YKFOATHCredentialAlgorithmSHA1 , @"Credential does not default to SHA1.");
}

@end
