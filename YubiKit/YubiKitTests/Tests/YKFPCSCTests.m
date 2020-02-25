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

#import <XCTest/XCTest.h>
#import "YKFTestCase.h"
#import "YKFPCSC.h"
#import "FakeYKFPCSCLayer.h"

@interface YKFPCSCTests: YKFTestCase

@property (nonatomic) FakeYKFPCSCLayer *pcscLayer;

@end

@implementation YKFPCSCTests

#pragma mark - Test Lifecycle

- (void)setUp {
    [super setUp];
    self.pcscLayer = [[FakeYKFPCSCLayer alloc] init];
    YKFPCSCLayer.fakePCSCLayer = self.pcscLayer;
}

- (void)tearDown {
    [super tearDown];
    YKFPCSCLayer.fakePCSCLayer = nil;
}

#pragma mark - Context Tests

- (void)test_WhenEstablishingAndReleasingContexts_ContextsCanBeRequestedAndReleased {
    self.pcscLayer.addContextResponse = YES;
    self.pcscLayer.removeContextResponse = YES;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt32 context = 0;
        SInt64 result = YKF_SCARD_S_SUCCESS;
        
        result = YKFSCardEstablishContext(YKF_SCARD_SCOPE_USER, nil, nil, &context);
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"Could not create a new PCSC context.");
        XCTAssert(context, @"PCSC context ID was not generated.");
        
        result = YKFSCardReleaseContext(context);
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"Could not release the PCSC context.");
    }];
}

- (void)test_WhenEstablishingContexts_ErrorIsReturnedIfTooManyContexts {
    self.pcscLayer.addContextResponse = NO;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt32 context = 0;
        SInt64 result = YKF_SCARD_S_SUCCESS;
        
        result = YKFSCardEstablishContext(YKF_SCARD_SCOPE_USER, nil, nil, &context);
        XCTAssertEqual(result, YKF_SCARD_E_NO_MEMORY, @"Error is not returned when there are too many contexts.");
        XCTAssertEqual(context, 0, @"PCSC context ID is generated when the establish context returned an error.");
    }];
}

- (void)test_WhenReleasingContexts_ErrorIsReturnedIfContextIsUnknown {
    self.pcscLayer.removeContextResponse = NO;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        
        result = YKFSCardReleaseContext(0);
        XCTAssertEqual(result, YKF_SCARD_E_INVALID_HANDLE, @"Error is not returned when the PC/SC context is unknown.");
    }];
}

- (void)test_WhenEstablishingContextsWithNilContextPointer_ErrorIsReturned {
    self.pcscLayer.addContextResponse = NO;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        
        result = YKFSCardEstablishContext(YKF_SCARD_SCOPE_USER, nil, nil, nil);
        XCTAssertEqual(result, YKF_SCARD_E_INVALID_PARAMETER, @"Error is not returned when the PC/SC context pointer is nil.");
    }];
}

#pragma mark - Transaction Tests

- (void)test_WhenUsingTransactions_TransactionsCanBeStartedAndEnded {
    self.pcscLayer.cardIsValidResponse = YES;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        
        result = YKFSCardBeginTransaction(card);
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"Could not begin PC/SC transaction.");
        
        result = YKFSCardEndTransaction(card, 0);
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"Could not end PC/SC transaction.");
    }];
}

- (void)test_WhenUsingTransactions_TransactionsWillFailIfTheCardIsUnknown {
    self.pcscLayer.cardIsValidResponse = NO;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        
        result = YKFSCardBeginTransaction(card);
        XCTAssertEqual(result, YKF_SCARD_E_INVALID_HANDLE, @"Begin PC/SC transaction could be executed when the card was unknown.");
        
        result = YKFSCardEndTransaction(card, 0);
        XCTAssertEqual(result, YKF_SCARD_E_INVALID_HANDLE, @"End PC/SC transaction could be executed when the card was unknown.");
    }];
}

#pragma mark - Listing Readers

- (void)test_WhenListingReaders_CanAskForReadersLengthSize {
    NSString *readerName = @"YubiKey";
    
    self.pcscLayer.listReadersResponse = YKF_SCARD_S_SUCCESS;
    self.pcscLayer.listReadersResponseParam = readerName;
    self.pcscLayer.contextIsValidResponse = YES;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 context = 0;
        UInt32 readersLength = 0;
        
        result = YKFSCardListReaders(context, nil, nil, &readersLength);
        NSUInteger expectedLength = readerName.length + 2; // double null terminated multistring.
        XCTAssertEqual(readersLength, expectedLength, @"PC/SC readers length does not match the expected length.");
    }];
}

- (void)test_WhenListingReaders_TheKeyReaderNameIsReturned {
    NSString *expectedReaderName = @"YubiKey";
    
    self.pcscLayer.listReadersResponse = YKF_SCARD_S_SUCCESS;
    self.pcscLayer.listReadersResponseParam = expectedReaderName;
    self.pcscLayer.contextIsValidResponse = YES;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 context = 0;
        UInt32 readersLength = (UInt32)expectedReaderName.length + 2;
        
        char *buffer = malloc(expectedReaderName.length + 2);
        XCTAssert(buffer, @"Could not allocated buffer.");
        
        result = YKFSCardListReaders(context, nil, buffer, &readersLength);
        NSUInteger expectedLength = expectedReaderName.length + 2; // double null terminated multistring.
        
        XCTAssertEqual(readersLength, expectedLength, @"PC/SC readers length does not match the expected length.");
        XCTAssert(strcmp(expectedReaderName.UTF8String, buffer) == 0, @"The reader name was not copied to the out parameter buffer.");
        
        free(buffer);
    }];
}

- (void)test_WhenListingReadersWithSmallBuffer_SmallBufferErrorIsReturned {
    NSString *expectedReaderName = @"YubiKey";
    
    self.pcscLayer.listReadersResponse = YKF_SCARD_S_SUCCESS;
    self.pcscLayer.listReadersResponseParam = expectedReaderName;
    self.pcscLayer.contextIsValidResponse = YES;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 context = 0;
        UInt32 readersLength = (UInt32)expectedReaderName.length;
        
        char *buffer = malloc(expectedReaderName.length); // too small buffer
        XCTAssert(buffer, @"Could not allocated buffer.");
        
        result = YKFSCardListReaders(context, nil, buffer, &readersLength);
        NSUInteger expectedLength = expectedReaderName.length + 2; // double null terminated multistring.
        
        XCTAssertEqual(readersLength, expectedLength, @"PC/SC readers length does not match the expected length.");
        XCTAssertEqual(result, YKF_SCARD_E_INSUFFICIENT_BUFFER, @"No error returened when the buffer is too small.");
        
        free(buffer);
    }];
}

#pragma mark - Reader Status

- (void)test_WhenAskingForCardStatus_CardIsPresentIfTheKeyIsConnected {
    self.pcscLayer.getStatusChangeResponse = YKF_SCARD_STATE_PRESENT;
    self.pcscLayer.contextIsValidResponse = YES;
    self.pcscLayer.getCardSerialResponse = @"12345";
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 context = 0;
        YKF_SCARD_READERSTATE readerState;
        
        result = YKFSCardGetStatusChange(context, 0, &readerState, 1);
        
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"Could not execute PC/SC get status change.");
        XCTAssert(readerState.eventState & YKF_SCARD_STATE_PRESENT, @"The card is not detected as present when the key is plugged in the device.");
    }];
}

- (void)test_WhenAskingForCardStatusWithNoReaderStates_ErrorIsReturned {
    self.pcscLayer.getStatusChangeResponse = YKF_SCARD_STATE_PRESENT;
    self.pcscLayer.contextIsValidResponse = YES;
    self.pcscLayer.getCardSerialResponse = @"12345";
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 context = 0;
        
        result = YKFSCardGetStatusChange(context, 0, nil, 1);
        
        XCTAssertEqual(result, YKF_SCARD_E_INVALID_PARAMETER, @"The PC/SC get status change did not return an error when no readers are passed.");
    }];
}

#pragma mark - Card Connect/Disconnect

- (void)test_WhenConnectingToTheKey_SuccessIsReturnedIfTheSessionIsOpen {
    self.pcscLayer.contextIsValidResponse = YES;
    self.pcscLayer.addCardToContextResponse = YES;
    self.pcscLayer.connectCardResponse = YKF_SCARD_S_SUCCESS;
    
    [self executeOnBackgroundQueueAndWait:^{
        const char *reader = "YubiKey";
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 context = 0;
        UInt32 activeProtocol = YKF_SCARD_PROTOCOL_T1;
        SInt32 card = 0;
        
        result = YKFSCardConnect(context, reader, YKF_SCARD_SHARE_EXCLUSIVE, YKF_SCARD_PROTOCOL_T1, &card, &activeProtocol);
        
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"PC/SC failed to connect to card.");
        XCTAssertNotEqual(card, 0, @"PC/SC card ID not generated after connecting to the card.");
    }];
}

- (void)test_WhenConnectingToTheKey_ErrorIsReturnedIfTheSessionIsClosed {
    self.pcscLayer.contextIsValidResponse = YES;
    self.pcscLayer.addCardToContextResponse = YES;
    self.pcscLayer.connectCardResponse = YKF_SCARD_F_WAITED_TOO_LONG;
    
    [self executeOnBackgroundQueueAndWait:^{
        const char *reader = "YubiKey";
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 context = 0;
        UInt32 activeProtocol = YKF_SCARD_PROTOCOL_T1;
        SInt32 card = 0;
        
        result = YKFSCardConnect(context, reader, YKF_SCARD_SHARE_EXCLUSIVE, YKF_SCARD_PROTOCOL_T1, &card, &activeProtocol);
        
        XCTAssertEqual(result, YKF_SCARD_F_WAITED_TOO_LONG, @"PC/SC did not return an error when session opening failed.");
        XCTAssertEqual(card, 0, @"PC/SC card generated after connecting to the card after failing to open the session.");
    }];
}

- (void)test_WhenDisconnectingFromTheKey_SuccessIsReturnedIfTheSessionIsClosed {
    self.pcscLayer.cardIsValidResponse = YES;
    self.pcscLayer.removeCardResponse = YES;
    self.pcscLayer.disconnectCardResponse = YKF_SCARD_S_SUCCESS;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        
        result = YKFSCardDisconnect(card, YKF_SCARD_LEAVE_CARD);
        
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"PC/SC card was not disconnected when the session was closed.");
    }];
}

- (void)test_WhenDisconnectingFromTheKey_ErrorIsReturnedIfTheSessionIsOpen {
    self.pcscLayer.cardIsValidResponse = YES;
    self.pcscLayer.removeCardResponse = YES;
    self.pcscLayer.disconnectCardResponse = YKF_SCARD_F_WAITED_TOO_LONG;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        
        result = YKFSCardDisconnect(card, YKF_SCARD_LEAVE_CARD);
        
        XCTAssertEqual(result, YKF_SCARD_F_WAITED_TOO_LONG, @"PC/SC did not return an error when the session was not closed.");
    }];
}

#pragma mark - Card Status

- (void)test_WhenAskingForCardStatus_TheStateCanBeUsedToCheckKeyConnection {
    self.pcscLayer.cardIsValidResponse = YES;
    self.pcscLayer.contextIsValidResponse = YES;
    self.pcscLayer.contextForCardResponse = 100;
    self.pcscLayer.getCardStateResponse = YKF_SCARD_STATE_PRESENT;
    self.pcscLayer.listReadersResponse = YKF_SCARD_S_SUCCESS;
    self.pcscLayer.listReadersResponseParam = @"YubiKey";
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        UInt32 state = 0;
        
        result = YKFSCardStatus(card, nil, nil, &state, nil, nil, nil);
        
        XCTAssertEqual(state, YKF_SCARD_STATE_PRESENT, @"PC/SC did not return correct state when the card was plugged in.");
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"PC/SC did not return success when getting the card status.");
    }];
}

- (void)test_WhenAskingForCardStatus_NilParametersCanBeSentIfSomeParametersAreNotRequired {
    self.pcscLayer.cardIsValidResponse = YES;
    self.pcscLayer.contextIsValidResponse = YES;
    self.pcscLayer.contextForCardResponse = 100;
    self.pcscLayer.getCardStateResponse = YKF_SCARD_STATE_PRESENT;
    self.pcscLayer.listReadersResponse = YKF_SCARD_S_SUCCESS;
    self.pcscLayer.listReadersResponseParam = @"YubiKey";
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        
        result = YKFSCardStatus(card, nil, nil, nil, nil, nil, nil);
        
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"PC/SC did not return success when calling YKFSCardStatus with nil params.");
    }];
}

#pragma mark - Card Attributes

- (void)test_WhenAskingForCardAttributes_KnownAttributesCanBeRetrieved {
    self.pcscLayer.cardIsValidResponse = YES;
    self.pcscLayer.contextIsValidResponse = YES;
    self.pcscLayer.getCardSerialResponse = @"123456";
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        UInt32 attrLength = 0;
        
        result = YKFSCardGetAttrib(card, YKF_SCARD_ATTR_VENDOR_IFD_SERIAL_NO, nil, &attrLength);
        XCTAssert(attrLength == self.pcscLayer.getCardSerialResponse.length + 1, @"Invalid length returned for the attribute.");
        
        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"PC/SC did not return success when reading the serial attribute.");
    }];
}

- (void)test_WhenAskingForUnsupportedAttributes_ErrorIsReturned {
    self.pcscLayer.cardIsValidResponse = YES;
    self.pcscLayer.contextIsValidResponse = YES;
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        UInt32 attrLength = 0;
        
        result = YKFSCardGetAttrib(card, 0, nil, &attrLength);
        XCTAssert(attrLength == 0, @"Invalid length returned for the attribute.");
        
        XCTAssertEqual(result, YKF_SCARD_E_UNSUPPORTED_FEATURE, @"PC/SC did not return error when reading unknown attribute.");
    }];
}

#pragma mark - Transmit

- (void)test_WhenSendingAPDUCommand_TheCommandIsSentToThePCSCLayer {
    self.pcscLayer.cardIsValidResponse = YES;
    self.pcscLayer.contextIsValidResponse = YES;
    self.pcscLayer.transmitResponse = YKF_SCARD_S_SUCCESS;
    
    const UInt8 response[] = {0x90, 0x00};
    self.pcscLayer.transmitResponseParam = [NSData dataWithBytes:response length:2];
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        UInt32 recvLength = 2;
        const UInt8 command[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06};
        
        UInt8 *recvBuffer = malloc(self.pcscLayer.transmitResponseParam.length);
        XCTAssert(recvBuffer != nil, @"Could not allocate PC/SC receive buffer for transmit.");
        
        result = YKFSCardTransmit(card, nil, command, 6, nil, recvBuffer, &recvLength);

        XCTAssertEqual(result, YKF_SCARD_S_SUCCESS, @"Could not send command over PC/SC.");
        XCTAssertEqual(recvLength, 2, @"Invalid length returned by the PC/SC transmit API.");
        
        free(recvBuffer);
    }];
}

- (void)test_WhenSendingAPDUCommandWithWrongBufferLength_ErrorIsReturned {
    self.pcscLayer.cardIsValidResponse = YES;
    self.pcscLayer.contextIsValidResponse = YES;
    self.pcscLayer.transmitResponse = YKF_SCARD_S_SUCCESS;
    
    const UInt8 response[] = {0x01, 0x02, 0x03, 0x90, 0x00};
    self.pcscLayer.transmitResponseParam = [NSData dataWithBytes:response length:5];
    
    [self executeOnBackgroundQueueAndWait:^{
        SInt64 result = YKF_SCARD_S_SUCCESS;
        SInt32 card = 0;
        UInt32 recvLength = 2;
        const UInt8 command[] = {0x01, 0x02, 0x03, 0x04, 0x05, 0x06};
        
        UInt8 *recvBuffer = malloc(self.pcscLayer.transmitResponseParam.length);
        XCTAssert(recvBuffer != nil, @"Could not allocate PC/SC receive buffer for transmit.");
        
        result = YKFSCardTransmit(card, nil, command, 6, nil, recvBuffer, &recvLength);
        
        XCTAssertEqual(result, YKF_SCARD_E_INSUFFICIENT_BUFFER, @"Error not returned when sending the wrong buffer length.");
        XCTAssertEqual(recvLength, 5, @"Correct length not returned by the PC/SC transmit.");
        
        free(recvBuffer);
    }];
}

#pragma mark - Helpers

- (void)executeOnBackgroundQueueAndWait:(void(^)(void))block {
    XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"PCSC execution expectation."];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        block();
        [expectation fulfill];
    });
    
    XCTWaiterResult result = [XCTWaiter waitForExpectations:@[expectation] timeout:15];
    XCTAssert(result == XCTWaiterResultCompleted, @"PCSC execution did timeout.");
}

@end
