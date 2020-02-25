# Yubico Mobile iOS SDK (YubiKit)

**YubiKit** is an iOS library provided by Yubico to interact with YubiKeys on iOS devices. 

The library is provided with a [demo application](./YubiKitDemo/README.md) which shows complete examples of how the library can be integrated and demonstrates all the features of this library in an iOS project.

Changes to this library are documented in this [Changelog](Changelog.md).

## **About**

**YubiKit** requires a physical key to test its features. Before running the included [demo application](./YubiKitDemo/README.md) or integrating YubiKit into your own app, you need an NFC-Enabled YubiKey or a YubiKey 5Ci to test functionality.

The host application can build the library as a dependency of the application target when used inside a Xcode workspace. In addition, the  library can be packed using the `build.sh` script, which is provided in the root folder of this project.

## **Getting Started**

To get started, you can try the [demo](./YubiKitDemo/README.md) as part of this library or start integrating the library into your own application. 

## Try the Demo
The library is provided with a demo application, [**YubiKitDemo**](./YubiKitDemo). The application is implemented in Swift and it shows several examples of how to use YubiKit, including WebAuthn/FIDO2 over the accessory or NFC YubiKeys.

The YubiKit Demo application shows how the library is linked with a project so it can be used for a side-by-side comparison when adding the library to your own project.

## Integrate the library

This section is intended for developers that want to start with their own iOS app and add  the YubiKit manually.

<details><summary><strong>Step-by-step instructions</strong></summary><p>

YubiKit SDK is currently available as a library and can be added to any new or existing iOS Xcode project.

**Download or Clone YubiKit SDK**

1. The library is archived into a Zip file named YubiKit[version] where version is the version number of the packed library. 

    [Download](https://github.com/Yubico/yubikit-ios/releases/) the latest YubiKit SDK (.zip) to your desktop `or` 

    `git clone https://github.com/Yubico/yubikit-ios.git`

2. Unzip the library archive.

**Add YubiKit folder to your Xcode project**

3. Drag the entire `/YubiKit[version]/YubiKit` folder to your Xcode project. Check the option *Copy items if needed*. 

**Linked Frameworks and Libraries**

4. `Project Settings` > `General` > `Linked Frameworks and Libraries`.
Click + and select Add Other. Locate the ``libYubiKit.a`` in YubiKit/debug_universal folder and add it.

**Library Search Paths**

5. ``Build Settings`` > Filter by 'Library Search Paths', expand to show debug & release.
Set Release to ``YubiKit/release`` folder and
Set Debug to ``YubiKit/debug_universal`` folder.

**Header Search Paths**

6. ``Build Settings`` > Filter by 'Header Search Path'. Set both Debug & Release to ``./YubiKit/**`` (recursive)

**-ObjC flag**

7. Add -ObjC flag
``Build Settings`` > Filter by 'Other Linker Flags'. Add the ``-ObjC`` flag to Debug and Release.

**Bridging-Header**

8. If your target project is written in Swift, you need to provide a bridge to the YubiKit library by adding ``#import <YubiKit/YubiKit.h>`` to your bridging header. If a bridging header does not exist within your project, you can add one by following this [documentation](https://developer.apple.com/library/content/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html).
    

**Enable Custom Lightning Protocol**

`REQUIRED` if you are supporting the YubiKey 5Ci over the Lightning connector.

> The YubiKey 5Ci is an Apple MFi external accessory and communicates over iAP2. You are telling your app that all communication with the 5Ci as a supported external accessory is via `com.yubico.ylp`.

Open info.plist and add `com.yubico.ylp` as a new item under `Supported external accessory protocols`

**Grant accesss to NFC**

`REQUIRED` if you are supporting NFC-Enabled YubiKeys.

Open info.plist and add the following usage:
'Privacy - NFC Scan Usage Description' - "This application needs access to NFC"

**Grant accesss to CAMERA**

Optional: if you are planning to use the camera to read QR codes for OTP
Open info.plist and add the following usage:
'Privacy - Camera Usage Description' - "This application needs access to Camera for reading QR codes."

</p>
</details>

## Documentation
YubiKit headers are documented and the documentation is available either by reading the header file or by using the QuickHelp from Xcode (Option + Click symbol). Use this documentation for a more detailed explanation of all the methods, properties, and parameters from the API. If you are interested in implementation details for a specific category like U2F, FIDO2, or OATH, checkout the [./docs](./docs/) section.

## **Customize the Library**
YubiKit allows customizing some of its behavior by using `YubiKitConfiguration` and `YubiKitExternalLocalization`.
<details><summary><strong>Customizing YubiKit Behavior</strong></summary><p>

For providing localized strings for the user facing messages shown by the library, YubiKit provides a collection of properties in `YubiKitExternalLocalization`.

One example of a localized string is the message shown in the NFC scanning UI while the device waits for a YubiKey to be scanned. This message can be localized by setting the value of `nfcScanAlertMessage`:
	
##### Swift

```swift
let localizedAlertMessage = NSLocalizedString("NFC_SCAN_MESSAGE", comment: "Scan your YubiKey.")
YubiKitExternalLocalization.nfcScanAlertMessage = localizedAlertMessage
```

##### Objective-C

```objective-c
#import <YubiKit/YubiKit.h>
...
NSString *localizedAlertMessage = NSLocalizedString(@"NFC_SCAN_MESSAGE", @"Scan your YubiKey.");
YubiKitExternalLocalization.nfcScanAlertMessage = localizedNfcScanAlertMessage;
```

For all the available properties and their use look at the code documentation for `YubiKitExternalLocalization`.

---

**Note:**
`YubiKitExternalLocalization` provides default values in English (en-US), which are useful only for debugging and prototyping. For production code always provide localized values.

---


</p>
</details>

## **Using the Library**
Once you have integrated the library, you can implement many of the features documented below:

- [FIDO](./docs/fido2.md) - Provides FIDO2 operations accessible via the *YKFKeyFIDO2Service*.

- [U2F](./docs/u2f.md) - Provides U2F operations accessible via the *YKFKeyU2FService*.

- [OATH](./docs/oath.md) - Allows applications, such as an authenticator app to store OATH TOTP and HOTP secrets on a YubiKey and generate one-time passwords.

- [OTP](./docs/otp.md) - Provides implementation classes to obtain YubiKey OTP via accessory (5Ci) or NFC.

- [RAW](./docs/raw.md) - Allows sending raw commands to YubiKeys over two channels: *YKFKeyRawCommandService* or over a [PC/SC](https://en.wikipedia.org/wiki/PC/SC) like interface.

## **YubiKit FAQ**

<details><summary><strong>Frequently Asked Questions About YubiKit</strong></summary><p>

#### Q1. Does YubiKit store any data on the device?

Yubikit doesn't store any data locally on the device. This includes NSUserDefaults, application sandbox folders and Keychain. All the data required to perform an operation is stored in memory for the duration of the operation and then discarded.

#### Q2. Does YubiKit communicate with any services?

Yubikit doesn't communicate with any services, like web services or other type of network communication. YubiKit is a library for sending, receiving and processing the data from a YubiKey.

#### Q3. Can I use YubiKit with other devices which are not from Yubico?

YubiKit is a library which should be used only to interact with a device manufactured by Yubico. While some parts of it may work with other devices, the library was developed and tested to work with YubiKeys. When attaching a MFI accessory, YubiKit will always check if the manufacturer of the device is Yubico before connecting to it.

#### Q4. Is YubiKit compiled with support for Bitcode and Position Independent code?

Yes, YubiKit is compiled to accommodate any modern iOS project. The supplied library is compiled with Position Independent code and Bitcode. The release version of the library is optimized (Fastest, smallest).

#### Q5. Is YubiKit logging or asserting in release mode?

No, YubiKit is not logging in release mode. The logs from YubiKit will show only in debug builds to help the developer to see what YubiKit does. The same stands for assertions. YubiKit will assert in debug mode to warn the developer when invalid parameters are passed to the library or when something unexpected happened with the key. In release, the library will handle invalid states in different ways (e.g. returning nil if the object was not properly initialized, returning errors, etc.).

#### Q6. Are there any versions of iOS where YubiKit does not work?

YubiKit should work on any modern version of iOS (10+) with a few exceptions\*. It's recommended to always ask the users to upgrade to the latest version of iOS to protect them from known, old iOS issues. Supporting the last 2 version of iOS (n and n-1) is usually a good practice to keep the old versions of iOS out. According to [Apple statistics](https://developer.apple.com/support/app-store/), ~90-95% of all iOS devices run the latest 2 versions of iOS because upgrading the OS is free and Apple usually provides a device with upgrades for 5 years.

\* Some versions of iOS had bugs affecting all external accessories. iOS 11.2 was one of them where the applications could not communicate with accessories due to some bugs in the XPC communication. The bug was fixed by Apple in iOS 11.2.6. For these reasons it's recommended to take in consideration rare but possible iOS bugs when designing the application. 

#### Q7. How can I debug the application while using a MFi accessory YubiKey?

Starting from Xcode 9, the IDE provides the ability to debug the application wirelessly. In this way the physical connector is not used for connecting the device to the computer, for debugging the application. This [WWDC session](https://developer.apple.com/videos/play/wwdc2017/404/) explains the wireless debugging functionality in Xcode.

#### Q8. Are the USB-C type iOS devices supported by the YubiKey 5Ci?

The USB-C type iOS devices, such as the iPad Pro 3rd generation, have limited support when using the YubiKey 5Ci or another type of YubiKey with USB-C connector. The OS is not officially supporting external accessories on these devices. However these devices support external USB keyboards, so the OTP functionality of the key will work and the key can be used to generate Yubico OTPs and HOTPs. 

</p>
</details>

## **Additional resources**

1. Xcode Help - [Add a capability to a target](http://help.apple.com/xcode/mac/current/#/dev88ff319e7)
2. Xcode Help - [Build settings reference](http://help.apple.com/xcode/mac/current/#/itcaec37c2a6)
3. Technical Q&A QA1490 -
[Building Objective-C static libraries with categories](https://developer.apple.com/library/content/qa/qa1490/_index.html)
4. Apple Developer - [Swift and Objective-C in the Same Project](https://developer.apple.com/library/content/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html)
5. Yubico - [Developers website](https://developers.yubico.com)
6. Yubico - [Online Demo](https://demo.yubico.com) for OTP and U2F
7. Yubico - [OTP documentation](https://developers.yubico.com/OTP)
8. Yubico - [What is U2F?](https://developers.yubico.com/U2F)
9. Yubico - [YKOATH Protocol Specifications](https://developers.yubico.com/OATH/YKOATH_Protocol.html)
10. FIDO Alliance - [CTAP2 specifications](https://fidoalliance.org/specs/fido-v2.0-ps-20190130/fido-client-to-authenticator-protocol-v2.0-ps-20190130.html)
11. W3.org - [Web Authentication:
An API for accessing Public Key Credentials](https://www.w3.org/TR/webauthn/)
