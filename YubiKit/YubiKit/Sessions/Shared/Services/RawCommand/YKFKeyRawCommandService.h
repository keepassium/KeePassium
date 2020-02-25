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
#import "YKFAPDU.h"

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name Raw Command Service Response Blocks
 * ---------------------------------------------------------------------------------------------------------------------
 */

/*!
 @abstract
    Response block for [executeCommand:completion:] which provides the result for the execution
    of the raw request.
 
 @param response
    The response of the request when it was successful. In case of error this parameter is nil.
 
 @param error
    In case of a failed request this parameter contains the error. If the request was successful
    this parameter is nil.
 */
typedef void (^YKFKeyRawCommandServiceResponseBlock)
    (NSData* _Nullable response, NSError* _Nullable error);

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name Raw Command Service Protocol
 * ---------------------------------------------------------------------------------------------------------------------
 */

NS_ASSUME_NONNULL_BEGIN

/*!
 @abstract
    Defines the interface for YKFKeyRawCommandService.
 */
@protocol YKFKeyRawCommandServiceProtocol<NSObject>

/*!
 @method executeCommand:completion:
 
 @abstract
    Sends to the key a raw APDU command to be executed by the key. The request is performed asynchronously
    on a background execution queue.
 
 @param apdu
    The APDU command to be executed.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread.
 
 @note:
    This method is thread safe and can be invoked from any thread (main or a background thread).
 */
- (void)executeCommand:(YKFAPDU *)apdu completion:(YKFKeyRawCommandServiceResponseBlock)completion;

/*!
 @method executeSyncCommand:completion:
 
 @abstract
    Sends synchronously to the key a raw APDU command to be executed. Calling this method will block the
    execution of the calling thread until the request is fulfilled by the key or if it's timing out.
 
 @discussion
    This method should never be called from the main thread. If the application calls
    it from the main thread, an assertion will be fired in debug configurations.
 
 @param apdu
    The APDU command to be executed.
 
 @param completion
    The response block which is executed after the request was processed by the key. The completion block
    will be executed on a background thread. After the completion block is executed the calling thread will
    resume its execution.
 */
- (void)executeSyncCommand:(YKFAPDU *)apdu completion:(YKFKeyRawCommandServiceResponseBlock)completion;

@end

NS_ASSUME_NONNULL_END

/**
 * ---------------------------------------------------------------------------------------------------------------------
 * @name Raw Command Service
 * ---------------------------------------------------------------------------------------------------------------------
 */

NS_ASSUME_NONNULL_BEGIN

/*!
 @class YKFKeyRawCommandService
 
 @abstract
    Provides a low level interface to communicate with the YubiKey.
 
 @discussion
    This service provides a low level interface to execute requests agaist the key when other specialized
    services (e.g U2F, OATH etc.) may not be used. While this interface allows for low level interactions
    with the key, it's recommended to use specialized services when available (e.g. if the intention
    is to use U2F, it's better to use the U2F Service provided by the library).
 
    The Raw Command service is mantained by the key session which controls its lifecycle. The application
    must not create one. It has to use only the single shared instance from YKFAccessorySession and sync its
    usage with the session state.
 */
@interface YKFKeyRawCommandService: YKFKeyService<YKFKeyRawCommandServiceProtocol>

/*
 Not available: use only the instance from the YKFAccessorySession.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
