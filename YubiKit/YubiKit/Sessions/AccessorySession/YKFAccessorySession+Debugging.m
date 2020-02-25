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

#import "YKFAccessorySession+Debugging.h"
#import "YKFLogger.h"

#ifdef DEBUG

@implementation YKFAccessorySession(Debugging)

- (void)checkApplicationConfiguration {
    // Search for the app bundle instead of using mainBundle to retrieve it when the library may be used inside frameworks.
    NSArray *bundlesArray = NSBundle.allBundles;
    NSBundle *applicationBundle = nil;
    for (NSBundle *bundle in bundlesArray) {
        NSString *bundlePath = bundle.bundlePath;
        if ([bundlePath hasSuffix:@".app"]) {
            applicationBundle = bundle;
            break;
        }
    }
    if (!applicationBundle) {
        YKFLogError(@"Could not locate the application bundle.");
    } else {
        NSArray *plistAccessoryProtocols = applicationBundle.infoDictionary[@"UISupportedExternalAccessoryProtocols"];
        if (plistAccessoryProtocols) {
            YKFLogInfo(@"The application defines protocols in Info.plist:\n%@", plistAccessoryProtocols.description);
        } else {
            YKFLogError(@"The application must define the UISupportedExternalAccessoryProtocols in the Info plist.");
        }
    }
}

@end

#endif
