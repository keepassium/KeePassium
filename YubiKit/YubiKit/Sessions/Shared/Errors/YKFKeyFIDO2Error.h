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

typedef NS_ENUM(NSUInteger, YKFKeyFIDO2ErrorCode) {
    
    /*! Indicates successful response.
     */
    YKFKeyFIDO2ErrorCodeSUCCESS = 0x00,
    
    /*! The command is not a valid CTAP command.
     */
    YKFKeyFIDO2ErrorCodeINVALID_COMMAND = 0x01,
    
    /*! The command included an invalid parameter.
     */
    YKFKeyFIDO2ErrorCodeINVALID_PARAMETER = 0x02,
    
    /*! Invalid message or item length.
     */
    YKFKeyFIDO2ErrorCodeINVALID_LENGTH = 0x03,
    
    /*! Invalid message sequencing.
     */
    YKFKeyFIDO2ErrorCodeINVALID_SEQ = 0x04,
    
    /*! Message timed out.
     */
    YKFKeyFIDO2ErrorCodeTIMEOUT = 0x05,
    
    /*! Channel busy.
     */
    YKFKeyFIDO2ErrorCodeCHANNEL_BUSY = 0x06,
    
    /*! Command requires channel lock.
     */
    YKFKeyFIDO2ErrorCodeLOCK_REQUIRED = 0x0A,
    
    /*! Command not allowed on this cid.
     */
    YKFKeyFIDO2ErrorCodeINVALID_CHANNEL = 0x0B,
    
    /*! Other unspecified error.
     */
    YKFKeyFIDO2ErrorCodeOTHER = 0x7F,
    
    /*! Invalid/unexpected CBOR error.
     */
    YKFKeyFIDO2ErrorCodeCBOR_UNEXPECTED_TYPE = 0x11,
    
    /*! Error when parsing CBOR.
     */
    YKFKeyFIDO2ErrorCodeINVALID_CBOR = 0x12,
    
    /*! Missing non-optional parameter.
     */
    YKFKeyFIDO2ErrorCodeMISSING_PARAMETER = 0x14,
    
    /*! Limit for number of items exceeded.
     */
    YKFKeyFIDO2ErrorCodeLIMIT_EXCEEDED = 0x15,
    
    /*! Unsupported extension.
     */
    YKFKeyFIDO2ErrorCodeUNSUPPORTED_EXTENSION = 0x16,
    
    /*! Valid credential found in the exclude list.
     */
    YKFKeyFIDO2ErrorCodeCREDENTIAL_EXCLUDED = 0x19,
    
    /*! Lengthy operation is in progress.
     */
    YKFKeyFIDO2ErrorCodePROCESSING = 0x21,
    
    /*! Credential not valid for the authenticator.
     */
    YKFKeyFIDO2ErrorCodeINVALID_CREDENTIAL = 0x22,
    
    /*! Authentication is waiting for user interaction.
     */
    YKFKeyFIDO2ErrorCodeUSER_ACTION_PENDING = 0x23,
    
    /*! Processing, lengthy operation is in progress.
     */
    YKFKeyFIDO2ErrorCodeOPERATION_PENDING = 0x24,
    
    /*! No request is pending.
     */
    YKFKeyFIDO2ErrorCodeNO_OPERATIONS = 0x25,
    
    /*! Authenticator does not support requested algorithm.
     */
    YKFKeyFIDO2ErrorCodeUNSUPPORTED_ALGORITHM = 0x26,
    
    /*! Not authorized for requested operation.
     */
    YKFKeyFIDO2ErrorCodeOPERATION_DENIED = 0x27,
    
    /*! Internal key storage is full.
     */
    YKFKeyFIDO2ErrorCodeKEY_STORE_FULL = 0x28,
    
    /*! Authenticator cannot cancel as it is not busy.
     */
    YKFKeyFIDO2ErrorCodeNOT_BUSY = 0x29,
    
    /*! No outstanding operations.
     */
    YKFKeyFIDO2ErrorCodeNO_OPERATION_PENDING = 0x2A,
    
    /*! Unsupported option.
     */
    YKFKeyFIDO2ErrorCodeUNSUPPORTED_OPTION = 0x2B,
    
    /*! Not a valid option for current operation.
     */
    YKFKeyFIDO2ErrorCodeINVALID_OPTION = 0x2C,
    
    /*! Pending keep alive was cancelled.
     */
    YKFKeyFIDO2ErrorCodeKEEPALIVE_CANCEL = 0x2D,
    
    /*! No valid credentials provided.
     */
    YKFKeyFIDO2ErrorCodeNO_CREDENTIALS = 0x2E,
    
    /*! Timeout waiting for user interaction.
     */
    YKFKeyFIDO2ErrorCodeUSER_ACTION_TIMEOUT = 0x2F,
    
    /*! Continuation command, such as, authenticatorGetNextAssertion not allowed.
     */
    YKFKeyFIDO2ErrorCodeNOT_ALLOWED = 0x30,
    
    /*! PIN Invalid.
     */
    YKFKeyFIDO2ErrorCodePIN_INVALID = 0x31,
    
    /*! PIN Blocked.
     */
    YKFKeyFIDO2ErrorCodePIN_BLOCKED = 0x32,
    
    /*! PIN authentication,pinAuth, verification failed.
     */
    YKFKeyFIDO2ErrorCodePIN_AUTH_INVALID = 0x33,
    
    /*! PIN authentication,pinAuth, blocked. Requires power recycle to reset.
     */
    YKFKeyFIDO2ErrorCodePIN_AUTH_BLOCKED = 0x34,
    
    /*! No PIN has been set.
     */
    YKFKeyFIDO2ErrorCodePIN_NOT_SET = 0x35,
    
    /*! PIN is required for the selected operation.
     */
    YKFKeyFIDO2ErrorCodePIN_REQUIRED = 0x36,
    
    /*! PIN policy violation. Currently only enforces minimum length.
     */
    YKFKeyFIDO2ErrorCodePIN_POLICY_VIOLATION = 0x37,
    
    /*! pinToken expired on authenticator.
     */
    YKFKeyFIDO2ErrorCodePIN_TOKEN_EXPIRED = 0x38,
    
    /*! Authenticator cannot handle this request due to memory constraints.
     */
    YKFKeyFIDO2ErrorCodeREQUEST_TOO_LARGE = 0x39,
    
    /*! The current operation has timed out.
     */
    YKFKeyFIDO2ErrorCodeACTION_TIMEOUT = 0x3A,
    
    /*! User presence is required for the requested operation.
     */
    YKFKeyFIDO2ErrorCodeUP_REQUIRED = 0x3B,
    
    /*! CTAP 2 spec last error.
     */
    YKFKeyFIDO2ErrorCodeSPEC_LAST = 0xDF,
    
    /*! Extension specific error.
     */
    YKFKeyFIDO2ErrorCodeEXTENSION_FIRST = 0xE0,
    
    /*! Extension specific error.
     */
    YKFKeyFIDO2ErrorCodeEXTENSION_LAST = 0xEF,
    
    /*! Vendor specific error.
     */
    YKFKeyFIDO2ErrorCodeVENDOR_FIRST = 0xF0,
    
    /*! Vendor specific error.
     */
    YKFKeyFIDO2ErrorCodeVENDOR_LAST = 0xFF,
};

NS_ASSUME_NONNULL_BEGIN

/*!
 @class
    YKFKeyFIDO2Error
 @abstract
    Error type returned by the YKFKeyFIDO2Service.
 */
@interface YKFKeyFIDO2Error: YKFKeySessionError
@end

NS_ASSUME_NONNULL_END
