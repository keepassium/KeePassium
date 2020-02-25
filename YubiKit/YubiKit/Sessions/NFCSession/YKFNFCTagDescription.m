//
//  YKFNFCTagDescription.m
//  YubiKit
//
//  Created by Irina Makhalova on 9/30/19.
//  Copyright © 2019 Yubico. All rights reserved.
//

#import "YKFNFCTagDescription.h"
#import "YKFNFCTagDescription+Private.h"
#import "YKFAssert.h"

@interface YKFNFCTagDescription()

@property(nonatomic, readwrite) NSData *identifier;
@property(nonatomic, readwrite) NSData *historicalBytes;

@end

@implementation YKFNFCTagDescription

- (instancetype)initWithTag:(id<NFCISO7816Tag>)tag  {
    YKFAssertAbortInit(tag);

    self = [super init];
    if (self) {
        NSAssert(tag.identifier, @"Identifier is not provided by the tag.");
        self.identifier = tag.identifier;
        YKFAssertAbortInit(self.identifier);

        NSAssert(tag.historicalBytes, @"Historical bytes are not provided by the tag.");
        self.historicalBytes = tag.historicalBytes;
        YKFAssertAbortInit(self.historicalBytes);
    }

    return self;
}
@end
