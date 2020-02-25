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

#import "YubiKitManager.h"
#import "YubiKitLogger.h"
#import "YubiKitConfiguration.h"
#import "YubiKitExternalLocalization.h"
#import "YubiKitDeviceCapabilities.h"

#import "YKFOTPTextParserProtocol.h"
#import "YKFOTPURIParserProtocol.h"
#import "YKFOTPToken.h"

#import "YKFQRReaderSession.h"
#import "YKFQRCodeScanError.h"
#import "YKFNFCSession.h"
#import "YKFNFCOTPService.h"
#import "YKFNFCError.h"
#import "YKFNFCTagDescription.h"

#import "YKFAccessorySession.h"
#import "YKFAccessoryDescription.h"

#import "YKFKeySessionError.h"
#import "YKFKeyFIDO2Error.h"
#import "YKFKeyU2FError.h"
#import "YKFKeyOATHError.h"
#import "YKFKeyAPDUError.h"

#import "YKFKeyU2FService.h"
#import "YKFKeyFIDO2Service.h"
#import "YKFKeyOATHService.h"
#import "YKFKeyRawCommandService.h"

#import "YKFKeyFIDO2Request.h"
#import "YKFKeyFIDO2MakeCredentialRequest.h"
#import "YKFKeyFIDO2GetAssertionRequest.h"
#import "YKFKeyFIDO2VerifyPinRequest.h"
#import "YKFKeyFIDO2SetPinRequest.h"
#import "YKFKeyFIDO2ChangePinRequest.h"

#import "YKFPCSC.h"

#import "YKFNSDataAdditions.h"
#import "YKFWebAuthnClientData.h"
