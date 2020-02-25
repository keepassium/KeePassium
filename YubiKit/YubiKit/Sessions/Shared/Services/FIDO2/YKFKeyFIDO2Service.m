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

#import "YKFKeyFIDO2Service.h"
#import "YKFKeyFIDO2Service+Private.h"
#import "YKFAccessoryConnectionController.h"
#import "YKFKeyFIDO2Error.h"
#import "YKFKeyAPDUError.h"
#import "YKFKeyCommandConfiguration.h"
#import "YKFLogger.h"
#import "YKFBlockMacros.h"
#import "YKFNSDataAdditions.h"
#import "YKFAssert.h"

#import "YKFFIDO2PinAuthKey.h"
#import "YKFKeyFIDO2ClientPinRequest.h"
#import "YKFKeyFIDO2ClientPinResponse.h"

#import "YKFSelectFIDO2ApplicationAPDU.h"
#import "YKFFIDO2MakeCredentialAPDU.h"
#import "YKFFIDO2GetAssertionAPDU.h"
#import "YKFFIDO2GetNextAssertionAPDU.h"
#import "YKFFIDO2TouchPoolingAPDU.h"
#import "YKFFIDO2ClientPinAPDU.h"
#import "YKFFIDO2GetInfoAPDU.h"
#import "YKFFIDO2ResetAPDU.h"

#import "YKFKeyFIDO2GetInfoResponse+Private.h"
#import "YKFKeyFIDO2MakeCredentialResponse+Private.h"
#import "YKFKeyFIDO2GetAssertionResponse+Private.h"

#import "YKFKeyFIDO2MakeCredentialRequest+Private.h"
#import "YKFKeyFIDO2GetAssertionRequest+Private.h"

#import "YKFNSDataAdditions+Private.h"
#import "YKFKeySessionError+Private.h"
#import "YKFKeyService+Private.h"
#import "YKFKeyFIDO2Request+Private.h"
#import "YKFAPDU+Private.h"

#pragma mark - Private Response Blocks

typedef void (^YKFKeyFIDO2ServiceResultCompletionBlock)
    (NSData* _Nullable response, NSError* _Nullable error);

typedef void (^YKFKeyFIDO2ServiceClientPinCompletionBlock)
    (YKFKeyFIDO2ClientPinResponse* _Nullable response, NSError* _Nullable error);

typedef void (^YKFKeyFIDO2ServiceClientPinSharedSecretCompletionBlock)
    (NSData* _Nullable sharedSecret, YKFCBORMap* _Nullable cosePlatformPublicKey, NSError* _Nullable error);

#pragma mark - YKFKeyFIDO2Service

@interface YKFKeyFIDO2Service()

@property (nonatomic, assign, readwrite) YKFKeyFIDO2ServiceKeyState keyState;
@property (nonatomic) id<YKFKeyConnectionControllerProtocol> connectionController;

// The cached authenticator pinToken, assigned after a successful validation.
@property NSData *pinToken;
// Keeps the state of the application selection to avoid reselecting the application.
@property BOOL applicationSelected;

@end

@implementation YKFKeyFIDO2Service

- (instancetype)initWithConnectionController:(id<YKFKeyConnectionControllerProtocol>)connectionController {
    YKFAssertAbortInit(connectionController);
    
    self = [super init];
    if (self) {
        self.connectionController = connectionController;
    }
    return self;
}

#pragma mark - Key State

- (void)updateKeyState:(YKFKeyFIDO2ServiceKeyState)keyState {
    if (self.keyState == keyState) {
        return;
    }
    self.keyState = keyState;
}

#pragma mark - Public Requests

- (void)executeGetInfoRequestWithCompletion:(YKFKeyFIDO2ServiceGetInfoCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    YKFKeyFIDO2Request *fido2Request = [[YKFKeyFIDO2Request alloc] init];
    fido2Request.apdu = [[YKFFIDO2GetInfoAPDU alloc] init];
    
    ykf_weak_self();
    [self executeFIDO2Request:fido2Request completion:^(NSData * response, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSData *cborData = [strongSelf cborFromKeyResponsePayloadData:response];
        YKFKeyFIDO2GetInfoResponse *getInfoResponse = [[YKFKeyFIDO2GetInfoResponse alloc] initWithCBORData:cborData];
        
        if (getInfoResponse) {
            completion(getInfoResponse, nil);
        } else {
            completion(nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeINVALID_CBOR]);
        }
    }];
}

- (void)executeVerifyPinRequest:(YKFKeyFIDO2VerifyPinRequest *)request completion:(YKFKeyFIDO2ServiceCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(request.pin);
    YKFParameterAssertReturn(completion);

    [self clearUserVerification];
    
    ykf_weak_self();
    [self executeGetSharedSecretWithCompletion:^(NSData *sharedSecret, YKFCBORMap *cosePlatformPublicKey, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(error);
            return;
        }        
        YKFParameterAssertReturn(sharedSecret)
        YKFParameterAssertReturn(cosePlatformPublicKey)
        
        // Get the authenticator pinToken
        YKFKeyFIDO2ClientPinRequest *clientPinGetPinTokenRequest = [[YKFKeyFIDO2ClientPinRequest alloc] init];
        clientPinGetPinTokenRequest.pinProtocol = 1;
        clientPinGetPinTokenRequest.subCommand = YKFKeyFIDO2ClientPinRequestSubCommandGetPINToken;
        clientPinGetPinTokenRequest.keyAgreement = cosePlatformPublicKey;
        
        NSData *pinData = [request.pin dataUsingEncoding:NSUTF8StringEncoding];
        NSData *pinHash = [[pinData ykf_SHA256] subdataWithRange:NSMakeRange(0, 16)];
        clientPinGetPinTokenRequest.pinHashEnc = [pinHash ykf_aes256EncryptedDataWithKey:sharedSecret];
        
        [strongSelf executeClientPinRequest:clientPinGetPinTokenRequest completion:^(YKFKeyFIDO2ClientPinResponse *response, NSError *error) {
            if (error) {
                completion(error);
                return;
            }
            NSData *encryptedPinToken = response.pinToken;
            if (!encryptedPinToken) {
                completion([YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeINVALID_CBOR]);
                return;
            }
            
            // Cache the pinToken
            strongSelf.pinToken = [response.pinToken ykf_aes256DecryptedDataWithKey:sharedSecret];
            
            if (!strongSelf.pinToken) {
                completion([YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeINVALID_CBOR]);
            } else {
                completion(nil);
            }
        }];
    }];
}

- (void)clearUserVerification {
    if (!self.pinToken && !self.applicationSelected) {
        return;
    }
    
    YKFLogVerbose(@"Clearing FIDO2 Service user verification.");
    
    ykf_weak_self();
    [self.connectionController dispatchOnSequentialQueue:^{
        ykf_safe_strong_self();
        strongSelf.pinToken = nil;
        strongSelf.applicationSelected = NO; // Force also an application re-selection.
    }];
}

- (void)executeChangePinRequest:(nonnull YKFKeyFIDO2ChangePinRequest *)request completion:(nonnull YKFKeyFIDO2ServiceCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(request.pinOld);
    YKFParameterAssertReturn(request.pinNew);
    YKFParameterAssertReturn(completion);

    if (request.pinOld.length < 4 || request.pinNew.length < 4 ||
        request.pinOld.length > 255 || request.pinNew.length > 255) {
        completion([YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodePIN_POLICY_VIOLATION]);
        return;
    }
    
    ykf_weak_self();
    [self executeGetSharedSecretWithCompletion:^(NSData *sharedSecret, YKFCBORMap *cosePlatformPublicKey, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(error);
            return;
        }
        YKFParameterAssertReturn(sharedSecret)
        YKFParameterAssertReturn(cosePlatformPublicKey)
        
        // Change the PIN
        YKFKeyFIDO2ClientPinRequest *changePinRequest = [[YKFKeyFIDO2ClientPinRequest alloc] init];
        NSData *oldPinData = [request.pinOld dataUsingEncoding:NSUTF8StringEncoding];
        NSData *newPinData = [[request.pinNew dataUsingEncoding:NSUTF8StringEncoding] ykf_fido2PaddedPinData];

        changePinRequest.pinProtocol = 1;
        changePinRequest.subCommand = YKFKeyFIDO2ClientPinRequestSubCommandChangePIN;
        changePinRequest.keyAgreement = cosePlatformPublicKey;

        NSData *oldPinHash = [[oldPinData ykf_SHA256] subdataWithRange:NSMakeRange(0, 16)];
        changePinRequest.pinHashEnc = [oldPinHash ykf_aes256EncryptedDataWithKey:sharedSecret];

        changePinRequest.pinEnc = [newPinData ykf_aes256EncryptedDataWithKey:sharedSecret];
        
        NSMutableData *pinAuthData = [NSMutableData dataWithData:changePinRequest.pinEnc];
        [pinAuthData appendData:changePinRequest.pinHashEnc];
        changePinRequest.pinAuth = [[pinAuthData ykf_fido2HMACWithKey:sharedSecret] subdataWithRange:NSMakeRange(0, 16)];
        
        [strongSelf executeClientPinRequest:changePinRequest completion:^(YKFKeyFIDO2ClientPinResponse *response, NSError *error) {
            if (error) {
                completion(error);
                return;
            }
            // clear the cached pin token.
            strongSelf.pinToken = nil;
            completion(nil);
        }];
    }];
}

- (void)executeSetPinRequest:(nonnull YKFKeyFIDO2SetPinRequest *)request completion:(nonnull YKFKeyFIDO2ServiceCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(request.pin);
    YKFParameterAssertReturn(completion);

    if (request.pin.length < 4 || request.pin.length > 255) {
        completion([YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodePIN_POLICY_VIOLATION]);
        return;
    }
    
    ykf_weak_self();
    [self executeGetSharedSecretWithCompletion:^(NSData *sharedSecret, YKFCBORMap *cosePlatformPublicKey, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(error);
            return;
        }
        YKFParameterAssertReturn(sharedSecret)
        YKFParameterAssertReturn(cosePlatformPublicKey)
        
        // Set the new PIN
        YKFKeyFIDO2ClientPinRequest *setPinRequest = [[YKFKeyFIDO2ClientPinRequest alloc] init];
        setPinRequest.pinProtocol = 1;
        setPinRequest.subCommand = YKFKeyFIDO2ClientPinRequestSubCommandSetPIN;
        setPinRequest.keyAgreement = cosePlatformPublicKey;
        
        NSData *pinData = [[request.pin dataUsingEncoding:NSUTF8StringEncoding] ykf_fido2PaddedPinData];
        
        setPinRequest.pinEnc = [pinData ykf_aes256EncryptedDataWithKey:sharedSecret];
        setPinRequest.pinAuth = [[setPinRequest.pinEnc ykf_fido2HMACWithKey:sharedSecret] subdataWithRange:NSMakeRange(0, 16)];
        
        [strongSelf executeClientPinRequest:setPinRequest completion:^(YKFKeyFIDO2ClientPinResponse *response, NSError *error) {
            if (error) {
                completion(error);
                return;
            }
            completion(nil);
        }];
    }];
}

- (void)executeGetPinRetriesWithCompletion:(YKFKeyFIDO2ServiceGetPinRetriesCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    YKFKeyFIDO2ClientPinRequest *pinRetriesRequest = [[YKFKeyFIDO2ClientPinRequest alloc] init];
    pinRetriesRequest.pinProtocol = 1;
    pinRetriesRequest.subCommand = YKFKeyFIDO2ClientPinRequestSubCommandGetRetries;
    
    [self executeClientPinRequest:pinRetriesRequest completion:^(YKFKeyFIDO2ClientPinResponse *response, NSError *error) {
        if (error) {
            completion(0, error);
            return;
        }
        completion(response.retries, nil);
    }];
}

- (void)executeMakeCredentialRequest:(YKFKeyFIDO2MakeCredentialRequest *)request completion:(YKFKeyFIDO2ServiceMakeCredentialCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);
    
    // Attach the PIN authentication if the pinToken is present.
    if (self.pinToken) {
        YKFParameterAssertReturn(request.clientDataHash);
        request.pinProtocol = 1;
        NSData *hmac = [request.clientDataHash ykf_fido2HMACWithKey:self.pinToken];
        request.pinAuth = [hmac subdataWithRange:NSMakeRange(0, 16)];
        if (!request.pinAuth) {
            completion(nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeOTHER]);
        }
    }
    
    YKFFIDO2MakeCredentialAPDU *apdu = [[YKFFIDO2MakeCredentialAPDU alloc] initWithRequest:request];
    if (!apdu) {
        YKFKeySessionError *error = [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeOTHER];
        completion(nil, error);
        return;
    }
    request.apdu = apdu;
    
    ykf_weak_self();
    [self executeFIDO2Request:request completion:^(NSData *response, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSData *cborData = [strongSelf cborFromKeyResponsePayloadData:response];
        YKFKeyFIDO2MakeCredentialResponse *makeCredentialResponse = [[YKFKeyFIDO2MakeCredentialResponse alloc] initWithCBORData:cborData];
        
        if (makeCredentialResponse) {
            completion(makeCredentialResponse, nil);
        } else {
            completion(nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeINVALID_CBOR]);
        }
    }];
}

- (void)executeGetAssertionRequest:(YKFKeyFIDO2GetAssertionRequest *)request completion:(YKFKeyFIDO2ServiceGetAssertionCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);
    
    // Attach the PIN authentication if the pinToken is present.
    if (self.pinToken) {
        YKFParameterAssertReturn(request.clientDataHash);
        request.pinProtocol = 1;
        NSData *hmac = [request.clientDataHash ykf_fido2HMACWithKey:self.pinToken];
        request.pinAuth = [hmac subdataWithRange:NSMakeRange(0, 16)];
        if (!request.pinAuth) {
            completion(nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeOTHER]);
        }
    }
    
    YKFFIDO2GetAssertionAPDU *apdu = [[YKFFIDO2GetAssertionAPDU alloc] initWithRequest:request];
    if (!apdu) {
        YKFKeySessionError *error = [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeOTHER];
        completion(nil, error);
        return;
    }
    request.apdu = apdu;
    
    ykf_weak_self();
    [self executeFIDO2Request:request completion:^(NSData *response, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSData *cborData = [strongSelf cborFromKeyResponsePayloadData:response];
        YKFKeyFIDO2GetAssertionResponse *getAssertionResponse = [[YKFKeyFIDO2GetAssertionResponse alloc] initWithCBORData:cborData];
        
        if (getAssertionResponse) {
            completion(getAssertionResponse, nil);
        } else {
            completion(nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeINVALID_CBOR]);
        }
    }];
}

- (void)executeGetNextAssertionWithCompletion:(YKFKeyFIDO2ServiceGetAssertionCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    YKFKeyFIDO2Request *fido2Request = [[YKFKeyFIDO2Request alloc] init];
    fido2Request.apdu = [[YKFFIDO2GetNextAssertionAPDU alloc] init];
    
    ykf_weak_self();
    [self executeFIDO2Request:fido2Request completion:^(NSData *response, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSData *cborData = [strongSelf cborFromKeyResponsePayloadData:response];
        YKFKeyFIDO2GetAssertionResponse *getAssertionResponse = [[YKFKeyFIDO2GetAssertionResponse alloc] initWithCBORData:cborData];
        
        if (getAssertionResponse) {
            completion(getAssertionResponse, nil);
        } else {
            completion(nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeINVALID_CBOR]);
        }
    }];
}

- (void)executeResetRequestWithCompletion:(YKFKeyFIDO2ServiceCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    YKFKeyFIDO2Request *fido2Request = [[YKFKeyFIDO2Request alloc] init];
    fido2Request.apdu = [[YKFFIDO2ResetAPDU alloc] init];
    
    ykf_weak_self();
    [self executeFIDO2Request:fido2Request completion:^(NSData *response, NSError *error) {
        ykf_strong_self();
        if (!error) {
            [strongSelf clearUserVerification];
        }
        completion(error);
    }];
}

#pragma mark - Private Requests

- (void)executeClientPinRequest:(YKFKeyFIDO2ClientPinRequest *)request completion:(YKFKeyFIDO2ServiceClientPinCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);

    YKFFIDO2ClientPinAPDU *apdu = [[YKFFIDO2ClientPinAPDU alloc] initWithRequest:request];
    if (!apdu) {
        YKFKeySessionError *error = [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeOTHER];
        completion(nil, error);
        return;
    }
    request.apdu = apdu;
    
    ykf_weak_self();
    [self executeFIDO2Request:request completion:^(NSData *response, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSData *cborData = [strongSelf cborFromKeyResponsePayloadData:response];
        YKFKeyFIDO2ClientPinResponse *clientPinResponse = nil;
        
        // In case of Set/Change PIN no CBOR payload is returned.
        if (cborData.length) {
            clientPinResponse = [[YKFKeyFIDO2ClientPinResponse alloc] initWithCBORData:cborData];
        }
        
        if (clientPinResponse) {
            completion(clientPinResponse, nil);
        } else {
            if (cborData.length) {
                completion(nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeINVALID_CBOR]);
            } else {
                completion(nil, nil);
            }
        }
    }];
}

- (void)executeGetSharedSecretWithCompletion:(YKFKeyFIDO2ServiceClientPinSharedSecretCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    // If there is a cached user verification?
    
    ykf_weak_self();
    [self.connectionController dispatchOnSequentialQueue:^{
        ykf_safe_strong_self();
        
        // Generate the platform key.
        YKFFIDO2PinAuthKey *platformKey = [[YKFFIDO2PinAuthKey alloc] init];
        if (!platformKey) {
            completion(nil, nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeOTHER]);
            return;
        }
        YKFCBORMap *cosePlatformPublicKey = platformKey.cosePublicKey;
        if (!cosePlatformPublicKey) {
            completion(nil, nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeOTHER]);
            return;
        }
        
        // Get the authenticator public key.
        YKFKeyFIDO2ClientPinRequest *clientPinKeyAgreementRequest = [[YKFKeyFIDO2ClientPinRequest alloc] init];
        clientPinKeyAgreementRequest.pinProtocol = 1;
        clientPinKeyAgreementRequest.subCommand = YKFKeyFIDO2ClientPinRequestSubCommandGetKeyAgreement;
        clientPinKeyAgreementRequest.keyAgreement = cosePlatformPublicKey;
        
        [strongSelf executeClientPinRequest:clientPinKeyAgreementRequest completion:^(YKFKeyFIDO2ClientPinResponse *response, NSError *error) {
            if (error) {
                completion(nil, nil, error);
                return;
            }
            NSDictionary *authenticatorKeyData = response.keyAgreement;
            if (!authenticatorKeyData) {
                completion(nil, nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeINVALID_CBOR]);
                return;
            }
            YKFFIDO2PinAuthKey *authenticatorKey = [[YKFFIDO2PinAuthKey alloc] initWithCosePublicKey:authenticatorKeyData];
            if (!authenticatorKey) {
                completion(nil, nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeINVALID_CBOR]);
                return;
            }
            
            // Generate the shared secret.
            NSData *sharedSecret = [platformKey sharedSecretWithAuthKey:authenticatorKey];
            if (!sharedSecret) {
                completion(nil, nil, [YKFKeyFIDO2Error errorWithCode:YKFKeyFIDO2ErrorCodeOTHER]);
                return;
            }
            sharedSecret = [sharedSecret ykf_SHA256];
            
            // Success
            completion(sharedSecret, cosePlatformPublicKey, nil);
        }];
    }];
}

#pragma mark - Application selection

- (void)selectFIDO2ApplicationWithCompletion:(void (^)(NSError *))completion {
    YKFParameterAssertReturn(completion);
    
    if (self.applicationSelected) {
        completion(nil);
        return;
    }
    
    YKFAPDU *selectFIDO2ApplicationAPDU = [[YKFSelectFIDO2ApplicationAPDU alloc] init];
    
    ykf_weak_self();
    [self.connectionController execute:selectFIDO2ApplicationAPDU
                         configuration:[YKFKeyCommandConfiguration fastCommandCofiguration]
                            completion:^(NSData *result, NSError *error, NSTimeInterval executionTime) {
        ykf_safe_strong_self();
        NSError *returnedError = nil;
        
        if (error) {
            returnedError = error;
        } else {
            int statusCode = [strongSelf statusCodeFromKeyResponse: result];
            switch (statusCode) {
                case YKFKeyAPDUErrorCodeNoError:
                    break;
                    
                case YKFKeyAPDUErrorCodeMissingFile:
                    returnedError = [YKFKeySessionError errorWithCode:YKFKeySessionErrorMissingApplicationCode];
                    break;
                    
                default:
                    returnedError = [YKFKeySessionError errorWithCode:statusCode];
            }
        }

        if (!returnedError) {
            strongSelf.applicationSelected = YES;
        }
        completion(returnedError);
    }];
}

#pragma mark - Request Execution

- (void)executeFIDO2Request:(YKFKeyFIDO2Request *)request completion:(YKFKeyFIDO2ServiceResultCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);
    
    [self.delegate keyService:self willExecuteRequest:request];
    
    [self updateKeyState:YKFKeyFIDO2ServiceKeyStateProcessingRequest];
    
    ykf_weak_self();
    [self selectFIDO2ApplicationWithCompletion:^(NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            [strongSelf updateKeyState:YKFKeyFIDO2ServiceKeyStateIdle];
            completion(nil, error);
            return;
        }
        [strongSelf executeFIDO2RequestWithoutApplicationSelection:request completion:completion];
    }];
}

- (void)executeFIDO2RequestWithoutApplicationSelection:(YKFKeyFIDO2Request *)request completion:(YKFKeyFIDO2ServiceResultCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);
    
    ykf_weak_self();
    [self.connectionController execute:request.apdu completion:^(NSData *result, NSError *error, NSTimeInterval executionTime) {
        ykf_safe_strong_self();
        
        if (error) {
            if (error.code == YKFKeyFIDO2ErrorCodeTIMEOUT) {
                strongSelf.applicationSelected = NO;
            }
            
            [strongSelf updateKeyState:YKFKeyFIDO2ServiceKeyStateIdle];
            completion(nil, error);
            return;
        }
        
        UInt16 statusCode = [strongSelf statusCodeFromKeyResponse: result];
        
        switch (statusCode) {
            case YKFKeyAPDUErrorCodeNoError: {
                UInt8 fido2Error = [strongSelf errorCodeFromKeyResponsePayloadData:result];
                
                if (fido2Error != YKFKeyFIDO2ErrorCodeSUCCESS) {
                    completion(nil, [YKFKeyFIDO2Error errorWithCode:fido2Error]);
                } else {
                    completion(result, nil);
                }
                [strongSelf updateKeyState:YKFKeyFIDO2ServiceKeyStateIdle];
            }
            break;
                
            case YKFKeyAPDUErrorCodeFIDO2TouchRequired: {
                [strongSelf handleTouchRequired:request completion:completion];
            }
            break;
                
            case YKFKeyAPDUErrorCodeInsNotSupported: {
                [strongSelf updateKeyState:YKFKeyFIDO2ServiceKeyStateIdle];
                completion(nil, [YKFKeySessionError errorWithCode:YKFKeySessionErrorMissingApplicationCode]);
            }
            break;
                
            default: {
                [strongSelf updateKeyState:YKFKeyFIDO2ServiceKeyStateIdle];
                completion(nil, [YKFKeyFIDO2Error errorWithCode:statusCode]);
            }
        }
    }];
}

#pragma mark - YKFKeyServiceProtocol

- (void)keyService:(YKFKeyService *)service willExecuteRequest:(YKFKeyRequest *)request {
    if (!service || (service == self)) {
        return;
    }
    [self clearUserVerification];
}

#pragma mark - Helpers

- (UInt8)errorCodeFromKeyResponsePayloadData:(NSData *)response {
    NSData *responsePayload = [self dataFromKeyResponse:response];
    YKFAssertReturnValue(responsePayload.length >= 1, @"Cannot extract FIDO2 error code from the key response.", YKFKeyFIDO2ErrorCodeOTHER);
    
    UInt8 *payloadBytes = (UInt8 *)responsePayload.bytes;
    return payloadBytes[0];
}

- (NSData *)cborFromKeyResponsePayloadData:(NSData *)response {
    NSData *responsePayload = [self dataFromKeyResponse:response];
    YKFAssertReturnValue(responsePayload.length >= 1, @"Cannot extract FIDO2 cbor from the key response.", nil);
    
    // discard the error byte
    return [responsePayload subdataWithRange:NSMakeRange(1, responsePayload.length - 1)];
}

- (void)handleTouchRequired:(YKFKeyFIDO2Request *)request completion:(YKFKeyFIDO2ServiceResultCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);
    
    if (![request shouldRetry]) {
        YKFKeySessionError *timeoutError = [YKFKeySessionError errorWithCode:YKFKeySessionErrorTouchTimeoutCode];
        completion(nil, timeoutError);

        [self updateKeyState:YKFKeyFIDO2ServiceKeyStateIdle];
        return;
    }
    
    [self updateKeyState:YKFKeyFIDO2ServiceKeyStateTouchKey];
    request.retries += 1;

    ykf_weak_self();
    [self.connectionController dispatchOnSequentialQueue:^{
        ykf_safe_strong_self();
        
        YKFKeyFIDO2Request *retryRequest = [[YKFKeyFIDO2Request alloc] init];
        retryRequest.retries = request.retries;
        retryRequest.apdu = [[YKFFIDO2TouchPoolingAPDU alloc] init];
        
        [strongSelf executeFIDO2RequestWithoutApplicationSelection:retryRequest completion:completion];
    }
    delay:request.retryTimeInterval];
}

@end
