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

NS_ASSUME_NONNULL_BEGIN

/*
 Helper category for building and parsing APDU related binary data.
 */
@interface NSMutableData(NSMutableData_APDU)

/*
 Appends one byte to the mutable data buffer.
 */
- (void)ykf_appendByte:(UInt8)byte;

/*
 Appends [tag] + [data length] + [data] to the mutable data buffer.
 */
- (void)ykf_appendEntryWithTag:(UInt8)tag data:(NSData *)data;

/*
 Appends a tag with the data = [header bytes] + [data];
 */
- (void)ykf_appendEntryWithTag:(UInt8)tag headerBytes:(NSArray *)headerBytes data:(NSData *)data;

/*
 Appends the UInt32 value to the mutable data after converting it to a big endian represetation (key representation).
 */
- (void)ykf_appendUInt32EntryWithTag:(UInt8)tag value:(UInt32)value;

/*
 Appends the UInt64 value to the mutable data after converting it to a big endian represetation (key representation).
 */
- (void)ykf_appendUInt64EntryWithTag:(UInt8)tag value:(UInt64)value;

@end

NS_ASSUME_NONNULL_END
