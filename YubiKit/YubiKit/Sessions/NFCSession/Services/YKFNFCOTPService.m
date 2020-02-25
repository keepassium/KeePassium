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

#import <CoreNFC/CoreNFC.h>

#import "YKFNFCOTPService.h"
#import "YKFNFCOTPService+Private.h"

#import "YKFNFCError.h"
#import "YKFNFCError+Errors.h"

#import "YubiKitExternalLocalization.h"
#import "YKFOTPTokenParser.h"
#import "YKFLogger.h"
#import "YKFDispatch.h"
#import "YubiKitDeviceCapabilities.h"
#import "YKFBlockMacros.h"
#import "YKFAssert.h"

#import "NFCNDEFReaderSession+Testing.h"

@interface YKFNFCOTPService()<NFCNDEFReaderSessionDelegate>

@property (nonatomic, strong) id<YKFNFCNDEFReaderSessionProtocol> nfcSession;
@property (nonatomic, strong) id<YKFOTPTokenParserProtocol> otpTokenParser;

@property (nonatomic, copy) YKFOTPResponseBlock nfcOTPResponseBlock;

@end

@implementation YKFNFCOTPService

- (instancetype)initWithTokenParser:(id<YKFOTPTokenParserProtocol>)tokenParser session:(id<YKFNFCNDEFReaderSessionProtocol>)session {
    self = [super init];
    if (self) {
        self.otpTokenParser = tokenParser ? tokenParser : [[YKFOTPTokenParser alloc] init];
        self.nfcSession = session;
    }
    return self;
}

#pragma mark - YKFNFCReaderManagerProtocol

- (void)requestOTPToken:(YKFOTPResponseBlock)completion {
    YKFAssertReturn(YubiKitDeviceCapabilities.supportsNFCScanning, @"Device does not support NFC scanning.");
    
    self.nfcOTPResponseBlock = completion;
    [self start];
}

- (void)start {
    if (!self.nfcSession) {
        // The updates are dispatched on the main queue.
        dispatch_queue_t mainQueue = dispatch_get_main_queue();
        self.nfcSession = [[NFCNDEFReaderSession alloc] initWithDelegate:self queue:mainQueue invalidateAfterFirstRead:YES];
        self.nfcSession.alertMessage = YubiKitExternalLocalization.nfcScanAlertMessage;
    }
    [self.nfcSession beginSession];
}

#pragma mark - NFCNDEFReaderSessionDelegate

- (void)readerSession:(NFCNDEFReaderSession *)session didInvalidateWithError:(NSError *)error {
    YKFAssertOnMainThread();
    
    self.nfcSession = nil;
    if ([self shouldIgnoreError: error]) {
        return;
    }
    
    YKFLogNSError(error);
    
    self.nfcOTPResponseBlock(nil, error);
    self.nfcOTPResponseBlock = nil;
}

- (void)readerSession:(NFCNDEFReaderSession *)session didDetectNDEFs:(NSArray<NFCNDEFMessage *> *)messages {
    YKFAssertOnMainThread();
    
    id<YKFOTPTokenProtocol> otpToken = [self.otpTokenParser otpTokenFromNfcMessages:messages];
    if (otpToken) {
        self.nfcOTPResponseBlock(otpToken, nil);
        self.nfcOTPResponseBlock = nil;
    } else {
        YKFNFCError *error = [YKFNFCError noTokenAfterScanError];
        self.nfcOTPResponseBlock(nil, error);
        self.nfcOTPResponseBlock = nil;
    }
}

#pragma mark - Helpers

- (BOOL)shouldIgnoreError:(NSError *)error {
    return error.code == NFCReaderSessionInvalidationErrorFirstNDEFTagRead;
}

@end
