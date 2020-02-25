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

#import "YKFViewController.h"
#import "UIWindowAdditions.h"

@implementation YKFViewController

- (void)pinViewToEdges:(UIView*)view insets:(UIEdgeInsets)insets {
    view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:view];
    
    NSLayoutConstraint *left = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeading
                                                            relatedBy:NSLayoutRelationEqual toItem:self.view
                                                            attribute:NSLayoutAttributeLeading multiplier:1 constant:insets.left];
    NSLayoutConstraint *right = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTrailing
                                                             relatedBy:NSLayoutRelationEqual toItem:self.view
                                                             attribute:NSLayoutAttributeTrailing multiplier:1 constant:-insets.right];
    NSLayoutConstraint *top = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop
                                                           relatedBy:NSLayoutRelationEqual toItem:self.view
                                                           attribute:NSLayoutAttributeTop multiplier:1 constant:insets.top];
    
    NSLayoutConstraint *bottom = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom
                                                              relatedBy:NSLayoutRelationEqual toItem:self.view
                                                              attribute:NSLayoutAttributeBottom multiplier:1 constant:-insets.bottom];
    
    NSArray *constraints = [[NSArray alloc] initWithObjects:left, right, top, bottom, nil];
    [self.view addConstraints:constraints];
}

- (void)pinViewToSafeAreaEdges:(UIView*)view  {    
    UIEdgeInsets safeAreaInsets = UIApplication.sharedApplication.keyWindow.ykf_safeAreaInsets;
    [self pinViewToEdges:view insets:safeAreaInsets];
}

@end
