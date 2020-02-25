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

#import "YKFPCSCErrors.h"
#import "YKFPCSCErrorMap.h"

@interface YKFPCSCErrorMap()

@property (nonatomic) NSDictionary<NSNumber*, NSString*> *errorMap;

@end

@implementation YKFPCSCErrorMap

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupErrorMap];
    }
    return self;
}

- (NSString *)errorForCode:(SInt64)code {
    return self.errorMap[@(code)];
}

#pragma mark - Helpers

- (void)setupErrorMap {
    NSMutableDictionary<NSNumber*, NSString*> *descriptions = [[NSMutableDictionary alloc] init];
    
    descriptions[@(YKF_SCARD_S_SUCCESS)] = @"No error.";
    descriptions[@(YKF_SCARD_F_INTERNAL_ERROR)] = @"An internal consistency check failed.";
    descriptions[@(YKF_SCARD_E_CANCELLED)] = @"The action was cancelled by an SCardCancel request.";
    descriptions[@(YKF_SCARD_E_INVALID_HANDLE)] = @"The supplied handle was invalid.";
    descriptions[@(YKF_SCARD_E_INVALID_PARAMETER)] = @"One or more of the supplied parameters could not be properly interpreted.";
    descriptions[@(YKF_SCARD_E_INVALID_TARGET)] = @"Registry startup information is missing or invalid.";
    descriptions[@(YKF_SCARD_E_NO_MEMORY)] = @"Not enough memory available to complete this command.";
    descriptions[@(YKF_SCARD_F_WAITED_TOO_LONG)] = @"An internal consistency timer has expired.";
    descriptions[@(YKF_SCARD_E_INSUFFICIENT_BUFFER)] = @"The data buffer to receive returned data is too small for the returned data.";
    descriptions[@(YKF_SCARD_E_UNKNOWN_READER)] = @"The specified reader name is not recognized.";
    descriptions[@(YKF_SCARD_E_TIMEOUT)] = @"The user-specified timeout value has expired.";
    descriptions[@(YKF_SCARD_E_SHARING_VIOLATION)] = @"The smart card cannot be accessed because of other connections outstanding.";
    descriptions[@(YKF_SCARD_E_NO_SMARTCARD)] = @"The operation requires a Smart Card, but no Smart Card is currently in the device.";
    descriptions[@(YKF_SCARD_E_UNKNOWN_CARD)] = @"The specified smart card name is not recognized.";
    descriptions[@(YKF_SCARD_E_CANT_DISPOSE)] = @"The system could not dispose of the media in the requested manner.";
    descriptions[@(YKF_SCARD_E_PROTO_MISMATCH)] = @"The requested protocols are incompatible with the protocol currently in use with the smart card.";
    descriptions[@(YKF_SCARD_E_NOT_READY)] = @"The reader or smart card is not ready to accept commands.";
    descriptions[@(YKF_SCARD_E_INVALID_VALUE)] = @"One or more of the supplied parameters values could not be properly interpreted.";
    descriptions[@(YKF_SCARD_E_SYSTEM_CANCELLED)] = @"The action was cancelled by the system, presumably to log off or shut down.";
    descriptions[@(YKF_SCARD_F_COMM_ERROR)] = @"An internal communications error has been detected.";
    descriptions[@(YKF_SCARD_F_UNKNOWN_ERROR)] = @"An internal error has been detected, but the source is unknown.";
    descriptions[@(YKF_SCARD_E_INVALID_ATR)] = @"An ATR obtained from the registry is not a valid ATR string.";
    descriptions[@(YKF_SCARD_E_NOT_TRANSACTED)] = @"An attempt was made to end a non-existent transaction.";
    descriptions[@(YKF_SCARD_E_READER_UNAVAILABLE)] = @"The specified reader is not currently available for use.";
    descriptions[@(YKF_SCARD_P_SHUTDOWN)] = @"The operation has been aborted to allow the server application to exit.";
    descriptions[@(YKF_SCARD_E_PCI_TOO_SMALL)] = @"The PCI Receive buffer was too small.";
    descriptions[@(YKF_SCARD_E_READER_UNSUPPORTED)] = @"The reader driver does not meet minimal requirements for support.";
    descriptions[@(YKF_SCARD_E_DUPLICATE_READER)] = @"The reader driver did not produce a unique reader name.";
    descriptions[@(YKF_SCARD_E_CARD_UNSUPPORTED)] = @"The smart card does not meet minimal requirements for support.";
    descriptions[@(YKF_SCARD_E_NO_SERVICE)] = @"The Smart card resource manager is not running.";
    descriptions[@(YKF_SCARD_E_SERVICE_STOPPED)] = @"The Smart card resource manager has shut down.";
    descriptions[@(YKF_SCARD_E_UNEXPECTED)] = @"An unexpected card error has occurred.";
    descriptions[@(YKF_SCARD_E_ICC_INSTALLATION)] = @"No primary provider can be found for the smart card.";
    descriptions[@(YKF_SCARD_E_ICC_CREATEORDER)] = @"The requested order of object creation is not supported.";
    descriptions[@(YKF_SCARD_E_DIR_NOT_FOUND)] = @"The identified directory does not exist in the smart card.";
    descriptions[@(YKF_SCARD_E_FILE_NOT_FOUND)] = @"The identified file does not exist in the smart card.";
    descriptions[@(YKF_SCARD_E_NO_DIR)] = @"The supplied path does not represent a smart card directory.";
    descriptions[@(YKF_SCARD_E_NO_FILE)] = @"The supplied path does not represent a smart card file.";
    descriptions[@(YKF_SCARD_E_NO_ACCESS)] = @"Access is denied to this file.";
    descriptions[@(YKF_SCARD_E_WRITE_TOO_MANY)] = @"The smart card does not have enough memory to store the information.";
    descriptions[@(YKF_SCARD_E_BAD_SEEK)] = @"There was an error trying to set the smart card file object pointer.";
    descriptions[@(YKF_SCARD_E_INVALID_CHV)] = @"The supplied PIN is incorrect.";
    descriptions[@(YKF_SCARD_E_UNKNOWN_RES_MNG)] = @"An unrecognized error code was returned from a layered component.";
    descriptions[@(YKF_SCARD_E_NO_SUCH_CERTIFICATE)] = @"The requested certificate does not exist.";
    descriptions[@(YKF_SCARD_E_CERTIFICATE_UNAVAILABLE)] = @"The requested certificate could not be obtained.";
    descriptions[@(YKF_SCARD_E_NO_READERS_AVAILABLE)] = @"Cannot find a smart card reader.";
    descriptions[@(YKF_SCARD_E_COMM_DATA_LOST)] = @"A communications error with the smart card has been detected. Retry the operation.";
    descriptions[@(YKF_SCARD_E_NO_KEY_CONTAINER)] = @"The requested key container does not exist on the smart card.";
    descriptions[@(YKF_SCARD_E_SERVER_TOO_BUSY)] = @"The Smart Card Resource Manager is too busy to complete this operation.";
    descriptions[@(YKF_SCARD_W_UNSUPPORTED_CARD)] = @"The reader cannot communicate with the card, due to ATR string configuration conflicts.";
    descriptions[@(YKF_SCARD_E_UNSUPPORTED_FEATURE)] = @"This smart card does not support the requested feature.";
    descriptions[@(YKF_SCARD_W_UNRESPONSIVE_CARD)] = @"The smart card is not responding to a reset.";
    descriptions[@(YKF_SCARD_W_UNPOWERED_CARD)] = @"Power has been removed from the smart card, so that further communication is not possible.";
    descriptions[@(YKF_SCARD_W_RESET_CARD)] = @"The smart card has been reset, so any shared state information is invalid.";
    descriptions[@(YKF_SCARD_W_REMOVED_CARD)] = @"The smart card has been removed, so further communication is not possible.";
    descriptions[@(YKF_SCARD_W_SECURITY_VIOLATION)] = @"Access was denied because of a security violation.";
    descriptions[@(YKF_SCARD_W_WRONG_CHV)] = @"The card cannot be accessed because the wrong PIN was presented.";
    descriptions[@(YKF_SCARD_W_CHV_BLOCKED)] = @"The card cannot be accessed because the maximum number of PIN entry attempts has been reached.";
    descriptions[@(YKF_SCARD_W_EOF)] = @"The end of the smart card file has been reached.";
    descriptions[@(YKF_SCARD_W_CANCELLED_BY_USER)] = @"The user pressed 'Cancel' on a Smart Card Selection Dialog.";
    descriptions[@(YKF_SCARD_W_CARD_NOT_AUTHENTICATED)] = @"No PIN was presented to the smart card.";
    
    self.errorMap = descriptions;
}

@end
