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

#import "YKFNSMutableDataAdditions.h"
#import "YKFAssert.h"

@implementation NSMutableData(NSMutableData_APDU)

- (void)ykf_appendByte:(UInt8)byte {
    [self appendBytes:&byte length:1];
}

- (void)ykf_appendEntryWithTag:(UInt8)tag data:(NSData *)data {    
    YKFParameterAssertReturn(tag > 0);
    YKFParameterAssertReturn(data.length > 0);
    YKFParameterAssertReturn(data.length <= UINT8_MAX);
    
    [self ykf_appendByte:tag];
    [self ykf_appendByte:data.length];
    [self appendData:data];
}

- (void)ykf_appendEntryWithTag:(UInt8)tag headerBytes:(NSArray *)headerBytes data:(NSData *)data {
    YKFParameterAssertReturn(tag > 0);
    YKFParameterAssertReturn(headerBytes.count > 0);
    YKFParameterAssertReturn(data.length > 0);
    YKFParameterAssertReturn(headerBytes.count + data.length <= UINT8_MAX);
    
    NSMutableData *buffer = [[NSMutableData alloc] initWithCapacity:headerBytes.count + data.length];
    for (NSNumber *byte in headerBytes) {
        UInt8 byteValue = [byte unsignedCharValue];
        [buffer ykf_appendByte:byteValue];
    }
    [buffer appendData:data];
    
    [self ykf_appendEntryWithTag:tag data:buffer];
}

- (void)ykf_appendUInt32EntryWithTag:(UInt8)tag value:(UInt32)value {
    YKFParameterAssertReturn(tag > 0);
    
    UInt32 bigEndianValue = CFSwapInt32HostToBig(value);
    
    [self ykf_appendByte:tag];
    [self ykf_appendByte:sizeof(UInt32)];
    [self appendBytes:&bigEndianValue length:sizeof(UInt32)];
}

- (void)ykf_appendUInt64EntryWithTag:(UInt8)tag value:(UInt64)value {
    YKFParameterAssertReturn(tag > 0);
    
    UInt64 bigEndianValue = CFSwapInt64HostToBig(value);
    
    [self ykf_appendByte:tag];
    [self ykf_appendByte:sizeof(UInt64)];
    [self appendBytes:&bigEndianValue length:sizeof(UInt64)];
}

@end
