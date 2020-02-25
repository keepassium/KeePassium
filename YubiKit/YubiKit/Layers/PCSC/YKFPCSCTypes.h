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

static const UInt8 YKF_MAX_ATR_SIZE = 33;

/*!
 @abstract
    Adapted version of SCARD_READERSTATE for YubiKit.
    For more details of the original API check https://pcsclite.apdu.fr/api/structSCARD__READERSTATE.html
 */
typedef struct {
    const char *reader;
    void *userData;
    UInt32 currentState;
    UInt32 eventState;
    UInt32 atr;
    unsigned char rgbAtr[YKF_MAX_ATR_SIZE];
}
YKF_SCARD_READERSTATE;

/*!
 @abstract
    Adapted version of SCARD_IO_REQUEST for YubiKit.
    For more details of the original API check https://pcsclite.apdu.fr/api/structSCARD__IO__REQUEST.html
 */
typedef struct {
    UInt32 protocol;
    UInt32 pciLength;
}
YKF_SCARD_IO_REQUEST;

/*!
 Scope is in user space.
 */
static const UInt32 YKF_SCARD_SCOPE_USER = 0x0000;

/*!
 T=1 active protocol.
 */
static const UInt32 YKF_SCARD_PROTOCOL_T1 = 0x0002;

/*!
 Exclusive mode only.
 */
static const UInt32 YKF_SCARD_SHARE_EXCLUSIVE = 0x0001;

/*!
 The application wants the state of the card.
 */
static const UInt32 YKF_SCARD_STATE_UNAWARE  = 0x0000;

/*!
 The state of the card has changed.
 */
static const UInt32 YKF_SCARD_STATE_CHANGED = 0x0002;

/*!
 The card is not available.
 In the YubiKit context this means that the key is not connected.
 */
static const UInt32 YKF_SCARD_STATE_EMPTY = 0x0010;

/*!
 The card is available.
 In the YubiKit context this means that the key is connected.
 */
static const UInt32 YKF_SCARD_STATE_PRESENT = 0x0020;

/*!
 Do nothing on close.
 */
static const UInt32 YKF_SCARD_LEAVE_CARD = 0x0000;

/*!
 There is no card in the reader.
 */
static const UInt32 YKF_SCARD_ABSENT = 0x0001;

/*!
 There is a card in the reader in position for use. The card is not powered.
 */
static const UInt32 YKF_SCARD_SWALLOWED = 0x0003;

/*!
 The card has been reset and specific communication protocols have been established.
 */
static const UInt32 YKF_SCARD_SPECIFICMODE = 0x0006;

/*!
 Reader's display name.
 */
static const UInt32 YKF_SCARD_ATTR_DEVICE_FRIENDLY_NAME = 0x7FFF0003;

/*!
 Vendor-supplied interface device serial number.
 */
static const UInt32 YKF_SCARD_ATTR_VENDOR_IFD_SERIAL_NO = 0x00010103;

/*!
 Vendor-supplied interface device type (model designation of reader).
 */
static const UInt32 YKF_SCARD_ATTR_VENDOR_IFD_TYPE = 0x00010101;

/*!
 Vendor name.
 */
static const UInt32 YKF_SCARD_ATTR_VENDOR_NAME = 0x00010100;
