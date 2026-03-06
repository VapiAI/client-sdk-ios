//
// Copyright (c) Vapi
//

import Foundation

/// Structured logger for the Vapi SDK. Provides consistent, machine-parseable
/// log output at each failure point so integrators and support engineers can
/// diagnose issues without needing to reproduce them.
enum VapiLogger {

    enum Level: String {
        case debug = "DEBUG"
        case info  = "INFO"
        case warn  = "WARN"
        case error = "ERROR"
    }

    enum Component: String {
        case urlConstruction = "URLConstruction"
        case network         = "Network"
        case webRTC          = "WebRTC"
        case callLifecycle   = "CallLifecycle"
        case appMessage      = "AppMessage"
    }

    static func log(
        level: Level,
        component: Component,
        message: String,
        context: [String: String] = [:]
    ) {
        var parts = ["[Vapi][\(level.rawValue)][\(component.rawValue)] \(message)"]
        for (key, value) in context.sorted(by: { $0.key < $1.key }) {
            parts.append("  \(key): \(value)")
        }
        print(parts.joined(separator: "\n"))
    }
}
