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

#import "YKFPCSC.h"
#import "YKFPCSCLayer.h"
#import "YubiKitManager.h"
#import "YKFAssert.h"

/*
 Assigns a random context value and creates the PC/SC communication layer.
 */
SInt64 YKFSCardEstablishContext(UInt32 scope, const void *reserved1, const void *reserved2, SInt32 *context) {
    YKFCAssertOffMainThread();
    
    if (!context) {
        return YKF_SCARD_E_INVALID_PARAMETER;
    }
    
    SInt32 newContext = arc4random();
    newContext = abs(newContext);
    
    if (![YKFPCSCLayer.shared addContext:newContext]) {
        return YKF_SCARD_E_NO_MEMORY;
    }
    
    *context = newContext;
    return YKF_SCARD_S_SUCCESS;
}

/*
 Releases the the PC/SC communication layer.
 */
SInt64 YKFSCardReleaseContext(SInt32 context) {
    YKFCAssertOffMainThread();

    if (![YKFPCSCLayer.shared removeContext:context]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    return YKF_SCARD_S_SUCCESS;
}

/*
 Starts the Key Session if not started and selects the PIV application.
 */
SInt64 YKFSCardConnect(SInt32 context, const char *reader, UInt32 shareMode, UInt32 preferredProtocols, SInt32 *card, UInt32 *activeProtocol) {
    YKFCAssertOffMainThread();
    
    if (!card || !activeProtocol) {
        return YKF_SCARD_E_INVALID_PARAMETER;
    }
    
    if (![YKFPCSCLayer.shared contextIsValid:context]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    
    SInt32 newCard = arc4random();
    newCard = abs(newCard);
    
    if (![YKFPCSCLayer.shared addCard:newCard toContext:context]) {
        return YKF_SCARD_E_NO_MEMORY;
    }

    SInt64 connectCardResponse = [YKFPCSCLayer.shared connectCard];
    if (connectCardResponse == YKF_SCARD_S_SUCCESS) {
        *card = newCard;
        *activeProtocol = YKF_SCARD_PROTOCOL_T1;
    }
    
    return connectCardResponse;
}

/*
 Stops and then starts the Key Session and selects the PIV application.
 */
SInt64 YKFSCardReconnect(SInt32 card, UInt32 shareMode, UInt32 preferredProtocols, UInt32 initialization, UInt32 *activeProtocol) {
    YKFCAssertOffMainThread();
    
    if (![YKFPCSCLayer.shared cardIsValid:card]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    
    *activeProtocol = YKF_SCARD_PROTOCOL_T1;
    return [YKFPCSCLayer.shared reconnectCard];
}

/*
 Stops the Key Session.
 */
SInt64 YKFSCardDisconnect(SInt32 card, UInt32 disposition) {
    YKFCAssertOffMainThread();
    
    if (![YKFPCSCLayer.shared cardIsValid:card]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    if (![YKFPCSCLayer.shared removeCard:card]) {
        return YKF_SCARD_F_COMM_ERROR;
    }
    
    return [YKFPCSCLayer.shared disconnectCard];
}

/*
 Does nothing. This will always succeed because only one application can talk to the key.
 */
SInt64 YKFSCardBeginTransaction(SInt32 card) {
    YKFCAssertOffMainThread();
    
    if (![YKFPCSCLayer.shared cardIsValid:card]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    
    return YKF_SCARD_S_SUCCESS;
}

/*
 Does nothing. This will always succeed because only one application can talk to the key.
 */
SInt64 YKFSCardEndTransaction(SInt32 card, UInt32 disposition) {
    YKFCAssertOffMainThread();
    
    if (![YKFPCSCLayer.shared cardIsValid:card]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    
    return YKF_SCARD_S_SUCCESS;
}

/*
 Returns the status of the Key Session and the serial of the key when connected.
 */
SInt64 YKFSCardStatus(SInt32 card, char *readerNames, UInt32 *readerLen, UInt32 *state, UInt32 *protocol, unsigned char *atr, UInt32 *atrLength) {
    YKFCAssertOffMainThread();
    
    if (![YKFPCSCLayer.shared cardIsValid:card]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    
    // Readers
    
    SInt32 context = [YKFPCSCLayer.shared contextForCard:card];
    if (!context) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    
    SInt64 result = YKFSCardListReaders(context, nil, readerNames, readerLen);
    if (result != YKF_SCARD_S_SUCCESS) {
        return result;
    }

    // State
    
    if (state) {
        *state = YKFPCSCLayer.shared.cardState;
    }
    
    // Protocol
    
    if (protocol) {
        *protocol = YKF_SCARD_PROTOCOL_T1;
    }
    
    // ATR
    
    NSData *keyAtr = YKFPCSCLayer.shared.cardAtr;
    if (keyAtr.length) {
        UInt8 *keyAtrBytes = (UInt8 *)keyAtr.bytes;
        
        UInt32 inAtrLength = atrLength ? *atrLength : 0;
        UInt32 outAtrLen = (UInt32)keyAtr.length;
        
        if (atrLength) {
            *atrLength = outAtrLen;
        }
        
        if (atr && inAtrLength && inAtrLength < outAtrLen) {
            return YKF_SCARD_E_INSUFFICIENT_BUFFER;
        }
        
        if (atr) {
            memcpy(atr, keyAtrBytes, outAtrLen);
        }
    }
    
    return YKF_SCARD_S_SUCCESS;
}

SInt64 YKFSCardGetStatusChange(SInt32 context, UInt32 timeout, YKF_SCARD_READERSTATE *readerStates, UInt32 readers) {
    YKFCAssertOffMainThread();
    
    if (![YKFPCSCLayer.shared contextIsValid:context]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    if (!readerStates && readers) {
        return YKF_SCARD_E_INVALID_PARAMETER;
    }
    
    // 1. Get the key connection status.
    UInt8 status = YKFPCSCLayer.shared.statusChange;
    
    // 2. Get the ATR
    NSData *keyAtr = YKFPCSCLayer.shared.cardAtr;
    NSCAssert(keyAtr.length <= YKF_MAX_ATR_SIZE, @"ATR value too long.");
    
    UInt8 *atrValue = (UInt8 *)keyAtr.bytes;
    UInt8 atrLength = keyAtr.length;
    
    // 3. Populate the list or readers.
    for (int i = 0; i < readers; ++i) {
        readerStates[i].eventState = status;
        
        readerStates[i].atr = atrLength;
        memset(readerStates[i].rgbAtr, 0, YKF_MAX_ATR_SIZE);
        memcpy(readerStates[i].rgbAtr, atrValue, atrLength);
    }
    
    return YKF_SCARD_S_SUCCESS;
}

/*
 Sends the APDU through the Raw Command Service to the PIV Application.
 */
SInt64 YKFSCardTransmit(SInt32 card, YKF_SCARD_IO_REQUEST *sendPci, const unsigned char *sendBuffer, UInt32 sendLength,
                        YKF_SCARD_IO_REQUEST *recvPci, unsigned char *recvBuffer, UInt32 *recvLength) {
    YKFCAssertOffMainThread();

    if (![YKFPCSCLayer.shared cardIsValid:card]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    if (!sendBuffer || !sendLength || !recvBuffer || !*recvLength) {
        // If send or receive buffers are empty/nil
        return YKF_SCARD_E_INVALID_PARAMETER;
    }
    
    NSData *commandData = [NSData dataWithBytes:sendBuffer length:sendLength];
    NSData *responseData = nil;
    
    SInt64 responseCode = [YKFPCSCLayer.shared transmit:commandData response:&responseData];
    
    if (responseCode == YKF_SCARD_S_SUCCESS) {
        UInt32 inRecvLength = recvLength ? *recvLength : 0;
        UInt32 outRecvLength = (UInt32)responseData.length;
        
        if (recvLength) {
            *recvLength = outRecvLength;
        }
        
        if (recvBuffer && inRecvLength < outRecvLength) {
            return YKF_SCARD_E_INSUFFICIENT_BUFFER;
        }
        
        [responseData getBytes:recvBuffer length:responseData.length];
    }
    return responseCode;
}

/*
 If the key is connected it will return the name of the key.
 */
SInt64 YKFSCardListReaders(SInt32 context, const char *groups, char *readers, UInt32 *readersLength) {
    YKFCAssertOffMainThread();
    
    if (![YKFPCSCLayer.shared contextIsValid:context]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    
    NSString *readerName = nil;
    SInt64 responseCode = [YKFPCSCLayer.shared listReaders:&readerName];
    
    if (responseCode == YKF_SCARD_S_SUCCESS && readerName) {
        const char *ykReader = [readerName cStringUsingEncoding:NSUTF8StringEncoding];
        if (!ykReader) {
            return YKF_SCARD_F_INTERNAL_ERROR;
        }
        
        unsigned long readerLength = strlen(ykReader);
        unsigned long outReadersLength = readerLength + 2; // double null terminated multistring.
        
        UInt32 inReadersLength = readersLength ? *readersLength : 0; // aux
        
        if (readersLength) {
            *readersLength = (UInt32)outReadersLength;
        }
        
        if (readers && inReadersLength < outReadersLength) {
            return YKF_SCARD_E_INSUFFICIENT_BUFFER;
        }
        
        if (readers) { // copy the value in the provided buffer.
            memset(readers, 0, outReadersLength);
            strcpy(readers, ykReader);
        }
    }
    return responseCode;
}

SInt64 YKFSCardCancel(SInt32 context) {
    YKFCAssertOffMainThread();
    
    if (![YKFPCSCLayer.shared contextIsValid:context]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    return YKF_SCARD_S_SUCCESS;
}

/*
 Returns some attributes specific to the YubiKey.
 */
SInt64 YKFSCardGetAttrib(SInt32 card, UInt32 attrId, UInt8 *attr, UInt32 *attrLength) {
    YKFCAssertOffMainThread();
    
    if (![YKFPCSCLayer.shared cardIsValid:card]) {
        return YKF_SCARD_E_INVALID_HANDLE;
    }
    
    const char *attributeValue = nil;
    switch (attrId) {
        case YKF_SCARD_ATTR_DEVICE_FRIENDLY_NAME:
            attributeValue = YKFPCSCLayer.shared.deviceFriendlyName.UTF8String;
            break;

        case YKF_SCARD_ATTR_VENDOR_IFD_SERIAL_NO: {
                NSString *serial = YKFPCSCLayer.shared.cardSerial;
                if (!serial.length) {
                    return YKF_SCARD_S_SUCCESS;
                }
                attributeValue = [serial UTF8String];
            }
            break;

        case YKF_SCARD_ATTR_VENDOR_IFD_TYPE:
            attributeValue = YKFPCSCLayer.shared.deviceModelName.UTF8String;
            break;

        case YKF_SCARD_ATTR_VENDOR_NAME:
            attributeValue = YKFPCSCLayer.shared.deviceVendorName.UTF8String;
            break;
            
        default:
            return YKF_SCARD_E_UNSUPPORTED_FEATURE;
            break;
    }
    
    UInt32 inAttrLength = attrLength ? *attrLength : 0;
    UInt32 outAttrLength = (UInt32)strlen(attributeValue) + 1;
    
    if (attrLength) {
        *attrLength = outAttrLength;
    }
    
    if (attr && inAttrLength < outAttrLength) {
        return YKF_SCARD_E_INSUFFICIENT_BUFFER;
    }
    
    if (attr) {
        memcpy(attr, attributeValue, outAttrLength);
    }
    
    return YKF_SCARD_S_SUCCESS;
}

const char* YKFPCSCStringifyError(const SInt64 pcscError) {
    NSString *description = [YKFPCSCLayer.shared stringifyError:pcscError];
    return description ? [description UTF8String] : "";
}
