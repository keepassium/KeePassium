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

#import <Foundation/Foundation.h>
#import "YKFAccessorySession.h"

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFPCSCLayerProtocol
 * ---------------------------------------------------------------------------------------------------------------------
 */

@protocol YKFPCSCLayerProtocol<NSObject>

@property (nonatomic, readonly) SInt32 cardState;
@property (nonatomic, readonly, nullable) NSString *cardSerial;
@property (nonatomic, readonly, nonnull) NSData *cardAtr;

@property (nonatomic, readonly) SInt64 statusChange;

@property (nonatomic, readonly, nullable) NSString *deviceFriendlyName;
@property (nonatomic, readonly, nullable) NSString *deviceModelName;
@property (nonatomic, readonly, nullable) NSString *deviceVendorName;

/*!
 Connects to the card. In the YubiKit context this opens the session with the key.
 */
- (SInt64)connectCard;

/*!
  Reconnects to the card. In the YubiKit context this reopens the session with the key.
 */
- (SInt64)reconnectCard;

/*!
 Disconnects the card. In the YubiKit context this closes the session with the key.
 */
- (SInt64)disconnectCard;

/*!
 Sends some data the card. In the YubiKit context this sends the data to the key.
 */
- (SInt64)transmit:(nonnull NSData *)commandData response:(NSData *_Nonnull*_Nullable)response;

/*!
 Returns the list of available readers. In the YubiKit context this returns the key name as a reader.
 */
- (SInt64)listReaders:(NSString *_Nonnull*_Nullable)yubikeyReaderName;

/*!
 Used by YKFPCSCStringifyError to create a human readable error from a defined code.
 */
- (nullable NSString *)stringifyError:(SInt64)errorCode;

/*
 Context and Card Tracking
 */

/*!
 @abstract
    Adds a new context to the layer. This happens when a new context is created from the PC/SC interface.
 @returns
    YES if the layer can store more contexts or no if the limit was exeeded (max 10).
 */
- (BOOL)addContext:(SInt32)context;

/*!
 @abstract
    Removes an existing context from the layer. This happens when a context is released from the PC/SC interface.
 @return
    YES if the context was removed.
 */
- (BOOL)removeContext:(SInt32)context;

/*!
 @abstract
    Adds a card which is associated with a context.
 @return
    YES if success.
 */
- (BOOL)addCard:(SInt32)card toContext:(SInt32)context;

/*!
 @abstract
    Removes a card from its associated context.
 @return
    YES if success.
 */
- (BOOL)removeCard:(SInt32)card;

/*!
 @return
    YES if the context is known by the layer, i.e. it was added using [addContext:].
 */
- (BOOL)contextIsValid:(SInt32)context;

/*!
 @return
    YES if the card is known by the layer, i.e. it was added using [addCard:toContext:].
 */
- (BOOL)cardIsValid:(SInt32)card;

/*!
 @return
    The context associated with the card if any. If no context is found returns 0.
 */
- (SInt32)contextForCard:(SInt32)card;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFPCSCLayer
 * ---------------------------------------------------------------------------------------------------------------------
 */

@interface YKFPCSCLayer: NSObject<YKFPCSCLayerProtocol>

/*!
 Returns the shared instance of the layer.
 */
@property (class, nonatomic, readonly, nonnull) id<YKFPCSCLayerProtocol> shared;

/*!
 @abstract
    Designated intialiser which will use the RawCommandService from the supplied session to
    communicate with the key.
 
 @param session
    The session to be used by the layer when communicating with the key.
 */
- (nullable instancetype)initWithAccessorySession:(nonnull id<YKFAccessorySessionProtocol>)session NS_DESIGNATED_INITIALIZER;

/*
 Not available: use [initWithAccessorySession:]
 */
- (nonnull instancetype)init NS_UNAVAILABLE;

@end

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name YKFPCSCLayer Testing Additions
 * ---------------------------------------------------------------------------------------------------------------------
 */

#ifdef DEBUG

@interface YKFPCSCLayer(/* Testing */)

// Injected singleton by a unit test.
@property (class, nonatomic, nullable) id<YKFPCSCLayerProtocol> fakePCSCLayer;

@end

#endif
