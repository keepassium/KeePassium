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

#import "YKFKeyOATHService.h"
#import "YKFKeyOATHService+Private.h"
#import "YKFKeyService+Private.h"
#import "YKFAccessoryConnectionController.h"
#import "YKFKeyOATHError.h"
#import "YKFKeyAPDUError.h"
#import "YKFOATHCredentialValidator.h"
#import "YKFLogger.h"
#import "YKFKeyCommandConfiguration.h"
#import "YKFBlockMacros.h"
#import "YKFAssert.h"

#import "YKFSelectOATHApplicationAPDU.h"
#import "YKFOATHSendRemainingAPDU.h"
#import "YKFOATHSetCodeAPDU.h"
#import "YKFOATHValidateAPDU.h"

#import "YKFKeySessionError+Private.h"
#import "YKFKeyOATHRequest+Private.h"

#import "YKFNSDataAdditions.h"
#import "YKFNSDataAdditions+Private.h"

#import "YKFKeyOATHListRequest.h"
#import "YKFKeyOATHResetRequest.h"
#import "YKFKeyOATHCalculateAllRequest.h"
#import "YKFKeyOATHCalculateAllRequest+Private.h"
#import "YKFKeyOATHSelectApplicationResponse.h"
#import "YKFKeyOATHValidateResponse.h"
#import "YKFKeyOATHCalculateAllResponse.h"

#import "YKFKeyOATHCalculateResponse+Private.h"
#import "YKFKeyOATHListResponse+Private.h"
#import "YKFKeyOATHCalculateAllResponse+Private.h"
#import "YKFKeyOATHCalculateRequest+Private.h"
#import "YKFAPDU+Private.h"

static const NSTimeInterval YKFKeyOATHServiceTimeoutThreshold = 10; // seconds

typedef void (^YKFKeyOATHServiceResultCompletionBlock)(NSData* _Nullable  result, NSError* _Nullable error);

@interface YKFKeyOATHService()

@property (nonatomic) id<YKFKeyConnectionControllerProtocol> connectionController;

/*
 In case of OATH, the reselection of the application leads to the loss of authentication (if any). To avoid
 this the select application response is cached to avoid reselecting the applet. If the request fails with
 timeout the cache gets invalidated to allow again the following requests to select the application again.
 */
@property (nonatomic) YKFKeyOATHSelectApplicationResponse *cachedSelectApplicationResponse;

@end

@implementation YKFKeyOATHService

- (instancetype)initWithConnectionController:(id<YKFKeyConnectionControllerProtocol>)connectionController {
    YKFAssertAbortInit(connectionController);
    
    self = [super init];
    if (self) {
        self.connectionController = connectionController;
    }
    return self;
}

#pragma mark - Credential Add/Delete

- (void)executePutRequest:(YKFKeyOATHPutRequest *)request completion:(YKFKeyOATHServiceCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);
    
    YKFKeySessionError *credentialError = [YKFOATHCredentialValidator validateCredential:request.credential includeSecret:YES];
    if (credentialError) {
        completion(credentialError);
    }
    
    [self executeOATHRequest:request completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        // No result except status code
        completion(error);
    }];
}

- (void)executeDeleteRequest:(YKFKeyOATHDeleteRequest *)request completion:(YKFKeyOATHServiceCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);

    YKFKeySessionError *credentialError = [YKFOATHCredentialValidator validateCredential:request.credential includeSecret:NO];
    if (credentialError) {
        completion(credentialError);
    }
    
    [self executeOATHRequest:request completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        // No result except status code
        completion(error);
    }];
}

#pragma mark - Credential Calculation

- (void)executeCalculateRequest:(YKFKeyOATHCalculateRequest *)request completion:(YKFKeyOATHServiceCalculateCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);
    
    YKFKeySessionError *credentialError = [YKFOATHCredentialValidator validateCredential:request.credential includeSecret:NO];
    if (credentialError) {
        completion(nil, credentialError);
    }

    [self executeOATHRequest:request completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        YKFKeyOATHCalculateResponse *response = [[YKFKeyOATHCalculateResponse alloc] initWithKeyResponseData:result
                                                                                             requestTimetamp:request.timestamp
                                                                                               requestPeriod:request.credential.period];
        if (!response) {
            completion(nil, [YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeBadCalculationResponse]);
            return;
        }
        
        completion(response, nil);
    }];
}

- (void)executeCalculateAllRequestWithCompletion:(YKFKeyOATHServiceCalculateAllCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    YKFKeyOATHCalculateAllRequest *request = [[YKFKeyOATHCalculateAllRequest alloc] init];
    
    [self executeOATHRequest:request completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }        
        YKFKeyOATHCalculateAllResponse *response = [[YKFKeyOATHCalculateAllResponse alloc] initWithKeyResponseData:result
                                                                                                   requestTimetamp:request.timestamp];
        if (!response) {
            completion(nil, [YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeBadCalculateAllResponse]);
            return;
        }
        
        completion(response, nil);
    }];
}

#pragma mark - Credential Listing

- (void)executeListRequestWithCompletion:(YKFKeyOATHServiceListCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    YKFKeyOATHListRequest *request = [[YKFKeyOATHListRequest alloc] init];
    
    [self executeOATHRequest:request completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        YKFKeyOATHListResponse *response = [[YKFKeyOATHListResponse alloc] initWithKeyResponseData:result];
        if (!response) {
            completion(nil, [YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeBadListResponse]);
            return;
        }
        
        completion(response, nil);
    }];
}

#pragma mark - Reset

- (void)executeResetRequestWithCompletion:(YKFKeyOATHServiceCompletionBlock)completion {
    YKFParameterAssertReturn(completion);
    
    YKFKeyOATHResetRequest *request = [[YKFKeyOATHResetRequest alloc] init];
    
    ykf_weak_self();
    [self executeOATHRequest:request completion:^(NSData * _Nullable result, NSError * _Nullable error) {
        ykf_safe_strong_self();
        if (error) {
            completion(error);
            return;
        }
        strongSelf.cachedSelectApplicationResponse = nil;
        completion(nil);
    }];
}

#pragma mark - OATH Authentication

- (void)executeSetCodeRequest:(YKFKeyOATHSetCodeRequest *)request completion:(YKFKeyOATHServiceCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);

    // This request does not reuse the select applet to get the salt for building the APDU and not ending in error.
    ykf_weak_self();
    [self selectOATHApplicationWithCompletion:^(YKFKeyOATHSelectApplicationResponse *response, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(error);
            return;
        }
        
        // Get the salt
        if (!response.selectID) {
            completion([YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeBadApplicationSelectionResponse]);
            return;
        }
        
        // Build the request APDU with the select ID salt
        request.apdu = [[YKFOATHSetCodeAPDU alloc] initWithRequest:request salt:response.selectID];
        
        [strongSelf executeOATHRequestWithoutApplicationSelection:request completion:^(NSData * _Nullable result, NSError * _Nullable error) {
            if (error) {
                completion(error);
                return;
            }
            completion(nil);
        }];
    }];
}

- (void)executeValidateRequest:(YKFKeyOATHValidateRequest *)request completion:(YKFKeyOATHServiceCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);

    // This request does not reuse the select applet to get the salt for building the APDU and not ending in error.
    ykf_weak_self();
    [self selectOATHApplicationWithCompletion:^(YKFKeyOATHSelectApplicationResponse *response, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(error);
            return;
        }
        
        // Get the salt
        if (!response.selectID || !response.challenge) {
            completion([YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeBadApplicationSelectionResponse]);
            return;
        }
        
        // Build the request APDU with the select ID salt
        request.apdu = [[YKFOATHValidateAPDU alloc] initWithRequest:request challenge:response.challenge salt:response.selectID];
        
        [strongSelf executeOATHRequestWithoutApplicationSelection:request completion:^(NSData * _Nullable result, NSError * _Nullable error) {
            if (error) {
                if (error.code == YKFKeyAPDUErrorCodeWrongData) {
                    completion([YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeWrongPassword]);
                } else {
                    completion(error);
                }
                return;
            }
            
            YKFKeyOATHValidateResponse *validateResponse = [[YKFKeyOATHValidateResponse alloc] initWithResponseData:result];
            if (!validateResponse) {
                completion([YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeBadValidationResponse]);
                return;
            }
            NSData *expectedApduData = ((YKFOATHValidateAPDU *)request.apdu).expectedChallengeData;
            if (![validateResponse.response isEqualToData:expectedApduData]) {
                completion([YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeBadValidationResponse]);
                return;
            }
            
            completion(nil);
        }];
    }];
}

#pragma mark - Request Execution

- (void)executeOATHRequest:(YKFKeyOATHRequest *)request completion:(YKFKeyOATHServiceResultCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);

    [self.delegate keyService:self willExecuteRequest:request];
    
    ykf_weak_self();
    [self selectOATHApplicationWithCompletion:^(YKFKeyOATHSelectApplicationResponse *response, NSError *error) {
        ykf_safe_strong_self();
        if (error) {
            completion(nil, error);
            return;
        }        
        [strongSelf executeOATHRequestWithoutApplicationSelection:request completion:completion];
    }];
}

- (void)executeOATHRequestWithoutApplicationSelection:(YKFKeyOATHRequest *)request completion:(YKFKeyOATHServiceResultCompletionBlock)completion {
    YKFParameterAssertReturn(request);
    YKFParameterAssertReturn(completion);

    __block __weak YKFKeyConnectionControllerCommandResponseBlock weakBlock; // recursive block
    YKFKeyConnectionControllerCommandResponseBlock block;
    
    // Used for chained responses
    __block NSMutableData *responseDataBuffer = [[NSMutableData alloc] init];
    
    ykf_weak_self();
    weakBlock = block = ^(NSData *result, NSError *error, NSTimeInterval executionTime) {
        ykf_safe_strong_self();
        
        __strong YKFKeyConnectionControllerCommandResponseBlock strongBlock = weakBlock;
        YKFAssertReturn(strongBlock, @"Recursive block failure.");
        
        if (error) {
            // Clear the select cache when the resonse is timing out.
            if (error.code == YKFKeySessionErrorReadTimeoutCode) {
                strongSelf.cachedSelectApplicationResponse = nil;
            }
            completion(nil, error);
            return;
        }
        YKFAssertReturn(result != nil, @"Invalid OATH request execution result value on success.");

        NSData *responseData = [self dataFromKeyResponse:result];
        [responseDataBuffer appendData:responseData];
        
        int statusCode = [strongSelf statusCodeFromKeyResponse: result];
        int shortStatusCode = [strongSelf shortStatusCodeFromStatusCode:statusCode];
        
        if (shortStatusCode == YKFKeyAPDUErrorCodeMoreData) {
            YKFLogInfo(@"Key has more data to send. Requesting for remaining data...");            
            
            // Queue a new request recursively
            YKFOATHSendRemainingAPDU *sendRemainingDataAPDU = [[YKFOATHSendRemainingAPDU alloc] init];
            [strongSelf.connectionController execute:sendRemainingDataAPDU completion:strongBlock];
            return;
        }
        
        switch (statusCode) {
            case YKFKeyAPDUErrorCodeNoError:
                completion(responseDataBuffer, nil);
                break;
            
            case YKFKeyAPDUErrorCodeAuthenticationRequired:
                if (executionTime < YKFKeyOATHServiceTimeoutThreshold) {
                    strongSelf.cachedSelectApplicationResponse = nil; // Clear the cache to allow the application selection again.
                    completion(nil, [YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeAuthenticationRequired]);
                } else {
                    completion(nil, [YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeTouchTimeout]);
                }
                break;
                
            // Errors - The status code is the error. The key doesn't send any other information.
            default: {
                YKFKeySessionError *connectionError = [YKFKeySessionError errorWithCode:statusCode];
                completion(nil, connectionError);
            }
        }
    };
    [self.connectionController execute:request.apdu completion:block];
}

#pragma mark - Application Selection

- (void)selectOATHApplicationWithCompletion:(void (^)(YKFKeyOATHSelectApplicationResponse* _Nullable, NSError* _Nullable))completion {
    YKFAPDU *selectOATHApplicationAPDU = [[YKFSelectOATHApplicationAPDU alloc] init];
    
    // Return cached response if available.
    if (self.cachedSelectApplicationResponse) {
        completion(self.cachedSelectApplicationResponse, nil);
        return;
    }
    
    ykf_weak_self();
    [self.connectionController execute:selectOATHApplicationAPDU
                         configuration:[YKFKeyCommandConfiguration fastCommandCofiguration]
                            completion:^(NSData *result, NSError *error, NSTimeInterval executionTime) {
        ykf_safe_strong_self();
        
        if (error) {
            completion(nil, error);
            return;
        }
        
        int statusCode = [strongSelf statusCodeFromKeyResponse: result];
        switch (statusCode) {
            case YKFKeyAPDUErrorCodeNoError: {
                    NSData *responseData = [self dataFromKeyResponse:result];
                    YKFKeyOATHSelectApplicationResponse *response = [[YKFKeyOATHSelectApplicationResponse alloc] initWithResponseData:responseData];
                    if (response) {
                        // Cache the response.
                        strongSelf.cachedSelectApplicationResponse = response;
                        completion(response, nil);
                    } else {
                        completion(nil, [YKFKeyOATHError errorWithCode:YKFKeyOATHErrorCodeBadApplicationSelectionResponse]);
                    }
                }
                break;
                
            case YKFKeyAPDUErrorCodeMissingFile:
                completion(nil, [YKFKeySessionError errorWithCode:YKFKeySessionErrorMissingApplicationCode]);
                break;
                
            default:
                completion(nil, [YKFKeySessionError errorWithCode:statusCode]);
        }
    }];
}

#pragma mark - YKFKeyServiceProtocol

- (void)keyService:(YKFKeyService *)service willExecuteRequest:(YKFKeyRequest *)request {
    if (!service || (service == self)) {
        return;
    }
    if (!self.cachedSelectApplicationResponse) {
        return;
    }
    
    YKFLogVerbose(@"Clearing OATH Service application selection.");
    
    self.cachedSelectApplicationResponse = nil;
}

#pragma mark - Test Helpers

- (void)invalidateApplicationSelectionCache {
    self.cachedSelectApplicationResponse = nil;
}

@end
