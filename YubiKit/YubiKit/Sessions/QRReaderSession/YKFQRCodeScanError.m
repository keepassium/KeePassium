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

#import "YKFQRCodeScanError.h"
#import "YKFQRCodeScanError+Errors.h"

NSString* const YKFQRCodeScanErrorDomain = @"YKQRCodeScanError";

int const YKFQRCodeScanErrorNoCameraAvailableCode = 1;
NSString* const YKFQRCodeScanErrorNoCameraAvailableDescription = @"No capture device available.";

int const YKFQRCodeScanErrorUnableToCreateCaptureDeviceInputCode = 2;
NSString* const YKFQRCodeScanErrorUnableToCreateCaptureDeviceInputDescription = @"Unable to create capture device input.";

int const YKFQRCodeScanErrorUnableToAddDeviceInputCode = 3;
NSString* const YKFQRCodeScanErrorUnableToAddDeviceInputDescription = @"Unable to add capture input to capture device.";

int const YKFQRCodeScanErrorUnableToAddQrDetectorCode = 4;
NSString* const YKFQRCodeScanErrorUnableToAddQrDetectorDescription = @"Unable to add QR metadata detector output.";

int const YKFQRCodeScanErrorNoDataAvailableCode = 5;
NSString* const YKFQRCodeScanErrorNoDataAvailableDescription = @"No data after QR code scan.";


@implementation YKFQRCodeScanError

+ (YKFQRCodeScanError *)noCameraAvailableError {
    return [[YKFQRCodeScanError alloc] initWithCode:YKFQRCodeScanErrorNoCameraAvailableCode
                                     description:YKFQRCodeScanErrorNoCameraAvailableDescription];
}

+ (YKFQRCodeScanError *)unableToCreateCaptureDeviceInputError {
    return [[YKFQRCodeScanError alloc] initWithCode:YKFQRCodeScanErrorUnableToCreateCaptureDeviceInputCode
                                        description:YKFQRCodeScanErrorUnableToCreateCaptureDeviceInputDescription];
}

+ (YKFQRCodeScanError *)unableToAddDeviceInputError {
    return [[YKFQRCodeScanError alloc] initWithCode:YKFQRCodeScanErrorUnableToAddDeviceInputCode
                                        description:YKFQRCodeScanErrorUnableToAddDeviceInputDescription];
}

+ (YKFQRCodeScanError *)unableToAddQrDetectorError {
    return [[YKFQRCodeScanError alloc] initWithCode:YKFQRCodeScanErrorUnableToAddQrDetectorCode
                                        description:YKFQRCodeScanErrorUnableToAddQrDetectorDescription];
}

+ (YKFQRCodeScanError *)noDataAvailableError {
    return [[YKFQRCodeScanError alloc] initWithCode:YKFQRCodeScanErrorNoDataAvailableCode
                                        description:YKFQRCodeScanErrorNoDataAvailableDescription];
}

#pragma mark - Creation

- (instancetype)initWithCode:(int)code description:(NSString *)description {
    return [super initWithDomain:YKFQRCodeScanErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: description}];
}

@end
