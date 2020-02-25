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

#import "YKFURIIdentifierCode.h"

@implementation YKFURIIdentifierCode

// Contains the most common URI Identifier codes used to shorten the URI in a NDEF URI type payload.
static NSDictionary *codesDictionary;

- (instancetype)init {
    self = [super init];
    if (self) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [self setupIdentifierCodes];
        });
    }
    return self;
}

- (void)setupIdentifierCodes {
    codesDictionary = @{
      @(0x00): @"", // No prepending is done.
      @(0x01): @"http://www.",
      @(0x02): @"https://www.",
      @(0x03): @"http://",
      @(0x04): @"https://",
      @(0x05): @"tel:",
      @(0x06): @"mailto:",
      @(0x07): @"ftp://anonymous:anonymous@",
      @(0x08): @"ftp://ftp.",
      @(0x09): @"ftps://",
      @(0x0A): @"sftp://",
      @(0x0B): @"smb://",
      @(0x0C): @"nfs://",
      @(0x0D): @"ftp://",
      @(0x0E): @"dav://",
      @(0x0F): @"news:",
      @(0x10): @"telnet://",
      @(0x11): @"imap:",
      @(0x12): @"rtsp://",
      @(0x13): @"urn:",
      @(0x14): @"pop:",
      @(0x15): @"sip:",
      @(0x16): @"sips:",
      @(0x17): @"tftp:",
      @(0x18): @"btspp://",
      @(0x19): @"btl2cap://",
      @(0x1A): @"btgoep://",
      @(0x1B): @"tcpobex://",
      @(0x1C): @"irdaobex://",
      @(0x1D): @"file://",
      @(0x1E): @"urn:epc:id:",
      @(0x1F): @"urn:epc:tag:",
      @(0x20): @"urn:epc:pat:",
      @(0x21): @"urn:epc:raw:",
      @(0x22): @"urn:epc:",
      @(0x23): @"urn:nfc:"
    };
}

- (NSString *)prependingStringForCode:(UInt8)code {
    return codesDictionary[@(code)];
}

@end
