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

#import "YubiKitExternalLocalization.h"

@implementation YubiKitExternalLocalization

static NSString *internalNfcScanAlertMessage = @"Scan your YubiKey";

+ (NSString *)nfcScanAlertMessage {
    return internalNfcScanAlertMessage;
}

+ (void)setNfcScanAlertMessage:(NSString *)nfcScanAlertMessage {
    NSParameterAssert(nfcScanAlertMessage.length);
    internalNfcScanAlertMessage = nfcScanAlertMessage;
}

static NSString *internalQrCodeScanHintMessage = @"Point the camera at the QR Code";

+ (NSString *)qrCodeScanHintMessage {
    return internalQrCodeScanHintMessage;
}

+ (void)setQrCodeScanHintMessage:(NSString *)qrCodeScanHintMessage {
    NSParameterAssert(qrCodeScanHintMessage.length);
    internalQrCodeScanHintMessage = qrCodeScanHintMessage;
}

static NSString *internalQrCodeScanCameraNotAvailableMessage = @"Camera permission is not granted. Please enable it in settings and try again.";

+ (NSString *)qrCodeScanCameraNotAvailableMessage {
    return internalQrCodeScanCameraNotAvailableMessage;
}

+ (void)setQrCodeScanCameraNotAvailableMessage:(NSString *)qrCodeScanCameraNotAvailableMessage {
    NSParameterAssert(qrCodeScanCameraNotAvailableMessage.length);
    internalQrCodeScanCameraNotAvailableMessage = qrCodeScanCameraNotAvailableMessage;
}

static NSString *internalQrCodeScanDismissButtonTitle = @"Dismiss";

+ (NSString *)qrCodeScanDismissButtonTitle {
    return internalQrCodeScanDismissButtonTitle;
}

+ (void)setQrCodeScanDismissButtonTitle:(NSString *)qrCodeScanDismissButtonTitle {
    NSParameterAssert(qrCodeScanDismissButtonTitle.length);
    internalQrCodeScanDismissButtonTitle = qrCodeScanDismissButtonTitle;
}

@end
