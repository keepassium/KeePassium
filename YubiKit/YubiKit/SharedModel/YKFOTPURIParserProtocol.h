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

NS_ASSUME_NONNULL_BEGIN

/*!
 @protocol YKFOTPURIParserProtocol
 
 @abstract
    Interface for a NFC OTP custom URI parser. If the used YubiKeys use a custom way of formatting the URI received from the YubiKey
    a custom parser can be provided by the host application by implementing this interface and setting it on YubiKitConfiguration.
 */
@protocol YKFOTPURIParserProtocol<NSObject>

/*!
 @method tokenFromPayload:
 
 @abstract:
    Implements the extraction of the token from the payload. This method should always return a token, since the token is the minimal
    information all payloads should have. In case the token is not valid it should return a empty string.
 */
- (NSString *)tokenFromPayload:(NSString *)payload;

/*!
 @method uriFromPayload:
 
 @abstract:
    Implements the extraction of the URI from the payload. This method can return nil if no URI is available in the payload.
 */
- (nullable NSString *)uriFromPayload:(NSString *)payload;

@end

NS_ASSUME_NONNULL_END
