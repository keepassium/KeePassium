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
#import "YKFKeyService.h"
#import "YKFKeyOATHPutRequest.h"
#import "YKFKeyOATHDeleteRequest.h"
#import "YKFKeyOATHCalculateRequest.h"
#import "YKFKeyOATHCalculateResponse.h"
#import "YKFKeyOATHSetCodeRequest.h"
#import "YKFKeyOATHValidateRequest.h"
#import "YKFKeyOATHListResponse.h"
#import "YKFKeyOATHCalculateAllResponse.h"

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name OATH Service Response Blocks
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Response block used by OATH requests which do not provide a result for the request.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful
    this parameter is nil.
 */
typedef void (^YKFKeyOATHServiceCompletionBlock)
    (NSError* _Nullable error);

/*!
 @abstract
    Response block for [executeCalculateRequest:completion:] which provides the result for the execution
    of the Calculate request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.

 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFKeyOATHServiceCalculateCompletionBlock)
    (YKFKeyOATHCalculateResponse* _Nullable response, NSError* _Nullable error);

/*!
 @abstract
    Response block for [executeListRequest:completion:] which provides the result for the execution
    of the List request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFKeyOATHServiceListCompletionBlock)
    (YKFKeyOATHListResponse* _Nullable response, NSError* _Nullable error);

/*!
 @abstract
    Response block for [executeCalculateAllRequest:completion:] which provides the result for the execution
    of the Calculate All request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFKeyOATHServiceCalculateAllCompletionBlock)
    (YKFKeyOATHCalculateAllResponse* _Nullable response, NSError* _Nullable error);

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name OATH Service Protocol
 * ---------------------------------------------------------------------------------------------------------------------
 */

NS_ASSUME_NONNULL_BEGIN

/*!
 @abstract
    Defines the interface for YKFKeyOATHService.
 */
@protocol YKFKeyOATHServiceProtocol<NSObject>

/*!
 @method executePutRequest:completion:
 
 @abstract
    Sends to the key an OATH Put request to add a new credential. The request is performed asynchronously
    on a background execution queue.
 
 @param request
    The request which contains the required information to add a new credential.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note:
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)executePutRequest:(YKFKeyOATHPutRequest *)request
               completion:(YKFKeyOATHServiceCompletionBlock)completion;

/*!
 @method executeDeleteRequest:completion:
 
 @abstract
    Sends to the key an OATH Delete request to remove an existing credential. The request is performed
    asynchronously on a background execution queue.
 
 @param request
    The request which contains the required information to remove a credential.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)executeDeleteRequest:(YKFKeyOATHDeleteRequest *)request
                  completion:(YKFKeyOATHServiceCompletionBlock)completion;

/*!
 @method executeCalculateRequest:completion:
 
 @abstract
    Sends to the key an OATH Calculate request to calculate an existing credential. The request is performed
    asynchronously on a background execution queue.
 
 @param request
    The request which contains the required information to calculate a credential.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)executeCalculateRequest:(YKFKeyOATHCalculateRequest *)request
                     completion:(YKFKeyOATHServiceCalculateCompletionBlock)completion;

/*!
 @method executeCalculateAllRequestWithCompletion:
 
 @abstract
    Sends to the key an OATH Calculate All request to calculate all stored credentials on the key.
    The request is performed asynchronously on a background execution queue.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)executeCalculateAllRequestWithCompletion:(YKFKeyOATHServiceCalculateAllCompletionBlock)completion;

/*!
 @method executeListRequestWithCompletion:
 
 @abstract
    Sends to the key an OATH List request to enumerate all stored credentials on the key.
    The request is performed asynchronously on a background execution queue.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)executeListRequestWithCompletion:(YKFKeyOATHServiceListCompletionBlock)completion;

/*!
 @method executeResetRequestWithCompletion:
 
 @abstract
    Sends to the key an OATH Reset request to reset the OATH application to its default state. This request
    will remove all stored credentials and the authentication, if set. The request is performed asynchronously
    on a background execution queue.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)executeResetRequestWithCompletion:(YKFKeyOATHServiceCompletionBlock)completion;

/*!
 @method executeSetCodeRequest:completion:
 
 @abstract
    Sends to the key an OATH Set Code request to set a PIN on the key OATH application. The request
    is performed asynchronously on a background execution queue.
 
 @param request
    The request which contains the required information to set a PIN on the key OATH application.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)executeSetCodeRequest:(YKFKeyOATHSetCodeRequest *)request
                   completion:(YKFKeyOATHServiceCompletionBlock)completion;

/*!
 @method executeValidateRequest:completion:
 
 @abstract
    Sends to the key an OATH Validate request to authentificate against the OATH application. After authentification
    all subsequent requests can be performed until the key application is deselected, as the result of performing
    another type of request (e.g. U2F) or by unplugging the key from the device. The request is performed
    asynchronously on a background execution queue.
 
 @param request
    The request which contains the required information to validate a PIN on the key OATH application.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. If the intention is to update the UI, dispatch the results
    on the main thread to avoid an UIKit assertion.
 
 @note
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)executeValidateRequest:(YKFKeyOATHValidateRequest *)request
                    completion:(YKFKeyOATHServiceCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name OATH Service
 * ---------------------------------------------------------------------------------------------------------------------
 */

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFKeyOATHService
 
 @abstract
    Provides the interface for executing OATH requests with the key.
@discussion
    The OATH service is mantained by the key session which controls its lifecycle. The application must not
    create one. It has to use only the single shared instance from YKFAccessorySession and sync its usage with
    the session state.
 */
@interface YKFKeyOATHService: YKFKeyService<YKFKeyOATHServiceProtocol>

/*
 Not available: use only the instance from the YKFAccessorySession.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

