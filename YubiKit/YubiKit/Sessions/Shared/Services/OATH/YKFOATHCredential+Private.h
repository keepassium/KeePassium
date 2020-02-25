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

@interface YKFOATHCredential()

/*!
 The name of the credential is precomputed when initialized with an URL like this
 <period>/label if the credential is of TOTP type or label if the credential is HOTP.
 The name of the credential is used by the key to identify which stored credential
 to use for a compute operation when requested.
 The name may not have more then 64 bytes (or 64 ASCI characters) which is the maximum size
 accepted by the YubiKey. This property can be overidden if the name is larger and an application
 mapping between the name and credential should be created.
 */
@property (nonatomic, nonnull) NSString *key;

@end
