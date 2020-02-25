//
//  YKFNFCTagDescription.h
//  YubiKit
//
//  Created by Irina Makhalova on 9/30/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreNFC/CoreNFC.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(13.0))

/*!
@class YKFNFCTagDescription

@abstract
   Provides a list of properties describing the connected key.
*/
@interface YKFNFCTagDescription : NSObject

/*!
 @property identifier
 
 @abstract
    The hardware UID of the tag.
 */
@property(nonatomic, readonly) NSData *identifier;

/*!
 @property historicalBytes
 
 @abstract
    The historical bytes extracted from the Type A Answer To Select response.
 */
@property(nonatomic, readonly) NSData *historicalBytes;


/*
 Not available: access the instance provided by YKFNFCSession.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
