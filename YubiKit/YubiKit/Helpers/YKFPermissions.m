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

#import <AVFoundation/AVFoundation.h>
#import "YKFPermissions.h"

@implementation YKFPermissions

@synthesize videoCaptureAuthorizationStatus;

- (YKFPermissionAuthorizationStatus)videoCaptureAuthorizationStatus {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType: AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusNotDetermined:
            return YKFPermissionAuthorizationStatusNotDetermined;
        case AVAuthorizationStatusDenied:
            return YKFPermissionAuthorizationStatusDenied;
        case AVAuthorizationStatusRestricted:
            return YKFPermissionAuthorizationStatusRestricted;
        case AVAuthorizationStatusAuthorized:
            return YKFPermissionAuthorizationStatusAuthorized;
    }
}

- (void)requestVideoCaptureAuthorization:(void (^_Nonnull)(BOOL))completion {
    YKFPermissionAuthorizationStatus status = self.videoCaptureAuthorizationStatus;
    if (status == YKFPermissionAuthorizationStatusAuthorized) {
        completion(YES);
        return;
    }
    if (status != YKFPermissionAuthorizationStatusNotDetermined) {
        completion(NO);
        return;
    }
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:completion];
}

@end
