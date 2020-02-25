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

#import "YKFAccessoryConnectionController.h"
#import "YubiKitManager.h"
#import "YKFPCSCLayer.h"
#import "YKFPCSCErrors.h"
#import "YKFPCSCTypes.h"
#import "YKFAssert.h"
#import "YKFBlockMacros.h"
#import "YKFPCSCErrorMap.h"
#import "YKFLogger.h"
#import "YKFAccessorySession+Private.h"
#import "YKFNSDataAdditions+Private.h"

static NSString* const YKFPCSCLayerReaderName = @"YubiKey";

// YK5 ATR
static const UInt8 YKFPCSCAtrSize = 23;
static const UInt8 YKFPCSCAtr[] = {0x3b, 0xfd, 0x13, 0x00, 0x00, 0x81, 0x31, 0xfe, 0x15, 0x80, 0x73, 0xc0, 0x21, 0xc0, 0x57, 0x59, 0x75, 0x62, 0x69, 0x4b, 0x65, 0x79, 0x40};

// Some constants to avoid too many unnecessary contexts in one app. Ideally the host app should
// use a singleton to access the key, even when using PC/SC instead of replicating the same execution
// code on multiple threads.
static const NSUInteger YKFPCSCLayerContextLimit = 10;
static const NSUInteger YKFPCSCLayerCardLimitPerContext = 10;


@interface YKFPCSCLayer()

@property (nonatomic) id<YKFAccessorySessionProtocol> accessorySession;
@property (nonatomic) YKFPCSCErrorMap *errorMap;

// Maps a context value to a list of card values
@property (nonatomic) NSMutableDictionary<NSNumber*, NSMutableArray<NSNumber*>*> *contextMap;

// Reverse lookup map between a card and a context.
@property (nonatomic) NSMutableDictionary<NSNumber*, NSNumber*> *cardMap;

@end


@implementation YKFPCSCLayer

@synthesize cardState;
@synthesize cardSerial;
@synthesize cardAtr;
@synthesize statusChange;
@synthesize deviceFriendlyName;
@synthesize deviceModelName;
@synthesize deviceVendorName;

#pragma mark - Lifecycle

static id<YKFPCSCLayerProtocol> sharedInstance;

+ (id<YKFPCSCLayerProtocol>)shared {
#ifdef DEBUG
    if (staticFakePCSCLayer) {
        return staticFakePCSCLayer;
    }
#endif
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[YKFPCSCLayer alloc] initWithAccessorySession:YubiKitManager.shared.accessorySession];
    });
    return sharedInstance;
}

- (instancetype)initWithAccessorySession:(id<YKFAccessorySessionProtocol>)session {
    YKFAssertAbortInit(session);
    
    self = [super init];
    if (self) {
        self.accessorySession = session;        
        self.contextMap = [[NSMutableDictionary alloc] init];
        self.cardMap = [[NSMutableDictionary alloc] init];
        self.errorMap = [[YKFPCSCErrorMap alloc] init];
    }
    return self;
}

#pragma mark - Property Overrides

- (SInt32)cardState {
    if (self.accessorySession.isKeyConnected) {
        if (self.accessorySession.sessionState == YKFAccessorySessionStateOpen) {
            return YKF_SCARD_SPECIFICMODE;
        }
        return YKF_SCARD_SWALLOWED;
    }
    return YKF_SCARD_ABSENT;
}

- (NSString *)cardSerial {
    if (self.accessorySession.isKeyConnected) {
        return self.accessorySession.accessoryDescription.serialNumber;
    }
    return nil;
}

- (NSData *)cardAtr {
    return [NSData dataWithBytes:YKFPCSCAtr length:YKFPCSCAtrSize];
}

- (SInt64)statusChange {
    if (self.accessorySession.isKeyConnected) {
        return YKF_SCARD_STATE_PRESENT | YKF_SCARD_STATE_CHANGED;
    }
    return YKF_SCARD_STATE_EMPTY | YKF_SCARD_STATE_CHANGED;
}

- (NSString *)deviceFriendlyName {
    if (self.accessorySession.isKeyConnected) {
        return self.accessorySession.accessoryDescription.name;
    }
    return nil;
}

- (NSString *)deviceModelName {
    if (self.accessorySession.isKeyConnected) {
        return self.accessorySession.accessoryDescription.name;
    }
    return nil;
}

- (NSString *)deviceVendorName {
    if (self.accessorySession.isKeyConnected) {
        return self.accessorySession.accessoryDescription.manufacturer;
    }
    return nil;
}

#pragma mark - PC/SC

- (SInt64)connectCard {
    if (!self.accessorySession.isKeyConnected) {
        return YKF_SCARD_E_NO_SMARTCARD;
    }
    
    BOOL sessionOpened = [self.accessorySession startSessionSync];
    return sessionOpened ? YKF_SCARD_S_SUCCESS : YKF_SCARD_F_WAITED_TOO_LONG;
}

- (SInt64)disconnectCard {
    if (!self.accessorySession.isKeyConnected) {
        return YKF_SCARD_E_NO_SMARTCARD;
    }
    
    BOOL sessionClosed = [self.accessorySession stopSessionSync];
    return sessionClosed ? YKF_SCARD_S_SUCCESS : YKF_SCARD_F_WAITED_TOO_LONG;
}

- (SInt64)reconnectCard {
    SInt64 disconnectResult = [self disconnectCard];
    if (disconnectResult != YKF_SCARD_S_SUCCESS) {
        return disconnectResult;
    }
    return [self connectCard];
}

- (SInt64)transmit:(NSData *)commandData response:(NSData **)response {
    YKFAssertReturnValue(self.accessorySession.sessionState == YKFAccessorySessionStateOpen, @"Session is closed. Cannot send command.", YKF_SCARD_E_READER_UNAVAILABLE);
    YKFAssertReturnValue(commandData.length, @"The command data is empty.", YKF_SCARD_E_INVALID_PARAMETER);
    
    YKFAPDU *command = [[YKFAPDU alloc] initWithData:commandData];
    YKFAssertReturnValue(command, @"Could not create APDU with data.", YKF_SCARD_E_INVALID_PARAMETER);

    __block NSData *responseData = nil;
    
    [self.accessorySession.rawCommandService executeSyncCommand:command completion:^(NSData *resp, NSError *error) {
        if (!error && resp) {
            responseData = resp;
        }
    }];
    
    if (responseData) {
        *response = responseData;
        return YKF_SCARD_S_SUCCESS;
    }
    
    return YKF_SCARD_F_WAITED_TOO_LONG;
}

- (SInt64)listReaders:(NSString **)yubikeyReaderName {
    if (self.accessorySession.isKeyConnected) {
        *yubikeyReaderName = YKFPCSCLayerReaderName;
        return YKF_SCARD_S_SUCCESS;
    }
    return YKF_SCARD_E_NO_READERS_AVAILABLE;
}

#pragma mark - Context and Card tracking helpers

- (BOOL)addContext:(SInt32)context {
    @synchronized (self.contextMap) {
        if (self.contextMap.allKeys.count >= YKFPCSCLayerContextLimit) {
            YKFLogError(@"PC/SC - Could not establish context %d. Too many contexts started by the application.", (int)context);
            return NO;
        }
        NSMutableArray<NSNumber*> *contextCards = [[NSMutableArray alloc] init];
        self.contextMap[@(context)] = contextCards;
        
        YKFLogInfo(@"PC/SC - Context %d established.", (int)context);
        return YES;
    }
}

- (BOOL)removeContext:(SInt32)context {
    @synchronized (self.contextMap) {
        if (!self.contextMap[@(context)]) {
            YKFLogError(@"PC/SC - Could not release context %d. Unknown context.", (int)context);
            return NO;
        }
        
        NSMutableArray<NSNumber*> *associatedCards = self.contextMap[@(context)];
        [self.contextMap removeObjectForKey:@(context)];
        
        @synchronized (self.cardMap) {
            ykf_weak_self();
            [associatedCards enumerateObjectsUsingBlock:^(NSNumber *obj, NSUInteger idx, BOOL *stop) {
                [weakSelf.cardMap removeObjectForKey:obj];
            }];
            
            YKFLogInfo(@"PC/SC - Context %d released.", (int)context);
            return YES;
        }
    }
}

- (BOOL)addCard:(SInt32)card toContext:(SInt32)context {
    if (![self contextIsValid:context]) {
        // YKFLogError(@"PC/SC - Could not use context %d. Unknown context.", context);
        return NO;
    }
    
    @synchronized (self.contextMap) {
        if (self.contextMap[@(context)].count >= YKFPCSCLayerCardLimitPerContext) {
            // YKFLogError(@"PC/SC - Could not connect to card %d in context %d. Too many cards per context.", card, context);
            return NO;
        }
        [self.contextMap[@(context)] addObject:@(card)];
    }
    @synchronized (self.cardMap) {
        self.cardMap[@(card)] = @(context);
    }
    
    // YKFLogInfo(@"PC/SC - Connected to card %d in context %d.", card, context);
    return YES;
}

- (BOOL)removeCard:(SInt32)card {    
    if (![self cardIsValid:card]) {
        // YKFLogError(@"PC/SC - Could not disconnect from card %d. Unknown card.", card);
        return NO;
    }

    @synchronized (self.cardMap) {
        NSNumber *context = self.cardMap[@(card)];
        [self.cardMap removeObjectForKey:@(card)];
        
        @synchronized (self.contextMap) {
            [self.contextMap[context] removeObject:@(card)];
        }
        
        // YKFLogInfo(@"PC/SC - Disconnected from card %d.", card);
        return YES;
    }
}

- (BOOL)contextIsValid:(SInt32)context {
    @synchronized (self.contextMap) {
        return self.contextMap[@(context)] != nil;
    }
}

- (BOOL)cardIsValid:(SInt32)card {
    @synchronized (self.cardMap) {
        return self.cardMap[@(card)] != nil;
    }
}

- (SInt32)contextForCard:(SInt32)card {
    @synchronized (self.cardMap) {
        return self.cardMap[@(card)] != nil ? self.cardMap[@(card)].intValue : 0;
    }
}

- (NSString *)stringifyError:(SInt64)errorCode {
    return [self.errorMap errorForCode:errorCode];
}

#pragma mark - Testing additions

#ifdef DEBUG

static id<YKFPCSCLayerProtocol> staticFakePCSCLayer;

+ (void)setFakePCSCLayer:(id<YKFPCSCLayerProtocol>)fakePCSCLayer {
    staticFakePCSCLayer = fakePCSCLayer;
}

+ (id<YKFPCSCLayerProtocol>)fakePCSCLayer {
    return staticFakePCSCLayer;
}

#endif

@end
