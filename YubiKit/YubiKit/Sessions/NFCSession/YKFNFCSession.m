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

#import "YubiKitDeviceCapabilities.h"
#import "YubiKitExternalLocalization.h"

#import "YKFNFCConnectionController.h"
#import "YKFNFCSession.h"
#import "YKFBlockMacros.h"
#import "YKFLogger.h"
#import "YKFAssert.h"

#import "YKFNFCOTPService+Private.h"
#import "YKFKeyU2FService+Private.h"
#import "YKFKeyFIDO2Service+Private.h"
#import "YKFKeyOATHService+Private.h"
#import "YKFKeyRawCommandService+Private.h"
#import "YKFNFCTagDescription+Private.h"

@interface YKFNFCSession()<NFCTagReaderSessionDelegate>

@property (nonatomic, readwrite) YKFNFCISO7816SessionState iso7816SessionState;

@property (nonatomic, readwrite) YKFNFCTagDescription *tagDescription API_AVAILABLE(ios(13.0));

@property (nonatomic, readwrite) YKFNFCOTPService *otpService API_AVAILABLE(ios(11.0));
@property (nonatomic, readwrite) YKFKeyU2FService *u2fService API_AVAILABLE(ios(13.0));
@property (nonatomic, readwrite) YKFKeyFIDO2Service *fido2Service API_AVAILABLE(ios(13.0));
@property (nonatomic, readwrite) YKFKeyOATHService *oathService API_AVAILABLE(ios(13.0));
@property (nonatomic, readwrite) YKFKeyRawCommandService *rawCommandService API_AVAILABLE(ios(13.0));

@property (nonatomic) id<YKFKeyConnectionControllerProtocol> connectionController;

@property (nonatomic) NSOperationQueue *communicationQueue;
@property (nonatomic) dispatch_queue_t sharedDispatchQueue;

@property (nonatomic) NFCTagReaderSession *nfcTagReaderSession API_AVAILABLE(ios(13.0));
@property (nonatomic) id<NFCISO7816Tag> iso7816NfcTag API_AVAILABLE(ios(13.0));

@property (nonatomic) NSTimer *iso7816NfcTagAvailabilityTimer;

@end

@implementation YKFNFCSession

- (instancetype)init {
    self = [super init];
    if (self) {
        if (@available(iOS 11, *)) {
            // Init with defaults
            self.otpService = [[YKFNFCOTPService alloc] initWithTokenParser:nil session:nil];
        }
        [self setupCommunicationQueue];
    }
    return self;
}

- (void)dealloc {
    if (@available(iOS 13.0, *)) {
        [self unobserveIso7816TagAvailability];
    }
}

#pragma mark - Property updates

- (void)updateIso7816SessionSate:(YKFNFCISO7816SessionState)state {
    if (self.iso7816SessionState == state) {
        return;
    }
    self.iso7816SessionState = state;
}

#pragma mark - Session lifecycle

- (void)startIso7816Session API_AVAILABLE(ios(13.0)) {
    YKFAssertReturn(YubiKitDeviceCapabilities.supportsISO7816NFCTags, @"Cannot start the NFC session on an unsupported device.");
    
    if (self.nfcTagReaderSession) {
        YKFLogInfo(@"NFC session already started. Ignoring start request.");
        return;
    }
    
    self.nfcTagReaderSession = [[NFCTagReaderSession alloc] initWithPollingOption:NFCPollingISO14443 delegate:self queue:nil];
    self.nfcTagReaderSession.alertMessage = YubiKitExternalLocalization.nfcScanAlertMessage;
    [self.nfcTagReaderSession beginSession];
}

- (void)stopIso7816Session API_AVAILABLE(ios(13.0)) {
    if (!self.nfcTagReaderSession) {
        YKFLogInfo(@"NFC session already stopped. Ignoring stop request.");
        return;
    }
    
    [self.nfcTagReaderSession invalidateSession];
    self.nfcTagReaderSession = nil;
}

- (void)cancelCommands API_AVAILABLE(ios(13.0)) {
    [self.connectionController cancelAllCommands];
}

#pragma mark - Shared communication queue

- (void)setupCommunicationQueue {
    // Create a sequential queue because the YubiKey accepts sequential commands.
    
    self.communicationQueue = [[NSOperationQueue alloc] init];
    self.communicationQueue.maxConcurrentOperationCount = 1;
    
    dispatch_queue_attr_t dispatchQueueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, DISPATCH_QUEUE_PRIORITY_HIGH, -1);
    self.sharedDispatchQueue = dispatch_queue_create("com.yubico.YKCOMNFC", dispatchQueueAttributes);
    
    self.communicationQueue.underlyingQueue = self.sharedDispatchQueue;
}

#pragma mark - NFCTagReaderSessionDelegate

- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error API_AVAILABLE(ios(13.0)) {
    YKFLogNSError(error);
    [self updateServicesForTag:nil state:YKFNFCISO7816SessionStateClosed];
}

- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session API_AVAILABLE(ios(13.0)) {
    YKFLogInfo(@"NFC session did become active.");
    [self updateIso7816SessionSate:YKFNFCISO7816SessionStatePooling];
}

- (void)tagReaderSession:(NFCTagReaderSession *)session didDetectTags:(NSArray<__kindof id<NFCTag>> *)tags API_AVAILABLE(ios(13.0)) {
    YKFLogInfo(@"NFC session did detect tags.");
    
    if (!tags.count) {
        return;
    }
    id<NFCISO7816Tag> activeTag = nil;
    for (id<NFCTag> tag in tags) {
        if (tag.type == NFCTagTypeISO7816Compatible) {
            activeTag = [tag asNFCISO7816Tag];
            break;
        }
    }
    if (!activeTag) {
        return;
    }
    
    [self updateServicesForTag:activeTag state:YKFNFCISO7816SessionStateOpening];

    ykf_weak_self();
    [self.nfcTagReaderSession connectToTag:activeTag completionHandler:^(NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            [strongSelf updateServicesForTag:activeTag state:YKFNFCISO7816SessionStateClosed];
            YKFLogNSError(error);
            self.nfcTagReaderSession = nil;
            return;
        }
        
        YKFLogInfo(@"NFC session did connect to tag.");
        [strongSelf updateServicesForTag:activeTag state:YKFNFCISO7816SessionStateOpen];
    }];
}

#pragma mark - Helpers

- (void)updateServicesForTag:(id<NFCISO7816Tag>)tag state:(YKFNFCISO7816SessionState)state API_AVAILABLE(ios(13.0)) {
    if (self.iso7816SessionState == state) {
        return;
    }
    switch (state) {
        case YKFNFCISO7816SessionStateClosed:
            self.u2fService = nil;
            self.fido2Service = nil;
            self.rawCommandService = nil;
            self.oathService = nil;
            self.connectionController = nil;
            
            [self unobserveIso7816TagAvailability];
            self.iso7816NfcTag = nil;
            
            [self.nfcTagReaderSession invalidateSession];
            self.nfcTagReaderSession = nil;
            self.tagDescription = nil;
            break;
        
        case YKFNFCISO7816SessionStatePooling:
            break;
            
        case YKFNFCISO7816SessionStateOpening:
            break;

        case YKFNFCISO7816SessionStateOpen:
            self.iso7816NfcTag = tag;
            [self observeIso7816TagAvailability];
            
            self.connectionController = [[YKFNFCConnectionController alloc] initWithNFCTag:tag operationQueue:self.communicationQueue];
            self.u2fService = [[YKFKeyU2FService alloc] initWithConnectionController:self.connectionController];
            self.fido2Service = [[YKFKeyFIDO2Service alloc] initWithConnectionController:self.connectionController];
            self.oathService = [[YKFKeyOATHService alloc] initWithConnectionController:self.connectionController];
            self.rawCommandService = [[YKFKeyRawCommandService alloc] initWithConnectionController:self.connectionController];
            self.tagDescription = [[YKFNFCTagDescription alloc] initWithTag: tag];
            break;
    }
    [self updateIso7816SessionSate:state];
}

#pragma mark - Tag availability observation

- (void)observeIso7816TagAvailability API_AVAILABLE(ios(13.0)) {
    // Note: A timer is used because the "available" property is not KVO observable and the tag has no delegate.
    // This solution is suboptimal but in line with some examples from Apple using a dispatch queue.
    ykf_weak_self();
    self.iso7816NfcTagAvailabilityTimer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:0.5 repeats:YES block:^(NSTimer *timer) {
        ykf_safe_strong_self();
        BOOL available = strongSelf.iso7816NfcTag.available;
        if (available) {
            YKFLogVerbose(@"NFC tag is available.");
        } else {
            YKFLogInfo(@"NFC tag is no longer available.");
            [strongSelf updateServicesForTag:nil state:YKFNFCISO7816SessionStateClosed];
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.iso7816NfcTagAvailabilityTimer forMode:NSDefaultRunLoopMode];
}

- (void)unobserveIso7816TagAvailability API_AVAILABLE(ios(13.0)) {
    // Note: A timer is used because the "available" property is not KVO observable and the tag has no delegate.
    // This solution is suboptimal but in line with some examples from Apple using a dispatch queue.
    [self.iso7816NfcTagAvailabilityTimer invalidate];
    self.iso7816NfcTagAvailabilityTimer = nil;
}

@end
