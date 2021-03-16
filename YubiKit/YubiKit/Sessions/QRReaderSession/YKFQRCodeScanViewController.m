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

#import "YKFQRCodeScanViewController.h"
#import "YKFQRCodeScanOverlayView.h"
#import "YKFPermissions.h"
#import "YKFQRCodeScanError.h"
#import "YKFLogger.h"
#import "YKFBlockMacros.h"
#import "YKFDispatch.h"

#import "YKFQRCodeScanError+Errors.h"

@interface YKFQRCodeScanViewController()<AVCaptureMetadataOutputObjectsDelegate, YKFQRCodeScanOverlayViewDelegate>

@property (nonatomic) AVCaptureSession *captureSession;
@property (nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic) id<YKFPermissionsProtocol> permissions;

@property (nonatomic) YKFQRCodeScanOverlayView *controlsOverlayView;

@end

@implementation YKFQRCodeScanViewController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.permissions = [[YKFPermissions alloc] init];
    }
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupViewAppearance];
    [self setupCaptureAndOverlay];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // Dispatch the capture session running on a next runloop to avoid animation hick-ups
    ykf_weak_self();
    ykf_dispatch_block_main(^{
        [weakSelf startCaptureSession];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopCaptureSession];
}

#pragma mark - Status bar

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

#pragma mark - Orientation

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    BOOL frameChanged = !CGRectEqualToRect(self.previewLayer.frame, self.view.layer.bounds);
    if (!frameChanged) {
        return;
    }
    
    self.previewLayer.frame = self.view.layer.bounds;
    [self updateVideoCaptureOrientation];
}

- (void)updateVideoCaptureOrientation {
    AVCaptureConnection *captureConnection = self.previewLayer.connection;
    
    if (!captureConnection || !captureConnection.supportsVideoOrientation) {
        return;
    }
    
    UIDeviceOrientation deviceOrientation = UIDevice.currentDevice.orientation;
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
            captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
            
        case UIDeviceOrientationPortraitUpsideDown:
            captureConnection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
            
        case UIDeviceOrientationLandscapeLeft:
            captureConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
            
        case UIDeviceOrientationLandscapeRight:
            captureConnection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
            
        case UIDeviceOrientationFaceUp:
        case UIDeviceOrientationFaceDown:
        case UIDeviceOrientationUnknown:
            // Do nothing
            break;
    }
}

#pragma mark - Capture session handling

- (void)startCaptureSession {
    BOOL authorized = self.permissions.videoCaptureAuthorizationStatus == YKFPermissionAuthorizationStatusAuthorized;
    if (authorized && !self.captureSession.isRunning) {
        [self updateVideoCaptureOrientation];
        [self.captureSession startRunning];
    }
}

- (void)stopCaptureSession {
    BOOL authorized = self.permissions.videoCaptureAuthorizationStatus == YKFPermissionAuthorizationStatusAuthorized;
    if (authorized && self.captureSession.isRunning) {
        [self.captureSession stopRunning];
    }
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    [self stopCaptureSession];
    
    AVMetadataObject *metadataObject = metadataObjects.firstObject;
    if (!metadataObject) {
        NSError *error = [YKFQRCodeScanError noDataAvailableError];
        [self.delegate qrCodeScanViewController:self didFailWithError:error];
        return;
    }
    
    AVMetadataMachineReadableCodeObject *readableObject = (AVMetadataMachineReadableCodeObject *)metadataObject;
    NSString *payload = readableObject.stringValue;
    if (!payload) {
        NSError *error = [YKFQRCodeScanError noDataAvailableError];
        [self.delegate qrCodeScanViewController:self didFailWithError:error];
        return;
    }
    
    [self.delegate qrCodeScanViewController:self didScanPayload:payload];
    
    YKFLogInfo(@"QR code scanned with value: %@", payload);
}

#pragma mark - UI Setup

- (void)setupViewAppearance {
    self.view.backgroundColor = [UIColor blackColor];
}

- (void)setupCaptureAndOverlay {
    switch (self.permissions.videoCaptureAuthorizationStatus) {
            
        case YKFPermissionAuthorizationStatusAuthorized:
            [self setupQRCodeDetection];
            [self setupControlsOverlay];
        break;
            
        case YKFPermissionAuthorizationStatusNotDetermined: {
            ykf_weak_self();
            [self.permissions requestVideoCaptureAuthorization:^(BOOL granted) {
                ykf_safe_strong_self();
                if (!granted) {
                    ykf_dispatch_block_main(^{
                        [strongSelf setupControlsOverlay];
                        [strongSelf.controlsOverlayView showCameraPermissionsNotGranted];
                    });
                    return;
                }                
                ykf_dispatch_block_main(^{
                    [strongSelf setupQRCodeDetection];
                    [strongSelf setupControlsOverlay];
                    [strongSelf startCaptureSession];
                });
            }];
        }
        break;
            
        case YKFPermissionAuthorizationStatusRestricted:
        case YKFPermissionAuthorizationStatusDenied:
            [self setupControlsOverlay];
            [self.controlsOverlayView showCameraPermissionsNotGranted];
    }
}

- (void)setupQRCodeDetection {
    NSError *error = [self setupCaptureSession];
    if (error) {
        [self.delegate qrCodeScanViewController:self didFailWithError:error];
        return;
    }
    
    error = [self setupQRCodeDetector];
    if (error) {
        [self.delegate qrCodeScanViewController:self didFailWithError:error];
        return;
    }
    
    [self setupPreviewLayer];
}

- (NSError *)setupCaptureSession {
    self.captureSession = [[AVCaptureSession alloc] init];
    
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!captureDevice) {
        return [YKFQRCodeScanError noCameraAvailableError];
    }
    
    NSError *videoInputError;
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&videoInputError];
    if (videoInputError) {
        return [YKFQRCodeScanError unableToCreateCaptureDeviceInputError];
    }
    
    if ([self.captureSession canAddInput:videoInput]) {
        [self.captureSession addInput:videoInput];
        return nil;
    }
    
    return [YKFQRCodeScanError unableToAddDeviceInputError];
}

- (NSError *)setupQRCodeDetector {
    AVCaptureMetadataOutput *metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    if ([self.captureSession canAddOutput:metadataOutput]) {
        [self.captureSession addOutput:metadataOutput];
        [metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
        metadataOutput.metadataObjectTypes = @[AVMetadataObjectTypeQRCode];
        return nil;
    }
    return [YKFQRCodeScanError unableToAddQrDetectorError];
}

- (void)setupPreviewLayer {
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    self.previewLayer.frame = self.view.layer.bounds;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer: self.previewLayer];
}

- (void)setupControlsOverlay {
    self.controlsOverlayView = [[YKFQRCodeScanOverlayView alloc] initWithFrame:self.view.bounds];
    self.controlsOverlayView.delegate = self;
    [self pinViewToEdges:self.controlsOverlayView insets:UIEdgeInsetsZero];
}

#pragma mark - YKFQRCodeScanOverlayViewDelegate

- (void)qrCodeScanControlsOverlayViewDidDismiss:(YKFQRCodeScanOverlayView *)view {
    [self.delegate qrCodeScanViewControllerDidCancel:self];
}

@end
