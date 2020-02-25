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

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name APDU Types
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Reffers to the encoding type of APDU as defined in ISO/IEC 7816-4 standard.
 */
typedef NS_ENUM(NSUInteger, YKFAPDUType) {
    /*!
     Data does not exceed 256 bytes in length. CCID commands usually are encoded with short APDUs.
     */
    YKFAPDUTypeShort,
    
    /*!
     Data exceeds 256 bytes in length. Some YubiKey applications (like U2F) use extended APDUs.
     */
    YKFAPDUTypeExtended
};

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name APDU
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @class YKFAPDU
 
 @abstract
    Data model for encapsulating an APDU command, as defined by ISO/IEC 7816-4 standard.
 */
@interface YKFAPDU: NSObject

/*!
 @method initWithCla:ins:p1:p2:data:type:
 
 @abstract
    Creates a new APDU binary command from a list of parameters specified by the ISO/IEC 7816-4 standard.
 
 @param cla
    The instruction class.
 @param ins
    The instruction number.
 @param p1
    The first instruction paramater byte.
 @param p2
    The second instruction paramater byte.
 @param data
    The command data.
 @param type
    The type of the APDU, short or extended.
 
 @returns
    The newly initialized object or nil if the data param is empty or if the data length is too large for a short APDU.
 */
- (nullable instancetype)initWithCla:(UInt8)cla ins:(UInt8)ins p1:(UInt8)p1 p2:(UInt8)p2 data:(nonnull NSData *)data type:(YKFAPDUType)type;

/*!
 @method initWithData:
 
 @abstract
    Creates a new APDU with pre-built data.
 @param data
    The pre-built APDU data.
 @note
    This initializer does not check for the data integrity. It is recommended to use always [initWithCla:ins:p1:p2:data:type:] when possible.
 
 @returns
    The newly initialized object or nil if the data param is empty.
 */
- (nullable instancetype)initWithData:(nonnull NSData *)data;

@end
