# Vapi iOS SDK

This package lets you start Vapi calls directly in your iOS app.

## Requirements

- iOS 13.0 or later

## Installation

### Swift Package Manager

In Xcode, go to File -> Add Packages... and enter the following URL in 'Search or Enter Package URL' textbox in the top right corner of that window: https://github.com/VapiAI/ios

Pick the desired dependency rule (under “Dependency Rule”), as well as build target (under “Add to Project”) and click “Add Package”.

### In Package.swift

To depend on the Vapi package, you can declare your dependency in your `Package.swift`:

```swift
.package(url: "https://github.com/VapiAI/ios"),
```

and add `"Vapi"` to your application/library target, `dependencies`, e.g. like this:

```swift
.target(name: "YourApp", dependencies: [
    .product(name: "Vapi", package: "ios")
],
```

## App Setup

You will need to update your project's Info.plist to add three new entries with the following keys:

- NSMicrophoneUsageDescription
- UIBackgroundModes

For the first two key's values, provide user-facing strings explaining why your app is asking for microphone access.

UIBackgroundModes is handled slightly differently and will resolve to an array. For its first item, specify the value voip. This ensures that audio will continue uninterrupted when your app is sent to the background.

To add the new entries through Xcode, open the Info.plist and add the following three entries:

| Key                                  | Type   | Value                                        |
|--------------------------------------|--------|----------------------------------------------|
| Privacy - Microphone Usage Description| String | "Your app name needs microphone access to work" |
| Required background modes            | Array  | 1 item                                       |
| ---> Item 0                          | String | "App provides Voice over IP services"        |

If you view the raw file contents of Info.plist, it should look like this:

```xml
<dict>
    ...
    <key>NSMicrophoneUsageDescription</key>
    <string>Your app name needs microphone access to work</string>
    <key>UIBackgroundModes</key>
    <array>
        <string>voip</string>
        <string>audio</string>
    </array>
    ...
</dict>
```

## Usage

### 1. Starting a Call

- **Methods:** 
  - `start(assistantId: String)`
  - `start(assistant: [String: Any])`
- **Description:** 
  - Use these methods to initiate a new call. You can either start a call by passing an `assistantId` or by providing an `assistant` dictionary with specific parameters.
  - These methods throw an error if there's already an ongoing call to ensure that only one call is active at any time.

### 2. Stopping a Call

- **Method:** `stop()`
- **Description:** 
  - This method ends an ongoing call.
  - It's an asynchronous operation, ensuring the call is properly disconnected.

### 3. Handling Events

- **Overview:** The SDK provides various events that you can listen to for handling different aspects of the call lifecycle and interactions.
- **Key Events:** 
  - `callDidStart`: Emitted when a call successfully begins.
  - `callDidEnd`: Emitted when a call is successfully ended.
  - `appMessageReceived([String: Any], from: Daily.ParticipantID)`: Occurs when a message is received during the call. Live transcripts and function calls will be sent through this.
  - `error(Swift.Error)`: Triggered if there's an error during the call setup or execution.

### Implementing in Your Project

To see these methods in action, refer to our example files:

- **SwiftUI Example:** Check the `SwiftUICallView.swift` file in the Example folder. This file demonstrates the integration of these methods in a SwiftUI view.
- **UIKit Example:** Look at the `UIKitCallViewController.swift` file for an example of using the Vapi SDK within a UIKit view controller.

These examples will guide you through effectively implementing and managing voice calls in your iOS applications using the Vapi SDK.

## License

```
MIT License

Copyright (c) 2023 Vapi Labs Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
