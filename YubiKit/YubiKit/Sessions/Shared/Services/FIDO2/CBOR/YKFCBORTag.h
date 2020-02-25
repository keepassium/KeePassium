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

/*
 Positive Integer Tags - Major type 0
 First 3 bits of the major type are 0 (0b000_00000). No mask is required for major type 0.
 */

static const UInt8 YKFCBORUInt8Tag   = 0x18; // 24
static const UInt8 YKFCBORUInt16Tag  = 0x19; // 25
static const UInt8 YKFCBORUInt32Tag  = 0x1A; // 26
static const UInt8 YKFCBORUInt64Tag  = 0x1B; // 27

/*
 Negative Integer Tags - Major type 1
 First 3 bits of the major type are 1 (0b001_00000). Minor types are the same as positive integers.
 */
static const UInt8 YKFCBORNegativeIntegerTagMask = 0b00100000;

static const UInt8 YKFCBORSInt8Tag   = YKFCBORUInt8Tag  | YKFCBORNegativeIntegerTagMask;
static const UInt8 YKFCBORSInt16Tag  = YKFCBORUInt16Tag | YKFCBORNegativeIntegerTagMask;
static const UInt8 YKFCBORSInt32Tag  = YKFCBORUInt32Tag | YKFCBORNegativeIntegerTagMask;
static const UInt8 YKFCBORSInt64Tag  = YKFCBORUInt64Tag | YKFCBORNegativeIntegerTagMask;

/*
 Byte String Tags - Major type 2
 First 3 bits of the major type are 2 (0b010_00000).
 */
static const UInt8 YKFCBORByteStringTagMask = 0b01000000;

/*
 Text String Tags - Major type 3
 First 3 bits of the major type are 3 (0b011_00000).
 */
static const UInt8 YKFCBORTextStringTagMask = 0b01100000;

/*
 Array Tags - Major type 4
 First 3 bits of the major type are 4 (0b100_00000).
 */
static const UInt8 YKFCBORArrayTagMask = 0b10000000;

/*
 Map - Major type 5
 First 3 bits of the major type are 5 (0b101_00000).
 */
static const UInt8 YKFCBORMapTagMask = 0b10100000;
