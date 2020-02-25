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

#import "YKFQRReaderSession.h"
#import "YKFQRCodeScanViewController.h"
#import "YubiKitDeviceCapabilities.h"
#import "YKFAssert.h"

@interface YKFQRReaderSession()<YKFQRCodeScanViewControllerDelegate>

@property (nonatomic) YKFQRCodeScanViewController *scanViewController;
@property (nonatomic, copy) YKFQRCodeResponseBlock qrCodeScanResponseBlock;

@end

@implementation YKFQRReaderSession

#pragma mark - YubiKitManagerProtocol

- (void)scanQrCodeWithPresenter:(UIViewController *)viewController completion:(YKFQRCodeResponseBlock)completion {
    YKFAssertReturn(YubiKitDeviceCapabilities.supportsQRCodeScanning, @"Device does not support QR code scanning.");
    
    self.qrCodeScanResponseBlock = completion;
    self.scanViewController = [[YKFQRCodeScanViewController alloc] init];
    self.scanViewController.delegate = self;
    
    [viewController presentViewController:self.scanViewController animated:YES completion:nil];
}

- (void)dismissQRCodeScanViewController {
    [self.scanViewController dismissViewControllerAnimated:YES completion:nil];
    self.scanViewController = nil;
}

#pragma mark - YKFQRCodeScanViewControllerDelegate

- (void)qrCodeScanViewController:(YKFQRCodeScanViewController *)viewController didFailWithError:(NSError *)error {
    [self dismissQRCodeScanViewController];
    if (self.qrCodeScanResponseBlock) {
        self.qrCodeScanResponseBlock(nil, error);
        self.qrCodeScanResponseBlock = nil;
    }
}

- (void)qrCodeScanViewController:(YKFQRCodeScanViewController *)viewController didScanPayload:(NSString *)payload {
    [self dismissQRCodeScanViewController];
    if (self.qrCodeScanResponseBlock) {
        self.qrCodeScanResponseBlock(payload, nil);
        self.qrCodeScanResponseBlock = nil;
    }
}

- (void)qrCodeScanViewControllerDidCancel:(YKFQRCodeScanViewController *)viewController {
    [self dismissQRCodeScanViewController];
    self.qrCodeScanResponseBlock = nil;
}

@end
