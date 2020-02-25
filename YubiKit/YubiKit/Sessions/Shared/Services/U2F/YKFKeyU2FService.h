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
#import "YKFKeyU2FSignRequest.h"
#import "YKFKeyU2FSignResponse.h"
#import "YKFKeyU2FRegisterRequest.h"
#import "YKFKeyU2FRegisterResponse.h"

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name U2F Service Response Blocks
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Response block used by [executeSignRequest:completion:] to provide the result of a sign request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful
    this parameter is nil.
 */
typedef void (^YKFKeyU2FServiceSignCompletionBlock)
    (YKFKeyU2FSignResponse* _Nullable response, NSError* _Nullable error);

/*!
 @abstract
    Response block used by [executeRegisterRequest:completion:] to provide the result of a register request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful this
    parameter is nil.
 */
typedef void (^YKFKeyU2FServiceRegisterCompletionBlock)
    (YKFKeyU2FRegisterResponse* _Nullable response, NSError* _Nullable error);

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name U2F Service Types
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Enumerates the contextual states of the key when performing U2F requests.
 */
typedef NS_ENUM(NSUInteger, YKFKeyU2FServiceKeyState) {
    
    /// The key is not performing any U2F operation.
    YYKFKeyU2FServiceKeyStateIdle,
    
    /// The key is executing an U2F request.
    YKFKeyU2FServiceKeyStateProcessingRequest,
    
    /// The user must touch the key to prove a human presence which allows the key to perform the current
    /// U2F operation.
    YKFKeyU2FServiceKeyStateTouchKey
};

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name U2F Service Protocol
 * ---------------------------------------------------------------------------------------------------------------------
 */

NS_ASSUME_NONNULL_BEGIN

/*!
 @abstract
    Defines the interface for YKFKeyU2FService.
 */
@protocol YKFKeyU2FServiceProtocol<NSObject>

/*!
 @property keyState
 
 @abstract
    This property provides the contextual state of the key when performing U2F requests.
 
 @discussion
    This property is useful for checking the status of an U2F request, when the operation requires the
    user presence. This property is KVO compliant and the application should observe it to ge asynchronous
    state updates of the U2F request.
 
 @note:
    The default behaviour of YubiKit is to always ask for human presence when performing an U2F operation. To detect
    asynchronously the touch state check for YKFKeyU2FServiceKeyStateTouchKey.
 */
@property (nonatomic, assign, readonly) YKFKeyU2FServiceKeyState keyState;

/*!
 @method executeRegisterRequest:completion:
 
 @abstract
    Sends to the key an U2F register request. The request is performed asynchronously on a background execution queue.
 
 @param request
    The request which packs all the required information to perform a registration.
 
 @param completion
    The response block which gets executed after the request was processed by the key. The completion block will be
    executed on a background thread. If the intention is to update the UI, dispatch the results on the main thread
    to avoid an UIKit assertion.
 
 @note:
    This method is thread safe and can be invoked from the main or a background thread.
    The key can execute only one request at a time. If multiple requests are made against the service, they are
    queued in the order they are received and executed sequentially.
 */
- (void)executeRegisterRequest:(YKFKeyU2FRegisterRequest *)request
                    completion:(YKFKeyU2FServiceRegisterCompletionBlock)completion;

/*!
 @method executeRegisterRequest:completion:
 
 @abstract
    Sends to the key an U2F sign request. The request is performed asynchronously on a background execution queue.
 
 @param request
    The request which packs all the required information to perform a signing.
 @param completion
    The response block which gets executed after the request was processed by the key. The completion block will be
    executed on a background thread. If the intention is to update the UI, dispatch the results on the main thread
    to avoid an UIKit assertion.
 
 NOTE:
    This method is thread safe and can be invoked from the main or a background thread.
    The key can execute only one request at a time. If multiple requests are made against the service, they are
    queued in the order they are received and executed sequentially.
 */
- (void)executeSignRequest:(YKFKeyU2FSignRequest *)request
                completion:(YKFKeyU2FServiceSignCompletionBlock)completion;

@end

NS_ASSUME_NONNULL_END

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name U2F Service
 * ---------------------------------------------------------------------------------------------------------------------
 */

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFKeyU2FService
 
 @abstract
    Provides the interface for sending U2F requests to the YubiKey.
 @discussion
    The U2F service is mantained by the key session which controls its lifecycle. The application must not create one.
    It has to use only the single shared instance from YKFAccessorySession and sync its usage with the session state.
 */
@interface YKFKeyU2FService: YKFKeyService<YKFKeyU2FServiceProtocol>

/*
 Not available: use only the shared instance from the YKFAccessorySession.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

/*!
 @constant YKFKeyU2FServiceProtocolKeyStatePropertyKey
 
 @abstract
    Helper property name to setup KVO paths in ObjC. For Swift there is a better built-in language support for
    composing keypaths.
 */
extern NSString* const YKFKeyU2FServiceProtocolKeyStatePropertyKey;

NS_ASSUME_NONNULL_END
