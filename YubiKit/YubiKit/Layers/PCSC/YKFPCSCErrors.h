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
//
//  Adapted version of PC/SC interface for YubiKit.
//  Error Codes as defined in https://docs.microsoft.com/en-us/windows/desktop/SecAuthN/authentication-return-values
//

/**
 No error was encountered.
 */
#define YKF_SCARD_S_SUCCESS                 0x00000000

/**
 An internal consistency check failed.
 */
#define YKF_SCARD_F_INTERNAL_ERROR          0x80100001

/**
 The action was cancelled by an SCardCancel request.
 */
#define YKF_SCARD_E_CANCELLED               0x80100002

/**
 The supplied handle was invalid.
 */
#define YKF_SCARD_E_INVALID_HANDLE          0x80100003

/**
 One or more of the supplied parameters could not be properly interpreted.
 */
#define YKF_SCARD_E_INVALID_PARAMETER       0x80100004

/**
 Registry startup information is missing or invalid.
 */
#define YKF_SCARD_E_INVALID_TARGET          0x80100005

/**
 Not enough memory available to complete this command.
 */
#define YKF_SCARD_E_NO_MEMORY               0x80100006

/**
 An internal consistency timer has expired.
 */
#define YKF_SCARD_F_WAITED_TOO_LONG         0x80100007

/**
 The data buffer to receive returned data is too small for the returned data.
 */
#define YKF_SCARD_E_INSUFFICIENT_BUFFER     0x80100008

/**
 The specified reader name is not recognized.
 */
#define YKF_SCARD_E_UNKNOWN_READER          0x80100009

/**
 The user-specified timeout value has expired.
 */
#define YKF_SCARD_E_TIMEOUT                 0x8010000A

/**
 The smart card cannot be accessed because of other connections outstanding.
 */
#define YKF_SCARD_E_SHARING_VIOLATION       0x8010000B

/**
 The operation requires a Smart Card, but no Smart Card is currently in the device.
 */
#define YKF_SCARD_E_NO_SMARTCARD            0x8010000C

/**
 The specified smart card name is not recognized.
 */
#define YKF_SCARD_E_UNKNOWN_CARD            0x8010000D

/**
 The system could not dispose of the media in the requested manner.
 */
#define YKF_SCARD_E_CANT_DISPOSE            0x8010000E

/**
 The requested protocols are incompatible with the protocol currently in use with the smart card.
 */
#define YKF_SCARD_E_PROTO_MISMATCH          0x8010000F

/**
 The reader or smart card is not ready to accept commands.
 */
#define YKF_SCARD_E_NOT_READY               0x80100010

/**
 One or more of the supplied parameters values could not be properly interpreted.
 */
#define YKF_SCARD_E_INVALID_VALUE           0x80100011

/**
 The action was cancelled by the system, presumably to log off or shut down.
 */
#define YKF_SCARD_E_SYSTEM_CANCELLED        0x80100012

/**
 An internal communications error has been detected.
 */
#define YKF_SCARD_F_COMM_ERROR              0x80100013

/**
 An internal error has been detected, but the source is unknown.
 */
#define YKF_SCARD_F_UNKNOWN_ERROR           0x80100014

/**
 An ATR obtained from the registry is not a valid ATR string.
 */
#define YKF_SCARD_E_INVALID_ATR             0x80100015

/**
 An attempt was made to end a non-existent transaction.
 */
#define YKF_SCARD_E_NOT_TRANSACTED          0x80100016

/**
 The specified reader is not currently available for use.
 */
#define YKF_SCARD_E_READER_UNAVAILABLE      0x80100017

/**
 The operation has been aborted to allow the server application to exit.
 */
#define YKF_SCARD_P_SHUTDOWN                0x80100018

/**
 The PCI Receive buffer was too small.
 */
#define YKF_SCARD_E_PCI_TOO_SMALL           0x80100019

/**
 The reader driver does not meet minimal requirements for support.
 */
#define YKF_SCARD_E_READER_UNSUPPORTED      0x8010001A

/**
 The reader driver did not produce a unique reader name.
 */
#define YKF_SCARD_E_DUPLICATE_READER        0x8010001B

/**
 The smart card does not meet minimal requirements for support.
 */
#define YKF_SCARD_E_CARD_UNSUPPORTED        0x8010001C

/**
 The Smart card resource manager is not running.
 */
#define YKF_SCARD_E_NO_SERVICE              0x8010001D

/**
 The Smart card resource manager has shut down.
 */
#define YKF_SCARD_E_SERVICE_STOPPED         0x8010001E

/**
 An unexpected card error has occurred.
 */
#define YKF_SCARD_E_UNEXPECTED              0x8010001F

/**
 No primary provider can be found for the smart card.
 */
#define YKF_SCARD_E_ICC_INSTALLATION        0x80100020

/**
 The requested order of object creation is not supported.
 */
#define YKF_SCARD_E_ICC_CREATEORDER         0x80100021

/**
 The identified directory does not exist in the smart card.
 */
#define YKF_SCARD_E_DIR_NOT_FOUND           0x80100023

/**
 The identified file does not exist in the smart card.
 */
#define YKF_SCARD_E_FILE_NOT_FOUND          0x80100024

/**
 The supplied path does not represent a smart card directory.
 */
#define YKF_SCARD_E_NO_DIR                  0x80100025

/**
 The supplied path does not represent a smart card file.
 */
#define YKF_SCARD_E_NO_FILE                 0x80100026

/**
 Access is denied to this file.
 */
#define YKF_SCARD_E_NO_ACCESS               0x80100027

/**
 The smart card does not have enough memory to store the information.
 */
#define YKF_SCARD_E_WRITE_TOO_MANY          0x80100028

/**
 There was an error trying to set the smart card file object pointer.
 */
#define YKF_SCARD_E_BAD_SEEK                0x80100029

/**
 The supplied PIN is incorrect.
 */
#define YKF_SCARD_E_INVALID_CHV             0x8010002A

/**
 An unrecognized error code was returned from a layered component.
 */
#define YKF_SCARD_E_UNKNOWN_RES_MNG         0x8010002B

/**
 The requested certificate does not exist.
 */
#define YKF_SCARD_E_NO_SUCH_CERTIFICATE     0x8010002C

/**
 The requested certificate could not be obtained.
 */
#define YKF_SCARD_E_CERTIFICATE_UNAVAILABLE 0x8010002D

/**
 Cannot find a smart card reader.
 */
#define YKF_SCARD_E_NO_READERS_AVAILABLE    0x8010002E

/**
 A communications error with the smart card has been detected. Retry the operation.
 */
#define YKF_SCARD_E_COMM_DATA_LOST          0x8010002F

/**
 The requested key container does not exist on the smart card.
 */
#define YKF_SCARD_E_NO_KEY_CONTAINER        0x80100030

/**
 The Smart Card Resource Manager is too busy to complete this operation.
 */
#define YKF_SCARD_E_SERVER_TOO_BUSY         0x80100031

/**
 The reader cannot communicate with the card, due to ATR string configuration conflicts.
 */
#define YKF_SCARD_W_UNSUPPORTED_CARD        0x80100065

/**
 This smart card does not support the requested feature.
 */
#define YKF_SCARD_E_UNSUPPORTED_FEATURE     0x8010001F

/**
 The smart card is not responding to a reset.
 */
#define YKF_SCARD_W_UNRESPONSIVE_CARD       0x80100066

/**
 Power has been removed from the smart card, so that further communication is not possible.
 */
#define YKF_SCARD_W_UNPOWERED_CARD          0x80100067

/**
 The smart card has been reset, so any shared state information is invalid.
 */
#define YKF_SCARD_W_RESET_CARD              0x80100068

/**
 The smart card has been removed, so further communication is not possible.
 */
#define YKF_SCARD_W_REMOVED_CARD            0x80100069

/**
 Access was denied because of a security violation.
 */
#define YKF_SCARD_W_SECURITY_VIOLATION      0x8010006A

/**
 The card cannot be accessed because the wrong PIN was presented.
 */
#define YKF_SCARD_W_WRONG_CHV               0x8010006B

/**
 The card cannot be accessed because the maximum number of PIN entry attempts has been reached.
 */
#define YKF_SCARD_W_CHV_BLOCKED             0x8010006C

/**
 The end of the smart card file has been reached.
 */
#define YKF_SCARD_W_EOF                     0x8010006D

/**
 The user pressed "Cancel" on a Smart Card Selection Dialog.
 */
#define YKF_SCARD_W_CANCELLED_BY_USER       0x8010006E

/**
 No PIN was presented to the smart card.
 */
#define YKF_SCARD_W_CARD_NOT_AUTHENTICATED  0x8010006F
