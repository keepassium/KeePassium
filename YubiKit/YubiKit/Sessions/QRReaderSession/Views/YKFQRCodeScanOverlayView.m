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

#import "YKFQRCodeScanOverlayView.h"
#import "YubiKitExternalLocalization.h"
#import "YubiKitManager.h"
#import "UIWindowAdditions.h"

@interface YKFQRCodeScanOverlayView()

@property (nonatomic) UIButton *dismissButton;
@property (nonatomic) UILabel *scanHintLabel;
@property (nonatomic) UILabel *cameraPermissionLabel;

@end

@implementation YKFQRCodeScanOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupControls];
    }
    return self;
}

- (void)showCameraPermissionsNotGranted {
    self.cameraPermissionLabel.hidden = NO;
    self.scanHintLabel.hidden = YES;
}

#pragma mark - Actions

- (void)dismissButtonDidPress:(id)sender {
    [self.delegate qrCodeScanControlsOverlayViewDidDismiss:self];
}

#pragma mark - Localization

- (void)setupLocalization {
    [self.dismissButton setTitle:YubiKitExternalLocalization.qrCodeScanDismissButtonTitle forState:UIControlStateNormal];
    self.scanHintLabel.text = YubiKitExternalLocalization.qrCodeScanHintMessage;
    self.cameraPermissionLabel.text = YubiKitExternalLocalization.qrCodeScanCameraNotAvailableMessage;
}

#pragma mark - UI setup

- (void)setupControls {
    self.backgroundColor = [UIColor clearColor];
    [self setupCameraPermissionLabel];
    [self setupDismissButton];
    [self setupScanHintLabel];
}

- (void)setupDismissButton {
    self.dismissButton = [[UIButton alloc] initWithFrame:CGRectZero];
    [self.dismissButton addTarget:self action:@selector(dismissButtonDidPress:) forControlEvents:UIControlEventTouchUpInside];
    self.dismissButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.dismissButton.backgroundColor = [UIColor blackColor];
    self.dismissButton.alpha = 0.8;
    self.dismissButton.layer.cornerRadius = 18;
    
    [self addSubview: self.dismissButton];
    
    UIEdgeInsets safeAreaInsets = UIApplication.sharedApplication.keyWindow.ykf_safeAreaInsets;
    
    NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self.dismissButton attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationEqual toItem:nil
                                                             attribute:NSLayoutAttributeWidth multiplier:1 constant:200];
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self.dismissButton attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual toItem:nil
                                                              attribute:NSLayoutAttributeHeight multiplier:1 constant:36];
    NSLayoutConstraint *horizontalAlign = [NSLayoutConstraint constraintWithItem:self.dismissButton attribute:NSLayoutAttributeCenterX
                                                                       relatedBy:NSLayoutRelationEqual toItem:self
                                                                       attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:self.dismissButton attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual toItem:self
                                                              attribute:NSLayoutAttributeBottom multiplier:1 constant: -(30 + safeAreaInsets.bottom)];
    
    NSArray *constraints = [[NSArray alloc] initWithObjects:width, height, horizontalAlign, bottom, nil];
    [self addConstraints:constraints];
}

- (void)setupScanHintLabel {
    UIEdgeInsets safeAreaInsets = UIApplication.sharedApplication.keyWindow.ykf_safeAreaInsets;
    
    UIView *hintBackgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    hintBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    hintBackgroundView.backgroundColor = [UIColor blackColor];
    hintBackgroundView.alpha = 0.5;
    
    [self addSubview:hintBackgroundView];
    
    NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:hintBackgroundView attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationEqual toItem:nil
                                                              attribute:NSLayoutAttributeHeight multiplier:1 constant:120 + safeAreaInsets.top];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:hintBackgroundView attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual toItem:self
                                                           attribute:NSLayoutAttributeTop multiplier:1 constant:0];
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:hintBackgroundView attribute:NSLayoutAttributeLeading
                                                            relatedBy:NSLayoutRelationEqual toItem:self
                                                            attribute:NSLayoutAttributeLeading multiplier:1 constant:0];
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:hintBackgroundView attribute:NSLayoutAttributeTrailing
                                                            relatedBy:NSLayoutRelationEqual toItem:self
                                                            attribute:NSLayoutAttributeTrailing multiplier:1 constant:0];
    
    NSArray *constraints = [[NSArray alloc] initWithObjects:height, top, left, right, nil];
    [self addConstraints:constraints];
    
    self.scanHintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.scanHintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.scanHintLabel.textColor = [UIColor whiteColor];
    self.scanHintLabel.textAlignment = NSTextAlignmentCenter;
    self.scanHintLabel.numberOfLines = 3;
    
    [self addSubview:self.scanHintLabel];
    
    height = [NSLayoutConstraint constraintWithItem:self.scanHintLabel attribute:NSLayoutAttributeHeight
                                          relatedBy:NSLayoutRelationEqual toItem:nil
                                          attribute:NSLayoutAttributeHeight multiplier:1 constant:120];
    top = [NSLayoutConstraint constraintWithItem:self.scanHintLabel attribute:NSLayoutAttributeTop
                                       relatedBy:NSLayoutRelationEqual toItem:self
                                       attribute:NSLayoutAttributeTop multiplier:1 constant:safeAreaInsets.top];
    left = [NSLayoutConstraint constraintWithItem:self.scanHintLabel attribute:NSLayoutAttributeLeading
                                        relatedBy:NSLayoutRelationEqual toItem:self
                                        attribute:NSLayoutAttributeLeading multiplier:1 constant:0];
    right = [NSLayoutConstraint constraintWithItem:self.scanHintLabel attribute:NSLayoutAttributeTrailing
                                         relatedBy:NSLayoutRelationEqual toItem:self
                                         attribute:NSLayoutAttributeTrailing multiplier:1 constant:0];
    
    constraints = [[NSArray alloc] initWithObjects:height, top, left, right, nil];
    [self addConstraints:constraints];
}

- (void)setupCameraPermissionLabel {
    self.cameraPermissionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.cameraPermissionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.cameraPermissionLabel.textColor = [UIColor whiteColor];
    self.cameraPermissionLabel.textAlignment = NSTextAlignmentCenter;
    self.cameraPermissionLabel.numberOfLines = 5;
    self.cameraPermissionLabel.hidden = YES;
    
    [self addSubview:self.cameraPermissionLabel];
    
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:self.cameraPermissionLabel attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual toItem:self
                                                           attribute:NSLayoutAttributeTop multiplier:1 constant:0];
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:self.cameraPermissionLabel attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual toItem:self
                                                              attribute:NSLayoutAttributeBottom multiplier:1 constant:-20];
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:self.cameraPermissionLabel attribute:NSLayoutAttributeLeading
                                                            relatedBy:NSLayoutRelationEqual toItem:self
                                                            attribute:NSLayoutAttributeLeading multiplier:1 constant:30];
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:self.cameraPermissionLabel attribute:NSLayoutAttributeTrailing
                                                             relatedBy:NSLayoutRelationEqual toItem:self
                                                             attribute:NSLayoutAttributeTrailing multiplier:1 constant:-30];
    
    NSArray *constraints = [[NSArray alloc] initWithObjects:top, bottom, left, right, nil];
    [self addConstraints:constraints];
}

@end
