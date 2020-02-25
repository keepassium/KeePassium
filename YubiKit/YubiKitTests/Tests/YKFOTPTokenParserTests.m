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
#import "YKFOTPTokenParser.h"
#import "YKFOTPURIParserProtocol.h"
#import "YKFOTPTextParserProtocol.h"
#import "YubiKitConfiguration.h"

#import "FakeYKFOTPTextParser.h"
#import "FakeYKFOTPURIParser.h"

@interface YKFOTPTokenParserTests: YKFTestCase

@property (nonatomic) YKFOTPTokenParser *tokenParser;

@end

@implementation YKFOTPTokenParserTests

- (void)setUp {
    [super setUp];
    self.tokenParser = [[YKFOTPTokenParser alloc] init];
}

- (void)tearDown {
    self.tokenParser = nil;
    YubiKitConfiguration.customOTPURIParser = nil;
    YubiKitConfiguration.customOTPTextParser = nil;
    [super tearDown];
}

#pragma mark - Yubico OTP tests (URI)

- (void)test_WhenTokenIsDefaultYubicoOTPAndURI_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *payload = @"https://my.yubico.com/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeURI];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeYubicoOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeURI, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.uri isEqualToString:payload], @"Wrong parsed URI.");
}

- (void)test_WhenShortYubicoOTPAndURI_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvh";
    NSString *payload = @"https://my.yubico.com/ccccccibhhbfbugtukgjtflbhikgetvh";
    
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeURI];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeYubicoOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeURI, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.uri isEqualToString:payload], @"Wrong parsed URI.");
}

- (void)test_WhenLongYubicoOTPAndURI_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhibhhbfbugtukgjtflbhikgetvhkgetvh";
    NSString *payload = @"https://my.yubico.com/ccccccibhhbfbugtukgjtflbhikgetvhibhhbfbugtukgjtflbhikgetvhkgetvh";
    
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeURI];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeYubicoOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeURI, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.uri isEqualToString:payload], @"Wrong parsed URI.");
}

#pragma mark - Yubico OTP tests (Text)

- (void)test_WhenDefaultYubicoOTPAndText_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    NSString *payload = @"en-US\\some/ccccccibhhbfbugtukgjtflbhikgetvhjggeilkffitk";
    
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeText];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeYubicoOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeText, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.text isEqualToString:payload], @"Wrong parsed text.");
}

- (void)test_WhenShortYubicoOTPAndText_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvh";
    NSString *payload = @"en-US\\some/ccccccibhhbfbugtukgjtflbhikgetvh";
    
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeText];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeYubicoOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeText, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.text isEqualToString:payload], @"Wrong parsed text.");
}

- (void)test_WhenLongYubicoOTPAndText_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"ccccccibhhbfbugtukgjtflbhikgetvhibhhbfbugtukgjtflbhikgetvhkgetvh";
    NSString *payload = @"en-US\\some/ccccccibhhbfbugtukgjtflbhikgetvhibhhbfbugtukgjtflbhikgetvhkgetvh";
    
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeText];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeYubicoOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeText, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.text isEqualToString:payload], @"Wrong parsed text.");
}

#pragma mark - HOTP tests (URI)

- (void)test_WhenLongHOTPAndURI_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"12345678";
    NSString *payload = @"https://my.yubico.com/12345678";
    
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeURI];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeHOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeURI, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.uri isEqualToString:payload], @"Wrong parsed URI.");
}

- (void)test_WhenShortHOTPAndURI_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"123456";
    NSString *payload = @"https://my.yubico.com/123456";
    
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeURI];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeHOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeURI, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.uri isEqualToString:payload], @"Wrong parsed URI.");
}

#pragma mark - HOTP tests (Text)

- (void)test_WhenLongHOTPAndText_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"12345678";
    NSString *payload = @"en-US\\some/12345678";

    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeText];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeHOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeText, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.text isEqualToString:payload], @"Wrong parsed text.");
}

- (void)test_WhenShortHOTPAndText_TokenIsCorrectlyParsed {
    NSString *expectedToken = @"123456";
    NSString *payload = @"en-US\\some/123456";
    
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeText];
    
    id<YKFOTPTokenProtocol> token = [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(token.type == YKFOTPTokenTypeHOTP, @"Wrong token type detected.");
    XCTAssert(token.metadataType == YKFOTPMetadataTypeText, @"Wrong metadata detected.");
    
    XCTAssert([token.value isEqualToString:expectedToken], @"Wrong parsed value.");
    XCTAssert([token.text isEqualToString:payload], @"Wrong parsed text.");
}

#pragma mark - Custom parsers

- (void)test_WhenCustomURIParserIsSet_ParserCallsTheCustomURIParser {
    FakeYKFOTPURIParser *customURIParser = [[FakeYKFOTPURIParser alloc] init];
    YubiKitConfiguration.customOTPURIParser = customURIParser;
    
    self.tokenParser = [[YKFOTPTokenParser alloc] init];
    
    NSString *payload = @"https://my.yubico.com/123456";
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeURI];
    [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(customURIParser.tokenFromPayloadInvoked, @"Custom URI parser not invoked.");
    XCTAssert(customURIParser.uriFromPayloadInvoked, @"Custom URI parser not invoked.");
}

- (void)test_WhenCustomTextParserIsSet_ParserCallsTheCustomTextParser {
    FakeYKFOTPTextParser *customTextParser = [[FakeYKFOTPTextParser alloc] init];
    YubiKitConfiguration.customOTPTextParser = customTextParser;
    
    self.tokenParser = [[YKFOTPTokenParser alloc] init];
    
    NSString *payload = @"en-US\\some/123456";
    NSArray *nfcResponse = [self nfcResponseWithPayload:payload metadataType:YKFOTPMetadataTypeText];
    [self.tokenParser otpTokenFromNfcMessages: nfcResponse];
    
    XCTAssert(customTextParser.tokenFromPayloadInvoked, @"Custom URI parser not invoked.");
    XCTAssert(customTextParser.textFromPayloadInvoked, @"Custom URI parser not invoked.");
}

#pragma mark - Helpers

- (NSArray *)nfcResponseWithPayload:(NSString *)payload metadataType:(YKFOTPMetadataType)type {
    NFCNDEFPayload *nfcPayload = [NFCNDEFPayload new];
    
    UInt8 payloadTypeURIBytes[1] = {'U'};
    UInt8 payloadTypeTextBytes[1] = {'T'};
    
    if (type == YKFOTPMetadataTypeURI) {
        nfcPayload.type = [NSData dataWithBytes:payloadTypeURIBytes length:1];
    } else if (type == YKFOTPMetadataTypeText){
        nfcPayload.type = [NSData dataWithBytes:payloadTypeTextBytes length:1];
    }
    
    nfcPayload.typeNameFormat = NFCTypeNameFormatNFCWellKnown;
    nfcPayload.payload = [self uriNFCPayloadDataWithString:payload metadataType:type];
    
    NFCNDEFMessage *nfcMessage = [NFCNDEFMessage new];
    nfcMessage.records = @[nfcPayload];
    return @[nfcMessage];
}

- (NSData *)uriNFCPayloadDataWithString:(NSString *)string  metadataType:(YKFOTPMetadataType)type {
    NSMutableData *mutableData = [[NSMutableData alloc] init];
    
    UInt8 typePrefix = 0;
    if (type == YKFOTPMetadataTypeURI) {
        typePrefix = 0x00;
    } else if (type == YKFOTPMetadataTypeText){
        typePrefix = 0x05;
    }
    
    [mutableData appendBytes:&typePrefix length:1];
    [mutableData appendData:[string dataUsingEncoding:NSUTF8StringEncoding]];
    
    return [mutableData copy];
}

@end
