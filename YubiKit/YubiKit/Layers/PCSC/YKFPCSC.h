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
//  PC/SC like interface for YubiKit.
//  PC/SC Lite API reference: https://pcsclite.apdu.fr/api/group__API.html
//
//  Note:
//    In the iOS SDK has no native concept of PC/SC. This interface is just an adaptation of
//    the PC/SC interface, specific to YubiKit.

#import <Foundation/Foundation.h>
#import "YKFPCSCErrors.h"
#import "YKFPCSCTypes.h"

/*!
 @abstract
    Adapted version of SCardEstablishContext for YubiKit.
    For more details of the original API check SCardEstablishContext on https://pcsclite.apdu.fr/api/group__API.html
 */
SInt64 YKFSCardEstablishContext(UInt32 scope,
                                const void *reserved1,
                                const void *reserved2,
                                SInt32 *context);
/*!
 @abstract
    Adapted version of SCardReleaseContext for YubiKit.
    For more details of the original API check SCardReleaseContext on https://pcsclite.apdu.fr/api/group__API.html
 */
SInt64 YKFSCardReleaseContext(SInt32 context);

/*!
 @abstract
    Adapted version of SCardConnect for YubiKit.
    For more details of the original API check SCardConnect on https://pcsclite.apdu.fr/api/group__API.html
 
 @discussion
    In YubiKit this API will try to start the communication session with the key if the key is
    connected to the device.
 */
SInt64 YKFSCardConnect(SInt32 context,
                       const char *reader,
                       UInt32 shareMode,
                       UInt32 preferredProtocols,
                       SInt32 *card,
                       UInt32 *activeProtocol);

/*!
 @abstract
    Adapted version of SCardReconnect for YubiKit.
    For more details of the original API check SCardReconnect on https://pcsclite.apdu.fr/api/group__API.html
 
 @discussion
    In YubiKit this API will try to stop and start the communication session with the key if the key is
    connected to the device.
 */
SInt64 YKFSCardReconnect(SInt32 card,
                         UInt32 shareMode,
                         UInt32 preferredProtocols,
                         UInt32 initialization,
                         UInt32 *activeProtocol);

/*!
 @abstract
    Adapted version of SCardDisconnect for YubiKit.
    For more details of the original API check SCardDisconnect on https://pcsclite.apdu.fr/api/group__API.html
 
 @discussion
    In YubiKit this API will try to stop the communication session with the key if the key is
    connected to the device.
 */
SInt64 YKFSCardDisconnect(SInt32 card,
                          UInt32 disposition);

/*!
 @abstract
    Adapted version of SCardBeginTransaction for YubiKit.
    For more details of the original API check SCardBeginTransaction on https://pcsclite.apdu.fr/api/group__API.html
 */
SInt64 YKFSCardBeginTransaction(SInt32 card);

/*!
 @abstract
    Adapted version of SCardEndTransaction for YubiKit.
    For more details of the original API check SCardEndTransaction on https://pcsclite.apdu.fr/api/group__API.html
 */
SInt64 YKFSCardEndTransaction(SInt32 card,
                              UInt32 disposition);

/*!
 @abstract
    Adapted version of SCardStatus for YubiKit.
    For more details of the original API check SCardStatus on https://pcsclite.apdu.fr/api/group__API.html
 */
SInt64 YKFSCardStatus(SInt32 card,
                      char *readerNames,
                      UInt32 *readerLen,
                      UInt32 *state,
                      UInt32 *protocol,
                      unsigned char *atr,
                      UInt32 *atrLength);

/*!
 @abstract
    Adapted version of SCardGetStatusChange for YubiKit.
    For more details of the original API check SCardGetStatusChange on https://pcsclite.apdu.fr/api/group__API.html
 
 @note
    Supports only YKF_SCARD_STATE_UNAWARE and returns immediately.
 */
SInt64 YKFSCardGetStatusChange(SInt32 context,
                               UInt32 timeout,
                               YKF_SCARD_READERSTATE *readerStates,
                               UInt32 readers);

/*!
 @abstract
    Adapted version of SCardTransmit for YubiKit.
    For more details of the original API check SCardTransmit on https://pcsclite.apdu.fr/api/group__API.html
 */
SInt64 YKFSCardTransmit(SInt32 card,
                        YKF_SCARD_IO_REQUEST *sendPci,
                        const unsigned char *sendBuffer,
                        UInt32 sendLength,
                        YKF_SCARD_IO_REQUEST *recvPci,
                        unsigned char *recvBuffer,
                        UInt32 *recvLength);

/*!
 @abstract
 Adapted version of SCardListReaders for YubiKit.
 For more details of the original API check SCardListReaders on https://pcsclite.apdu.fr/api/group__API.html
 */
SInt64 YKFSCardListReaders(SInt32 context,
                           const char *groups,
                           char *readers,
                           UInt32 *readersLength);


/*!
 @abstract
    Adapted version of SCardCancel for YubiKit.
    For more details of the original API check SCardCancel on https://pcsclite.apdu.fr/api/group__API.html
 */
SInt64 YKFSCardCancel(SInt32 context);

/*!
 @abstract
    Adapted version of SCardGetAttrib for YubiKit.
    For more details of the original API check SCardGetAttrib on https://pcsclite.apdu.fr/api/group__API.html
 */
SInt64 YKFSCardGetAttrib(SInt32 card,
                         UInt32 attrId,
                         UInt8 *attr,
                         UInt32 *attrLength);

/*!
 @abstract
    Return a description of the PC/SC error code.
 */
const char* YKFPCSCStringifyError(const SInt64 pcscError);
