//
//  MF_Base32Additions.h
//  Base32 -- RFC 4648 compatible implementation
//  see http://www.ietf.org/rfc/rfc4648.txt for more details
//
//  Designed to be compiled with Automatic Reference Counting
//
//  Created by Dave Poirier on 12-06-14.
//  Public Domain
//

#import <Foundation/Foundation.h>

#define NSBase32StringEncoding  0x4D467E32

@interface NSString (Base32Addition)
+(NSString *)stringFromBase32String:(NSString *)base32String;
-(NSString *)base32String;
@end

@interface NSData (Base32Addition)
+(NSData *)dataWithBase32String:(NSString *)base32String;
-(NSString *)base32String;
@end

@interface MF_Base32Codec : NSObject
+(NSData *)dataFromBase32String:(NSString *)base32String;
+(NSString *)base32StringFromData:(NSData *)data;
@end
