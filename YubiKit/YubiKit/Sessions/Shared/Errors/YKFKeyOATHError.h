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

#import "YKFKeySessionError.h"

typedef NS_ENUM(NSUInteger, YKFKeyOATHErrorCode) {
    
    /*! The host application tried to perform an OATH put credential operation with a credential which has a name longer then the
     maximum allowed length by the key.
     */
    YKFKeyOATHErrorCodeNameTooLong = 0x000100,
    
    /*! The host application tried to perform an OATH put credential operation with a credential which has a secret longer then the
     maximum allowed length of the SHA block size. The size of the secret should be less or equal to the size of the hash algorithm.
     */
    YKFKeyOATHErrorCodeSecretTooLong = 0x000101,
    
    /*! The key did not return correct data to a calculate request.
     */
    YKFKeyOATHErrorCodeBadCalculationResponse = 0x000102,
    
    /*! The key did not return correct data for a list request.
     */
    YKFKeyOATHErrorCodeBadListResponse = 0x000103,
    
    /*! The key did not return correct data when selecting the key OATH application.
     */
    YKFKeyOATHErrorCodeBadApplicationSelectionResponse = 0x000104,
    
    /*! The OATH application requires a validate call to unlock the application, when a password/code is set.
     */
    YKFKeyOATHErrorCodeAuthenticationRequired = 0x000105,
    
    /*! The key did not return correct data when validating a code set on the OATH application.
     */
    YKFKeyOATHErrorCodeBadValidationResponse = 0x000106,
    
    /*! The key did not return correct data when calculating all credentials.
     */
    YKFKeyOATHErrorCodeBadCalculateAllResponse = 0x000107,
    
    /*! The key did time out, waiting for the user to touch the key when calculating a credential which requires touch.
     */
    YKFKeyOATHErrorCodeTouchTimeout = 0x000108,
    
    /*! Wrong password used for authentication.
     */
    YKFKeyOATHErrorCodeWrongPassword = 0x000109
};


NS_ASSUME_NONNULL_BEGIN

/*!
 @class
    YKFKeyOATHError
 @abstract
    Error type returned by the YKFKeyOATHService.
 */
@interface YKFKeyOATHError: YKFKeySessionError
@end

NS_ASSUME_NONNULL_END
