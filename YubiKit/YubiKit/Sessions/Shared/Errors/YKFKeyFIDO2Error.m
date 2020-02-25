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

#import "YKFKeyFIDO2Error.h"
#import "YKFKeySessionError+Private.h"

#pragma mark - Error Descriptions

static NSString* const YKFKeyFIDO2ErrorSUCCESS = @"Successful response";
static NSString* const YKFKeyFIDO2ErrorINVALID_COMMAND = @"The command is not a valid CTAP command.";
static NSString* const YKFKeyFIDO2ErrorINVALID_PARAMETER = @"The command included an invalid parameter.";
static NSString* const YKFKeyFIDO2ErrorINVALID_LENGTH = @"Invalid message or item length.";
static NSString* const YKFKeyFIDO2ErrorINVALID_SEQ = @"Invalid message sequencing.";
static NSString* const YKFKeyFIDO2ErrorTIMEOUT = @"Message timed out.";
static NSString* const YKFKeyFIDO2ErrorCHANNEL_BUSY = @"Channel busy.";
static NSString* const YKFKeyFIDO2ErrorLOCK_REQUIRED = @"Command requires channel lock.";
static NSString* const YKFKeyFIDO2ErrorINVALID_CHANNEL = @"Command not allowed on this cid.";
static NSString* const YKFKeyFIDO2ErrorOTHER = @"Other unspecified error.";
static NSString* const YKFKeyFIDO2ErrorCBOR_UNEXPECTED_TYPE = @"Invalid/unexpected CBOR error.";
static NSString* const YKFKeyFIDO2ErrorINVALID_CBOR = @"Error when parsing CBOR.";
static NSString* const YKFKeyFIDO2ErrorMISSING_PARAMETER = @"Missing non-optional parameter.";
static NSString* const YKFKeyFIDO2ErrorLIMIT_EXCEEDED = @"Limit for number of items exceeded.";
static NSString* const YKFKeyFIDO2ErrorUNSUPPORTED_EXTENSION = @"Unsupported extension.";
static NSString* const YKFKeyFIDO2ErrorCREDENTIAL_EXCLUDED = @"Valid credential found in the exclude list.";
static NSString* const YKFKeyFIDO2ErrorPROCESSING = @"Lengthy operation is in progress.";
static NSString* const YKFKeyFIDO2ErrorINVALID_CREDENTIAL = @"Credential not valid for the authenticator.";
static NSString* const YKFKeyFIDO2ErrorUSER_ACTION_PENDING = @"Authentication is waiting for user interaction.";
static NSString* const YKFKeyFIDO2ErrorOPERATION_PENDING = @"Processing, lengthy operation is in progress.";
static NSString* const YKFKeyFIDO2ErrorNO_OPERATIONS = @"No request is pending.";
static NSString* const YKFKeyFIDO2ErrorUNSUPPORTED_ALGORITHM = @"Authenticator does not support requested algorithm.";
static NSString* const YKFKeyFIDO2ErrorOPERATION_DENIED = @"Not authorized for requested operation.";
static NSString* const YKFKeyFIDO2ErrorKEY_STORE_FULL = @"Internal key storage is full.";
static NSString* const YKFKeyFIDO2ErrorNOT_BUSY = @"Authenticator cannot cancel as it is not busy.";
static NSString* const YKFKeyFIDO2ErrorNO_OPERATION_PENDING = @"No outstanding operations.";
static NSString* const YKFKeyFIDO2ErrorUNSUPPORTED_OPTION = @"Unsupported option.";
static NSString* const YKFKeyFIDO2ErrorINVALID_OPTION = @"Not a valid option for current operation.";
static NSString* const YKFKeyFIDO2ErrorKEEPALIVE_CANCEL = @"Pending keep alive was cancelled.";
static NSString* const YKFKeyFIDO2ErrorNO_CREDENTIALS = @"No valid credentials provided.";
static NSString* const YKFKeyFIDO2ErrorUSER_ACTION_TIMEOUT = @"Timeout waiting for user interaction.";
static NSString* const YKFKeyFIDO2ErrorNOT_ALLOWED = @"Continuation command, such as, authenticatorGetNextAssertion not allowed.";
static NSString* const YKFKeyFIDO2ErrorPIN_INVALID = @"PIN Invalid.";
static NSString* const YKFKeyFIDO2ErrorPIN_BLOCKED = @"PIN Blocked.";
static NSString* const YKFKeyFIDO2ErrorPIN_AUTH_INVALID = @"PIN authentication,pinAuth, verification failed.";
static NSString* const YKFKeyFIDO2ErrorPIN_AUTH_BLOCKED = @"PIN authentication,pinAuth, blocked. Requires power recycle to reset.";
static NSString* const YKFKeyFIDO2ErrorPIN_NOT_SET = @"No PIN has been set.";
static NSString* const YKFKeyFIDO2ErrorPIN_REQUIRED = @"PIN is required for the selected operation.";
static NSString* const YKFKeyFIDO2ErrorPIN_POLICY_VIOLATION = @"PIN policy violation. Currently only enforces minimum length.";
static NSString* const YKFKeyFIDO2ErrorPIN_TOKEN_EXPIRED = @"pinToken expired on authenticator.";
static NSString* const YKFKeyFIDO2ErrorREQUEST_TOO_LARGE = @"Authenticator cannot handle this request due to memory constraints.";
static NSString* const YKFKeyFIDO2ErrorACTION_TIMEOUT = @"The current operation has timed out.";
static NSString* const YKFKeyFIDO2ErrorUP_REQUIRED = @"User presence is required for the requested operation.";

#pragma mark - YKFKeyFIDO2Error

@implementation YKFKeyFIDO2Error

static NSDictionary *errorMap = nil;

+ (YKFKeySessionError *)errorWithCode:(NSUInteger)code {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [YKFKeyFIDO2Error buildErrorMap];
    });
    
    NSString *errorDescription = errorMap[@(code)];
    if (!errorDescription) {
        return [super errorWithCode:code];
    }
    return [[YKFKeySessionError alloc] initWithCode:code message:errorDescription];
}

+ (void)buildErrorMap {
    errorMap =
    @{@(YKFKeyFIDO2ErrorCodeSUCCESS): YKFKeyFIDO2ErrorSUCCESS,
      @(YKFKeyFIDO2ErrorCodeINVALID_COMMAND): YKFKeyFIDO2ErrorINVALID_COMMAND,
      @(YKFKeyFIDO2ErrorCodeINVALID_PARAMETER): YKFKeyFIDO2ErrorINVALID_PARAMETER,
      @(YKFKeyFIDO2ErrorCodeINVALID_LENGTH): YKFKeyFIDO2ErrorINVALID_LENGTH,
      @(YKFKeyFIDO2ErrorCodeINVALID_SEQ): YKFKeyFIDO2ErrorINVALID_SEQ,
      @(YKFKeyFIDO2ErrorCodeTIMEOUT): YKFKeyFIDO2ErrorTIMEOUT,
      @(YKFKeyFIDO2ErrorCodeCHANNEL_BUSY): YKFKeyFIDO2ErrorCHANNEL_BUSY,
      @(YKFKeyFIDO2ErrorCodeLOCK_REQUIRED): YKFKeyFIDO2ErrorLOCK_REQUIRED,
      @(YKFKeyFIDO2ErrorCodeINVALID_CHANNEL): YKFKeyFIDO2ErrorINVALID_CHANNEL,
      @(YKFKeyFIDO2ErrorCodeOTHER): YKFKeyFIDO2ErrorOTHER,
      @(YKFKeyFIDO2ErrorCodeCBOR_UNEXPECTED_TYPE): YKFKeyFIDO2ErrorCBOR_UNEXPECTED_TYPE,
      @(YKFKeyFIDO2ErrorCodeINVALID_CBOR): YKFKeyFIDO2ErrorINVALID_CBOR,
      @(YKFKeyFIDO2ErrorCodeMISSING_PARAMETER): YKFKeyFIDO2ErrorMISSING_PARAMETER,
      @(YKFKeyFIDO2ErrorCodeLIMIT_EXCEEDED): YKFKeyFIDO2ErrorLIMIT_EXCEEDED,
      @(YKFKeyFIDO2ErrorCodeUNSUPPORTED_EXTENSION): YKFKeyFIDO2ErrorUNSUPPORTED_EXTENSION,
      @(YKFKeyFIDO2ErrorCodeCREDENTIAL_EXCLUDED): YKFKeyFIDO2ErrorCREDENTIAL_EXCLUDED,
      @(YKFKeyFIDO2ErrorCodePROCESSING): YKFKeyFIDO2ErrorPROCESSING,
      @(YKFKeyFIDO2ErrorCodeINVALID_CREDENTIAL): YKFKeyFIDO2ErrorINVALID_CREDENTIAL,
      @(YKFKeyFIDO2ErrorCodeUSER_ACTION_PENDING): YKFKeyFIDO2ErrorUSER_ACTION_PENDING,
      @(YKFKeyFIDO2ErrorCodeOPERATION_PENDING): YKFKeyFIDO2ErrorOPERATION_PENDING,
      @(YKFKeyFIDO2ErrorCodeNO_OPERATIONS): YKFKeyFIDO2ErrorNO_OPERATIONS,
      @(YKFKeyFIDO2ErrorCodeUNSUPPORTED_ALGORITHM): YKFKeyFIDO2ErrorUNSUPPORTED_ALGORITHM,
      @(YKFKeyFIDO2ErrorCodeOPERATION_DENIED): YKFKeyFIDO2ErrorOPERATION_DENIED,
      @(YKFKeyFIDO2ErrorCodeKEY_STORE_FULL): YKFKeyFIDO2ErrorKEY_STORE_FULL,
      @(YKFKeyFIDO2ErrorCodeNOT_BUSY): YKFKeyFIDO2ErrorNOT_BUSY,
      @(YKFKeyFIDO2ErrorCodeNO_OPERATION_PENDING): YKFKeyFIDO2ErrorNO_OPERATION_PENDING,
      @(YKFKeyFIDO2ErrorCodeUNSUPPORTED_OPTION): YKFKeyFIDO2ErrorUNSUPPORTED_OPTION,
      @(YKFKeyFIDO2ErrorCodeINVALID_OPTION): YKFKeyFIDO2ErrorINVALID_OPTION,
      @(YKFKeyFIDO2ErrorCodeKEEPALIVE_CANCEL): YKFKeyFIDO2ErrorKEEPALIVE_CANCEL,
      @(YKFKeyFIDO2ErrorCodeNO_CREDENTIALS): YKFKeyFIDO2ErrorNO_CREDENTIALS,
      @(YKFKeyFIDO2ErrorCodeUSER_ACTION_TIMEOUT): YKFKeyFIDO2ErrorUSER_ACTION_TIMEOUT,
      @(YKFKeyFIDO2ErrorCodeNOT_ALLOWED): YKFKeyFIDO2ErrorNOT_ALLOWED,
      @(YKFKeyFIDO2ErrorCodePIN_INVALID): YKFKeyFIDO2ErrorPIN_INVALID,
      @(YKFKeyFIDO2ErrorCodePIN_BLOCKED): YKFKeyFIDO2ErrorPIN_BLOCKED,
      @(YKFKeyFIDO2ErrorCodePIN_AUTH_INVALID): YKFKeyFIDO2ErrorPIN_AUTH_INVALID,
      @(YKFKeyFIDO2ErrorCodePIN_AUTH_BLOCKED): YKFKeyFIDO2ErrorPIN_AUTH_BLOCKED,
      @(YKFKeyFIDO2ErrorCodePIN_NOT_SET): YKFKeyFIDO2ErrorPIN_NOT_SET,
      @(YKFKeyFIDO2ErrorCodePIN_REQUIRED): YKFKeyFIDO2ErrorPIN_REQUIRED,
      @(YKFKeyFIDO2ErrorCodePIN_POLICY_VIOLATION): YKFKeyFIDO2ErrorPIN_POLICY_VIOLATION,
      @(YKFKeyFIDO2ErrorCodePIN_TOKEN_EXPIRED): YKFKeyFIDO2ErrorPIN_TOKEN_EXPIRED,
      @(YKFKeyFIDO2ErrorCodeREQUEST_TOO_LARGE): YKFKeyFIDO2ErrorREQUEST_TOO_LARGE,
      @(YKFKeyFIDO2ErrorCodeACTION_TIMEOUT): YKFKeyFIDO2ErrorACTION_TIMEOUT,
      @(YKFKeyFIDO2ErrorCodeUP_REQUIRED): YKFKeyFIDO2ErrorUP_REQUIRED
      };
}

@end
