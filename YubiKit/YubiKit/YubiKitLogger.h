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

NS_ASSUME_NONNULL_BEGIN
/*!
 @protocol YubiKitLoggerProtocol
 
 @abstract
    Provides the interface for custom logger.
 */
@protocol YubiKitLoggerProtocol <NSObject>

- (void)log:(NSString*) message;

@end

/*!
 @class YubiKitLogger
 
 @abstract
     YubiKitLogger allows the host application to configure a custom logger when the default logger of
     the library is insufficient for the host application.
 
 @note:
    To configure YubiKitLogger set the customLogger property.
 */
@interface YubiKitLogger : NSObject

@property (class, nonatomic, nullable) id<YubiKitLoggerProtocol> customLogger;

@end

NS_ASSUME_NONNULL_END
